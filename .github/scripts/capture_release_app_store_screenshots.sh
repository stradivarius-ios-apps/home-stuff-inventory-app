#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT:?PROJECT is required}"
: "${SCHEME:?SCHEME is required}"
: "${CONFIGURATION:?CONFIGURATION is required}"
: "${RELEASE_SCREENSHOT_DEVICE_TYPE:?RELEASE_SCREENSHOT_DEVICE_TYPE is required}"
: "${RELEASE_SCREENSHOT_SIMULATOR_NAME:?RELEASE_SCREENSHOT_SIMULATOR_NAME is required}"
: "${RELEASE_SCREENSHOT_OS:?RELEASE_SCREENSHOT_OS is required}"
: "${RELEASE_SCREENSHOT_SOURCE_SHA:?RELEASE_SCREENSHOT_SOURCE_SHA is required}"

result_bundle="TestResults/ReleaseAppStoreScreenshots.xcresult"
output_directory="release-app-store-screenshots"
runtime_identifier="com.apple.CoreSimulator.SimRuntime.iOS-${RELEASE_SCREENSHOT_OS//./-}"
export runtime_identifier

rm -rf TestResults "$output_directory"
mkdir -p TestResults

xcrun simctl list runtimes --json | ruby -rjson -e '
  expected = ENV.fetch("runtime_identifier")
  abort "Required runtime is unavailable: #{expected}" unless JSON.parse(STDIN.read).fetch("runtimes").any? { |runtime| runtime["identifier"] == expected && runtime["isAvailable"] }
'
xcrun simctl list devicetypes --json | ruby -rjson -e '
  expected = ENV.fetch("RELEASE_SCREENSHOT_DEVICE_TYPE")
  abort "Required device type is unavailable: #{expected}" unless JSON.parse(STDIN.read).fetch("devicetypes").any? { |device| device["identifier"] == expected }
'

release_udid="$(xcrun simctl list devices available --json | ruby -rjson -e '
  runtime = ENV.fetch("runtime_identifier")
  type = ENV.fetch("RELEASE_SCREENSHOT_DEVICE_TYPE")
  device = JSON.parse(STDIN.read).fetch("devices").fetch(runtime, []).find { |candidate| candidate["deviceTypeIdentifier"] == type && candidate["isAvailable"] }
  puts device["udid"] if device
')"
if [[ -z "$release_udid" ]]; then
  release_udid="$(xcrun simctl create "$RELEASE_SCREENSHOT_SIMULATOR_NAME" "$RELEASE_SCREENSHOT_DEVICE_TYPE" "$runtime_identifier")"
fi

xcrun simctl boot "$release_udid" || true
xcrun simctl bootstatus "$release_udid" -b
xcrun simctl ui "$release_udid" appearance light
xcrun simctl status_bar "$release_udid" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$release_udid" \
  -configuration "$CONFIGURATION" \
  -only-testing:"HomeStuffInventoryAppUITests/InventoryReleaseScreenshotUITests/testReleaseAppStoreScreenshots" \
  -resultBundlePath "$result_bundle" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG RELEASE_APP_STORE_SCREENSHOTS" \
  CODE_SIGNING_ALLOWED=NO

ruby .github/scripts/export_release_app_store_screenshots.rb "$result_bundle" "$output_directory"
