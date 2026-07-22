#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "time"

ROOT = File.expand_path("../..", __dir__)
UI_TEST_DIRECTORY = File.join(ROOT, "HomeStuffInventoryAppUITests")
SCREENSHOT_SUITES = %w[InventoryScreenshotCaptureUITests InventoryReleaseScreenshotUITests].freeze
SHARDS = {
  "A" => %w[
    InventorySmokeUITests
    InventorySettingsUITests
    InventoryItemFormUITests
    InventoryStartupRecoveryUITests
    InventoryManagedValueRowUITests
  ],
  "B" => %w[
    InventoryBrowseDetailUITests
    PlaceSummaryRowUITests
    RecentItemsTileLayoutUITests
  ]
}.freeze
DEFAULT_UI_SHARD_TIMEOUT_SECONDS = 30 * 60
DEFAULT_PROCESS_TERMINATION_GRACE_SECONDS = 10
DEFAULT_PROGRESS_INTERVAL_SECONDS = 60
PROCESS_POLL_INTERVAL_SECONDS = 0.1

def abort_with(message)
  warn "Full Test Validation failed: #{message}"
  exit 1
end

def active_ui_test_classes
  Dir[File.join(UI_TEST_DIRECTORY, "*UITests.swift")].filter_map do |path|
    source = File.read(path)
    next if source.match?(/^#if (PR_UI_SCREENSHOTS|RELEASE_APP_STORE_SCREENSHOTS)/)

    source[/final class (\w+UITests)\b/, 1]
  end.sort
end

def active_ui_test_identifiers
  SHARDS.values.flatten.flat_map do |suite|
    path = File.join(UI_TEST_DIRECTORY, "#{suite}.swift")
    File.read(path).scan(/^\s*func (test\w+)\s*\(/).flatten.map do |method|
      "HomeStuffInventoryAppUITests.#{suite} #{method}"
    end
  end.sort
end

def validate_manifest!
  expected = active_ui_test_classes
  declared = SHARDS.values.flatten.sort
  duplicates = declared.tally.select { |_name, count| count > 1 }.keys
  missing = expected - declared
  unexpected = declared - expected
  abort_with("UI shard manifest has duplicate classes: #{duplicates.join(", ")}") unless duplicates.empty?
  abort_with("UI shard manifest is missing active classes: #{missing.join(", ")}") unless missing.empty?
  abort_with("UI shard manifest contains inactive classes: #{unexpected.join(", ")}") unless unexpected.empty?
end

def result_test_count(result_bundle)
  command = ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", result_bundle]
  output, status = Open3.capture2e(*command)
  return nil unless status.success?

  parsed = JSON.parse(output)
  parsed["testsCount"] || parsed.dig("testPlanRunSummaries", 0, "testsCount")
rescue Errno::ENOENT, JSON::ParserError
  nil
end

def parsed_log_tests(log_path)
  return { "identifiers" => [], "durations" => [] } unless File.exist?(log_path)

  File.foreach(log_path).each_with_object({ "identifiers" => [], "durations" => [] }) do |line, details|
    match = line.match(/Test Case '-\[(?<identifier>[^\]]+)\]' (?<status>passed|failed) \((?<duration>[\d.]+) seconds\)/) ||
            line.match(/Test case '(?<identifier>[^']+)' (?<status>passed|failed) on '.+' \((?<duration>[\d.]+) seconds\)/i)
    next unless match

    details["identifiers"] << match[:identifier]
    details["durations"] << { "identifier" => match[:identifier], "duration_seconds" => match[:duration].to_f }
  end.tap do |details|
    details["identifiers"].uniq!
  end
end

def empty_successful_result?(log_path)
  return false unless File.exist?(log_path)

  File.read(log_path).match?(/Executed 0 tests(?:,| with)/)
end

def attach_test_observability(result_bundle, log_path)
  log_details = parsed_log_tests(log_path)
  {
    "test_count" => log_details.fetch("identifiers").length.positive? ? log_details.fetch("identifiers").length : result_test_count(result_bundle),
    "test_identifiers" => log_details.fetch("identifiers"),
    "test_durations" => log_details.fetch("durations"),
    "result_summary_test_count" => result_test_count(result_bundle),
    "empty_successful_result" => empty_successful_result?(log_path)
  }
end

def run_shard(name, test_run, destination, result_directory, timeout_seconds)
  result_bundle = File.join(result_directory, "UIShard#{name}.xcresult")
  log_path = File.join(result_directory, "UIShard#{name}.log")
  FileUtils.rm_rf(result_bundle)
  selectors = SHARDS.fetch(name).map { |suite| "-only-testing:HomeStuffInventoryAppUITests/#{suite}" }
  command = [
    "xcodebuild", "test-without-building", "-xctestrun", test_run,
    "-destination", destination, "-parallel-testing-enabled", "NO",
    *selectors, "-resultBundlePath", result_bundle
  ]
  started_at = Time.now
  log_file = File.open(log_path, "w")
  pid = Process.spawn(*command, out: log_file, err: log_file, pgroup: true)
  log_file.close
  {
    "pid" => pid,
    "started_at" => started_at,
    "deadline" => Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds,
    "result_bundle" => result_bundle,
    "log" => log_path
  }
end

def positive_number_environment(name, default, maximum: nil)
  value = Float(ENV.fetch(name, default.to_s))
  valid = value.finite? && value.positive? && (maximum.nil? || value <= maximum)
  range = maximum ? " no greater than #{maximum}" : ""
  abort_with("#{name} must be a finite positive number#{range}") unless valid

  value
rescue ArgumentError
  abort_with("#{name} must be a finite positive number")
end

def ui_shard_timeout_seconds
  positive_number_environment("UI_SHARD_TIMEOUT_SECONDS", DEFAULT_UI_SHARD_TIMEOUT_SECONDS, maximum: DEFAULT_UI_SHARD_TIMEOUT_SECONDS)
end

def process_termination_grace_seconds
  positive_number_environment("UI_SHARD_TERMINATION_GRACE_SECONDS", DEFAULT_PROCESS_TERMINATION_GRACE_SECONDS)
end

def progress_interval_seconds
  positive_number_environment("UI_SHARD_PROGRESS_INTERVAL_SECONDS", DEFAULT_PROGRESS_INTERVAL_SECONDS)
end

def wait_for_process(pid)
  Process.waitpid2(pid, Process::WNOHANG)
rescue Errno::ECHILD
  nil
end

def signal_process_group(pid, signal)
  Process.kill(signal, -pid)
rescue Errno::ESRCH
  nil
end

def process_group_alive?(pid)
  Process.kill(0, -pid)
  true
rescue Errno::ESRCH
  false
rescue Errno::EPERM
  true
end

def terminate_process_group(pid)
  signal_process_group(pid, "TERM")
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + process_termination_grace_seconds
  leader_status = nil
  loop do
    completed = wait_for_process(pid) unless leader_status
    leader_status ||= completed&.last
    return leader_status unless process_group_alive?(pid)
    break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep PROCESS_POLL_INTERVAL_SECONDS
  end
  signal_process_group(pid, "KILL")
  leader_status || Process.waitpid2(pid).last
rescue Errno::ECHILD
  leader_status
end

def shard_result(name, shard, process_status, status:, reason: nil)
  finished_at = Time.now
  File.open(shard.fetch("log"), "a") do |log|
    log.puts "Full Test Validation shard #{name} #{reason}." if reason
  end
  {
    "status" => status,
    "exit_status" => process_status&.exitstatus,
    "termination_signal" => process_status&.termsig,
    "process_id" => shard.fetch("pid"),
    "started_at" => shard.fetch("started_at").utc.iso8601,
    "finished_at" => finished_at.utc.iso8601,
    "duration_seconds" => (finished_at - shard.fetch("started_at")).round,
    "result_bundle" => shard.fetch("result_bundle"),
    "log" => shard.fetch("log")
  }.merge(attach_test_observability(shard.fetch("result_bundle"), shard.fetch("log")))
end

def write_shard_summary(result_directory, payload)
  path = File.join(result_directory, "ui-shard-summary.json")
  temporary_path = "#{path}.tmp"
  File.write(temporary_path, JSON.pretty_generate(payload))
  File.rename(temporary_path, path)
end

def publish_shard_outputs(payload)
  github_output = ENV.fetch("GITHUB_OUTPUT", nil)
  return unless github_output

  File.open(github_output, "a") do |output|
    payload.each { |name, result| output.puts "shard_#{name.downcase}_status=#{result.fetch("status")}" }
  end
end

def report_running_shards(running)
  running.each do |name, shard|
    elapsed = (Time.now - shard.fetch("started_at")).round
    identifiers = parsed_log_tests(shard.fetch("log")).fetch("identifiers")
    latest_test = identifiers.last || "no completed test identifier captured yet"
    puts "UI shard #{name} is still running after #{elapsed} seconds (pid #{shard.fetch("pid")}); latest completed test: #{latest_test}."
  end
end

def run_ui_shards
  test_run, destination_a, destination_b, result_directory = ARGV
  abort_with("usage: run-ui-shards XCTESTRUN DESTINATION_A DESTINATION_B RESULT_DIRECTORY") unless result_directory
  validate_manifest!
  FileUtils.mkdir_p(result_directory)
  timeout_seconds = ui_shard_timeout_seconds
  progress_seconds = progress_interval_seconds
  process_termination_grace_seconds

  running = {}
  payload = {}
  interrupted_signal = nil
  previous_traps = %w[INT TERM].to_h do |signal|
    [signal, Signal.trap(signal) { interrupted_signal = signal }]
  end
  orchestration_completed = false
  begin
    abort_with("received SIG#{interrupted_signal} before UI shard startup") if interrupted_signal
    running["A"] = run_shard("A", test_run, destination_a, result_directory, timeout_seconds)
    abort_with("received SIG#{interrupted_signal} during UI shard startup") if interrupted_signal
    running["B"] = run_shard("B", test_run, destination_b, result_directory, timeout_seconds)
    running.each { |name, shard| puts "Started UI shard #{name} as process group #{shard.fetch("pid")} with a #{timeout_seconds.to_i}-second timeout." }
    next_progress_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + progress_seconds

    until running.empty?
      running.dup.each do |name, shard|
        completed = wait_for_process(shard.fetch("pid"))
        next unless completed

        process_status = completed.last
        payload[name] = shard_result(name, shard, process_status, status: process_status.success? ? "success" : "failure")
        puts "UI shard #{name} finished with status #{payload.fetch(name).fetch("status")} after #{payload.fetch(name).fetch("duration_seconds")} seconds."
        running.delete(name)
        write_shard_summary(result_directory, payload)
      end
      break if running.empty?

      if interrupted_signal
        running.each do |name, shard|
          process_status = terminate_process_group(shard.fetch("pid"))
          payload[name] = shard_result(name, shard, process_status, status: "failure", reason: "was interrupted by SIG#{interrupted_signal}")
        end
        running.clear
        write_shard_summary(result_directory, payload)
        break
      end

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if now >= next_progress_at
        report_running_shards(running)
        next_progress_at = now + progress_seconds
      end
      running.dup.each do |name, shard|
        next if now < shard.fetch("deadline")

        process_status = terminate_process_group(shard.fetch("pid"))
        payload[name] = shard_result(
          name,
          shard,
          process_status,
          status: "timeout",
          reason: "exceeded the independent #{timeout_seconds.to_i}-second timeout and its process group was terminated"
        )
        warn "UI shard #{name} timed out after #{payload.fetch(name).fetch("duration_seconds")} seconds; its process group was terminated."
        running.delete(name)
        write_shard_summary(result_directory, payload)
      end
      sleep PROCESS_POLL_INTERVAL_SECONDS unless running.empty?
    end
    orchestration_completed = true
  ensure
    %w[INT TERM].each { |signal| Signal.trap(signal, previous_traps.fetch(signal)) }
    running.each do |name, shard|
      process_status = terminate_process_group(shard.fetch("pid"))
      payload[name] ||= shard_result(name, shard, process_status, status: "failure", reason: "was terminated during orchestrator cleanup")
    end
    write_shard_summary(result_directory, payload) unless payload.empty?
    publish_shard_outputs(payload) unless orchestration_completed || payload.empty?
  end
  successful_shards = payload.select { |_name, result| result.fetch("status") == "success" }
  duplicate_identifiers = successful_shards.values.flat_map { |result| result.fetch("test_identifiers") }.tally.select { |_identifier, count| count > 1 }.keys.sort
  empty_shards = successful_shards.select { |_name, result| result.fetch("empty_successful_result") }.keys
  executed_identifiers = successful_shards.values.flat_map { |result| result.fetch("test_identifiers") }.uniq.sort
  missing_identifiers = payload.values.all? { |result| result.fetch("status") == "success" } ? active_ui_test_identifiers - executed_identifiers : []
  unexpected_identifiers = payload.values.all? { |result| result.fetch("status") == "success" } ? executed_identifiers - active_ui_test_identifiers : []
  payload.each_value do |result|
    result["duplicate_test_identifiers"] = duplicate_identifiers
    result["empty_successful_result"] ||= false
    result["missing_test_identifiers"] = missing_identifiers
    result["unexpected_test_identifiers"] = unexpected_identifiers
  end
  unless duplicate_identifiers.empty? && empty_shards.empty? && missing_identifiers.empty? && unexpected_identifiers.empty?
    payload.each_value { |result| result["status"] = "failure" }
    warn "Full Test Validation failed: duplicate UI test identifiers: #{duplicate_identifiers.join(", ")}" unless duplicate_identifiers.empty?
    warn "Full Test Validation failed: successful UI shard reported zero executed tests: #{empty_shards.join(", ")}" unless empty_shards.empty?
    warn "Full Test Validation failed: missing UI test identifiers: #{missing_identifiers.join(", ")}" unless missing_identifiers.empty?
    warn "Full Test Validation failed: unexpected UI test identifiers: #{unexpected_identifiers.join(", ")}" unless unexpected_identifiers.empty?
  end
  write_shard_summary(result_directory, payload)
  publish_shard_outputs(payload)
  exit 1 if payload.values.any? { |result| result.fetch("status") != "success" }
end

def validate_unit_result
  results_path = ARGV.fetch(0)
  details = attach_test_observability(File.join(results_path, "UnitTests.xcresult"), File.join(results_path, "UnitTests.log"))
  count = details.fetch("test_count")
  abort_with("successful unit/localization stage did not report a positive test count") unless count&.positive?
  abort_with("successful unit/localization stage reported zero executed tests") if details.fetch("empty_successful_result")
  puts "Unit/localization result contains #{count} tests."
end

def summarize
  results_path = ARGV.fetch(0)
  summary_path = ENV.fetch("GITHUB_STEP_SUMMARY")
  source_sha = ENV.fetch("VALIDATED_SHA", "unavailable")
  started_at = Time.parse(ENV.fetch("WORKFLOW_STARTED_AT", Time.now.utc.iso8601))
  finished_at = Time.now
  unit_duration = ENV["UNIT_DURATION_SECONDS"]
  build_duration = ENV["BUILD_DURATION_SECONDS"]
  unit_details = attach_test_observability(File.join(results_path, "UnitTests.xcresult"), File.join(results_path, "UnitTests.log"))
  unit_count = unit_details.fetch("test_count")
  shards = File.exist?(File.join(results_path, "ui-shard-summary.json")) ? JSON.parse(File.read(File.join(results_path, "ui-shard-summary.json"))) : {}
  slowest = shards.max_by { |_name, result| result.fetch("duration_seconds", 0) }
  overlap_seconds = if shards.length == 2
                      starts = shards.values.map { |result| Time.parse(result.fetch("started_at")) }
                      finishes = shards.values.map { |result| Time.parse(result.fetch("finished_at")) }
                      [(finishes.min - starts.max).round, 0].max
                    end
  total_duration = (finished_at - started_at).round
  threshold = total_duration <= 900 ? "met 15-minute target" : total_duration <= 1080 ? "met 18-minute intermediate threshold" : "did not meet timing thresholds"
  ui_identifiers = shards.values.flat_map { |result| result.fetch("test_identifiers", []) }.sort
  expected_ui_identifiers = active_ui_test_identifiers
  missing_ui_identifiers = expected_ui_identifiers - ui_identifiers
  unexpected_ui_identifiers = ui_identifiers - expected_ui_identifiers
  slowest_tests = shards.values.flat_map { |result| result.fetch("test_durations", []) }.sort_by { |test| -test.fetch("duration_seconds") }.first(10)

  File.open(summary_path, "a") do |summary|
    summary.puts "## Full Test Validation timing"
    summary.puts "- Validated SHA: `#{source_sha}`"
    summary.puts "- Build-for-testing: #{build_duration || "unavailable"} seconds"
    summary.puts "- Unit/localization: #{unit_duration || "unavailable"} seconds; #{unit_count || "test count unavailable"} tests"
    shards.each { |name, result| summary.puts "- UI shard #{name}: #{result["duration_seconds"]} seconds; #{result["test_count"] || "test count unavailable"} tests (`#{result["status"]}`)" }
    summary.puts "- Combined UI tests: #{ui_identifiers.length} tests"
    summary.puts "- UI test identifiers: #{ui_identifiers.empty? ? "unavailable from captured logs" : ui_identifiers.map { |identifier| "`#{identifier}`" }.join(", ") }"
    summary.puts "- Missing expected UI identifiers: #{missing_ui_identifiers.empty? ? "none" : missing_ui_identifiers.map { |identifier| "`#{identifier}`" }.join(", ") }" unless ui_identifiers.empty?
    summary.puts "- Unexpected UI identifiers: #{unexpected_ui_identifiers.empty? ? "none" : unexpected_ui_identifiers.map { |identifier| "`#{identifier}`" }.join(", ") }" unless ui_identifiers.empty?
    summary.puts "- Duplicate UI identifiers: #{shards.values.flat_map { |result| result.fetch("duplicate_test_identifiers", []) }.uniq.then { |identifiers| identifiers.empty? ? "none" : identifiers.map { |identifier| "`#{identifier}`" }.join(", ") }}"
    summary.puts "- UI shard process overlap: #{overlap_seconds} seconds#{overlap_seconds == 0 ? " (not observed)" : ""}" unless overlap_seconds.nil?
    summary.puts "- Slower UI shard: #{slowest ? "#{slowest.first} (#{slowest.last["duration_seconds"]} seconds)" : "unavailable"}"
    summary.puts "- Total job time observed by workflow: #{total_duration} seconds (#{threshold})"
    if slowest_tests.empty?
      summary.puts "- Per-test timing unavailable from captured Xcode logs."
    else
      summary.puts "- Ten slowest UI methods:"
      slowest_tests.each { |test| summary.puts "  - `#{test.fetch("identifier")}`: #{test.fetch("duration_seconds")} seconds" }
    end
    summary.puts "- `xcresulttool` summary counts are diagnostic; captured Xcode test logs provide the exact identifiers and totals when available."
  end
end

if __FILE__ == $PROGRAM_NAME
  case ARGV.shift
  when "validate-manifest" then validate_manifest!
  when "run-ui-shards" then run_ui_shards
  when "validate-unit-result" then validate_unit_result
  when "summarize" then summarize
  else abort_with("expected validate-manifest, run-ui-shards, validate-unit-result, or summarize")
  end
end
