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

# A fresh device prevents unrelated simulator state or apps from affecting capture.
release_udid="$(xcrun simctl create "${RELEASE_SCREENSHOT_SIMULATOR_NAME}-$$" "$RELEASE_SCREENSHOT_DEVICE_TYPE" "$runtime_identifier")"
cleanup_simulator() {
  local result=$?
  trap - EXIT
  xcrun simctl shutdown "$release_udid" >/dev/null 2>&1 || true
  if ! xcrun simctl delete "$release_udid"; then
    echo "Failed to delete the release screenshot simulator." >&2
    if [[ "$result" -eq 0 ]]; then result=1; fi
  fi
  exit "$result"
}
trap cleanup_simulator EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcrun simctl boot "$release_udid"
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
  ENABLE_TESTABILITY=YES \
  CODE_SIGNING_ALLOWED=NO

ruby .github/scripts/export_release_app_store_screenshots.rb "$result_bundle" "$output_directory"
