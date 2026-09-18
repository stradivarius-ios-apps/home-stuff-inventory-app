#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "support/release_contract"

module AppStoreReleaseNotesContract
  LOCALES = %w[en-GB uk].freeze
  MAXIMUM_LENGTH = 4_000

  module_function

  def validate!(root:, version:)
    version = ReleaseContract.strict_version!(version, label: "Release-notes version")
    directory = File.join(root, version)
    raise "Release-notes directory does not exist: #{directory}" unless Dir.exist?(directory)

    files = Dir.children(directory).reject { |entry| entry.start_with?(".") }.sort
    expected = LOCALES.map { |locale| "#{locale}.txt" }
    raise "Release-notes files must be exactly #{expected.join(', ')}." unless files == expected

    expected.each do |file|
      value = File.read(File.join(directory, file), encoding: "UTF-8").strip
      raise "#{version}/#{file} is empty." if value.empty?
      raise "#{version}/#{file} exceeds #{MAXIMUM_LENGTH} characters." if value.length > MAXIMUM_LENGTH
    end
    true
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    AppStoreReleaseNotesContract.validate!(root: ARGV.fetch(0, "fastlane/release_notes"), version: ARGV.fetch(1))
    puts "App Store release notes are valid for en-GB and uk."
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
