#!/usr/bin/env ruby
# frozen_string_literal: true

require "uri"

module AppStoreMetadataContract
  LOCALES = %w[en-GB uk].freeze
  FILES = %w[description.txt keywords.txt privacy_url.txt promotional_text.txt subtitle.txt support_url.txt].freeze
  LIMITS = {
    "description.txt" => 4_000,
    "keywords.txt" => 100,
    "promotional_text.txt" => 170,
    "subtitle.txt" => 30
  }.freeze
  FORBIDDEN = %w[name.txt release_notes.txt].freeze

  module_function

  def validate!(root)
    raise "Metadata directory does not exist: #{root}" unless Dir.exist?(root)
    actual_locales = Dir.children(root).reject { |entry| entry.start_with?(".") }.select { |entry| File.directory?(File.join(root, entry)) }.sort
    raise "Metadata locales must be exactly #{LOCALES.join(', ')}." unless actual_locales == LOCALES.sort

    LOCALES.each do |locale|
      directory = File.join(root, locale)
      files = Dir.children(directory).reject { |entry| entry.start_with?(".") }.sort
      forbidden = files & FORBIDDEN
      raise "#{locale} must not manage app name or release notes: #{forbidden.join(', ')}." unless forbidden.empty?
      raise "#{locale} metadata files must be exactly #{FILES.join(', ')}." unless files == FILES.sort

      FILES.each do |file|
        value = File.read(File.join(directory, file), encoding: "UTF-8").strip
        raise "#{locale}/#{file} is empty." if value.empty?
        limit = LIMITS[file]
        raise "#{locale}/#{file} exceeds #{limit} characters." if limit && value.length > limit
      end

      %w[support_url.txt privacy_url.txt].each do |file|
        uri = URI.parse(File.read(File.join(directory, file)).strip)
        raise "#{locale}/#{file} must be a public HTTPS URL." unless uri.is_a?(URI::HTTPS) && uri.host
      end
    end

    true
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    AppStoreMetadataContract.validate!(ARGV.fetch(0, "fastlane/metadata"))
    puts "App Store metadata contract is valid for en-GB and uk."
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
