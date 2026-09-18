#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "validate_app_store_release_notes"

class AppStoreReleaseNotesContractTest < Minitest::Test
  def with_notes(files)
    Dir.mktmpdir do |root|
      directory = File.join(root, "1.3.1")
      FileUtils.mkdir_p(directory)
      files.each { |name, value| File.write(File.join(directory, name), value) }
      yield root
    end
  end

  def test_accepts_complete_localized_notes_for_strict_version
    with_notes("en-GB.txt" => "Improved inventory browsing.", "uk.txt" => "Покращено перегляд інвентарю.") do |root|
      assert AppStoreReleaseNotesContract.validate!(root: root, version: "1.3.1")
    end
  end

  def test_rejects_missing_or_unexpected_locales
    with_notes("en-GB.txt" => "Notes", "fr.txt" => "Notes") do |root|
      assert_raises(RuntimeError) { AppStoreReleaseNotesContract.validate!(root: root, version: "1.3.1") }
    end
  end

  def test_rejects_empty_notes_and_non_strict_versions
    with_notes("en-GB.txt" => "Notes", "uk.txt" => "   ") do |root|
      assert_raises(RuntimeError) { AppStoreReleaseNotesContract.validate!(root: root, version: "1.3.1") }
      assert_raises(RuntimeError) { AppStoreReleaseNotesContract.validate!(root: root, version: "v1.3.1") }
    end
  end
end
