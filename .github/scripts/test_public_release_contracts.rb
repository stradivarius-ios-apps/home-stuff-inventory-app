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

  def test_public_screenshot_manifest_contract_is_complete
    manifest = {
      "schema_version" => ReleaseScreenshotContract::SCHEMA_VERSION,
      "source_sha" => SHA,
      "device_directory" => ReleaseScreenshotContract::DEVICE_DIRECTORY,
      "app_store_device_slot" => ReleaseScreenshotContract::DEVICE_SLOT,
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

    assert ReleaseScreenshotContract.validate_manifest!(manifest, expected_source_sha: SHA)
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
