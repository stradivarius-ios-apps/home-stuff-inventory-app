#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
SCRIPT = File.join(ROOT, ".github/scripts/full_test_validation.rb")
SHARD = "01"
SHARD_TESTS = %w[
  testCompactInventoryRowPreservesRetrievalOrderAndTapTarget
  testPrimaryEditAndNotesSaveKeepDestructiveAndContextControlsAsNegativeControls
  testPlaceFilterNarrowsInventoryAndCanBeCleared
  testSearchingByItemNameLocationAndPlace
].freeze

def assert(condition, message)
  abort "Full Test Validation helper test failed: #{message}" unless condition
end

def shard_command(results)
  ["ruby", SCRIPT, "run-ui-shard", SHARD, "shared.xctestrun", "platform=iOS Simulator,id=shard-01", results]
end

def test_case_line(method, status: "passed", duration: 1.0)
  "Test Case '-[HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests #{method}]' #{status} (#{duration} seconds)."
end

manifest_output, manifest_status = Open3.capture2e("ruby", SCRIPT, "validate-manifest")
assert(manifest_status.success?, "explicit 18-shard manifest is invalid: #{manifest_output}")

Dir.mktmpdir("full-test-validation-success") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), <<~SH)
    #!/bin/sh
    #{SHARD_TESTS.map { |method| "echo #{test_case_line(method).dump}" }.join("\n")}
  SH
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", Dir[File.join(fake_bin, "*")])
  output_path = File.join(directory, "github-output")
  results = File.join(directory, "results")
  environment = {
    "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
    "GITHUB_OUTPUT" => output_path
  }
  output, status = Open3.capture2e(environment, *shard_command(results))
  assert(status.success?, "complete shard must succeed: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig(SHARD, "status") == "success", "successful shard status was not recorded")
  assert(summary.dig(SHARD, "test_identifiers").length == 4, "successful shard did not retain all identifiers")
  published_output = File.read(output_path)
  assert(published_output.include?("status=success"), "successful matrix status was not published")
  assert(published_output.include?("shard_01_status=success"), "named shard status was not published")
end

Dir.mktmpdir("full-test-validation-failure") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), "#!/bin/sh\nexit 1\n")
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", Dir[File.join(fake_bin, "*")])
  output_path = File.join(directory, "github-output")
  results = File.join(directory, "results")
  environment = {
    "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
    "GITHUB_OUTPUT" => output_path
  }
  output, status = Open3.capture2e(environment, *shard_command(results))
  assert(!status.success?, "failed shard must fail its matrix job: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig(SHARD, "status") == "failure", "shard failure was not recorded")
  assert(File.read(output_path).include?("status=failure"), "failed matrix status was not published")
end

Dir.mktmpdir("full-test-validation-timeout") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  child_pid_path = File.join(directory, "child-pid")
  File.write(File.join(fake_bin, "xcodebuild"), <<~SH)
    #!/bin/sh
    echo #{test_case_line(SHARD_TESTS.first, duration: 0.1).dump}
    trap 'exit 0' TERM
    sh -c 'trap "" TERM; while :; do sleep 1; done' &
    child=$!
    echo "$child" > "$CHILD_PID_PATH"
    wait "$child"
  SH
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", Dir[File.join(fake_bin, "*")])
  output_path = File.join(directory, "github-output")
  results = File.join(directory, "results")
  environment = {
    "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
    "GITHUB_OUTPUT" => output_path,
    "CHILD_PID_PATH" => child_pid_path,
    "UI_SHARD_TIMEOUT_SECONDS" => "0.5",
    "UI_SHARD_TERMINATION_GRACE_SECONDS" => "0.2"
  }
  started_at = Time.now
  output, status = Open3.capture2e(environment, *shard_command(results))
  assert(!status.success?, "timed-out shard must fail its matrix job: #{output}")
  assert(Time.now - started_at < 5, "independent shard timeout did not bound execution")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig(SHARD, "status") == "timeout", "shard timeout status was not recorded")
  assert(summary.dig(SHARD, "test_identifiers").include?("HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests #{SHARD_TESTS.first}"), "partial shard result was not retained")
  assert(File.read(output_path).include?("status=timeout"), "timeout matrix status was not published")
  assert(File.read(File.join(results, "UIShard01.log")).include?("process group was terminated"), "timeout diagnostics were not retained")
  child_pid = Integer(File.read(child_pid_path))
  child_alive = begin
    Process.kill(0, child_pid)
    true
  rescue Errno::ESRCH
    false
  end
  assert(!child_alive, "timed-out shard left a child process running")
