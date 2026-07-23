#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "open3"

UPLOAD_ARTIFACT_V7 = "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"

def fail_contract(message)
  warn "CI lane contract failed: #{message}"
  exit 1
end

def workflow_on(workflow)
  workflow["on"] || workflow[true] || {}
end

def strings(value)
  case value
  when Hash then value.flat_map { |key, nested| [key.to_s, *strings(nested)] }
  when Array then value.flat_map { |nested| strings(nested) }
  else [value.to_s]
  end
end

def step!(steps, name)
  steps.find { |step| step["name"] == name } || fail_contract("missing #{name} step")
end

def isolated_simulator_contract!(job, create_name, cleanup_name)
  steps = Array(job["steps"])
  create = step!(steps, create_name)
  cleanup = step!(steps, cleanup_name)
  create_run = create["run"].to_s
  cleanup_run = cleanup["run"].to_s
  fail_contract("#{create_name} must create an iPhone 17 simulator") unless create_run.include?("simctl create") && create_run.include?("\"iPhone 17\"")
  fail_contract("#{create_name} must set a UDID destination") unless create_run.include?("DESTINATION=platform=iOS Simulator,id=$simulator_udid")
  create_command = create_run.index("simctl create")
  boot_command = create_run.index("simctl boot \"")
  bootstatus_command = create_run.index("simctl bootstatus")
  unless create_command && boot_command && bootstatus_command && create_command < boot_command && boot_command < bootstatus_command
    fail_contract("#{create_name} must create, boot, then wait for bootstatus in that order")
  end
  fail_contract("#{cleanup_name} must always run") unless cleanup["if"] == "always()"
  fail_contract("#{cleanup_name} must shut down and delete its simulator") unless cleanup_run.include?("simctl shutdown") && cleanup_run.include?("simctl delete")
  create_index = steps.index(create)
  cleanup_index = steps.index(cleanup)
  test_indexes = steps.each_index.select { |index| steps[index]["run"].to_s.include?("xcodebuild test") }
  fail_contract("#{create_name} must have at least one xcodebuild test step to isolate") if test_indexes.empty?
  fail_contract("#{create_name} must precede every xcodebuild test step") unless test_indexes.all? { |index| create_index < index }
  fail_contract("#{cleanup_name} must follow every xcodebuild test step") unless test_indexes.all? { |index| index < cleanup_index }
end

path = ".github/workflows/pr-ui-screenshots.yml"
workflow = YAML.load_file(path)
events = workflow_on(workflow)
event_names = events.is_a?(Hash) ? events.keys.map(&:to_s) : Array(events).map(&:to_s)
fail_contract("#{path} must cover pull requests and manual capture") unless event_names == %w[pull_request workflow_dispatch]

job = workflow.dig("jobs", "pr-ui-screenshots")
fail_contract("missing pr-ui-screenshots job") unless job.is_a?(Hash)
expected_runner = "macos-26-intel"
fail_contract("PR screenshots must use the supported GitHub-hosted runner") unless job["runs-on"] == expected_runner

lane_text = strings(workflow).join("\n")
required = [
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS=\"DEBUG PR_UI_SCREENSHOTS\"",
  "HomeStuffInventoryAppUITests/InventoryScreenshotCaptureUITests/testEnglishLightReviewScreenshots",
  "HomeStuffInventoryAppUITests/InventoryScreenshotCaptureUITests/testEnglishDarkReviewScreenshots",
  "HomeStuffInventoryAppUITests/InventoryScreenshotCaptureUITests/testUkrainianLightReviewScreenshots",
  "HomeStuffInventoryAppUITests/InventoryScreenshotCaptureUITests/testUkrainianDarkReviewScreenshots",
  ".github/scripts/export_pr_ui_screenshots.rb",
  "TestResults/PRUIScreenshots.xcresult",
  "pr-ui-screenshots"
]
required.each { |text| fail_contract("#{path} must include #{text}") unless lane_text.include?(text) }

[
  "HSI PR Screenshots", "simctl create", "SIMULATOR_UDID=$simulator_udid",
  "platform=iOS Simulator,id=$simulator_udid", "simctl bootstatus", "AppleContentSizeCategory",
  "Delete isolated screenshot simulator", "simctl shutdown", "simctl delete"
].each { |text| fail_contract("#{path} must isolate and normalize its simulator: missing #{text}") unless lane_text.include?(text) }

