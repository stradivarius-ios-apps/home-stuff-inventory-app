#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
SCRIPT = File.join(ROOT, ".github/scripts/bounded_process.rb")

def assert(condition, message)
  abort "Bounded process helper test failed: #{message}" unless condition
end

Dir.mktmpdir("bounded-process-success") do |directory|
  log = File.join(directory, "success.log")
  summary = File.join(directory, "success.json")
  output_path = File.join(directory, "github-output")
  output, status = Open3.capture2e(
    { "GITHUB_OUTPUT" => output_path },
    "ruby", SCRIPT, "run",
    "--timeout-seconds", "2",
    "--progress-seconds", "0.1",
    "--log", log,
    "--summary", summary,
    "--",
    "ruby", "-e", 'puts "completed"'
  )
  assert(status.success?, "successful command failed: #{output}")
  assert(File.read(log).include?("completed"), "successful command output was not captured")
  assert(JSON.parse(File.read(summary)).fetch("status") == "success", "success summary was not recorded")
  assert(File.read(output_path).include?("status=success"), "success output was not published")
end

Dir.mktmpdir("bounded-process-failure") do |directory|
  summary = File.join(directory, "failure.json")
  output, status = Open3.capture2e(
    "ruby", SCRIPT, "run",
    "--timeout-seconds", "2",
    "--log", File.join(directory, "failure.log"),
    "--summary", summary,
    "--",
    "ruby", "-e", "exit 7"
  )
  assert(!status.success?, "failed command must fail the helper: #{output}")
  payload = JSON.parse(File.read(summary))
  assert(payload.fetch("status") == "failure", "failure status was not recorded")
  assert(payload.fetch("exit_status") == 7, "failure exit status was not retained")
end

Dir.mktmpdir("bounded-process-timeout") do |directory|
  child_pid_path = File.join(directory, "child-pid")
  command_path = File.join(directory, "stubborn.rb")
  File.write(command_path, <<~RUBY)
    child = spawn("ruby", "-e", 'trap("TERM") {}; loop { sleep 1 }')
    File.write(ENV.fetch("CHILD_PID_PATH"), child.to_s)
    trap("TERM") {}
    Process.wait(child)
  RUBY
  summary = File.join(directory, "timeout.json")
  started_at = Time.now
  output, status = Open3.capture2e(
    { "CHILD_PID_PATH" => child_pid_path },
    "ruby", SCRIPT, "run",
    "--timeout-seconds", "0.5",
    "--grace-seconds", "0.2",
    "--progress-seconds", "0.1",
    "--log", File.join(directory, "timeout.log"),
    "--summary", summary,
    "--",
    "ruby", command_path
  )
  assert(!status.success?, "timed-out command must fail the helper: #{output}")
  assert(Time.now - started_at < 5, "timeout did not bound the helper")
  payload = JSON.parse(File.read(summary))
  assert(payload.fetch("status") == "timeout", "timeout status was not recorded")
  child_pid = Integer(File.read(child_pid_path))
  child_alive = begin
    Process.kill(0, child_pid)
    true
  rescue Errno::ESRCH
    false
  end
  assert(!child_alive, "timeout left a descendant process running")
end

Dir.mktmpdir("bounded-process-invalid-timeout") do |directory|
  marker = File.join(directory, "spawned")
  ["0", "1e999", "NaN", "900.1"].each do |invalid_timeout|
    FileUtils.rm_f(marker)
    output, status = Open3.capture2e(
      "ruby", SCRIPT, "run",
      "--timeout-seconds", invalid_timeout,
      "--log", File.join(directory, "invalid.log"),
      "--summary", File.join(directory, "invalid.json"),
      "--",
      "ruby", "-e", "File.write(#{marker.dump}, 'spawned')"
    )
    assert(!status.success?, "invalid timeout #{invalid_timeout.inspect} must fail: #{output}")
    assert(!File.exist?(marker), "invalid timeout #{invalid_timeout.inspect} spawned the command")
  end
end