end

Dir.mktmpdir("full-test-validation-invalid-timeout") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  spawn_marker = File.join(directory, "spawned")
  File.write(File.join(fake_bin, "xcodebuild"), "#!/bin/sh\ntouch \"$SPAWN_MARKER\"\n")
  FileUtils.chmod("u+x", File.join(fake_bin, "xcodebuild"))
  ["0", "1e999", "NaN", "1200.1"].each do |invalid_timeout|
    FileUtils.rm_f(spawn_marker)
    environment = {
      "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
      "SPAWN_MARKER" => spawn_marker,
      "UI_SHARD_TIMEOUT_SECONDS" => invalid_timeout
    }
    output, status = Open3.capture2e(environment, *shard_command(File.join(directory, "results-#{invalid_timeout.tr("^0-9A-Za-z", "-")}")))
    assert(!status.success?, "invalid timeout #{invalid_timeout.inspect} must fail: #{output}")
    assert(!File.exist?(spawn_marker), "invalid timeout #{invalid_timeout.inspect} spawned a shard")
  end
end

Dir.mktmpdir("full-test-validation-missing-identifiers") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), "#!/bin/sh\necho #{test_case_line(SHARD_TESTS.first).dump}\n")
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", Dir[File.join(fake_bin, "*")])
  results = File.join(directory, "results")
  output, status = Open3.capture2e({ "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" }, *shard_command(results))
  assert(!status.success?, "missing shard identifiers must fail: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig(SHARD, "missing_test_identifiers").length == 3, "missing identifiers were not recorded")
end

Dir.mktmpdir("full-test-validation-empty-result") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), "#!/bin/sh\necho 'Executed 0 tests, with 0 failures (0 unexpected)'\n")
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", Dir[File.join(fake_bin, "*")])
  results = File.join(directory, "results")
  output, status = Open3.capture2e({ "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" }, *shard_command(results))
  assert(!status.success?, "empty successful shard must fail: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig(SHARD, "empty_successful_result"), "empty result was not recorded")
end

Dir.mktmpdir("full-test-validation-observability") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nprintf '%s\\n' '{\"testPlanRunSummaries\":[{\"testsCount\":999}]}'\n")
  FileUtils.chmod("u+x", File.join(fake_bin, "xcrun"))
  results = File.join(directory, "results")
  FileUtils.mkdir_p(results)
  File.write(File.join(results, "UIShard01.log"), SHARD_TESTS.map { |method| test_case_line(method, duration: 1.25) }.join("\n"))
  File.write(File.join(results, "ui-shard-summary.json"), JSON.pretty_generate({
    SHARD => {
      "status" => "success",
      "duration_seconds" => 5,
      "started_at" => "2026-07-28T12:00:00Z",
      "finished_at" => "2026-07-28T12:00:05Z",
      "test_count" => 4,
      "test_identifiers" => SHARD_TESTS.map { |method| "HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests #{method}" },
      "test_durations" => SHARD_TESTS.map { |method| { "identifier" => "HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests #{method}", "duration_seconds" => 1.25 } }
    }
  }))
  summary_path = File.join(directory, "summary.md")
  environment = {
    "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
    "GITHUB_STEP_SUMMARY" => summary_path,
    "VALIDATED_SHA" => "0123456789012345678901234567890123456789",
    "WORKFLOW_STARTED_AT" => "2026-07-28T12:00:00Z"
  }
  output, status = Open3.capture2e(environment, "ruby", SCRIPT, "summarize", results)
  assert(status.success?, "shard summary must succeed: #{output}")
  summary = File.read(summary_path)
  assert(summary.include?("Combined UI tests: 4 tests"), "shard summary did not report its test total")
  assert(summary.include?("Missing expected UI identifiers: none"), "shard summary did not scope completeness to its manifest")
end

Dir.mktmpdir("full-test-validation-empty-unit-result") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nprintf '%s\\n' '{\"testPlanRunSummaries\":[{\"testsCount\":0}]}'\n")
  FileUtils.chmod("u+x", File.join(fake_bin, "xcrun"))
  results = File.join(directory, "results")
  FileUtils.mkdir_p(results)
  File.write(File.join(results, "UnitTests.log"), "Executed 0 tests, with 0 failures (0 unexpected)\n")
  output, status = Open3.capture2e({ "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" }, "ruby", SCRIPT, "validate-unit-result", results)
  assert(!status.success?, "empty successful unit result must fail: #{output}")
end

puts "Full Test Validation helper tests are valid."
