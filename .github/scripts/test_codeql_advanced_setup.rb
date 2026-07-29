#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class CodeQLAdvancedSetupTest < Minitest::Test
  WORKFLOW_PATH = ".github/workflows/codeql.yml"
  CONFIG_PATH = ".github/codeql/codeql-config.yml"
  CODEQL_ACTION = "github/codeql-action"
  CODEQL_SHA = "e4fba868fa4b1b91e1fdab776edc8cfbe6e9fb81"

  def setup
    @workflow = YAML.load_file(WORKFLOW_PATH)
  end

  def test_trigger_and_transition_gate_preserve_scanning
    events = @workflow["on"] || @workflow[true] || {}

    assert_equal ["main"], events.dig("push", "branches")
    assert events.key?("pull_request")
    assert events.key?("schedule")
    assert events.key?("workflow_dispatch")

    @workflow.fetch("jobs").each_value do |job|
      assert_equal "vars.ADVANCED_CODEQL_ENABLED == 'true'", job.fetch("if")
    end
  end

  def test_permissions_are_minimal_for_sarif_upload
    assert_equal(
      { "contents" => "read", "security-events" => "write" },
      @workflow.fetch("permissions")
    )
  end

  def test_interpreted_languages_use_no_build_mode
    job = @workflow.dig("jobs", "interpreted")

    assert_equal "ubuntu-latest", job.fetch("runs-on")
    assert_equal %w[actions python ruby], job.dig("strategy", "matrix", "language")
    init = step(job, "Initialize CodeQL")
    assert_equal "${{ matrix.language }}", init.dig("with", "languages")
    assert_equal "none", init.dig("with", "build-mode")
    assert_equal "${{ env.CODEQL_CONFIG }}", init.dig("with", "config-file")
  end

  def test_swift_uses_measured_manual_release_build
    job = @workflow.dig("jobs", "swift")
    text = File.read(WORKFLOW_PATH)

    assert_equal "macos-26", job.fetch("runs-on")
    assert_equal 30, job.fetch("timeout-minutes")
    assert_includes text, "bash .github/scripts/configure_hosted_xcode.sh"

    init = step(job, "Initialize CodeQL")
    assert_equal "swift", init.dig("with", "languages")
    assert_equal "manual", init.dig("with", "build-mode")

    build = step(job, "Build Swift for CodeQL").fetch("run")
    [
      "-configuration Release",
      "-sdk iphoneos",
      "-arch arm64",
      "CODE_SIGNING_REQUIRED=NO",
      "CODE_SIGNING_ALLOWED=NO",
      "ONLY_ACTIVE_ARCH=YES",
      "SWIFT_OPTIMIZATION_LEVEL=-Onone",
      "SWIFT_COMPILATION_MODE=singlefile",
      "DEBUG_INFORMATION_FORMAT=dwarf"
    ].each { |value| assert_includes build, value }
    refute_includes text, "#{CODEQL_ACTION}/autobuild@"
  end

  def test_every_codeql_action_is_exactly_pinned
    uses = @workflow.fetch("jobs").values.flat_map do |job|
      Array(job["steps"]).filter_map { |step| step["uses"] }
    end
    codeql_uses = uses.select { |value| value.start_with?("#{CODEQL_ACTION}/") }

    refute_empty codeql_uses
    codeql_uses.each { |value| assert_match(/\A#{Regexp.escape(CODEQL_ACTION)}\/[^@]+@#{CODEQL_SHA}\z/, value) }
  end

  def test_existing_remote_and_local_threat_model_is_preserved
    config = YAML.load_file(CONFIG_PATH)

    assert_equal "local", config.fetch("threat-models")
  end

  private

  def step(job, name)
    job.fetch("steps").find { |candidate| candidate["name"] == name } ||
      flunk("missing step #{name}")
  end
end