steps = Array(job["steps"])
isolated_simulator_contract!(job, "Create isolated screenshot simulator", "Delete isolated screenshot simulator")
create_index = steps.index(step!(steps, "Create isolated screenshot simulator"))
normalize_index = steps.index(step!(steps, "Normalize screenshot presentation state"))
capture_index = steps.index(step!(steps, "Capture deterministic PR screenshots"))
fail_contract("screenshot normalization must be between simulator creation and capture") unless create_index < normalize_index && normalize_index < capture_index
normalize_run = steps[normalize_index]["run"].to_s
[
  "AppleContentSizeCategory", "ReduceMotionEnabled -bool false",
  "ReduceTransparencyEnabled -bool false", "DarkerSystemColorsEnabled -bool false"
].each { |value| fail_contract("screenshot normalization must set #{value}") unless normalize_run.include?(value) }
screenshot_upload = steps.find { |step| step["name"] == "Upload PR UI screenshots" }
unless screenshot_upload&.dig("uses") == UPLOAD_ARTIFACT_V7 &&
       screenshot_upload["if"] == "success()" &&
       screenshot_upload.dig("with", "path") == "pr-ui-screenshots" &&
       screenshot_upload.dig("with", "retention-days") == 3
  fail_contract("successful screenshot artifact must use upload-artifact@v7 with success() and three-day retention")
end

failure_upload = steps.find { |step| step["name"] == "Upload PR screenshot result bundle on failure" }
unless failure_upload&.dig("uses") == UPLOAD_ARTIFACT_V7 &&
       failure_upload["if"] == "failure()" &&
       failure_upload.dig("with", "path") == "TestResults/PRUIScreenshots.xcresult" &&
       failure_upload.dig("with", "retention-days") == 3
  fail_contract("xcresult must upload only on failure with three-day retention")
end

Dir[".github/workflows/*.yml"].reject { |candidate| candidate == path }.each do |candidate|
  text = File.read(candidate)
  if text.include?("PR_UI_SCREENSHOTS") || text.include?("InventoryScreenshotCaptureUITests/testEnglishLightReviewScreenshots")
    fail_contract("#{candidate} must not enable the PR screenshot lane")
  end
end

test_source = File.read("HomeStuffInventoryAppUITests/InventoryScreenshotCaptureUITests.swift")
fail_contract("screenshot test must be compile-time isolated") unless test_source.start_with?("#if PR_UI_SCREENSHOTS")
fail_contract("screenshot test must reuse shared screenshot support") unless test_source.include?("InventoryScreenshotUITestCase")

support_source = File.read("HomeStuffInventoryAppUITests/InventoryScreenshotUITestCase.swift")
fail_contract("shared screenshot support must be isolated to both screenshot lanes") unless support_source.start_with?("#if PR_UI_SCREENSHOTS || RELEASE_APP_STORE_SCREENSHOTS")
fail_contract("screenshot support must set a standard Dynamic Type baseline") unless support_source.include?("UICTContentSizeCategoryL")
fail_contract("screenshot support must avoid tab indexes") if support_source.include?("element(boundBy:")
Dir["HomeStuffInventoryAppUITests/*Screenshot*.swift"].each do |source_path|
  source = File.read(source_path)
  fail_contract("#{source_path} must avoid index-based tab navigation") if source.include?("tapTab(index:") || source.include?("element(boundBy:")
end

