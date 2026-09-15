#!/usr/bin/env ruby
# frozen_string_literal: true

# Release gate: an iOS 27 candidate must use an Xcode and Simulator SDK that support iOS 27.
require "open3"
require "json"

module IOS27Compatibility
  module_function

  REQUIRED_MAJOR_VERSION = 27
  REQUIRED_RUNTIME_IDENTIFIER = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"
  REQUIRED_RUNTIME_VERSION = "27.0"

  def fail!(message)
    warn "iOS 27 compatibility gate failed: #{message}"
    exit 1
  end

  def major_version!(version, label)
    match = version.strip.match(/\A(\d+)(?:\.\d+)*\z/)
    fail!("#{label} is not a numeric version: #{version.inspect}") unless match

    match[1].to_i
  end

  def validate!(xcode_version:, simulator_sdk_version:, runtimes:)
    xcode_major = major_version!(xcode_version, "Xcode version")
    sdk_major = major_version!(simulator_sdk_version, "iOS Simulator SDK version")

    fail!("Xcode #{xcode_version} does not support the required Xcode #{REQUIRED_MAJOR_VERSION} toolchain") if xcode_major < REQUIRED_MAJOR_VERSION
    fail!("iOS Simulator SDK #{simulator_sdk_version} does not support iOS #{REQUIRED_MAJOR_VERSION}") if sdk_major < REQUIRED_MAJOR_VERSION
    runtime = runtimes.find do |candidate|
      candidate["identifier"] == REQUIRED_RUNTIME_IDENTIFIER &&
        candidate["version"] == REQUIRED_RUNTIME_VERSION
    end
    fail!("required iOS #{REQUIRED_RUNTIME_VERSION} simulator runtime is unavailable") unless runtime&.fetch("isAvailable", false)

    puts "iOS 27 compatibility gate passed (Xcode #{xcode_version}, iOS Simulator SDK #{simulator_sdk_version}, runtime #{REQUIRED_RUNTIME_VERSION})."
  end

  def command_output!(*command)
    output, status = Open3.capture2e(*command)
    fail!("#{command.join(' ')} failed:\n#{output}") unless status.success?

    output.strip
  end

  def validate_host!
    xcode_version = command_output!("xcodebuild", "-version")[/^Xcode\s+(.+)$/, 1]
    fail!("xcodebuild -version did not report an Xcode version") unless xcode_version

    validate!(
      xcode_version: xcode_version,
      simulator_sdk_version: command_output!("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"),
      runtimes: JSON.parse(command_output!("xcrun", "simctl", "list", "runtimes", "--json")).fetch("runtimes")
    )
  end
end

IOS27Compatibility.validate_host! if __FILE__ == $PROGRAM_NAME
