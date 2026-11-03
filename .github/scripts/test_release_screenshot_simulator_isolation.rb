# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class ReleaseScreenshotSimulatorIsolationTest < Minitest::Test
  HELPER = File.expand_path("capture_release_app_store_screenshots.sh", __dir__)

  def setup
    @root = Dir.mktmpdir("release-simulator-test")
    @bin = File.join(@root, "bin")
    @calls = File.join(@root, "calls")
    FileUtils.mkdir_p(@bin)
    stub("xcrun", <<~'SH')
      #!/bin/bash
      printf '%s\n' "$*" >> "$CALL_LOG"
      case "$*" in
        'simctl list runtimes --json') printf '%s\n' '{"runtimes":[{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-5","isAvailable":true}]}' ;;
        'simctl list devicetypes --json') printf '%s\n' '{"devicetypes":[{"identifier":"device-type"}]}' ;;
        'simctl create '*) echo 'test-device-uuid' ;;
        'simctl delete test-device-uuid') exit "${DELETE_EXIT:-0}" ;;
      esac
    SH
    stub("xcodebuild", "#!/bin/bash\nexit \"${BUILD_EXIT:-0}\"\n")
    stub("ruby", <<~'SH')
      #!/bin/bash
      if [[ "$1" == '-rjson' ]]; then exec "$REAL_RUBY" "$@"; fi
      exit 0
    SH
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_uses_new_simulator_and_deletes_it_after_success
    _out, err, result = run_capture
    assert result.success?, err
    calls = File.read(@calls)
    assert_match(/simctl create .* device-type com\.apple\.CoreSimulator\.SimRuntime\.iOS-26-5/, calls)
    refute_includes calls, "simctl list devices available"
    assert_includes calls, "simctl shutdown test-device-uuid"
    assert_includes calls, "simctl delete test-device-uuid"
  end

  def test_deletes_own_simulator_when_test_fails
    _out, _err, result = run_capture("BUILD_EXIT" => "65")
    assert_equal 65, result.exitstatus
    assert_includes File.read(@calls), "simctl delete test-device-uuid"
  end

  def test_cleanup_failure_fails_otherwise_successful_capture
    _out, err, result = run_capture("DELETE_EXIT" => "1")
    refute result.success?
    assert_includes err, "Failed to delete the release screenshot simulator."
  end

  private

  def stub(name, contents)
    path = File.join(@bin, name)
    File.write(path, contents)
    File.chmod(0o755, path)
  end

  def run_capture(extra = {})
    env = {
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}", "CALL_LOG" => @calls,
      "REAL_RUBY" => RbConfig.ruby, "PROJECT" => "test.xcodeproj", "SCHEME" => "test",
      "CONFIGURATION" => "Debug", "RELEASE_SCREENSHOT_DEVICE_TYPE" => "device-type",
      "RELEASE_SCREENSHOT_SIMULATOR_NAME" => "Screenshot test", "RELEASE_SCREENSHOT_OS" => "26.5",
      "RELEASE_SCREENSHOT_SOURCE_SHA" => "a" * 40
    }.merge(extra)
    Open3.capture3(env, "bash", HELPER, chdir: @root)
  end
end
