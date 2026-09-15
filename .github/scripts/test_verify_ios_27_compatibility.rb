#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "verify_ios_27_compatibility"

class IOS27CompatibilityTest < Minitest::Test
  def test_accepts_xcode_and_simulator_sdk_27
    output = capture_io do
      IOS27Compatibility.validate!(xcode_version: "27.0", simulator_sdk_version: "27.0")
    end.first

    assert_includes output, "iOS 27 SDK compatibility gate passed"
  end

  def test_rejects_an_older_xcode
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) do
        IOS27Compatibility.validate!(xcode_version: "26.6", simulator_sdk_version: "27.0")
      end

      assert_equal 1, error.status
    end

    assert_includes error_output, "Xcode 26.6"
  end

  def test_rejects_an_older_simulator_sdk
    _output, error_output = capture_io do
      error = assert_raises(SystemExit) do
        IOS27Compatibility.validate!(xcode_version: "27.0", simulator_sdk_version: "26.5")
      end

      assert_equal 1, error.status
    end

    assert_includes error_output, "iOS Simulator SDK 26.5"
  end
end
