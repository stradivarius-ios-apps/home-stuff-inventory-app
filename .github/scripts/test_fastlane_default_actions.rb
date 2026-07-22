#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

root = File.expand_path("../..", __dir__)
stdout, stderr, status = Open3.capture3("bundle", "exec", "fastlane", "actions", chdir: root)
print stdout
warn stderr unless stderr.empty?
abort "Locked Fastlane bundle could not load its default actions." unless status.success?

puts "Locked Fastlane default actions load successfully."
