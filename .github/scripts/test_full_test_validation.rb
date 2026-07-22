#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "time"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
SCRIPT = File.join(ROOT, ".github/scripts/full_test_validation.rb")

def assert(condition, message)
  abort "Full Test Validation helper test failed: #{message}" unless condition
end

Dir.mktmpdir("full-test-validation") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  fake_xcodebuild = File.join(fake_bin, "xcodebuild")
  File.write(fake_xcodebuild, <<~SH)
    #!/bin/sh
    destination=""
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "-destination" ]; then destination="$2"; shift 2; continue; fi
      shift
    done
    if echo "$destination" | grep -q shard-a; then sleep 1; exit 1; fi
    sleep 2
  SH
  FileUtils.chmod("u+x", fake_xcodebuild)

  output_path = File.join(directory, "github-output")
  environment = {
    "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
    "GITHUB_OUTPUT" => output_path
  }
  results = File.join(directory, "results")
  output, status = Open3.capture2e(environment, "ruby", SCRIPT, "run-ui-shards", "shared.xctestrun", "platform=iOS Simulator,id=shard-a", "platform=iOS Simulator,id=shard-b", results)
  assert(!status.success?, "a failed shard must fail the orchestrator: #{output}")
  assert(File.exist?(File.join(results, "ui-shard-summary.json")), "orchestrator did not create a shard summary: #{output}")

  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig("A", "status") == "failure", "shard A failure was not recorded")
  assert(summary.dig("B", "status") == "success", "shard B must finish after shard A fails")
  assert(File.read(output_path).include?("shard_b_status=success"), "shard B completion output was not published")
  assert(Time.parse(summary.dig("B", "finished_at")) >= Time.parse(summary.dig("A", "finished_at")), "orchestrator returned before the second shard completed")
end

Dir.mktmpdir("full-test-validation-observability") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcrun"), <<~SH)
    #!/bin/sh
    printf '%s\\n' '{"testPlanRunSummaries":[{"testsCount":999}]}'
  SH
  FileUtils.chmod("u+x", File.join(fake_bin, "xcrun"))

  results = File.join(directory, "results")
  FileUtils.mkdir_p(results)
  File.write(File.join(results, "UnitTests.log"), <<~LOG)
    Test case 'InventorySearchTests/broadSearch()' passed on 'Clone 1 of iPhone 17 - HomeStuffInventoryApp (1234)' (0.123 seconds)
    Test case 'InventorySearchTests/ranking()' passed on 'Clone 1 of iPhone 17 - HomeStuffInventoryApp (1234)' (0.456 seconds)
  LOG
  File.write(File.join(results, "UIShardA.log"), <<~LOG)
    Test Case '-[HomeStuffInventoryAppUITests.InventorySmokeUITests testFreeReleaseGate]' passed (12.34 seconds).
  LOG
  File.write(File.join(results, "UIShardB.log"), <<~LOG)
    Test Case '-[HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests testOpeningItemDetail]' passed (45.67 seconds).
  LOG
  File.write(File.join(results, "ui-shard-summary.json"), JSON.pretty_generate({
    "A" => {
      "status" => "success", "duration_seconds" => 20,
      "started_at" => "2026-07-17T12:00:00Z", "finished_at" => "2026-07-17T12:00:20Z",
      "test_count" => 1,
      "test_identifiers" => ["HomeStuffInventoryAppUITests.InventorySmokeUITests testFreeReleaseGate"],
      "test_durations" => [{ "identifier" => "HomeStuffInventoryAppUITests.InventorySmokeUITests testFreeReleaseGate", "duration_seconds" => 12.34 }]
    },
    "B" => {
      "status" => "success", "duration_seconds" => 50,
      "started_at" => "2026-07-17T12:00:01Z", "finished_at" => "2026-07-17T12:00:51Z",
      "test_count" => 1,
      "test_identifiers" => ["HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests testOpeningItemDetail"],
      "test_durations" => [{ "identifier" => "HomeStuffInventoryAppUITests.InventoryBrowseDetailUITests testOpeningItemDetail", "duration_seconds" => 45.67 }]
    }
  }))
  summary_path = File.join(directory, "summary.md")
  environment = {
    "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}",
    "GITHUB_STEP_SUMMARY" => summary_path,
    "VALIDATED_SHA" => "0123456789012345678901234567890123456789",
    "WORKFLOW_STARTED_AT" => "2026-07-17T12:00:00Z",
    "UNIT_DURATION_SECONDS" => "1",
    "BUILD_DURATION_SECONDS" => "2"
  }
  output, status = Open3.capture2e(environment, "ruby", SCRIPT, "summarize", results)
  assert(status.success?, "observability summary must succeed: #{output}")
  summary = File.read(summary_path)
  assert(summary.include?("Unit/localization: 1 seconds; 2 tests"), "Xcode 26.6 log fixture did not provide the unit total")
  assert(summary.include?("Combined UI tests: 2 tests"), "Xcode 26.6 log fixture did not provide the combined UI total")
  assert(summary.include?("testOpeningItemDetail`: 45.67 seconds"), "Xcode 26.6 log fixture did not provide per-test timing")
