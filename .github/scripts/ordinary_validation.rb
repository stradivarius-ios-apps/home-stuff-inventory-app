#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "time"

module OrdinaryValidation
  module_function

  def abort_with(message)
    warn "Ordinary validation failed: #{message}"
    exit 1
  end

  def result_test_count(result_bundle)
    command = ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", result_bundle]
    output, status = Open3.capture2e(*command)
    abort_with("could not inspect #{result_bundle}: #{output.strip}") unless status.success?

    parsed = JSON.parse(output)
    parsed["totalTestCount"] ||
      parsed["testsCount"] ||
      parsed.dig("testPlanRunSummaries", 0, "testsCount")
  rescue Errno::ENOENT, JSON::ParserError => error
    abort_with("could not inspect #{result_bundle}: #{error.message}")
  end

  def validate_result
    result_bundle = ARGV.fetch(0)
    label = ARGV.fetch(1)
    count = result_test_count(result_bundle)
    abort_with("successful #{label} phase did not report a positive test count") unless count&.positive?

    puts "#{label} result contains #{count} tests."
  end

  def duration(name)
    value = ENV[name]
    value && value.match?(/\A\d+\z/) ? value.to_i : nil
  end

  def display_duration(value)
    value ? "#{value} seconds" : "unavailable"
  end

  def summarize
    summary_path = ENV.fetch("GITHUB_STEP_SUMMARY")
    finished_at = Time.now.to_i
    ready_at = duration("VALIDATION_JOB_STARTED_AT").then do |started_at|
      queue = duration("VALIDATION_QUEUE_SECONDS")
      started_at && queue ? started_at - queue : nil
    end
    job_started_at = duration("VALIDATION_JOB_STARTED_AT")
    total_execution = job_started_at ? finished_at - job_started_at : nil
    critical_path = ready_at ? finished_at - ready_at : nil

    rows = [
      ["External runner queue", duration("VALIDATION_QUEUE_SECONDS"), "queue"],
      ["Setup and simulator", duration("VALIDATION_SETUP_SECONDS"), "execution"],
      ["Build-for-testing", duration("VALIDATION_BUILD_SECONDS"), ENV.fetch("BUILD_OUTCOME", "unavailable")],
      ["Unit and localization", duration("VALIDATION_UNIT_SECONDS"), ENV.fetch("UNIT_OUTCOME", "unavailable")],
      ["UI smoke", duration("VALIDATION_UI_SECONDS"), ENV.fetch("UI_OUTCOME", "unavailable")],
      ["Coverage enforcement", duration("VALIDATION_COVERAGE_SECONDS"), ENV.fetch("COVERAGE_OUTCOME", "unavailable")],
      ["Diagnostics and cleanup", duration("VALIDATION_CLEANUP_SECONDS"), "execution"]
    ]

    File.open(summary_path, "a") do |summary|
      summary.puts "## Ordinary Validation timing"
      summary.puts
      summary.puts "- Validated SHA: `#{ENV.fetch("VALIDATED_SHA", "unavailable")}`"
      summary.puts "- Execution critical path: #{display_duration(total_execution)}"
      summary.puts "- Queue plus execution critical path: #{display_duration(critical_path)}"
      summary.puts
      summary.puts "| Phase | Duration | Result |"
      summary.puts "| --- | ---: | --- |"
      rows.each do |label, value, result|
        summary.puts "| #{label} | #{display_duration(value)} | `#{result}` |"
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  case ARGV.shift
  when "validate-result" then OrdinaryValidation.validate_result
  when "summarize" then OrdinaryValidation.summarize
  else OrdinaryValidation.abort_with("expected validate-result or summarize")
  end
end
