#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require_relative "support/public_automation_contract"

UPLOAD_ARTIFACT_V7 = "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
CANONICAL_ENV = {
  "PROJECT" => "HomeStuffInventoryApp.xcodeproj",
  "SCHEME" => "HomeStuffInventoryApp",
  "CONFIGURATION" => "Debug",
  "RELEASE_SCREENSHOT_DEVICE_TYPE" => "com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus",
  "RELEASE_SCREENSHOT_SIMULATOR_NAME" => "Home Stuff Release Screenshots iPhone 14 Plus",
  "RELEASE_SCREENSHOT_OS" => "26.5"
}.freeze
HELPER = ".github/scripts/capture_release_app_store_screenshots.sh"

def fail_lane(message)
  warn "Public release screenshot lane contract failed: #{message}"
  exit 1
end

path = PublicAutomationContract::CANONICAL_RELEASE_SCREENSHOT_WORKFLOW
workflow = YAML.load_file(path)
text = File.read(path)
helper = File.read(HELPER)
events = workflow["on"] || workflow[true] || {}

fail_lane("workflow must remain reusable-only") unless events.keys.map(&:to_s) == ["workflow_call"]
fail_lane("reusable release_ref must be required") unless events.dig("workflow_call", "inputs", "release_ref", "required") == true

job = workflow.dig("jobs", "release-app-store-screenshots")
fail_lane("missing canonical release screenshot job") unless job.is_a?(Hash)
fail_lane("canonical release screenshot job must use GitHub-hosted macOS") unless job["runs-on"] == "macos-26-intel"
fail_lane("canonical release screenshot job must not have a private-control-plane condition") if job.key?("if")

CANONICAL_ENV.each do |key, value|
  fail_lane("workflow must configure #{key}") unless workflow.dig("env", key).to_s == value
end
fail_lane("workflow must configure the display device") unless workflow.dig("env", "RELEASE_SCREENSHOT_DEVICE") == "iPhone 14 Plus"
fail_lane("workflow must configure light appearance") unless workflow.dig("env", "RELEASE_SCREENSHOT_APPEARANCE") == "Light"
fail_lane("workflow must invoke the shared capture helper once") unless text.scan("bash #{HELPER}").length == 1

%w[simctl\ create simctl\ bootstatus simctl\ status_bar xcodebuild\ test export_release_app_store_screenshots.rb].each do |command|
  fail_lane("workflow duplicates #{command}") if text.include?(command.delete("\\"))
end

[
  "set -euo pipefail", "simctl create", "simctl bootstatus", "simctl status_bar", "appearance light",
  "InventoryReleaseScreenshotUITests/testReleaseAppStoreScreenshots", "DEBUG RELEASE_APP_STORE_SCREENSHOTS",
  "TestResults/ReleaseAppStoreScreenshots.xcresult", "release-app-store-screenshots", "export_release_app_store_screenshots.rb"
].each { |value| fail_lane("shared helper is missing #{value}") unless helper.include?(value) }

steps = Array(job["steps"])
uploads = steps.select { |step| step["uses"].to_s.start_with?("actions/upload-artifact@") }
fail_lane("workflow must have exactly one failure diagnostic upload") unless uploads.length == 1
upload = uploads.first
fail_lane("diagnostic upload must use pinned upload-artifact v7") unless upload["uses"] == UPLOAD_ARTIFACT_V7
fail_lane("diagnostic upload must be failure-only") unless upload["if"] == "failure()"
fail_lane("diagnostic retention must be three days") unless upload.dig("with", "retention-days") == 3
fail_lane("diagnostic upload must ignore absent paths") unless upload.dig("with", "if-no-files-found") == "ignore"
fail_lane("diagnostic upload must contain only the result bundle") unless upload.dig("with", "path") == "TestResults/ReleaseAppStoreScreenshots.xcresult"

source = File.read("HomeStuffInventoryAppUITests/InventoryReleaseScreenshotUITests.swift")
fail_lane("UI test must be compile-time isolated") unless source.start_with?("#if RELEASE_APP_STORE_SCREENSHOTS")
fail_lane("UI test must reuse shared screenshot support") unless source.include?("InventoryScreenshotUITestCase")
fail_lane("UI test must use localized App Store demo data") unless source.include?("--use-app-store-demo-data") && source.include?("--app-store-demo-locale")
fail_lane("UI test retains the legacy 2032 workaround") if source.include?("2032")

puts "Public release screenshot lane contract is valid."
