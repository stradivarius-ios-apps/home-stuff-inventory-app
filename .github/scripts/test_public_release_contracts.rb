#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "support/release_contract"
require_relative "support/release_screenshot_contract"

class PublicReleaseContractsTest < Minitest::Test
  SHA = "a" * 40

  def test_public_release_version_and_sha_contracts
    assert_equal "1.2.3", ReleaseContract.strict_version!("1.2.3", label: "release version")
    assert_equal SHA, ReleaseContract.strict_sha!(SHA.upcase, label: "release SHA")
    assert_raises(RuntimeError) { ReleaseContract.strict_version!("01.2.3", label: "release version") }
    assert_raises(RuntimeError) { ReleaseContract.strict_sha!("a" * 39, label: "release SHA") }
  end

  def screenshot_manifest
    manifest = {
      "schema_version" => ReleaseScreenshotContract::SCHEMA_VERSION,
      "source_sha" => SHA,
      "device_directory" => ReleaseScreenshotContract::DEVICE_DIRECTORY,
      "app_store_device_slot" => ReleaseScreenshotContract::DEVICE_SLOT,
      "app_store_display_type" => ReleaseScreenshotContract::DISPLAY_TYPE,
      "required_size" => {
        "width" => ReleaseScreenshotContract::WIDTH,
        "height" => ReleaseScreenshotContract::HEIGHT
      },
      "locales" => ReleaseScreenshotContract::LOCALE_MAPPING.map do |source_locale, app_store_locale|
        {
          "source_locale" => source_locale,
          "app_store_locale" => app_store_locale,
          "screenshots" => ReleaseScreenshotContract::FILES.each_with_index.map do |file, index|
            {
              "index" => index + 1,
              "file" => file,
              "path" => ReleaseScreenshotContract.expected_path(source_locale, file),
              "width" => ReleaseScreenshotContract::WIDTH,
              "height" => ReleaseScreenshotContract::HEIGHT
            }
          end
        }
      end
    }

    manifest
  end

  def test_public_screenshot_manifest_contract_is_complete
    assert ReleaseScreenshotContract.validate_manifest!(screenshot_manifest, expected_source_sha: SHA)
    assert_equal "APP_IPHONE_61", ReleaseScreenshotContract::DISPLAY_TYPE
    assert_equal [1206, 2622], [ReleaseScreenshotContract::WIDTH, ReleaseScreenshotContract::HEIGHT]
  end

  def test_screenshot_contract_rejects_legacy_optional_targets
    [
      { "schema_version" => 1 },
      { "app_store_display_type" => "APP_IPHONE_65" },
      { "app_store_device_slot" => "6.5-inch iPhone" },
      { "device_directory" => "iPhone-14-Plus" },
      { "required_size" => { "width" => 1284, "height" => 2778 } }
    ].each do |change|
      assert_raises(RuntimeError) { ReleaseScreenshotContract.validate_manifest!(screenshot_manifest.merge(change), expected_source_sha: SHA) }
    end
  end

  def test_public_release_clients_use_public_shared_contracts
    version_clients = %w[prepare_release_version.rb create_github_release_preflight.rb]
    version_clients.each do |script|
      assert_includes File.read(File.expand_path(script, __dir__)), 'require_relative "support/release_contract"'
    end

    assert_includes File.read(File.expand_path("export_release_app_store_screenshots.rb", __dir__)),
                    'require_relative "support/release_screenshot_contract"'
  end
end
