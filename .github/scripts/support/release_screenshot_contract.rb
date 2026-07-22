#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

module ReleaseScreenshotContract
  SCHEMA_VERSION = 1
  WIDTH = 1284
  HEIGHT = 2778
  DEVICE_DIRECTORY = "iPhone-14-Plus"
  DEVICE_SLOT = "6.5-inch iPhone"
  LOCALE_MAPPING = { "en" => "en-GB", "uk" => "uk" }.freeze
  SHA = /\A[0-9a-f]{40}\z/
  LOCALES = LOCALE_MAPPING.keys.freeze
  FILES = %w[
    01-item-detail.png
    02-locations-overview.png
    03-location-detail.png
    04-place-detail.png
    05-search-answer.png
    06-add-item-context.png
  ].freeze

  module_function

  def expected_path(locale, file)
    File.join("Screenshots", DEVICE_DIRECTORY, locale, file)
  end

  def validate_manifest!(manifest, expected_source_sha: nil)
    raise "Unsupported screenshot manifest schema." unless manifest["schema_version"] == SCHEMA_VERSION
    raise "Unexpected device directory." unless manifest["device_directory"] == DEVICE_DIRECTORY
    raise "Unexpected App Store device slot." unless manifest["app_store_device_slot"] == DEVICE_SLOT
    raise "Unexpected required dimensions." unless manifest["required_size"] == { "width" => WIDTH, "height" => HEIGHT }
    source_sha = manifest["source_sha"]
    raise "Screenshot source SHA is invalid." unless source_sha == "local-validation" || source_sha.to_s.match?(SHA)
    if expected_source_sha && manifest["source_sha"] != expected_source_sha
      raise "Screenshot source SHA #{manifest['source_sha'].inspect} does not match expected #{expected_source_sha}."
    end

    locales = manifest.fetch("locales")
    raise "Locale order must be #{LOCALES.join(', ')}." unless locales.map { |locale| locale["source_locale"] } == LOCALES

    locales.each do |locale|
      source_locale = locale.fetch("source_locale")
      raise "Invalid App Store locale mapping for #{source_locale}." unless locale["app_store_locale"] == LOCALE_MAPPING.fetch(source_locale)
      screenshots = locale.fetch("screenshots")
      raise "Screenshot order is invalid for #{source_locale}." unless screenshots.map { |screen| screen["file"] } == FILES
      raise "Screenshot indexes are invalid for #{source_locale}." unless screenshots.map { |screen| screen["index"] } == (1..FILES.length).to_a
      screenshots.each do |screen|
        expected = expected_path(source_locale, screen.fetch("file"))
        raise "Screenshot path is invalid: #{screen['path'].inspect}." unless screen["path"] == expected
        raise "Screenshot dimensions are invalid for #{expected}." unless screen["width"] == WIDTH && screen["height"] == HEIGHT
      end
    end
    true
  end

  def artifact_paths(manifest)
    manifest.fetch("locales").flat_map do |locale|
      locale.fetch("screenshots").map { |screen| screen.fetch("path") }
    end
  end

  def validate_artifact_files!(root, manifest)
    expected = artifact_paths(manifest).sort
    actual = Dir.glob(File.join(root, "Screenshots", "**", "*.png")).map { |path| path.delete_prefix("#{root}/") }.sort
    raise "Artifact contains missing, duplicate, or unexpected PNG files." unless actual == expected

    expected.each do |relative|
      validate_png_file!(File.join(root, relative), label: relative)
    end
    true
  end

  def validate_png_file!(path, label: path)
    raise "Screenshot PNG is missing: #{label}" unless File.file?(path)

    stdout, stderr, status = Open3.capture3("sips", "-g", "format", "-g", "pixelWidth", "-g", "pixelHeight", path)
    unless status.success?
      details = [stdout, stderr].reject(&:empty?).join("\n")
      raise "Screenshot PNG cannot be decoded: #{label}#{": #{details}" unless details.empty?}"
    end

    format = stdout[/format:\s*(\S+)/i, 1]
    raise "Screenshot file is not a PNG: #{label}" unless format&.casecmp?("png")

    width = stdout[/pixelWidth:\s*(\d+)/, 1]&.to_i
    height = stdout[/pixelHeight:\s*(\d+)/, 1]&.to_i
    raise "Screenshot PNG dimensions could not be read: #{label}" unless width && height
    raise "Invalid dimensions for #{label}: expected #{WIDTH}x#{HEIGHT}, got #{width}x#{height}" unless width == WIDTH && height == HEIGHT

    [width, height]
  end
end
