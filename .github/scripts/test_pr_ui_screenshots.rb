#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "export_pr_ui_screenshots"
require_relative "resolve_pr_ui_ref"

class PRUIRefTest < Minitest::Test
  def test_resolves_pull_request_number
    assert_equal "refs/pull/263/head", PRUIRef.resolve("263")
  end

  def test_accepts_branch_tag_and_sha
    assert_equal "feature/RCI-01_capture", PRUIRef.resolve("feature/RCI-01_capture")
    assert_equal "refs/tags/v1.2.3", PRUIRef.resolve("refs/tags/v1.2.3")
    assert_equal "a" * 40, PRUIRef.resolve("A" * 40)
  end

  def test_rejects_empty_and_unsafe_refs
    ["", "../main", "feature//bad", "refs/heads/.hidden", "main;echo bad"].each do |value|
      assert_raises(ArgumentError) { PRUIRef.resolve(value) }
    end
  end
end

class InventoryPRScreenshotExporterTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir
    @output = File.join(@root, "output")
    @attachments = File.join(@output, "_attachments")
    FileUtils.mkdir_p(@attachments)
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_copies_exact_contract
    write_manifest(expected_entries)

    exporter.copy_expected_attachments(File.join(@attachments, "manifest.json"))

    expected_entries.each do |locale, appearance, screen|
      assert File.file?(File.join(@output, locale, appearance, "#{screen}.png"))
    end
  end

  def test_rejects_missing_duplicate_and_unexpected_screenshots
    expected = expected_entries

    write_manifest(expected.drop(1))
    assert_raises(RuntimeError) { exporter.copy_expected_attachments(File.join(@attachments, "manifest.json")) }

    write_manifest(expected + [expected.first])
    assert_raises(RuntimeError) { exporter.copy_expected_attachments(File.join(@attachments, "manifest.json")) }

    write_manifest(expected + [["en", "light", "settings"]])
    assert_raises(RuntimeError) { exporter.copy_expected_attachments(File.join(@attachments, "manifest.json")) }
  end

  def test_rejects_identical_light_and_dark_screenshots
    write_manifest(expected_entries, identical_pair: ["en", "location-detail"])

    error = assert_raises(RuntimeError) do
      exporter.copy_expected_attachments(File.join(@attachments, "manifest.json"))
    end

    assert_equal "Light and dark screenshots are identical: en/location-detail", error.message
  end

  private

  def exporter
    InventoryPRScreenshotExporter.new(result_bundle: File.join(@root, "result.xcresult"), output_directory: @output)
  end

  def expected_entries
    InventoryPRScreenshotExporter::LOCALES.product(
      InventoryPRScreenshotExporter::APPEARANCES,
      InventoryPRScreenshotExporter::SCREENS
    )
  end

  def write_manifest(entries, identical_pair: nil)
    FileUtils.rm_rf(@attachments)
    FileUtils.mkdir_p(@attachments)
    attachments = entries.each_with_index.map do |(locale, appearance, screen), index|
      exported_name = "attachment-#{index}.png"
      content = if identical_pair == [locale, screen]
                  "#{locale}-identical-#{screen}"
                else
                  "#{locale}-#{appearance}-#{screen}"
                end
      File.write(File.join(@attachments, exported_name), content)
      {
        "suggestedHumanReadableName" => "#{locale}-#{appearance}-#{screen}",
        "exportedFileName" => exported_name
      }
    end
    File.write(File.join(@attachments, "manifest.json"), JSON.generate([{ "attachments" => attachments }]))
  end
end