full_test_path = ".github/workflows/full-tests.yml"
full_test_workflow = YAML.load_file(full_test_path)
full_test_job = full_test_workflow.dig("jobs", "full-test-suite")
fail_contract("missing full-test-suite job") unless full_test_job.is_a?(Hash)
full_test_runner = "macos-26"
fail_contract("Full Test Validation must use the supported Apple Silicon GitHub-hosted runner") unless full_test_job["runs-on"] == full_test_runner
full_test_events = workflow_on(full_test_workflow)
fail_contract("Full Test Validation must cover pull requests") unless full_test_events.key?("pull_request")
full_test_text = strings(full_test_workflow).join("\n")
[
  "build-for-testing", "test-without-building", "DerivedData/FullTestValidation",
  "HSI Full Tests A", "HSI Full Tests B", "simctl create", "simctl bootstatus",
  "run-ui-shards",
  "Delete isolated full-test simulators", "simctl shutdown", "simctl delete"
].each { |text| fail_contract("#{full_test_path} is missing required full-test architecture: #{text}") unless full_test_text.include?(text) }
full_test_steps = Array(full_test_job["steps"])
build_step = step!(full_test_steps, "Build test products once")["run"].to_s
fail_contract("Full Test Validation must build test products exactly once") unless build_step.scan("build-for-testing").length == 1
fail_contract("Full Test Validation must resolve one generated xctestrun") unless step!(full_test_steps, "Resolve shared test run file")["run"].to_s.include?("Expected exactly one generated .xctestrun")
unit_step = step!(full_test_steps, "Run full unit and localization tests without rebuilding")["run"].to_s
fail_contract("Full Test Validation must keep the complete unit target") unless unit_step.include?("-only-testing:HomeStuffInventoryAppTests")
fail_contract("Full Test Validation unit stage must not rebuild") unless unit_step.include?("test-without-building")
unit_result_step = step!(full_test_steps, "Reject empty successful unit results")["run"].to_s
fail_contract("Full Test Validation must reject empty successful unit results") unless unit_result_step.include?("validate-unit-result")
simulator_step = step!(full_test_steps, "Create isolated full-test simulators")["run"].to_s
fail_contract("Full Test Validation must create two distinct iPhone 17 simulators") unless simulator_step.scan("simctl create").length == 2 && simulator_step.include?("simulator_a") && simulator_step.include?("simulator_b")
shard_step = step!(full_test_steps, "Run concurrent UI shards without rebuilding")["run"].to_s
fail_contract("Full Test Validation must run both UI shards from one shared test run") unless shard_step.include?("run-ui-shards") && shard_step.scan("platform=iOS Simulator,id=").length == 2
configured_shard_timeout = full_test_job.fetch("env", {}).fetch("UI_SHARD_TIMEOUT_SECONDS", nil) || full_test_workflow.fetch("env", {}).fetch("UI_SHARD_TIMEOUT_SECONDS", nil)
fail_contract("Full Test Validation must reserve time for diagnostics after independently bounded UI shards") unless configured_shard_timeout.is_a?(Integer) && configured_shard_timeout.between?(1, 1800)
cleanup_step = step!(full_test_steps, "Delete isolated full-test simulators")
fail_contract("Full Test Validation simulator cleanup must always run") unless cleanup_step["if"] == "always()"
fail_contract("Full Test Validation cleanup must delete both simulators") unless cleanup_step["run"].to_s.include?("udid_a") && cleanup_step["run"].to_s.include?("udid_b")
%w[Upload\ failed\ unit\ diagnostics Upload\ failed\ UI\ shard\ A\ diagnostics Upload\ failed\ UI\ shard\ B\ diagnostics].each do |name|
  fail_contract("missing full-test failure diagnostics step #{name}") unless full_test_steps.any? { |step| step["name"] == name }
end
manifest_script = ".github/scripts/full_test_validation.rb"
fail_contract("missing UI shard manifest validator") unless File.exist?(manifest_script)
manifest_source = File.read(manifest_script)
fail_contract("UI shards must disable nested Xcode parallel testing") unless manifest_source.include?("-parallel-testing-enabled") && manifest_source.include?("NO")
fail_contract("UI shards need separate result bundles and logs") unless manifest_source.include?('UIShard#{name}.xcresult') && manifest_source.include?('UIShard#{name}.log')
fail_contract("UI shards must reject missing identifiers") unless manifest_source.include?("missing_test_identifiers")
fail_contract("UI shards must run in independently terminable process groups") unless manifest_source.include?("pgroup: true") && manifest_source.include?("terminate_process_group")
fail_contract("UI shard timeout must fail closed") unless manifest_source.include?('status: "timeout"') && manifest_source.include?('result.fetch("status") != "success"')
manifest_output, manifest_status = Open3.capture2e("ruby", manifest_script, "validate-manifest")
fail_contract("UI shard manifest validator failed: #{manifest_output}") unless manifest_status.success?
helper_test_output, helper_test_status = Open3.capture2e("ruby", ".github/scripts/test_full_test_validation.rb")
fail_contract("UI shard failure-propagation test failed: #{helper_test_output}") unless helper_test_status.success?

smoke_source = File.read("HomeStuffInventoryAppUITests/InventorySmokeUITests.swift")
ui_test_support_source = File.read("HomeStuffInventoryAppUITests/InventoryUITestCase.swift")
ui_smoke_contract_source = smoke_source + ui_test_support_source
fail_contract("UI smoke suite must cover maximum Dynamic Type navigation") unless smoke_source.include?("testMaximumDynamicTypeNavigatesLocationItemDetailAndPicker")
fail_contract("maximum Dynamic Type smoke must use the accessibility size") unless smoke_source.include?("UICTContentSizeCategoryAccessibilityXXXL")
fail_contract("maximum Dynamic Type smoke must require hittable targets") unless ui_smoke_contract_source.include?("element.isHittable")
fail_contract("maximum Dynamic Type smoke must not fall back from a scoped container") if smoke_source.include?("scrollView?.exists == true ? scrollView!")
%w[inventory.list locations.list locations.locationDetail locations.placeDetail.itemList inventory.itemDetail inventory.itemForm inventory.selection].each do |identifier|
  fail_contract("maximum Dynamic Type smoke must scope to #{identifier}") unless ui_smoke_contract_source.include?(identifier)
