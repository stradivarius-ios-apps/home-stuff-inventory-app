#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "yaml"
require_relative "release_app_preflight"

class ReleaseAppPreflightTest < Minitest::Test
  KEY = OpenSSL::PKey::RSA.generate(2048).to_pem
  ACTOR = "home-stuff-release-handoff[bot]"

  def installation
    { "id" => 10, "app_id" => 9, "app_slug" => "home-stuff-release-handoff",
      "account" => { "login" => "stradivarius-ios-apps" }, "target_type" => "Organization",
      "repository_selection" => "selected", "suspended_at" => nil,
      "permissions" => { "actions" => "write", "metadata" => "read" } }
  end

  def test_preflight_uses_only_read_requests_after_token_mint
    paths = []
    api = lambda do |method, path, token:, body: nil|
      assert_equal :get, method
      assert_nil body
      refute_empty token
      paths << path
      case path
      when "/app/installations/10" then installation
      when "/installation/repositories?per_page=100"
        { "total_count" => 1, "repositories" => [{ "full_name" => ReleaseAppPreflight::REPOSITORY }] }
      when "/repos/#{ReleaseAppPreflight::REPOSITORY}/actions/workflows/#{ReleaseAppPreflight::WORKFLOW}"
        { "id" => ReleasePrivateHandoff::WORKFLOW_ID }
      else
        flunk "Unexpected preflight request"
      end
    end
    mint = lambda do |app_id:, installation_id:, private_key:|
      assert_equal ["9", "10", KEY], [app_id, installation_id, private_key]
      "test-installation-token"
    end

    assert ReleaseAppPreflight.run!(app_id: "9", installation_id: "10", actor: ACTOR,
      private_key: KEY, api: api, mint: mint)
    assert_equal [
      "/app/installations/10",
      "/installation/repositories?per_page=100",
      "/repos/#{ReleaseAppPreflight::REPOSITORY}/actions/workflows/#{ReleaseAppPreflight::WORKFLOW}"
    ], paths
  end

  def test_rejects_broader_installation_permissions
    data = installation.merge("permissions" => installation.fetch("permissions").merge("contents" => "write"))
    assert_raises(RuntimeError) do
      ReleaseAppPreflight.validate_installation!(data, app_id: "9", installation_id: "10", actor: ACTOR)
    end
  end

  def test_rejects_other_actor_and_repository
    assert_raises(RuntimeError) do
      ReleaseAppPreflight.validate_installation!(installation, app_id: "9", installation_id: "10",
        actor: "another-app[bot]")
    end
    assert_raises(RuntimeError) do
      ReleaseAppPreflight.validate_repositories!(
        "total_count" => 2,
        "repositories" => [{ "full_name" => ReleaseAppPreflight::REPOSITORY },
          { "full_name" => "stradivarius-ios-apps/another-private-repository" }]
      )
    end
  end

  def test_workflow_is_manual_read_only_and_environment_scoped
    workflow = YAML.load_file(File.expand_path("../workflows/release-app-preflight.yml", __dir__))
    events = workflow["on"] || workflow[true]
    assert_equal ["workflow_dispatch"], events.keys
    job = workflow.fetch("jobs").fetch("preflight")
    assert_equal "release-orchestration", job.fetch("environment")
    assert_equal({ "contents" => "read" }, workflow.fetch("permissions"))
    assert_includes job.fetch("if"), "refs/heads/main"
    assert_equal "ruby .github/scripts/release_app_preflight.rb", job.fetch("steps").last.fetch("run")
  end
end
