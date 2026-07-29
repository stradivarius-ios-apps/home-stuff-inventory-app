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
fail_contract("#{path} must support manual capture only") unless event_names == %w[workflow_dispatch]

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
full_test_source_job = full_test_workflow.dig("jobs", "source")
full_test_build_job = full_test_workflow.dig("jobs", "build-and-unit-tests")
full_test_shard_job = full_test_workflow.dig("jobs", "ui-shards")
fail_contract("missing full-test-suite job") unless full_test_job.is_a?(Hash)
fail_contract("Full Test Validation must keep a stable hosted aggregator") unless full_test_job["runs-on"] == "ubuntu-latest" && full_test_job["name"] == "Full Test Suite"
fail_contract("Full Test Validation must resolve exact source separately") unless full_test_source_job.is_a?(Hash) && full_test_source_job["runs-on"] == "ubuntu-latest"
fail_contract("Full Test Validation build and shards must use reviewed hosted Apple Silicon") unless full_test_build_job["runs-on"] == "macos-26" && full_test_shard_job["runs-on"] == "macos-26"
full_test_events = workflow_on(full_test_workflow)
fail_contract("Full Test Validation must not run for ordinary pull requests") if full_test_events.key?("pull_request")
fail_contract("Full Test Validation must cover protected version tags") unless full_test_events.dig("push", "tags") == ["v*"]
fail_contract("Full Test Validation must support explicit version validation") unless full_test_events.key?("workflow_dispatch")
fail_contract("Full Test Validation must remain reusable by release automation") unless full_test_events.key?("workflow_call")
full_test_text = strings(full_test_workflow).join("\n")
[
  "build-for-testing", "test-without-building", "DerivedData/FullTestValidation",
  "FullTestProducts.tar.gz", "api.github.com/repos/$GITHUB_REPOSITORY/actions/artifacts/$ARTIFACT_ID/zip",
  "simctl create", "simctl bootstatus",
  "run-ui-shard",
  "Delete isolated shard simulator", "simctl shutdown", "simctl delete"
].each { |text| fail_contract("#{full_test_path} is missing required full-test architecture: #{text}") unless full_test_text.include?(text) }
full_test_source_steps = Array(full_test_source_job["steps"])
full_test_build_steps = Array(full_test_build_job["steps"])
full_test_shard_steps = Array(full_test_shard_job["steps"])
build_step = step!(full_test_build_steps, "Build test products once")["run"].to_s
fail_contract("Full Test Validation must build test products exactly once") unless build_step.scan("build-for-testing").length == 1
fail_contract("Full Test Validation must resolve one generated xctestrun") unless step!(full_test_build_steps, "Resolve shared test run file")["run"].to_s.include?("Expected exactly one generated .xctestrun")
unit_step = step!(full_test_build_steps, "Run full unit and localization tests without rebuilding")["run"].to_s
fail_contract("Full Test Validation must keep the complete unit target") unless unit_step.include?("-only-testing:HomeStuffInventoryAppTests")
fail_contract("Full Test Validation unit stage must not rebuild") unless unit_step.include?("test-without-building")
unit_result_step = step!(full_test_build_steps, "Reject empty successful unit results")["run"].to_s
fail_contract("Full Test Validation must reject empty successful unit results") unless unit_result_step.include?("validate-unit-result")
fail_contract("Full Test Validation must package only immutable test products") unless step!(full_test_build_steps, "Package immutable shared test products")["run"].to_s.include?('-C "$DERIVED_DATA/Build" Products')
artifact_upload = step!(full_test_build_steps, "Upload immutable shared test products")
artifact_download = step!(full_test_shard_steps, "Download immutable shared test products")
fail_contract("Full Test Validation must pass the immutable artifact ID to shards") unless
  artifact_upload["id"] == "test-products" &&
  full_test_build_job.dig("outputs", "test_products_artifact_id") == "${{ steps.test-products.outputs.artifact-id }}" &&
  artifact_download.dig("env", "ARTIFACT_ID") == "${{ needs.build-and-unit-tests.outputs.test_products_artifact_id }}"
fail_contract("Full Test Validation must fail closed on an invalid artifact ID") unless artifact_download["run"].to_s.include?('[[ ! "$ARTIFACT_ID" =~ ^[0-9]+$ ]]')
fail_contract("Full Test Validation must use the organization-compatible artifact API") if
  File.read(full_test_path).include?("actions/download-artifact@")