end

validation = File.read(".github/workflows/validation.yml")
fail_contract("Validation must use the deterministic public automation runner") unless validation.include?("ruby .github/scripts/run_public_automation_checks.rb")
fail_contract("Validation must not depend on the private release automation runner") if validation.include?("run_release_automation_checks.rb")
fail_contract("Validation must not enumerate individual release validators") if validation.include?("ruby .github/scripts/validate_release_pipeline_lane.rb")
fail_contract("Validation UI smoke must cover the free release gate Item creation flow") unless validation.include?("InventorySmokeUITests/testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement")
fail_contract("Validation must not select the superseded standalone Item-creation smoke test") if validation.include?("testAddingItemFromMainInventoryScreen")
validation_workflow = YAML.load_file(".github/workflows/validation.yml")
validation_build_steps = Array(validation_workflow.dig("jobs", "build-test", "steps"))
ui_smoke = step!(validation_build_steps, "Run UI smoke baseline")
fail_contract("Validation UI smoke must use the bounded process helper") unless ui_smoke["run"].to_s.include?("ruby .github/scripts/bounded_process.rb run")
fail_contract("Validation UI smoke must use a local 900-second deadline") unless ui_smoke["run"].to_s.include?("--timeout-seconds 900")
fail_contract("Validation UI smoke must preserve failure for diagnostics") unless ui_smoke["continue-on-error"] == true
ui_smoke_upload = step!(validation_build_steps, "Upload result bundles on failure")
fail_contract("Validation UI smoke diagnostics must include its log") unless ui_smoke_upload.dig("with", "path").to_s.include?("TestResults/UITests.log")
fail_contract("Validation UI smoke diagnostics must include its summary") unless ui_smoke_upload.dig("with", "path").to_s.include?("TestResults/ui-smoke-summary.json")
ui_smoke_fail = step!(validation_build_steps, "Fail when UI smoke failed")
fail_contract("Validation UI smoke failure must propagate") unless ui_smoke_fail["if"].to_s.include?("steps.ui-smoke.outcome == 'failure'")
fastlane_smoke = validation_workflow.dig("jobs", "fastlane-smoke-test")
fail_contract("Validation must run the Fastlane smoke test on the hosted runner") unless fastlane_smoke&.fetch("runs-on", nil) == expected_runner
%w[fastlane-smoke-test build-test code-coverage].each do |job_name|
  fail_contract("Validation #{job_name} must use the supported hosted runner") unless validation_workflow.dig("jobs", job_name, "runs-on") == expected_runner
  condition = validation_workflow.dig("jobs", job_name, "if").to_s
  fail_contract("Validation #{job_name} must remain path-aware") unless condition.include?("needs.classify-changes.outputs.")
  fail_contract("Validation #{job_name} must not exclude pull requests") if condition.include?("github.event_name != 'pull_request'")
end
fastlane_steps = Array(fastlane_smoke["steps"])
setup_ruby = step!(fastlane_steps, "Set up locked Ruby")
fail_contract("Fastlane smoke test must pin reviewed ruby/setup-ruby") unless setup_ruby["uses"] == "ruby/setup-ruby@a30dfa457ad68707b8b910ac3a244714b61c0626"
fail_contract("Fastlane smoke test must provision Ruby 4.0.5") unless setup_ruby.dig("with", "ruby-version").to_s == "4.0.5"
fail_contract("Fastlane smoke test must provision Bundler 2.7.2") unless setup_ruby.dig("with", "bundler").to_s == "2.7.2"
fail_contract("Fastlane smoke test must not use an implicit gem cache") unless setup_ruby.dig("with", "bundler-cache") == false
verify_ruby = step!(fastlane_steps, "Verify production Ruby and Bundler")["run"].to_s
fail_contract("Fastlane smoke test must require Ruby 4.0.5") unless verify_ruby.include?("RUBY_VERSION == \"4.0.5\"")
fail_contract("Fastlane smoke test must require Bundler 2.7.2") unless verify_ruby.include?("Bundler version 2.7.2")
install_bundle = step!(fastlane_steps, "Install locked Fastlane bundle")["run"].to_s
fail_contract("Fastlane smoke test must install the locked bundle with Bundler 2.7.2") unless install_bundle.include?("bundle _2.7.2_ install")
load_actions = step!(fastlane_steps, "Load locked Fastlane default actions")["run"].to_s
fail_contract("Fastlane smoke test must load default actions through the public automation runner") unless load_actions.include?("FASTLANE_SMOKE_TEST=true ruby .github/scripts/run_public_automation_checks.rb")

puts "CI lane contracts are valid."
