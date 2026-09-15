#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "verify_ios_27_compatibility"

class IOS27CompatibilityTest < Minitest::Test
  IOS_27_RUNTIME = [{
    "identifier" => "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
    "version" => "27.0",
    "isAvailable" => true
  }].freeze

  def test_accepts_xcode_and_simulator_sdk_27
    output = capture_io do
      IOS27Compatibility.validate!(
        xcode_version: "27.0",
        simulator_sdk_version: "27.0",
        runtimes: IOS_27_RUNTIME
      )
    end.first

    assert_includes output, "iOS 27 compatibility gate passed"
  end

  def test_rejects_an_older_xcode
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) do
        IOS27Compatibility.validate!(
          xcode_version: "26.6",
          simulator_sdk_version: "27.0",
          runtimes: IOS_27_RUNTIME
        )
      end

      assert_equal 1, error.status
    end

    assert_includes error_output, "Xcode 26.6"
  end

  def test_rejects_an_older_simulator_sdk
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) do
        IOS27Compatibility.validate!(
          xcode_version: "27.0",
          simulator_sdk_version: "26.5",
          runtimes: IOS_27_RUNTIME
        )
      end

      assert_equal 1, error.status
    end

    assert_includes error_output, "iOS Simulator SDK 26.5"
  end

  def test_rejects_a_missing_or_unavailable_27_0_runtime
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) do
        IOS27Compatibility.validate!(
          xcode_version: "27.0",
          simulator_sdk_version: "27.0",
          runtimes: [{
            "identifier" => "com.apple.CoreSimulator.SimRuntime.iOS-27-1",
            "version" => "27.1",
            "isAvailable" => true
          }]
        )
      end

      assert_equal 1, error.status
    end

    assert_includes error_output, "required iOS 27.0 simulator runtime is unavailable"
  end
end