matrix_shards = full_test_shard_job.dig("strategy", "matrix", "shard")
fail_contract("Full Test Validation must use 18 explicit matrix shards") unless matrix_shards == (1..18).map { |number| format("%02d", number) }
simulator_step = step!(full_test_shard_steps, "Create isolated shard simulator")
fail_contract("Each Full Test UI shard must create exactly one isolated simulator") unless simulator_step["run"].to_s.scan("simctl create").length == 1
fail_contract("Each Full Test UI shard simulator setup must be bounded") unless simulator_step["timeout-minutes"].is_a?(Integer) && simulator_step["timeout-minutes"] <= 10
shard_step = step!(full_test_shard_steps, "Run bounded UI shard without rebuilding")["run"].to_s
fail_contract("Each Full Test UI shard must use restored products without rebuilding") unless shard_step.include?("run-ui-shard") && shard_step.include?("steps.test-run.outputs.path")
configured_shard_timeout = full_test_workflow.fetch("env", {}).fetch("UI_SHARD_TIMEOUT_SECONDS", nil)
fail_contract("Full Test Validation must reserve time for per-shard diagnostics") unless configured_shard_timeout.is_a?(Integer) && configured_shard_timeout.between?(1, 1200)
cleanup_step = step!(full_test_shard_steps, "Delete isolated shard simulator")
fail_contract("Full Test Validation simulator cleanup must always run") unless cleanup_step["if"] == "always()"
fail_contract("Full Test Validation cleanup must delete its matrix simulator") unless cleanup_step["run"].to_s.include?("steps.simulator.outputs.udid")
fail_contract("Full Test Validation must retain unit failure diagnostics") unless full_test_build_steps.any? { |step| step["name"] == "Upload failed unit diagnostics" }
fail_contract("Full Test Validation must retain per-shard failure diagnostics") unless full_test_shard_steps.any? { |step| step["name"] == "Upload failed UI shard diagnostics" }
source_checkout = step!(full_test_source_steps, "Check out repository")
fail_contract("Full Test Validation source resolver must preserve exact ref selection") unless source_checkout.dig("with", "ref") == "${{ github.event_name == 'push' && github.sha || inputs.source_ref || github.sha }}"
fail_contract("Full Test Suite aggregator must wait for every matrix shard") unless Array(full_test_job["needs"]).include?("ui-shards")
manifest_script = ".github/scripts/full_test_validation.rb"
fail_contract("missing UI shard manifest validator") unless File.exist?(manifest_script)
manifest_source = File.read(manifest_script)
fail_contract("UI shards must disable nested Xcode parallel testing") unless manifest_source.include?("-parallel-testing-enabled") && manifest_source.include?("NO")
fail_contract("UI shards need separate result bundles and logs") unless manifest_source.include?('UIShard#{name}.xcresult') && manifest_source.include?('UIShard#{name}.log')
fail_contract("UI shards must reject missing identifiers") unless manifest_source.include?("missing_test_identifiers")
fail_contract("UI shards must run in independently terminable process groups") unless manifest_source.include?("pgroup: true") && manifest_source.include?("terminate_process_group")
fail_contract("UI shard manifest must contain 18 bounded groups") unless manifest_source.scan(/^\s+"[0-9]{2}" => %w\[/).length == 18
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
validation_events = workflow_on(validation_workflow)
fail_contract("Validation must run for pull requests") unless validation_events.key?("pull_request")
fail_contract("Validation must support manual dispatch") unless validation_events.key?("workflow_dispatch")
fail_contract("Validation must not repeat after protected main merges") if validation_events.key?("push")
validation_build_steps = Array(validation_workflow.dig("jobs", "build-test", "steps"))
validation_build = validation_workflow.dig("jobs", "build-test")
isolated_simulator_contract!(validation_build, "Create isolated simulator", "Delete isolated simulator")
build_once = step!(validation_build_steps, "Build coverage-enabled test products once")["run"].to_s
fail_contract("Validation must build test products exactly once") unless build_once.scan("build-for-testing").length == 1
fail_contract("Validation build must enable coverage before test execution") unless build_once.include?("-enableCodeCoverage YES")
unit_tests = step!(validation_build_steps, "Run coverage-enabled unit and localization tests without rebuilding")["run"].to_s
fail_contract("Validation must run the complete unit/localization target") unless unit_tests.include?("-only-testing:HomeStuffInventoryAppTests")
fail_contract("Validation unit/localization phase must not rebuild") unless unit_tests.include?("test-without-building")
unit_result = step!(validation_build_steps, "Reject empty successful unit results")["run"].to_s
fail_contract("Validation must reject empty successful unit results") unless unit_result.include?("ordinary_validation.rb validate-result")
ui_smoke = step!(validation_build_steps, "Run UI smoke baseline")
fail_contract("Validation UI smoke must use the bounded process helper") unless ui_smoke["run"].to_s.include?("ruby .github/scripts/bounded_process.rb run")
fail_contract("Validation UI smoke must use a local 900-second deadline") unless ui_smoke["run"].to_s.include?("--timeout-seconds 900")
fail_contract("Validation UI smoke must preserve failure for diagnostics") unless ui_smoke["continue-on-error"] == true
fail_contract("Validation UI smoke must reuse built products") unless ui_smoke["run"].to_s.include?("test-without-building")
ui_result = step!(validation_build_steps, "Reject empty successful UI smoke result")["run"].to_s
fail_contract("Validation must reject empty successful UI smoke results") unless ui_result.include?("ordinary_validation.rb validate-result")
coverage = step!(validation_build_steps, "Enforce 90% app-code coverage")["run"].to_s
fail_contract("Validation coverage must use the authoritative unit result") unless coverage.include?("check-code-coverage.py TestResults/UnitTests.xcresult --minimum 90")
ui_smoke_upload = step!(validation_build_steps, "Upload result bundles on failure")
fail_contract("Validation UI smoke diagnostics must include its log") unless ui_smoke_upload.dig("with", "path").to_s.include?("TestResults/UITests.log")
fail_contract("Validation UI smoke diagnostics must include its summary") unless ui_smoke_upload.dig("with", "path").to_s.include?("TestResults/ui-smoke-summary.json")
fail_contract("Validation unit diagnostics must include its log") unless ui_smoke_upload.dig("with", "path").to_s.include?("TestResults/UnitTests.log")
summary = step!(validation_build_steps, "Summarize ordinary validation timing")["run"].to_s
fail_contract("Validation must publish timing observability") unless summary.include?("ordinary_validation.rb summarize")
phase_gate = step!(validation_build_steps, "Fail unless every app validation phase succeeded")
%w[BUILD_OUTCOME UNIT_OUTCOME COVERAGE_OUTCOME UI_OUTCOME].each do |outcome|
  fail_contract("Validation required app gate must propagate #{outcome}") unless phase_gate.dig("env", outcome)
end
fastlane_smoke = validation_workflow.dig("jobs", "fastlane-smoke-test")
fail_contract("Validation must run Fastlane smoke away from scarce macOS capacity") unless fastlane_smoke&.fetch("runs-on", nil) == "ubuntu-latest"
{
  "fastlane-smoke-test" => "ubuntu-latest",
  "build-test" => "macos-26",
  "code-coverage" => "ubuntu-latest"
}.each do |job_name, runner|
  fail_contract("Validation #{job_name} must use the reviewed hosted runner") unless validation_workflow.dig("jobs", job_name, "runs-on") == runner
  condition = validation_workflow.dig("jobs", job_name, "if").to_s
  fail_contract("Validation #{job_name} must remain path-aware") unless condition.include?("needs.classify-changes.outputs.")
  fail_contract("Validation #{job_name} must not exclude pull requests") if condition.include?("github.event_name != 'pull_request'")
end
coverage_gate = validation_workflow.dig("jobs", "code-coverage")
fail_contract("Stable Code coverage check must depend on combined app validation") unless Array(coverage_gate["needs"]).include?("build-test")
required_gate = validation_workflow.dig("jobs", "ci-validation")
fail_contract("Required CI workflow validation must always aggregate selected phases") unless required_gate["if"] == "always()"
%w[classify-changes ci-contracts fastlane-smoke-test build-test code-coverage].each do |dependency|
  fail_contract("Required CI workflow validation must depend on #{dependency}") unless Array(required_gate["needs"]).include?(dependency)
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
