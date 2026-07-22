#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require_relative "export_release_app_store_screenshots"
require_relative "resolve_release_screenshot_ref"

class ReleaseScreenshotRefTest < Minitest::Test
  def test_accepts_strict_release_tags_and_sha
    assert_equal "v1.2.3", ReleaseScreenshotRef.resolve("v1.2.3")
    assert_equal "v1.2.3", ReleaseScreenshotRef.resolve("refs/tags/v1.2.3")
    assert_equal "a" * 40, ReleaseScreenshotRef.resolve("A" * 40)
  end

  def test_rejects_branches_mutable_refs_and_invalid_tags
    ["", "main", "refs/heads/main", "release/1.2.3", "v1.2", "v01.2.3", "../main", "main;echo bad"].each do |value|
      assert_raises(ArgumentError) { ReleaseScreenshotRef.resolve(value) }
    end
  end
end

class ReleaseScreenshotExporterTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("release-screenshots")
    @bin = File.join(@root, "bin")
    @fixture = File.join(@root, "fixture")
    @result = File.join(@root, "Result.xcresult")
    @output = File.join(@root, "output")
    FileUtils.mkdir_p([@bin, @fixture, @result])
    write_stub_tools
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_exports_exact_ordered_locale_contract
    write_fixture(expected_attachments)
    stdout, stderr, status = run_exporter

    assert status.success?, stderr
    assert_includes stdout, "Exported 12 validated"
    manifest = JSON.parse(File.read(File.join(@output, "screenshots-manifest.json")))
    ReleaseScreenshotContract.validate_manifest!(manifest)
    assert_equal %w[en uk], manifest.fetch("locales").map { |locale| locale.fetch("source_locale") }
    assert_equal %w[en-GB uk], manifest.fetch("locales").map { |locale| locale.fetch("app_store_locale") }
  end

  def test_rejects_missing_duplicate_unexpected_and_wrong_dimensions
    cases = [
      expected_attachments.drop(1),
      expected_attachments + [expected_attachments.first.merge("exportedFileName" => "duplicate.png")],
      expected_attachments + [{ "suggestedHumanReadableName" => "en-07-stale", "exportedFileName" => "stale.png" }]
    ]
    cases.each do |attachments|
      write_fixture(attachments)
      _stdout, _stderr, status = run_exporter
      refute status.success?
    end

    write_fixture(expected_attachments)
    _stdout, stderr, status = run_exporter("SCREENSHOT_WIDTH" => "1206")
    refute status.success?
    assert_includes stderr, "Invalid dimensions"

    write_fixture(expected_attachments)
    _stdout, stderr, status = run_exporter("RELEASE_SCREENSHOT_SOURCE_SHA" => "wrong")
    refute status.success?
    assert_includes stderr, "source SHA"
  end

  def test_manifest_validation_rejects_misordered_files
    write_fixture(expected_attachments)
    _stdout, stderr, status = run_exporter
    assert status.success?, stderr
    manifest = JSON.parse(File.read(File.join(@output, "screenshots-manifest.json")))
    manifest.fetch("locales").first.fetch("screenshots").reverse!
    assert_raises(RuntimeError) { ReleaseScreenshotContract.validate_manifest!(manifest) }
  end

  private

  def expected_attachments
    ReleaseScreenshotContract::LOCALES.flat_map do |locale|
      ReleaseScreenshotContract::FILES.map do |file|
        {
          "suggestedHumanReadableName" => "#{locale}-#{File.basename(file, '.png')}",
          "exportedFileName" => "#{locale}-#{file}"
        }
      end
    end
  end

  def write_fixture(attachments)
    FileUtils.rm_rf(@fixture)
    FileUtils.mkdir_p(@fixture)
    File.write(File.join(@fixture, "manifest.json"), JSON.generate([{ "attachments" => attachments }]))
    attachments.each { |attachment| File.write(File.join(@fixture, attachment.fetch("exportedFileName")), "png") }
  end

  def run_exporter(extra_env = {})
    env = {
      "PATH" => "#{@bin}:#{ENV.fetch('PATH')}",
      "SCREENSHOT_EXPORT_FIXTURE" => @fixture
    }.merge(extra_env)
    Open3.capture3(env, "ruby", File.expand_path("export_release_app_store_screenshots.rb", __dir__), @result, @output)
  end

  def write_stub_tools
    File.write(File.join(@bin, "xcrun"), <<~RUBY)
      #!/usr/bin/env ruby
      require "fileutils"
      fixture = ENV.fetch("SCREENSHOT_EXPORT_FIXTURE")
      output = ARGV.fetch(ARGV.index("--output-path") + 1)
      FileUtils.mkdir_p(output)
      FileUtils.cp(File.join(fixture, "manifest.json"), File.join(output, "manifest.json"))
      Dir[File.join(fixture, "*.png")].each { |path| FileUtils.cp(path, File.join(output, File.basename(path))) }
    RUBY
    File.write(File.join(@bin, "sips"), <<~RUBY)
      #!/usr/bin/env ruby
      puts "format: png"
      puts "pixelWidth: \#{ENV.fetch("SCREENSHOT_WIDTH", "1284")}"
      puts "pixelHeight: \#{ENV.fetch("SCREENSHOT_HEIGHT", "2778")}"
    RUBY
    FileUtils.chmod(0o755, [File.join(@bin, "xcrun"), File.join(@bin, "sips")])
  end
end
