#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "yaml"
require_relative "release_private_handoff"

class ReleasePrivateHandoffTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SHA = "a" * 40

  def test_dispatch_response_requires_exact_run_id_and_url
    assert_equal 123, ReleasePrivateHandoff.validate_dispatch!("workflow_run_id" => 123,
      "run_url" => "https://api.github.com/repos/stradivarius-ios-apps/home-stuff-inventory/actions/runs/123")
    assert_raises(KeyError) { ReleasePrivateHandoff.validate_dispatch!({}) }
    assert_raises(KeyError) { ReleasePrivateHandoff.validate_dispatch!("workflow_run_id" => 123) }
    assert_raises(RuntimeError) { ReleasePrivateHandoff.validate_dispatch!("workflow_run_id" => "123", "run_url" => "https://api.github.com/repos/stradivarius-ios-apps/home-stuff-inventory/actions/runs/123") }
    assert_raises(RuntimeError) { ReleasePrivateHandoff.validate_dispatch!("workflow_run_id" => 123, "run_url" => "https://elsewhere.test/123") }
  end

  def test_installation_token_has_only_actions_write_on_single_repository
    request = nil
    original_request = ReleasePrivateHandoff.method(:request!)
    ReleasePrivateHandoff.define_singleton_method(:request!) do |method, path, token:, body:|
      request = [method, path, body]
      { "token" => "mock-token" }
    end
    key = OpenSSL::PKey::RSA.generate(2048)
    assert_equal "mock-token", ReleasePrivateHandoff.installation_token!(app_id: "9", installation_id: "10", private_key: key.to_pem)
    assert_equal [:post, "/app/installations/10/access_tokens",
      { repositories: ["home-stuff-inventory"], permissions: { actions: "write" } }], request
  ensure
    ReleasePrivateHandoff.define_singleton_method(:request!, original_request)
  end

  def test_wait_result_fails_closed_on_wrong_run_or_upload_failure
    run = { "id" => 123, "workflow_id" => 318196942, "event" => "workflow_dispatch",
      "head_branch" => "main", "head_sha" => SHA, "actor" => { "login" => "release-handoff[bot]" },
      "status" => "completed", "conclusion" => "success" }
    assert_equal "success", ReleasePrivateHandoff.validate_run!(run, id: 123, private_sha: SHA, app_actor: "release-handoff[bot]")
    assert_raises(RuntimeError) { ReleasePrivateHandoff.validate_run!(run.merge("id" => 124), id: 123, private_sha: SHA, app_actor: "release-handoff[bot]") }
    assert_raises(RuntimeError) { ReleasePrivateHandoff.validate_run!(run.merge("workflow_id" => 1), id: 123, private_sha: SHA, app_actor: "release-handoff[bot]") }
    assert_raises(RuntimeError) { ReleasePrivateHandoff.validate_run!(run.merge("actor" => { "login" => "other[bot]" }), id: 123, private_sha: SHA, app_actor: "release-handoff[bot]") }
    assert_equal "failure", ReleasePrivateHandoff.validate_run!(run.merge("conclusion" => "failure"), id: 123, private_sha: SHA, app_actor: "release-handoff[bot]")
    assert_equal "cancelled", ReleasePrivateHandoff.validate_run!(run.merge("conclusion" => "cancelled"), id: 123, private_sha: SHA, app_actor: "release-handoff[bot]")
  end

  def test_private_stage_status_requires_one_complete_allowlisted_summary
    name = "Release stage status / provenance=success;archive=success;upload=success;screenshots=success;metadata=recovered_partial;readiness=ready_for_app_review"
    assert_equal "ready_for_app_review", ReleasePrivateHandoff.stage_status_from_jobs!("jobs" => [{ "name" => name }]).fetch("readiness")
    assert_raises(RuntimeError) { ReleasePrivateHandoff.stage_status_from_jobs!("jobs" => [{ "name" => name }, { "name" => name }]) }
    assert_raises(RuntimeError) { ReleasePrivateHandoff.stage_status_from_jobs!("jobs" => [{ "name" => "Release stage status / archive=unknown" }]) }
    %w[
      provenance=success;provenance=success
      archive=success;archive=success
      unknown=success
      provenance=
      =success
      provenance
    ].each do |invalid|
      record = "Release stage status / #{invalid};archive=success;upload=success;screenshots=success;metadata=published;readiness=ready_for_app_review"
      assert_raises(RuntimeError) { ReleasePrivateHandoff.stage_status_from_jobs!("jobs" => [{ "name" => record }]) }
    end
    missing = "Release stage status / provenance=success;archive=success;upload=success;screenshots=success;metadata=published"
    invalid_readiness = "Release stage status / provenance=success;archive=success;upload=success;screenshots=success;metadata=published;readiness=success"
    [missing, invalid_readiness].each do |record|
      assert_raises(RuntimeError) { ReleasePrivateHandoff.stage_status_from_jobs!("jobs" => [{ "name" => record }]) }
    end
  end

  def test_dispatches_only_dedicated_workflow_and_waits_for_returned_run
    calls = []
    api = lambda do |method, path, token:, body: nil|
      calls << [method, path, body]
      if method == :post
        { "workflow_run_id" => 123, "run_url" => "https://api.github.com/repos/stradivarius-ios-apps/home-stuff-inventory/actions/runs/123" }
      elsif path.end_with?("/jobs?per_page=100")
        { "jobs" => [{ "name" => "Release stage status / provenance=success;archive=success;upload=success;screenshots=success;metadata=published;readiness=ready_for_app_review" }] }
      else
        { "id" => 123, "workflow_id" => 318196942, "event" => "workflow_dispatch",
          "head_branch" => "main", "head_sha" => SHA, "actor" => { "login" => "release-handoff[bot]" },
          "status" => "completed", "conclusion" => "success" }
      end
    end
    Dir.mktmpdir do |dir|
      output = File.join(dir, "output")
      original = ENV["GITHUB_OUTPUT"]
      original_token = ReleasePrivateHandoff.method(:installation_token!)
      original_request = ReleasePrivateHandoff.method(:request!)
      ENV["GITHUB_OUTPUT"] = output
      ReleasePrivateHandoff.define_singleton_method(:installation_token!) { |**_args| "test-token" }
      ReleasePrivateHandoff.define_singleton_method(:request!, api)
      assert_equal 123, ReleasePrivateHandoff.execute!(sha: SHA, tag: "v1.3.0", public_run_id: "456",
        app_id: "9", installation_id: "10", private_key: "not-used", app_actor: "release-handoff[bot]")
      assert_equal "private_run_id=123\nprivate_provenance=success\nprivate_archive=success\nprivate_upload=success\nprivate_screenshots=success\nprivate_metadata=published\nprivate_readiness=ready_for_app_review\n", File.read(output)
    ensure
      ENV["GITHUB_OUTPUT"] = original
      ReleasePrivateHandoff.define_singleton_method(:installation_token!, original_token)
      ReleasePrivateHandoff.define_singleton_method(:request!, original_request)
    end
    assert_equal [:post, :get, :get], calls.map(&:first)
    assert_equal "/repos/stradivarius-ios-apps/home-stuff-inventory/actions/workflows/private-public-release.yml/dispatches", calls.first[1]
    assert_equal "/repos/stradivarius-ios-apps/home-stuff-inventory/actions/runs/123/jobs?per_page=100", calls.last[1]
    assert_equal({ ref: "main",
      inputs: { public_source_sha: SHA, public_release_tag: "v1.3.0", upload: "true", publish_metadata: "true", publish_screenshots: "true", verify_readiness: "true", public_run_id: "456" } }, calls.first[2])
  end

  def test_failed_or_cancelled_private_runs_write_safe_outputs_before_failing
    %w[failure cancelled].each do |conclusion|
      output = File.join(Dir.mktmpdir, "output")
      original_output, original_token, original_request = ENV["GITHUB_OUTPUT"], ReleasePrivateHandoff.method(:installation_token!), ReleasePrivateHandoff.method(:request!)
      ENV["GITHUB_OUTPUT"] = output
      ReleasePrivateHandoff.define_singleton_method(:installation_token!) { |**_| "token" }
      ReleasePrivateHandoff.define_singleton_method(:request!) do |method, path, token:, body: nil|
        if method == :post
          { "workflow_run_id" => 123, "run_url" => "https://api.github.com/repos/stradivarius-ios-apps/home-stuff-inventory/actions/runs/123" }
        elsif path.end_with?("/jobs?per_page=100")
          { "jobs" => [{ "name" => "Release stage status / provenance=success;archive=success;upload=success;screenshots=success;metadata=failed;readiness=not-requested" }] }
        else
          { "id" => 123, "workflow_id" => 318196942, "event" => "workflow_dispatch", "head_branch" => "main", "head_sha" => SHA, "actor" => { "login" => "release-handoff[bot]" }, "status" => "completed", "conclusion" => conclusion }
        end
      end
      assert_raises(RuntimeError) { ReleasePrivateHandoff.execute!(sha: SHA, tag: "v1.3.0", public_run_id: "456", app_id: "9", installation_id: "10", private_key: "unused", app_actor: "release-handoff[bot]") }
      assert_includes File.read(output), "private_metadata=failed\n"
      assert_includes File.read(output), "private_provenance=success\n"
    ensure
      ENV["GITHUB_OUTPUT"] = original_output
      ReleasePrivateHandoff.define_singleton_method(:installation_token!, original_token)
      ReleasePrivateHandoff.define_singleton_method(:request!, original_request)
    end
  end

  def test_workflow_pins_identity_and_restricts_secret_job
    flow = YAML.load_file(File.join(ROOT, ".github/workflows/release.yml"))
    events = flow[true] || flow.fetch("on")
    assert_equal ["workflow_dispatch"], events.keys
    assert_equal false, events.dig("workflow_dispatch", "inputs", "validation_only", "default")
    assert_equal false, events.dig("workflow_dispatch", "inputs", "existing_protected_tag", "default")
    assert_equal false, flow.dig("concurrency", "cancel-in-progress")
    assert_equal "./.github/workflows/validation.yml", flow.dig("jobs", "validation", "uses")
    assert_equal true, flow.dig("jobs", "validation", "with", "run_app_validation")
    evidence_job = flow.dig("jobs", "evidence")
    assert_equal({ "contents" => "read", "checks" => "read" }, evidence_job.fetch("permissions"))
    checkout_index = evidence_job.fetch("steps").index { |step| step["name"] == "Check out captured release source" }
    helper_index = evidence_job.fetch("steps").index { |step| step["run"].to_s.include?("release_check_evidence") }
    refute_nil checkout_index
    refute_nil helper_index
    assert_operator checkout_index, :<, helper_index
    checkout = evidence_job.fetch("steps").fetch(checkout_index)
    assert_equal "actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0", checkout.fetch("uses")
    assert_equal "${{ needs.identity.outputs.sha }}", checkout.dig("with", "ref")
    assert_equal false, checkout.dig("with", "persist-credentials")
    assert_includes flow.dig("jobs", "public-release", "if"), "needs.evidence.result == 'success'"
    assert_equal "${{ needs.identity.outputs.sha }}", flow.dig("jobs", "public-release", "with", "trusted_release_sha")
    assert_equal "${{ inputs.existing_protected_tag }}", flow.dig("jobs", "public-release", "with", "existing_protected_tag")
    private_job = flow.dig("jobs", "private-release")
    assert_equal "release-orchestration", private_job.fetch("environment")
    assert_equal({ "contents" => "read" }, private_job.fetch("permissions"))
    assert_includes private_job.fetch("if"), "needs.public-release.result == 'success'"
    assert_includes flow.dig("jobs", "public-release", "if"), "!inputs.validation_only"
    assert_includes private_job.fetch("if"), "!inputs.validation_only"
    assert_equal "${{ needs.identity.outputs.sha }}", flow.dig("jobs", "private-release", "steps").last.dig("env", "PUBLIC_SOURCE_SHA")
    assert_equal "${{ steps.private.outputs.private_readiness }}", private_job.dig("outputs", "readiness")
    assert_equal "${{ steps.private.outputs.private_provenance }}", private_job.dig("outputs", "provenance")
    refute flow.dig("jobs", "identity", "outputs").key?("provenance")
    assert_equal "${{ needs.private-release.outputs.provenance }}", flow.dig("jobs", "summary", "steps").first.dig("env", "PRIVATE_PROVENANCE")
    summary = flow.dig("jobs", "summary", "steps").first.fetch("run")
    assert_includes summary, "ready_for_app_review"
    assert_includes summary, "pending_processing"
    refute_includes summary, "TestFlight upload accepted for processing."
    create_flow = YAML.load_file(File.join(ROOT, ".github/workflows/create-github-release.yml"))
    create_events = create_flow[true] || create_flow.fetch("on")
    assert_equal false, create_events.dig("workflow_call", "inputs", "existing_protected_tag", "default")
    release_steps = create_flow.dig("jobs", "create-github-release", "steps")
    identity = flow.dig("jobs", "identity")
    preflight_step = identity.fetch("steps").find { |step| step["id"] == "identity" }
    assert_includes preflight_step.fetch("run"), "create_github_release_preflight.rb"
    assert_includes preflight_step.fetch("run"), "--trusted-release-sha"
    preflight_outputs = File.read(File.join(ROOT, ".github/scripts/create_github_release_preflight.rb")).scan(/write_output\("([^\"]+)"/).flatten
    assert_equal "${{ steps.identity.outputs.source_sha }}", identity.dig("outputs", "sha")
    assert_equal "${{ steps.identity.outputs.version }}", identity.dig("outputs", "version")
    assert_equal "${{ steps.identity.outputs.tag_name }}", identity.dig("outputs", "tag")
    %w[source_sha version tag_name].each { |name| assert_includes preflight_outputs, name }
    note_step = identity.fetch("steps").find { |step| step["name"] == "Validate exact-version App Store What's New" }
    refute_nil note_step
    assert_includes note_step.fetch("run"), "validate_app_store_release_notes.rb fastlane/release_notes"
    assert_equal "${{ steps.identity.outputs.version }}", note_step.dig("env", "RELEASE_VERSION")
    assert_operator identity.fetch("steps").index(note_step), :>, identity.fetch("steps").index(preflight_step)
    assert_includes flow.dig("jobs", "validation").fetch("needs"), "identity"
    assert_includes release_steps.find { |step| step["id"] == "preflight" }.fetch("run"), "--existing-protected-tag"
    create_events = create_flow[true] || create_flow.fetch("on")
    assert create_events.key?("workflow_call")
    refute create_events.key?("workflow_dispatch")
    assert_equal({ "RELEASE_TAG_APP_PRIVATE_KEY" => { "required" => false } }, create_events.dig("workflow_call", "secrets"))
    assert_equal({ "RELEASE_TAG_APP_PRIVATE_KEY" => "${{ secrets.RELEASE_TAG_APP_PRIVATE_KEY }}" }, flow.dig("jobs", "public-release", "secrets"))
    refute_match(/secrets:\s*inherit/, File.read(File.join(ROOT, ".github/workflows/release.yml")))
    credential_gate = release_steps.find { |step| step["name"] == "Require production tag App credentials" }
    refute_nil credential_gate
    assert_equal "${{ vars.RELEASE_TAG_APP_ID }}", credential_gate.dig("env", "RELEASE_TAG_APP_ID")
    assert_equal "${{ secrets.RELEASE_TAG_APP_PRIVATE_KEY }}", credential_gate.dig("env", "RELEASE_TAG_APP_PRIVATE_KEY")
    assert_includes credential_gate.fetch("run"), '[[ -z "$RELEASE_TAG_APP_ID" || -z "$RELEASE_TAG_APP_PRIVATE_KEY" ]]'
    assert_operator release_steps.index(credential_gate), :<, release_steps.index { |step| step["id"] == "release-tag-token" }
    assert_equal ["identity", "evidence"], flow.dig("jobs", "public-release", "needs")
    assert_equal "${{ needs.identity.outputs.sha }}", flow.dig("jobs", "public-release", "with", "trusted_release_sha")
    assert_includes flow.dig("jobs", "public-release", "if"), "!inputs.validation_only"
    assert_equal "./.github/workflows/create-github-release.yml", flow.dig("jobs", "public-release", "uses")
    selected_action = JSON.parse(File.read(File.join(ROOT, "docs/security/public-repository-settings-plan.json"))).dig("desired_controls", "actions", "release_tag_token_action")
    assert_equal "actions/create-github-app-token@064492a9a1762067169d50c792a7dc02bc3d1254", selected_action
    assert_equal selected_action, release_steps.find { |step| step["id"] == "release-tag-token" }.fetch("uses")
    create_tag = release_steps.find { |step| step["id"] == "release" }.fetch("run")
    assert_includes create_tag, 'if [[ "$EXISTING_EXACT_TAG" != "true" ]]'
    assert_includes create_tag, 'git cat-file -t "refs/tags/$TAG_NAME"'
    assert_includes create_tag, 'git ls-remote origin "refs/tags/$TAG_NAME^{}"'
    release_checkout = release_steps.find { |step| step["name"] == "Check out release source" }
    assert_equal "${{ steps.release-tag-token.outputs.token }}", release_checkout.dig("with", "token")
    assert_equal true, release_checkout.dig("with", "persist-credentials")
    assert_equal "${{ steps.release-tag-token.outputs.token }}", release_steps.find { |step| step["id"] == "release" }.dig("env", "GH_TOKEN")
    assert_equal "${{ steps.release-tag-token.outputs.token }}", release_steps.find { |step| step["id"] == "preflight" }.dig("env", "GH_TOKEN")
    assert_includes flow.dig("jobs", "public-release", "if"), "needs.evidence.result == 'success'"
    assert_includes flow.dig("jobs", "public-release", "if"), "!inputs.validation_only"
    text = File.read(File.join(ROOT, ".github/workflows/release.yml"))
    refute_match(/pull_request_target|write-all|APP_STORE_CONNECT_API_PRIVATE_KEY/, text)
    refute_match(/latest.run|actions\/runs\?/, File.read(File.join(ROOT, ".github/scripts/release_private_handoff.rb")))
  end
end
