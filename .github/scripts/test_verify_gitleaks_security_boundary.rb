#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

require_relative "verify_gitleaks_security_boundary"

class GitleaksSecurityBoundaryTest < Minitest::Test
  def test_trusted_policy_requires_default_rules_and_empty_ignore_file
    with_policy do |config, ignore|
      assert_nil GitleaksSecurityBoundary.validate_trusted_policy!(config_path: config, ignore_path: ignore)
    end
  end

  def test_rejects_modified_trusted_configuration
    with_policy(config_contents: "[extend]\nuseDefault = false\n") do |config, ignore|
      assert_raises(GitleaksSecurityBoundary::VerificationError) do
        GitleaksSecurityBoundary.validate_trusted_policy!(config_path: config, ignore_path: ignore)
      end
    end
  end

  def test_rejects_nonempty_trusted_ignore_file
    with_policy(ignore_contents: "candidate fingerprint\n") do |config, ignore|
      assert_raises(GitleaksSecurityBoundary::VerificationError) do
        GitleaksSecurityBoundary.validate_trusted_policy!(config_path: config, ignore_path: ignore)
      end
    end
  end

  def test_scan_arguments_enforce_external_policy_and_disable_inline_allow
    arguments = GitleaksSecurityBoundary.scan_arguments(
      candidate: "/temporary/candidate",
      config_path: "/temporary/trusted.toml",
      ignore_path: "/temporary/trusted.ignore"
    )

    assert_equal "/temporary/trusted.toml", arguments.fetch(arguments.index("--config") + 1)
    assert_equal "/temporary/trusted.ignore", arguments.fetch(arguments.index("--gitleaks-ignore-path") + 1)
    assert_includes arguments, "--ignore-gitleaks-allow"
    assert_includes arguments, "--redact=100"
    assert_includes arguments, "--exit-code"
    refute_includes arguments, "--report-path"
  end

  def test_committed_source_does_not_contain_complete_synthetic_detector_value
    source = File.read(File.join(__dir__, "verify_gitleaks_security_boundary.rb"))
    refute_includes source, GitleaksSecurityBoundary.synthetic_detector_value
  end

  private

  def with_policy(config_contents: GitleaksSecurityBoundary::TRUSTED_CONFIG, ignore_contents: "")
    Dir.mktmpdir("gitleaks-policy-test") do |root|
      config = File.join(root, "trusted.toml")
      ignore = File.join(root, "trusted.ignore")
      File.binwrite(config, config_contents)
      File.binwrite(ignore, ignore_contents)
      yield config, ignore
    end
  end
end
