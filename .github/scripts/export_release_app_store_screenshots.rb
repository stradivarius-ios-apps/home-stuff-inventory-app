#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "open3"
require "time"
require_relative "support/release_screenshot_contract"

class ReleaseScreenshotExporter
  include ReleaseScreenshotContract

  def initialize(result_bundle:, output_directory:)
    @result_bundle = result_bundle
    @output_directory = output_directory
    @attachments_directory = File.join(output_directory, "_attachments")
  end

  def run
    raise "Result bundle does not exist: #{@result_bundle}" unless File.directory?(@result_bundle)

    FileUtils.rm_rf(@output_directory)
    FileUtils.mkdir_p(@attachments_directory)
    export_attachments
    sources = validated_sources
    dimensions = copy_and_validate_dimensions(sources)
    FileUtils.rm_rf(@attachments_directory)
    manifest = build_manifest(dimensions)
    ReleaseScreenshotContract.validate_manifest!(manifest)
    File.write(File.join(@output_directory, "screenshots-manifest.json"), JSON.pretty_generate(manifest))
    write_summary(manifest)
    write_index(manifest)
  end

  private

  def export_attachments
    command = ["xcrun", "xcresulttool", "export", "attachments", "--path", @result_bundle, "--output-path", @attachments_directory]
    stdout, stderr, status = Open3.capture3(*command)
    raise [stdout, stderr].reject(&:empty?).join("\n") unless status.success?
  end

  def validated_sources
    manifest = JSON.parse(File.read(File.join(@attachments_directory, "manifest.json")))
    attachments = manifest.flat_map { |test| test.fetch("attachments", []) }
    expected = LOCALES.product(FILES).to_h { |locale, file| ["#{locale}-#{File.basename(file, '.png')}", [locale, file]] }
    candidates = Hash.new { |hash, key| hash[key] = [] }
    unexpected = []

    attachments.each do |attachment|
      raw_name = attachment["suggestedHumanReadableName"].to_s
      name = raw_name.sub(/_\d+_[[:xdigit:]-]+\.png\z/, "")
      next unless name.match?(/\A(?:en|uk)-/)

      key = expected[name]
      unless key
        unexpected << raw_name
        next
      end
      source = File.join(@attachments_directory, attachment.fetch("exportedFileName"))
      raise "Exported attachment is missing: #{source}" unless File.file?(source)
      candidates[key] << source
    end

    raise "Unexpected or stale release screenshots: #{unexpected.join(', ')}" unless unexpected.empty?
    duplicates = candidates.select { |_key, values| values.length > 1 }.keys
    raise "Duplicate release screenshots: #{duplicates.map { |key| key.join('/') }.join(', ')}" unless duplicates.empty?
    missing = LOCALES.product(FILES).reject { |key| candidates[key].one? }
    raise "Missing release screenshots: #{missing.map { |key| key.join('/') }.join(', ')}" unless missing.empty?

    candidates.transform_values(&:first)
  end

  def copy_and_validate_dimensions(sources)
    dimensions = {}
    LOCALES.product(FILES).each do |locale, file|
      relative = ReleaseScreenshotContract.expected_path(locale, file)
      destination = File.join(@output_directory, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(sources.fetch([locale, file]), destination)

      dimensions[relative] = ReleaseScreenshotContract.validate_png_file!(destination, label: relative)
    end
    dimensions
  end

  def build_manifest(dimensions)
    {
      "schema_version" => SCHEMA_VERSION,
      "captured_at" => Time.now.utc.iso8601,
      "source_sha" => ENV.fetch("RELEASE_SCREENSHOT_SOURCE_SHA", "local-validation"),
      "result_bundle" => File.basename(@result_bundle),
      "device" => "#{ENV.fetch('RELEASE_SCREENSHOT_DEVICE', 'iPhone 14 Plus')} Simulator",
      "device_directory" => DEVICE_DIRECTORY,
      "app_store_device_slot" => DEVICE_SLOT,
      "os" => "iOS #{ENV.fetch('RELEASE_SCREENSHOT_OS', '26.5')}",
      "appearance" => ENV.fetch("RELEASE_SCREENSHOT_APPEARANCE", "Light"),
      "required_size" => { "width" => WIDTH, "height" => HEIGHT },
      "locales" => LOCALES.map do |locale|
        {
          "source_locale" => locale,
          "app_store_locale" => LOCALE_MAPPING.fetch(locale),
          "screenshots" => FILES.each_with_index.map do |file, index|
            relative = ReleaseScreenshotContract.expected_path(locale, file)
            width, height = dimensions.fetch(relative)
            { "index" => index + 1, "file" => file, "path" => relative, "width" => width, "height" => height }
          end
        }
      end
    }
  end

  def write_summary(manifest)
    File.open(File.join(@output_directory, "summary.md"), "w") do |file|
      file.puts "# Release App Store Screenshots"
      file.puts
      file.puts "- Source SHA: `#{manifest.fetch('source_sha')}`"
      file.puts "- Device: #{manifest.fetch('device')}"
      file.puts "- App Store slot: #{DEVICE_SLOT}"
      file.puts "- Required size: #{WIDTH} x #{HEIGHT} PNG, portrait"
      file.puts "- Locales: English (`en-GB`) and Ukrainian (`uk`)"
      file.puts "- Validation: exact names, order, count, uniqueness, locale mapping, and dimensions passed"
      manifest.fetch("locales").each do |locale|
        file.puts
        file.puts "## #{locale.fetch('app_store_locale')}"
        locale.fetch("screenshots").each { |screen| file.puts "- #{screen.fetch('index')}. `#{screen.fetch('path')}`" }
      end
    end
  end

  def write_index(manifest)
    File.open(File.join(@output_directory, "index.html"), "w") do |file|
      file.puts '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
      file.puts '<title>Release App Store Screenshots</title><style>body{font-family:-apple-system,sans-serif;margin:24px;background:#f6f8fa;color:#1f2328}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}figure{margin:0;padding:12px;background:white;border:1px solid #d0d7de;border-radius:10px}img{display:block;width:100%;border-radius:7px}figcaption{margin-top:8px;font-weight:600}</style></head><body><h1>Release App Store Screenshots</h1>'
      manifest.fetch("locales").each do |locale|
        file.puts "<h2>#{CGI.escapeHTML(locale.fetch('app_store_locale'))}</h2><div class=\"grid\">"
        locale.fetch("screenshots").each do |screen|
          path = CGI.escapeHTML(screen.fetch("path"))
          label = CGI.escapeHTML("#{screen.fetch('index')}. #{screen.fetch('file')}")
          file.puts "<figure><img src=\"#{path}\" alt=\"#{label}\"><figcaption>#{label}</figcaption></figure>"
        end
        file.puts "</div>"
      end
      file.puts "</body></html>"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 2
    warn "Usage: export_release_app_store_screenshots.rb RESULT_BUNDLE OUTPUT_DIRECTORY"
    exit 2
  end
  begin
    ReleaseScreenshotExporter.new(result_bundle: ARGV[0], output_directory: ARGV[1]).run
    puts "Exported 12 validated release App Store screenshots to #{ARGV[1]}"
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
