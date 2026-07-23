#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "optparse"
require "time"

MAX_TIMEOUT_SECONDS = 15 * 60
MAX_TERMINATION_GRACE_SECONDS = 60
MAX_PROGRESS_INTERVAL_SECONDS = 15 * 60
PROCESS_POLL_INTERVAL_SECONDS = 0.1

def abort_with(message)
  warn "Bounded process failed: #{message}"
  exit 1
end

def positive_number(value, name, maximum:)
  number = Float(value)
  abort_with("#{name} must be a finite positive number no greater than #{maximum}") unless number.finite? && number.positive? && number <= maximum

  number
rescue ArgumentError
  abort_with("#{name} must be a finite positive number no greater than #{maximum}")
end

def wait_for_process(pid)
  Process.waitpid2(pid, Process::WNOHANG)
rescue Errno::ECHILD
  nil
end

def signal_process_group(pid, signal)
  Process.kill(signal, -pid)
rescue Errno::ESRCH
  nil
end

def process_group_alive?(pid)
  Process.kill(0, -pid)
  true
rescue Errno::ESRCH
  false
rescue Errno::EPERM
  true
end

def terminate_process_group(pid, grace_seconds)
  signal_process_group(pid, "TERM")
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace_seconds
  leader_status = nil
  loop do
    completed = wait_for_process(pid) unless leader_status
    leader_status ||= completed&.last
    return leader_status unless process_group_alive?(pid)
    break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep PROCESS_POLL_INTERVAL_SECONDS
  end
  signal_process_group(pid, "KILL")
  leader_status || Process.waitpid2(pid).last
rescue Errno::ECHILD
  leader_status
end

def write_summary(path, payload)
  FileUtils.mkdir_p(File.dirname(path))
  temporary_path = "#{path}.tmp"
  File.write(temporary_path, JSON.pretty_generate(payload))
  File.rename(temporary_path, path)
end

def publish_outputs(payload)
  output_path = ENV["GITHUB_OUTPUT"]
  return unless output_path

  File.open(output_path, "a") do |output|
    output.puts "status=#{payload.fetch("status")}"
    output.puts "duration_seconds=#{payload.fetch("duration_seconds")}"
  end
end

def latest_log_line(path)
  return "log is not available yet" unless File.exist?(path)

  File.foreach(path).filter_map { |line| line.strip.empty? ? nil : line.strip }.last || "log has no output yet"
end

def run_bounded_process
  options = {
    timeout_seconds: MAX_TIMEOUT_SECONDS,
    grace_seconds: 10,
    progress_seconds: 60
  }
  parser = OptionParser.new do |arguments|
    arguments.on("--timeout-seconds VALUE") { |value| options[:timeout_seconds] = value }
    arguments.on("--grace-seconds VALUE") { |value| options[:grace_seconds] = value }
    arguments.on("--progress-seconds VALUE") { |value| options[:progress_seconds] = value }
    arguments.on("--log PATH") { |value| options[:log] = value }
    arguments.on("--summary PATH") { |value| options[:summary] = value }
  end
  parser.order!(ARGV)
  command = ARGV
  abort_with("usage: run [options] -- COMMAND [ARGUMENTS...]") if command.empty?
  abort_with("--log is required") unless options[:log]
  abort_with("--summary is required") unless options[:summary]

  timeout_seconds = positive_number(options[:timeout_seconds], "--timeout-seconds", maximum: MAX_TIMEOUT_SECONDS)
  grace_seconds = positive_number(options[:grace_seconds], "--grace-seconds", maximum: MAX_TERMINATION_GRACE_SECONDS)
  progress_seconds = positive_number(options[:progress_seconds], "--progress-seconds", maximum: MAX_PROGRESS_INTERVAL_SECONDS)
  FileUtils.mkdir_p(File.dirname(options.fetch(:log)))
  FileUtils.rm_f(options.fetch(:log))

  started_at = Time.now
  monotonic_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deadline = monotonic_started_at + timeout_seconds
  next_progress_at = monotonic_started_at + progress_seconds
  interrupted_signal = nil
  previous_traps = %w[INT TERM].to_h do |signal|
    [signal, Signal.trap(signal) { interrupted_signal = signal }]
  end
  pid = nil
  process_status = nil
  status = nil
  reason = nil
  begin
    log = File.open(options.fetch(:log), "w")
    pid = Process.spawn(*command, out: log, err: log, pgroup: true)
    log.close
    puts "Started bounded process group #{pid} with a #{timeout_seconds.to_i}-second timeout."

    loop do
      completed = wait_for_process(pid)
      if completed
        process_status = completed.last
        status = process_status.success? ? "success" : "failure"
        break
      end

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if interrupted_signal
        process_status = terminate_process_group(pid, grace_seconds)
        status = "interrupted"
        reason = "received SIG#{interrupted_signal}"
        break
      end
      if now >= deadline
        process_status = terminate_process_group(pid, grace_seconds)
        status = "timeout"
        reason = "exceeded the #{timeout_seconds.to_i}-second timeout"
        break
      end
      if now >= next_progress_at
        elapsed = (now - monotonic_started_at).round
        puts "Bounded process #{pid} is still running after #{elapsed} seconds; latest log line: #{latest_log_line(options.fetch(:log))}"
        next_progress_at = now + progress_seconds
      end
      sleep PROCESS_POLL_INTERVAL_SECONDS
    end
  rescue StandardError => error
    process_status ||= terminate_process_group(pid, grace_seconds) if pid
    status = "failure"
    reason = "#{error.class}: #{error.message}"
  ensure
    %w[INT TERM].each { |signal| Signal.trap(signal, previous_traps.fetch(signal)) }
  end

  finished_at = Time.now
  payload = {
    "status" => status,
    "reason" => reason,
    "exit_status" => process_status&.exitstatus,
    "termination_signal" => process_status&.termsig,
    "process_id" => pid,
    "started_at" => started_at.utc.iso8601,
    "finished_at" => finished_at.utc.iso8601,
    "duration_seconds" => (finished_at - started_at).round,
    "log" => options.fetch(:log)
  }
  write_summary(options.fetch(:summary), payload)
  publish_outputs(payload)
  puts "Bounded process finished with status #{status} after #{payload.fetch("duration_seconds")} seconds#{reason ? ": #{reason}" : "."}"
  exit 1 unless status == "success"
end

if __FILE__ == $PROGRAM_NAME
  command = ARGV.shift
  command == "run" ? run_bounded_process : abort_with("expected run")
end
