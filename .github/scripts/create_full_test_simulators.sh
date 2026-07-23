#!/bin/bash

set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"

simulator_a=""
simulator_b=""
setup_complete=false

cleanup_incomplete_setup() {
  status=$?
  trap - EXIT INT TERM
  if [[ "$setup_complete" != "true" ]]; then
    for simulator_udid in "$simulator_a" "$simulator_b"; do
      if [[ -n "$simulator_udid" ]]; then
        xcrun simctl shutdown "$simulator_udid" || true
        xcrun simctl delete "$simulator_udid" || true
      fi
    done
  fi
  exit "$status"
}

trap 'exit 130' INT
trap 'exit 143' TERM
trap cleanup_incomplete_setup EXIT

suffix="${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
simulator_a="$(xcrun simctl create "HSI Full Tests A $suffix" "iPhone 17" "com.apple.CoreSimulator.SimRuntime.iOS-26-5")"
simulator_b="$(xcrun simctl create "HSI Full Tests B $suffix" "iPhone 17" "com.apple.CoreSimulator.SimRuntime.iOS-26-5")"
{
  echo "udid_a=$simulator_a"
  echo "udid_b=$simulator_b"
} >> "$GITHUB_OUTPUT"

xcrun simctl boot "$simulator_a"
xcrun simctl boot "$simulator_b"
xcrun simctl bootstatus "$simulator_a" -b
xcrun simctl bootstatus "$simulator_b" -b

setup_complete=true
