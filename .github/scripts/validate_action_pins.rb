#!/usr/bin/env ruby
# frozen_string_literal: true

PINS = {
  "actions/checkout" => ["9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0", "v7.0.0"],
  "actions/create-github-app-token" => ["bcd2ba49218906704ab6c1aa796996da409d3eb1", "v3.2.0"],
  "actions/upload-artifact" => ["043fb46d1a93c77aae656e7c1c64a875d1fc6a0a", "v7.0.1"],
  "github/codeql-action" => ["2892aa5e19bbd11bc0cff5427e3b750a04d9e3c2", "v4.38.2"]
}.freeze

Dir[".github/workflows/*.yml"].sort.each do |path|
  File.readlines(path, chomp: true).each_with_index do |line, index|
    match = line.match(/^\s*uses:\s*(actions\/[^@\s]+)@([^\s#]+)(?:\s+#\s*(v\d+(?:\.\d+){0,2}))?\s*$/)
    next unless match

    action, revision, version = match.captures
    expected = PINS.fetch(action) { abort "#{path}:#{index + 1} has an unreviewed official action #{action}." }
    abort "#{path}:#{index + 1} must pin #{action} to its reviewed immutable SHA and version comment." unless expected == [revision, version]
  end
end

puts "Official GitHub Actions are pinned to reviewed immutable SHAs."
