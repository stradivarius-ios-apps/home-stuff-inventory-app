#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "rbconfig"
require_relative "support/public_automation_contract"

root = __dir__
repository_root = File.expand_path("../..", root)
include_fastlane = ENV["FASTLANE_SMOKE_TEST"] == "true"

if ARGV == ["--list-files"]
  puts PublicAutomationContract.public_runner_file_closure(
    repository_root: repository_root
  )
  exit
end

abort "Usage: run_public_automation_checks.rb [--list-files]" unless ARGV.empty?

scripts = PublicAutomationContract::PUBLIC_CHECKS.dup
scripts << PublicAutomationContract::FASTLANE_SMOKE_TEST if include_fastlane

scripts.each do |script|
  path = File.join(root, script)
  abort "Public automation check is missing: #{script}" unless File.file?(path)
  puts "\n==> #{script}"
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, path, chdir: repository_root)
  print stdout
  warn stderr unless stderr.empty?
  abort "Public automation check failed: #{script}" unless status.success?
end

puts "\nAll #{scripts.length} public automation checks passed."
