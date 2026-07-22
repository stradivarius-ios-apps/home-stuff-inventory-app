#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "digest"
require "json"
require "open3"
require "tmpdir"

require_relative "validate_public_surface"

module GitleaksSecurityBoundary
  class VerificationError < StandardError; end

  TRUSTED_CONFIG = <<~TOML.freeze
    [extend]
    useDefault = true
  TOML

  module_function

  def verify!(binary:, config_path:, ignore_path:)
    validate_trusted_policy!(config_path: config_path, ignore_path: ignore_path)

    Dir.mktmpdir("gitleaks-security-boundary") do |workspace|
      synthetic_value = synthetic_detector_value
      verify_ordinary_detection!(
        workspace: workspace,
        binary: binary,
        config_path: config_path,
        ignore_path: ignore_path,
        synthetic_value: synthetic_value
      )
      verify_candidate_config_cannot_suppress!(
        workspace: workspace,
        binary: binary,
        config_path: config_path,
        ignore_path: ignore_path,
        synthetic_value: synthetic_value
      )
      verify_candidate_ignore_cannot_suppress!(
        workspace: workspace,
        binary: binary,
        config_path: config_path,
        ignore_path: ignore_path,
        synthetic_value: synthetic_value
      )
      verify_inline_allow_cannot_suppress!(
        workspace: workspace,
        binary: binary,
        config_path: config_path,
        ignore_path: ignore_path,
        synthetic_value: synthetic_value
      )
      verify_no_report_artifacts!(workspace)
    end

    true
  end

  def validate_trusted_policy!(config_path:, ignore_path:)
    raise VerificationError, "Trusted Gitleaks configuration is invalid." unless File.binread(config_path) == TRUSTED_CONFIG
    raise VerificationError, "Trusted Gitleaks ignore file is not empty." unless File.file?(ignore_path) && File.zero?(ignore_path)
  rescue Errno::ENOENT
    raise VerificationError, "Trusted Gitleaks policy file is missing."
  end

  def scan_arguments(candidate:, config_path:, ignore_path:)
    [
      "dir", candidate,
      "--config", config_path,
      "--gitleaks-ignore-path", ignore_path,
      "--ignore-gitleaks-allow",
      "--no-banner",
      "--redact=100",
      "--exit-code", "1",
      "--log-level", "error"
    ]
  end

  def synthetic_detector_value
    ["ghp", "_", Digest::SHA256.hexdigest("public scanner boundary fixture")[0, 36]].join
  end

  def verify_ordinary_detection!(workspace:, binary:, config_path:, ignore_path:, synthetic_value:)
    candidate = candidate_directory(workspace, "ordinary", synthetic_value: synthetic_value)
    result = run_scan(binary, scan_arguments(candidate: candidate, config_path: config_path, ignore_path: ignore_path))
    assert_detected!(result, synthetic_value)

    detected_fingerprint!(
      binary,
      candidate: candidate,
      config_path: config_path,
      ignore_path: ignore_path,
      synthetic_value: synthetic_value
    )
  end

  def verify_candidate_config_cannot_suppress!(workspace:, binary:, config_path:, ignore_path:, synthetic_value:)
    candidate = candidate_directory(workspace, "candidate-config", synthetic_value: synthetic_value)
    candidate_config = File.join(candidate, ".gitleaks.toml")
    File.binwrite(
      candidate_config,
      "[extend]\nuseDefault = true\n[allowlist]\npaths = ['''detector\\.txt''']\n"
    )
    assert_suppressed!(
      run_scan(binary, scan_arguments(candidate: candidate, config_path: candidate_config, ignore_path: ignore_path)),
      synthetic_value,
      "candidate configuration"
    )
    assert_detected!(
      run_scan(binary, scan_arguments(candidate: candidate, config_path: config_path, ignore_path: ignore_path)),
      synthetic_value
    )
  end

  def verify_candidate_ignore_cannot_suppress!(workspace:, binary:, config_path:, ignore_path:, synthetic_value:)
    candidate = candidate_directory(workspace, "candidate-ignore", synthetic_value: synthetic_value)
    fingerprint = detected_fingerprint!(
      binary,
      candidate: candidate,
      config_path: config_path,
      ignore_path: ignore_path,
      synthetic_value: synthetic_value
    )
    candidate_ignore = File.join(candidate, ".gitleaksignore")
    File.binwrite(candidate_ignore, "#{fingerprint}\n")
    assert_suppressed!(
      run_scan(binary, scan_arguments(candidate: candidate, config_path: config_path, ignore_path: candidate_ignore)),
      synthetic_value,
      "candidate ignore file"
    )
    ignore_rule_present = PublicSurfaceValidation.path_violations(".gitleaksignore").any? do |violation|
      violation.fetch(:rule) == "pull-request-controlled Gitleaks ignore file"
    end
    raise VerificationError, "Public-surface policy did not reject the candidate Gitleaks ignore file." unless ignore_rule_present

    detector_file = File.join(candidate, "detector.txt")
    assert_detected!(
      run_scan(binary, scan_arguments(candidate: detector_file, config_path: config_path, ignore_path: ignore_path)),
      synthetic_value
    )
  end

  def verify_inline_allow_cannot_suppress!(workspace:, binary:, config_path:, ignore_path:, synthetic_value:)
    candidate = File.join(workspace, "inline-allow")
    FileUtils.mkdir_p(candidate)
    File.binwrite(File.join(candidate, "detector.txt"), "token = #{synthetic_value} # gitleaks:allow\n")
    control_arguments = scan_arguments(candidate: candidate, config_path: config_path, ignore_path: ignore_path)
    control_arguments.delete("--ignore-gitleaks-allow")
    assert_suppressed!(run_scan(binary, control_arguments), synthetic_value, "inline allow directive")
    assert_detected!(
      run_scan(binary, scan_arguments(candidate: candidate, config_path: config_path, ignore_path: ignore_path)),
      synthetic_value
    )
  end

  def candidate_directory(workspace, name, synthetic_value:)
    candidate = File.join(workspace, name)
    FileUtils.mkdir_p(candidate)
    File.binwrite(File.join(candidate, "detector.txt"), "token = #{synthetic_value}\n")
    candidate
  end

  def run_scan(binary, arguments)
    stdout, stderr, status = Open3.capture3(binary, *arguments)
    { stdout: stdout, stderr: stderr, status: status }
  end

  def detected_fingerprint!(binary, candidate:, config_path:, ignore_path:, synthetic_value:)
    result = run_scan(
      binary,
      scan_arguments(candidate: candidate, config_path: config_path, ignore_path: ignore_path) +
        ["--report-format", "json", "--report-path", "-"]
    )
    assert_detected!(result, synthetic_value)
    findings = JSON.parse(result.fetch(:stdout))
    fingerprint = findings.first&.fetch("Fingerprint", nil)
    raise VerificationError, "Synthetic Gitleaks finding did not include a fingerprint." if fingerprint.to_s.empty?

    fingerprint
  rescue JSON::ParserError
    raise VerificationError, "Synthetic Gitleaks fingerprint report was invalid."
  end

  def assert_detected!(result, synthetic_value)
    output = "#{result.fetch(:stdout)}#{result.fetch(:stderr)}"
    raise VerificationError, "Synthetic detector value appeared in Gitleaks output." if output.include?(synthetic_value)
    raise VerificationError, "Gitleaks suppression-boundary self-test did not detect the synthetic fixture." unless result.fetch(:status).exitstatus == 1
  end

  def assert_suppressed!(result, synthetic_value, mechanism)
    output = "#{result.fetch(:stdout)}#{result.fetch(:stderr)}"
    raise VerificationError, "Synthetic detector value appeared in Gitleaks control output." if output.include?(synthetic_value)
    raise VerificationError, "Synthetic Gitleaks #{mechanism} control was not effective." unless result.fetch(:status).success?
  end

  def verify_no_report_artifacts!(workspace)
    report = Dir.glob("**/*", File::FNM_DOTMATCH, base: workspace).find do |path|
      File.file?(File.join(workspace, path)) && File.basename(path).match?(/\A(?:gitleaks-)?report\./i)
    end
    raise VerificationError, "Gitleaks boundary self-test created a report artifact." if report
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby #{File.basename(__FILE__)} GITLEAKS_BINARY TRUSTED_CONFIG TRUSTED_IGNORE" unless ARGV.length == 3

  begin
    GitleaksSecurityBoundary.verify!(
      binary: ARGV.fetch(0),
      config_path: ARGV.fetch(1),
      ignore_path: ARGV.fetch(2)
    )
    puts "Gitleaks trusted-policy boundary self-test passed."
  rescue GitleaksSecurityBoundary::VerificationError => error
    abort error.message
  end
end
