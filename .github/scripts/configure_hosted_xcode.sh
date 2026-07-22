#!/bin/bash

set -euo pipefail

readonly expected_xcode_version="26.6"
readonly expected_xcode_build="17F113"
readonly developer_directory="/Applications/Xcode_26.6.app/Contents/Developer"
readonly simulator_runtime="iOS 26.5"

if [[ ! -d "$developer_directory" ]]; then
  echo "Required Xcode developer directory is unavailable: $developer_directory"
  exit 1
fi

sudo xcode-select --switch "$developer_directory"
sudo xcodebuild -runFirstLaunch

actual_version="$(xcodebuild -version)"
expected_version=$'Xcode '"$expected_xcode_version"$'\nBuild version '"$expected_xcode_build"
if [[ "$actual_version" != "$expected_version" ]]; then
  echo "Unexpected Xcode selection."
  printf 'Expected:\n%s\nActual:\n%s\n' "$expected_version" "$actual_version"
  exit 1
fi

if [[ "$(xcode-select -p)" != "$developer_directory" ]]; then
  echo "xcode-select did not retain the required developer directory."
  exit 1
fi

if ! xcrun simctl list runtimes available | grep -Fq "$simulator_runtime"; then
  echo "Required simulator runtime is unavailable: $simulator_runtime"
  xcrun simctl list runtimes available
  exit 1
fi

for device_type in "iPhone 17" "iPhone 14 Plus"; do
  if ! xcrun simctl list devicetypes | grep -Fq "$device_type"; then
    echo "Required simulator device type is unavailable: $device_type"
    exit 1
  fi
done

echo "Hosted toolchain contract: macos-26-intel, Xcode $expected_xcode_version ($expected_xcode_build), $simulator_runtime."
