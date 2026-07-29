#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class HostedPublicCITest < Minitest::Test
  HOSTED_RUNNER = "macos-26-intel"
  APPLE_SILICON_RUNNER = "macos-26"
  ORDINARY_JOBS = {
    ".github/workflows/validation.yml" => {
      "classify-changes" => ["Classify changed files", "ubuntu-latest"],
      "ci-contracts" => ["CI contract checks", "ubuntu-latest"],
      "ci-validation" => ["CI workflow validation", "ubuntu-latest"],
      "fastlane-smoke-test" => ["Locked Fastlane smoke test", "ubuntu-latest"],
      "build-test" => ["Build and test", APPLE_SILICON_RUNNER],
      "code-coverage" => ["Code coverage", "ubuntu-latest"]
    },
    ".github/workflows/full-tests.yml" => {
      "source" => ["Resolve Exact Source", "ubuntu-latest"],
      "build-and-unit-tests" => ["Build, Unit, and Localization Tests", APPLE_SILICON_RUNNER],
      "ui-shards" => ['UI Shard ${{ matrix.shard }}', APPLE_SILICON_RUNNER],
      "full-test-suite" => ["Full Test Suite", "ubuntu-latest"]
    },
    ".github/workflows/pr-ui-screenshots.yml" => {
      "pr-ui-screenshots" => ["Capture PR UI screenshots", HOSTED_RUNNER]
    },
    ".github/workflows/release-app-store-screenshots.yml" => {
      "release-app-store-screenshots" => ["Capture release App Store screenshots", HOSTED_RUNNER]
    }
  }.freeze

  def test_public_jobs_use_stable_names_and_only_github_hosted_runners
    ORDINARY_JOBS.each do |path, expected_jobs|
      workflow = YAML.load_file(path)
      unless path.end_with?("pr-ui-screenshots.yml")
        expected_permissions = path.end_with?("full-tests.yml") ?
          { "actions" => "read", "contents" => "read" } :
          { "contents" => "read" }
        assert_equal expected_permissions, workflow.fetch("permissions"), "#{path} needs read-only default permissions"
      end

      expected_jobs.each do |job_id, (check_name, runner)|
        job = workflow.dig("jobs", job_id)
        refute_nil job, "#{path} is missing stable job #{job_id}"
        assert_equal check_name, job.fetch("name"), "#{path}:#{job_id} check name changed"
        assert_equal runner, job.fetch("runs-on"), "#{path}:#{job_id} is not GitHub-hosted"
        refute_equal "${{ false }}", job["if"], "#{path}:#{job_id} remains disabled"
      end
    end
  end

  def test_pull_request_baseline_is_secretless_and_has_no_private_fallback
    %w[validation.yml pr-ui-screenshots.yml].each do |name|
      path = File.join(".github/workflows", name)
      workflow = YAML.load_file(path)
      events = workflow["on"] || workflow[true] || {}
      assert events.key?("pull_request"), "#{path} must run for same-repository and fork pull requests"
      if name == "validation.yml"
        refute events.key?("push"), "#{path} must not repeat complete validation after a protected merge"
        assert events.key?("workflow_dispatch"), "#{path} must retain manual validation"
      end

      text = File.read(path)
      refute_includes text, "pull_request_target"
      refute_match(/\$\{\{\s*secrets\./, text)
      refute_includes text, "self-hosted"
      refute_includes text, "home-stuff-inventory, xcode"
      refute_match(%r{repos/[^$\s]+/home-stuff-inventory}, text)
    end
  end

  def test_full_test_validation_is_release_only
    path = ".github/workflows/full-tests.yml"
    workflow = YAML.load_file(path)
    events = workflow["on"] || workflow[true] || {}

    refute events.key?("pull_request"), "#{path} must not run for ordinary pull requests"
    assert_equal ["v*"], events.dig("push", "tags")
    assert events.key?("workflow_dispatch"), "#{path} must support explicit version validation"
    assert events.key?("workflow_call"), "#{path} must remain reusable by release automation"
  end

  def test_ci_lane_changes_exercise_the_hosted_app_baseline
    workflow = File.read(".github/workflows/validation.yml")
    ci_case = workflow[/\.github\/workflows\/\*\|\.github\/scripts\/\*\|Gemfile\|fastlane\/\*\).*?;;/m]
    refute_nil ci_case
    assert_includes ci_case, "app_validation_required=true"
    assert_includes ci_case, "ci_validation_required=true"
  end

  def test_every_ordinary_lane_records_or_verifies_the_executed_sha
    required_evidence = {
      ".github/workflows/validation.yml" => ["Verify exact validation source", "github.sha"],
      ".github/workflows/full-tests.yml" => ["Record exact validated source", "VALIDATED_SHA"],
      ".github/workflows/pr-ui-screenshots.yml" => ["Summarize resolved source", "resolved_sha"],
      ".github/workflows/release-app-store-screenshots.yml" => ["Summarize resolved release source", "source_sha"]
    }

    required_evidence.each do |path, markers|
      text = File.read(path)
      markers.each { |marker| assert_includes text, marker, "#{path} is missing exact-SHA evidence #{marker}" }
    end
  end

  def test_full_test_release_tag_uses_exact_event_sha_without_mutable_override
    path = ".github/workflows/full-tests.yml"
    workflow = YAML.load_file(path)
    events = workflow["on"] || workflow[true] || {}
    assert_equal ["v*"], events.dig("push", "tags")

    job = workflow.dig("jobs", "source")
    assert_equal "Resolve Exact Source", job.fetch("name")
    checkout = job.fetch("steps").find { |step| step["name"] == "Check out repository" }
    assert_equal "${{ github.event_name == 'push' && github.sha || inputs.source_ref || github.sha }}",
                 checkout.dig("with", "ref")

    source = job.fetch("steps").find { |step| step["name"] == "Record exact validated source" }
    assert_equal "${{ github.event_name }}", source.dig("env", "EVENT_NAME")
    assert_equal "${{ github.ref }}", source.dig("env", "EVENT_REF")
    assert_equal "${{ github.sha }}", source.dig("env", "EVENT_SHA")
    assert_includes source.fetch("run"), 'if [[ "$EVENT_NAME" == "push" ]]'
    assert_includes source.fetch("run"), '[[ "$EVENT_REF" != refs/tags/v* ]]'
    assert_includes source.fetch("run"), '[[ -n "$SOURCE_REF" ]]'
    assert_includes source.fetch("run"), '[[ "$sha" != "$EVENT_SHA" ]]'
  end

  def test_hosted_toolchain_is_explicit_and_verified
    helper = File.read(".github/scripts/configure_hosted_xcode.sh")
    assert_includes helper, "/Applications/Xcode_26.6.app/Contents/Developer"
    assert_includes helper, 'expected_xcode_build="17F113"'
    assert_includes helper, 'simulator_runtime="iOS 26.5"'
    assert_includes helper, "sudo xcode-select --switch"
    assert_includes helper, "sudo xcodebuild -runFirstLaunch"
    assert_includes helper, "xcode-select -p"

    ORDINARY_JOBS.each_key do |path|
      next if path.end_with?("validation.yml")
      assert_includes File.read(path), "bash .github/scripts/configure_hosted_xcode.sh"
    end
    validation = File.read(".github/workflows/validation.yml")
    assert_equal 2, validation.scan("bash .github/scripts/configure_hosted_xcode.sh").length
    assert_includes validation, "ruby/setup-ruby@a30dfa457ad68707b8b910ac3a244714b61c0626"
    assert_includes validation, 'ruby-version: "4.0.5"'
    assert_includes validation, 'bundler: "2.7.2"'
    refute_includes validation, "$RUNNER_TOOL_CACHE/Ruby/"
    assert_includes validation, "ruby .github/scripts/bounded_process.rb run"
    assert_includes validation, "--timeout-seconds 900"
    assert_includes validation, "TestResults/ui-smoke-summary.json"
    assert_includes validation, "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
    assert_equal 1, validation.scan("build-for-testing").length
    assert_operator validation.scan("test-without-building").length, :>=, 2
    assert_includes validation, "scripts/ci/check-code-coverage.py TestResults/UnitTests.xcresult --minimum 90"
    assert_includes validation, "ordinary_validation.rb validate-result"
    assert_includes validation, "ordinary_validation.rb summarize"
  end

  def test_public_artifacts_are_short_lived_and_not_named_from_free_form_input
    ORDINARY_JOBS.each_key do |path|
      workflow = YAML.load_file(path)
      workflow.fetch("jobs").each_value do |job|
        Array(job["steps"]).select { |step| step["uses"].to_s.start_with?("actions/upload-artifact@") }.each do |upload|
          retention = upload.dig("with", "retention-days")
          assert_operator retention, :<=, 3, "#{path} retains a public artifact longer than three days"
          refute_includes upload.dig("with", "name").to_s, "inputs.", "#{path} uses free-form input in an artifact name"
        end
      end
    end
  end

  def test_full_test_products_download_obeys_the_organization_action_allowlist
    workflow = YAML.load_file(".github/workflows/full-tests.yml")
    build_job = workflow.dig("jobs", "build-and-unit-tests")
    shard_job = workflow.dig("jobs", "ui-shards")
    upload = build_job.fetch("steps").find { |step| step["name"] == "Upload immutable shared test products" }
    download = shard_job.fetch("steps").find { |step| step["name"] == "Download immutable shared test products" }

    assert_equal "${{ steps.test-products.outputs.artifact-id }}",
                 build_job.dig("outputs", "test_products_artifact_id")
    assert_equal "test-products", upload.fetch("id")
    assert_equal "${{ needs.build-and-unit-tests.outputs.test_products_artifact_id }}",
                 download.dig("env", "ARTIFACT_ID")
    assert_equal "${{ github.token }}", download.dig("env", "GITHUB_TOKEN")
    assert_includes download.fetch("run"), "api.github.com/repos/$GITHUB_REPOSITORY/actions/artifacts/$ARTIFACT_ID/zip"
    assert_includes download.fetch("run"), '[[ ! "$ARTIFACT_ID" =~ ^[0-9]+$ ]]'
    refute_includes File.read(".github/workflows/full-tests.yml"), "actions/download-artifact@"
  end
end
