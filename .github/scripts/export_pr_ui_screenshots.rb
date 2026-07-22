#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "digest"
require "fileutils"
require "json"
require "open3"

class InventoryPRScreenshotExporter
  LOCALES = %w[en uk].freeze
  APPEARANCES = %w[light dark].freeze
  SCREENS = %w[locations-overview location-detail place-detail inventory-overview item-detail search-results].freeze

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
    copy_expected_attachments(File.join(@attachments_directory, "manifest.json"))
    FileUtils.rm_rf(@attachments_directory)
    write_summary
    write_index
  end

  def copy_expected_attachments(manifest_path)
    manifest = JSON.parse(File.read(manifest_path))
    attachments = manifest.flat_map { |test| test.fetch("attachments", []) }
    copied = {}

    attachments.each do |attachment|
      name = attachment["suggestedHumanReadableName"].to_s
      next unless name.match?(/\A(?:en|uk)-(?:light|dark)-/)

      match = /\A(#{Regexp.union(LOCALES)})-(#{Regexp.union(APPEARANCES)})-(#{Regexp.union(SCREENS)})(?:_\d+_[[:xdigit:]-]+\.png)?\z/.match(name)
      raise "Unexpected PR screenshot attachment: #{name}" unless match

      key = [match[1], match[2], match[3]]
      raise "Duplicate PR screenshot attachment: #{key.join('/')}" if copied.key?(key)

      source = File.join(@attachments_directory, attachment.fetch("exportedFileName"))
      raise "Exported screenshot file is missing: #{source}" unless File.file?(source)

      destination = File.join(@output_directory, key[0], key[1], "#{key[2]}.png")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
      copied[key] = true
    end

    missing = LOCALES.product(APPEARANCES, SCREENS).reject { |key| copied.key?(key) }
    unless missing.empty?
      raise "Missing expected PR screenshots: #{missing.map { |key| key.join('/') }.join(', ')}"
    end

    validate_appearance_differences
  end

  private

  def validate_appearance_differences
    LOCALES.product(SCREENS).each do |locale, screen|
      light = File.join(@output_directory, locale, "light", "#{screen}.png")
      dark = File.join(@output_directory, locale, "dark", "#{screen}.png")
      next unless Digest::SHA256.file(light) == Digest::SHA256.file(dark)

      raise "Light and dark screenshots are identical: #{locale}/#{screen}"
    end
  end

  def export_attachments
    command = [
      "xcrun", "xcresulttool", "export", "attachments",
      "--path", @result_bundle,
      "--output-path", @attachments_directory
    ]
    stdout, stderr, status = Open3.capture3(*command)
    return if status.success?

    raise [stdout, stderr].reject(&:empty?).join("\n")
  end

  def write_summary
    File.open(File.join(@output_directory, "summary.md"), "w") do |file|
      file.puts "# PR UI Screenshots"
      file.puts
      file.puts "Deterministic Home Stuff Inventory visual-review baseline."
      LOCALES.product(APPEARANCES).each do |locale, appearance|
        file.puts
        file.puts "## #{locale} — #{appearance}"
        SCREENS.each do |screen|
          file.puts
          file.puts "### #{screen}"
          file.puts
          file.puts "![#{locale} #{appearance} #{screen}](#{locale}/#{appearance}/#{screen}.png)"
        end
      end
    end
  end

  def write_index
    File.open(File.join(@output_directory, "index.html"), "w") do |file|
      file.puts "<!doctype html>"
      file.puts "<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
      file.puts "<title>Home Stuff Inventory PR UI Screenshots</title>"
      file.puts "<style>body{font-family:-apple-system,sans-serif;margin:24px;background:#f6f8fa;color:#1f2328}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px}figure{margin:0;padding:12px;background:white;border:1px solid #d0d7de;border-radius:10px}img{display:block;width:100%;border-radius:7px}figcaption{margin-top:8px;font-weight:600}</style></head><body>"
      file.puts "<h1>PR UI Screenshots</h1>"
      LOCALES.product(APPEARANCES).each do |locale, appearance|
        heading = CGI.escapeHTML("#{locale} — #{appearance}")
        file.puts "<h2>#{heading}</h2><div class=\"grid\">"
        SCREENS.each do |screen|
          path = "#{locale}/#{appearance}/#{screen}.png"
          label = CGI.escapeHTML("#{locale} #{appearance} #{screen}")
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
    warn "Usage: export_pr_ui_screenshots.rb RESULT_BUNDLE OUTPUT_DIRECTORY"
    exit 2
  end

  begin
    InventoryPRScreenshotExporter.new(result_bundle: ARGV[0], output_directory: ARGV[1]).run
    puts "Exported PR UI screenshots to #{ARGV[1]}"
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
