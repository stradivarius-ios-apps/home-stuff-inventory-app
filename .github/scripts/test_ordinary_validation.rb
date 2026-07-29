#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class OrdinaryValidationTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, ".github/scripts/ordinary_validation.rb")

  def with_fake_xcrun(test_count)
    Dir.mktmpdir do |directory|
      fake_xcrun = File.join(directory, "xcrun")
      File.write(fake_xcrun, <<~SH)
        #!/bin/sh
        printf '%s\n' '{"totalTestCount":#{test_count}}'
      SH
      FileUtils.chmod("u+x", fake_xcrun)
      yield({ "PATH" => "#{directory}:#{ENV.fetch("PATH")}" })
    end
  end

  def test_validate_result_accepts_a_positive_test_count
    with_fake_xcrun(42) do |environment|
      output, status = Open3.capture2e(
        environment,
        "ruby", SCRIPT, "validate-result", "Result.xcresult", "unit/localization"
      )

      assert status.success?, output
      assert_includes output, "unit/localization result contains 42 tests"
    end
  end

  def test_validate_result_rejects_an_empty_success
    with_fake_xcrun(0) do |environment|
      output, status = Open3.capture2e(
        environment,
        "ruby", SCRIPT, "validate-result", "Result.xcresult", "UI smoke"
      )

      refute status.success?
      assert_includes output, "did not report a positive test count"
    end
  end

  def test_summary_reports_each_critical_path_phase
    Dir.mktmpdir do |directory|
      summary = File.join(directory, "summary.md")
      now = Time.now.to_i
      environment = {
        "GITHUB_STEP_SUMMARY" => summary,
        "VALIDATED_SHA" => "abc123",
        "VALIDATION_JOB_STARTED_AT" => (now - 100).to_s,
        "VALIDATION_QUEUE_SECONDS" => "20",
        "VALIDATION_SETUP_SECONDS" => "10",
        "VALIDATION_BUILD_SECONDS" => "30",
        "VALIDATION_UNIT_SECONDS" => "25",
        "VALIDATION_UI_SECONDS" => "20",
        "VALIDATION_COVERAGE_SECONDS" => "2",
        "VALIDATION_CLEANUP_SECONDS" => "3",
        "BUILD_OUTCOME" => "success",
        "UNIT_OUTCOME" => "success",
        "UI_OUTCOME" => "success",
        "COVERAGE_OUTCOME" => "success"
      }
      output, status = Open3.capture2e(environment, "ruby", SCRIPT, "summarize")

      assert status.success?, output
      text = File.read(summary)
      assert_includes text, "Ordinary Validation timing"
      assert_includes text, "External runner queue"
      assert_includes text, "Build-for-testing"
      assert_includes text, "Unit and localization"
      assert_includes text, "UI smoke"
      assert_includes text, "Coverage enforcement"
      assert_includes text, "Diagnostics and cleanup"
      assert_includes text, "Queue plus execution critical path"
    end
  end
end
