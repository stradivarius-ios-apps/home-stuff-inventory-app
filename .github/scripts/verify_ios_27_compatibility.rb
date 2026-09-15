#!/usr/bin/env ruby
# frozen_string_literal: true

# Release gate: an iOS 27 candidate must use an Xcode and Simulator SDK that support iOS 27.
require "open3"

module IOS27Compatibility
  module_function

  REQUIRED_MAJOR_VERSION = 27

  def fail!(message)
    warn "iOS 27 compatibility gate failed: #{message}"
    exit 1
  end

  def major_version!(version, label)
    match = version.strip.match(/\A(\d+)(?:\.\d+)*\z/)
    fail!("#{label} is not a numeric version: #{version.inspect}") unless match

    match[1].to_i
  end

  def validate!(xcode_version:, simulator_sdk_version:)
    xcode_major = major_version!(xcode_version, "Xcode version")
    sdk_major = major_version!(simulator_sdk_version, "iOS Simulator SDK version")

    fail!("Xcode #{xcode_version} does not support the required Xcode #{REQUIRED_MAJOR_VERSION} toolchain") if xcode_major < REQUIRED_MAJOR_VERSION
    fail!("iOS Simulator SDK #{simulator_sdk_version} does not support iOS #{REQUIRED_MAJOR_VERSION}") if sdk_major < REQUIRED_MAJOR_VERSION

    puts "iOS 27 SDK compatibility gate passed (Xcode #{xcode_version}, iOS Simulator SDK #{simulator_sdk_version})."
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
      simulator_sdk_version: command_output!("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version")
    )
  end
end

IOS27Compatibility.validate_host! if __FILE__ == $PROGRAM_NAME
