#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class HostedPublicCITest < Minitest::Test
  HOSTED_RUNNER = "macos-26-intel"
  ORDINARY_JOBS = {
    ".github/workflows/validation.yml" => {
      "classify-changes" => ["Classify changed files", "ubuntu-latest"],
      "ci-validation" => ["CI workflow validation", "ubuntu-latest"],
      "fastlane-smoke-test" => ["Locked Fastlane smoke test", HOSTED_RUNNER],
      "build-test" => ["Build and test", HOSTED_RUNNER],
      "code-coverage" => ["Code coverage", HOSTED_RUNNER]
    },
    ".github/workflows/full-tests.yml" => {
      "full-test-suite" => ["Full Test Suite", HOSTED_RUNNER]
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
        assert_equal({ "contents" => "read" }, workflow.fetch("permissions"), "#{path} needs read-only default permissions")
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
    %w[validation.yml full-tests.yml pr-ui-screenshots.yml].each do |name|
      path = File.join(".github/workflows", name)
      workflow = YAML.load_file(path)
      events = workflow["on"] || workflow[true] || {}
      assert events.key?("pull_request"), "#{path} must run for same-repository and fork pull requests"

      text = File.read(path)
      refute_includes text, "pull_request_target"
      refute_match(/\$\{\{\s*secrets\./, text)
      refute_includes text, "self-hosted"
      refute_includes text, "home-stuff-inventory, xcode"
      refute_match(%r{repos/[^$\s]+/home-stuff-inventory}, text)
    end
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

    job = workflow.dig("jobs", "full-test-suite")
    assert_equal "Full Test Suite", job.fetch("name")
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
    assert_operator validation.scan("bash .github/scripts/configure_hosted_xcode.sh").length, :>=, 2
    assert_includes validation, '$RUNNER_TOOL_CACHE/Ruby/4.0.5/x64/bin'
    assert_includes validation, "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
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
end
