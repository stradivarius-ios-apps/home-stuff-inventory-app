#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

BASH4_CASE_EXPANSION = /\$\{[A-Za-z_][A-Za-z0-9_]*(?:,,|\^\^)\}/

Dir[".github/workflows/*.yml"].sort.each do |path|
  workflow = YAML.load_file(path)
  jobs = workflow.fetch("jobs", {})
  macos_job = jobs.values.any? do |job|
    labels = Array(job["runs-on"])
    labels.include?("macos-26-intel") || (labels.include?("self-hosted") && labels.include?("macOS"))
  end
  next unless macos_job

  if File.read(path).match?(BASH4_CASE_EXPANSION)
    abort "#{path} uses Bash 4-only case expansion in a macOS workflow."
  end
end

puts "macOS workflows avoid Bash 4-only case expansion."