end

Dir.mktmpdir("full-test-validation-duplicate-detection") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), <<~SH)
    #!/bin/sh
    echo "Test Case '-[HomeStuffInventoryAppUITests.InventorySmokeUITests testDuplicate]' passed (1.0 seconds)."
  SH
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", File.join(fake_bin, "xcodebuild"))
  FileUtils.chmod("u+x", File.join(fake_bin, "xcrun"))
  results = File.join(directory, "results")
  output, status = Open3.capture2e({ "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" }, "ruby", SCRIPT, "run-ui-shards", "shared.xctestrun", "platform=iOS Simulator,id=shard-a", "platform=iOS Simulator,id=shard-b", results)
  assert(!status.success?, "duplicate UI identifiers must fail the orchestrator: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig("A", "duplicate_test_identifiers") == ["HomeStuffInventoryAppUITests.InventorySmokeUITests testDuplicate"], "duplicate UI identifier was not recorded")
end

Dir.mktmpdir("full-test-validation-empty-result") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), "#!/bin/sh\necho 'Executed 0 tests, with 0 failures (0 unexpected)'\n")
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", File.join(fake_bin, "xcodebuild"))
  FileUtils.chmod("u+x", File.join(fake_bin, "xcrun"))
  results = File.join(directory, "results")
  output, status = Open3.capture2e({ "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" }, "ruby", SCRIPT, "run-ui-shards", "shared.xctestrun", "platform=iOS Simulator,id=shard-a", "platform=iOS Simulator,id=shard-b", results)
  assert(!status.success?, "an empty successful result must fail the orchestrator: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(summary.dig("A", "empty_successful_result"), "empty successful result was not recorded")
end

Dir.mktmpdir("full-test-validation-missing-identifiers") do |directory|
  fake_bin = File.join(directory, "bin")
  FileUtils.mkdir_p(fake_bin)
  File.write(File.join(fake_bin, "xcodebuild"), <<~SH)
    #!/bin/sh
    echo "Test Case '-[HomeStuffInventoryAppUITests.InventorySmokeUITests testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement]' passed (1.0 seconds)."
  SH
  File.write(File.join(fake_bin, "xcrun"), "#!/bin/sh\nexit 1\n")
  FileUtils.chmod("u+x", File.join(fake_bin, "xcodebuild"))
  FileUtils.chmod("u+x", File.join(fake_bin, "xcrun"))
  results = File.join(directory, "results")
  output, status = Open3.capture2e({ "PATH" => "#{fake_bin}:#{ENV.fetch("PATH")}" }, "ruby", SCRIPT, "run-ui-shards", "shared.xctestrun", "platform=iOS Simulator,id=shard-a", "platform=iOS Simulator,id=shard-b", results)
  assert(!status.success?, "missing UI identifiers must fail the orchestrator: #{output}")
  summary = JSON.parse(File.read(File.join(results, "ui-shard-summary.json")))
  assert(!summary.dig("A", "missing_test_identifiers").empty?, "missing UI identifiers were not recorded")
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
  assert(!status.success?, "an empty successful unit result must fail validation: #{output}")
end

puts "Full Test Validation helper tests are valid."
