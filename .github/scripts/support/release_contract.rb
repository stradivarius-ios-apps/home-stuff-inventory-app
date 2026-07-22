#!/usr/bin/env ruby
# frozen_string_literal: true

module ReleaseContract
  PROJECT_PATH = "HomeStuffInventoryApp.xcodeproj/project.pbxproj"
  CHANGELOG_PATH = "CHANGELOG.md"
  IDENTIFIER = /(?:0|[1-9]\d*)/
  SEMVER = /\A#{IDENTIFIER}\.#{IDENTIFIER}\.#{IDENTIFIER}\z/
  SHA = /\A[0-9a-fA-F]{40}\z/

  module_function

  def tuple(version)
    version.split(".").map(&:to_i)
  end

  def compare(left, right)
    tuple(left) <=> tuple(right)
  end

  def strict_version!(value, label: "Version")
    version = value.to_s.strip
    raise "#{label} must use strict MAJOR.MINOR.PATCH SemVer." unless version.match?(SEMVER)
    version
  end

  def strict_sha!(value, label: "SHA")
    sha = value.to_s.strip
    raise "#{label} must be an exact 40-character SHA." unless sha.match?(SHA)

    sha.downcase
  end

  def normalize_version(input, allow_leading_v: false)
    value = input.to_s.strip
    return nil if value.empty?
    value = value.delete_prefix("v") if allow_leading_v
    strict_version!(value)
  end

  def project_value!(content, setting)
    values = content.scan(/#{Regexp.escape(setting)}\s*=\s*([^;]+);/).flatten.map(&:strip).uniq
    raise "Expected exactly one #{setting} value, found: #{values.join(', ')}." unless values.one?
    values.first
  end

  def project_marketing_version!(content)
    strict_version!(project_value!(content, "MARKETING_VERSION"), label: "MARKETING_VERSION")
  end

  def tag_for(version)
    "v#{strict_version!(version)}"
  end

  def tag_version(tag)
    match = /\Av(#{IDENTIFIER}\.#{IDENTIFIER}\.#{IDENTIFIER})\z/.match(tag.to_s.strip)
    match && match[1]
  end

  def valid_tag_versions(tags)
    tags.filter_map { |tag| tag_version(tag) }
  end

  def changelog_has_version?(content, version)
    content.match?(/^## #{Regexp.escape(version)}(?:\s|$)/)
  end

  def finalized_changelog_entry!(content, version)
    lines = content.lines
    index = lines.index { |line| line.match?(/^## #{Regexp.escape(version)}(?:\s+[-—]\s+.*)?\s*$/) }
    raise "CHANGELOG.md has no entry for #{version}." unless index

    next_index = lines[(index + 1)..]&.index { |line| line.start_with?("## ") }
    finish = next_index ? index + 1 + next_index : lines.length
    entry = lines[index...finish].join.strip
    raise "CHANGELOG.md entry for #{version} is not finalized (Unreleased/TODO remains)." if entry.match?(/\b(?:Unreleased|TODO)\b/i)
    raise "CHANGELOG.md entry for #{version} has no usable release-note bullets." unless entry.lines.any? { |line| line.start_with?("- ") }
    if entry.lines.any? { |line| line.match?(/^- Merge pull request #\d+ from /i) }
      raise "CHANGELOG.md entry for #{version} contains GitHub merge boilerplate."
    end
    entry
  end
end
