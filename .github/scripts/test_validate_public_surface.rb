#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require "digest"

require_relative "validate_public_surface"

class PublicSurfaceValidationTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  def test_accepts_ordinary_source_files
    with_repository do |root|
      write(root, "Sources/Feature.swift", "struct Feature {}\n")
      assert_valid(root, ["Sources/Feature.swift"])
    end
  end

  def test_accepts_real_approved_synthetic_fixtures
    files = PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_FILES.to_a
    assert_valid(REPOSITORY_ROOT, files)
  end

  def test_every_approved_fixture_has_exactly_one_pinned_hash
    approved = PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_FILES
    hashes = PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_SHA256

    assert_equal approved, hashes.keys.to_set
    assert_equal approved.length, hashes.length
    hashes.each_value { |digest| assert_match(/\A[0-9a-f]{64}\z/, digest) }
  end

  def test_real_fixture_bytes_match_pinned_hashes
    PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_SHA256.each do |path, expected_hash|
      contents = File.binread(File.join(REPOSITORY_ROOT, path))
      assert_equal expected_hash, Digest::SHA256.hexdigest(contents), path
    end
  end

  def test_validation_preserves_malformed_fixture_byte_for_byte
    path = "docs/data/portability-recovery-v1/malformed-truncated-backup.json"
    before = File.binread(File.join(REPOSITORY_ROOT, path))

    assert_valid(REPOSITORY_ROOT, [path])
    assert_equal before, File.binread(File.join(REPOSITORY_ROOT, path))
  end

  def test_rejects_modified_contents_at_approved_fixture_path
    with_real_fixtures do |root, files|
      path = files.first
      write(root, path, File.binread(File.join(root, path)) + "modified")
      assert_rule(root, path, "approved synthetic fixture content mismatch")
    end
  end

  def test_rejects_real_looking_household_data_at_approved_fixture_path
    with_real_fixtures do |root, files|
      path = files.first
      private_marker = "private-household-place-never-print"
      write(root, path, %({"items":[{"name":"#{private_marker}"}]}))
      error = validation_error(root, [path])

      assert_includes error.message, "approved synthetic fixture content mismatch"
      refute_includes error.message, private_marker
    end
  end

  def test_rejects_missing_approved_fixture_omitted_from_tracked_path_set
    with_real_fixtures do |root, files|
      path = files.first
      File.delete(File.join(root, path))
      error = raw_validation_error(root, files - [path])

      assert_equal <<~MESSAGE.chomp, error.message
        Tracked public-surface validation failed:
        - #{path}: approved synthetic fixture content mismatch
      MESSAGE
      refute_includes error.message, PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_SHA256.fetch(path)
    end
  end

  def test_case_variant_does_not_satisfy_exact_approved_fixture_path
    with_real_fixtures do |root, files|
      missing = files.first
      variant = missing.sub("docs/", "DOCS/")
      contents = File.binread(File.join(root, missing))
      File.delete(File.join(root, missing))
      write(root, variant, contents)
      error = raw_validation_error(root, (files - [missing]) + [variant])

      assert_includes error.message, "#{missing}: approved synthetic fixture content mismatch"
      refute_includes error.message, PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_SHA256.fetch(missing)
      refute_includes error.message, contents
    end
  end

  def test_suffix_collision_does_not_satisfy_exact_approved_fixture_path
    with_real_fixtures do |root, files|
      missing = files.first
      collision = "#{missing}.backup"
      contents = File.binread(File.join(root, missing))
      File.delete(File.join(root, missing))
      write(root, collision, contents)
      error = raw_validation_error(root, (files - [missing]) + [collision])

      assert_includes error.message, "#{missing}: approved synthetic fixture content mismatch"
    end
  end

  def test_non_normalized_variants_do_not_satisfy_exact_approved_fixture_path
    with_real_fixtures do |root, files|
      missing = files.first
      File.delete(File.join(root, missing))
      variants = [
        "./#{missing}",
        missing.sub("portability-recovery-v1/", "portability-recovery-v1/../portability-recovery-v1/")
      ]

      variants.each do |variant|
        error = raw_validation_error(root, (files - [missing]) + [variant])
        assert_includes error.message, "#{missing}: approved synthetic fixture content mismatch"
        assert_includes error.message, "non-normalized repository path"
      end
    end
  end

  def test_git_enumeration_detects_fixture_removed_from_real_tracked_set
    with_real_fixtures do |root, files|
      git(root, "init", "--quiet")
      git(root, "add", "--", *files)
      missing = files.first
      git(root, "rm", "--quiet", "--force", "--", missing)

      tracked_files = PublicSurfaceValidation.tracked_candidate_files(root)
      refute_includes tracked_files, missing
      error = raw_validation_error(root, tracked_files)

      assert_equal <<~MESSAGE.chomp, error.message
        Tracked public-surface validation failed:
        - #{missing}: approved synthetic fixture content mismatch
      MESSAGE
    end
  end

  def test_fixture_mismatch_error_does_not_print_hashes_or_contents
    with_real_fixtures do |root, files|
      path = files.first
      contents = "private-fixture-content-never-print"
      write(root, path, contents)
      error = validation_error(root, [path])

      refute_includes error.message, PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_SHA256.fetch(path)
      refute_includes error.message, Digest::SHA256.hexdigest(contents)
      refute_includes error.message, contents
    end
  end

  def test_rejects_unapproved_fixture_inside_synthetic_directory
    with_repository do |root|
      path = "docs/data/portability-recovery-v1/new-fixture.json"
      write(root, path, "{}\n")
      assert_rule(root, path, "unapproved synthetic data fixture")
    end
  end

  def test_rejects_real_looking_export_inside_synthetic_directory
    with_repository do |root|
      path = "docs/data/portability-recovery-v1/real-export.json"
      write(root, path, "{}\n")
      assert_rule(root, path, "unapproved synthetic data fixture")
    end
  end

  def test_rejects_private_audit_directory_case_insensitively
    with_repository do |root|
      %w[.audit-private .audit-private/private-ledger.json .AUDIT-PRIVATE/extracted/blob.bin].each do |path|
        write(root, path, "evidence") unless path == ".audit-private"
        assert_rule(root, path, "private audit evidence directory")
      end
    end
  end

  def test_rejects_git_submodule_configuration
    with_repository do |root|
      path = ".gitmodules"
      write(root, path, "submodule configuration must not be inspected")
      assert_rule(root, path, "Git submodule configuration")
    end
  end

  def test_rejects_git_submodule_configuration_case_insensitively
    with_repository do |root|
      path = ".GITMODULES"
      write(root, path, "submodule configuration must not be inspected")
      assert_rule(root, path, "Git submodule configuration")
    end
  end

  def test_rejects_pull_request_controlled_gitleaks_policy_files
    with_repository do |root|
      rules = {
        ".gitleaks.toml" => "pull-request-controlled Gitleaks configuration",
        ".GITLEAKS.TOML" => "pull-request-controlled Gitleaks configuration",
        ".gitleaksignore" => "pull-request-controlled Gitleaks ignore file",
        ".GITLEAKSIGNORE" => "pull-request-controlled Gitleaks ignore file"
      }

      rules.each do |path, rule|
        write(root, path, "candidate policy must not be inspected")
        assert_rule(root, path, rule)
      end
    end
  end

  def test_rejects_temporary_evidence_directory
    with_repository do |root|
      path = "TemporaryEvidence/review.txt"
      write(root, path, "review")
      assert_rule(root, path, "temporary evidence directory")
    end
  end

  def test_rejects_signing_material
    with_repository do |root|
      path = "release/signing-key.p8"
      write(root, path, "placeholder")
      assert_rule(root, path, "signing material")
    end
  end

  def test_rejects_apple_build_and_diagnostic_artifacts
    with_repository do |root|
      %w[build/app.ipa build/app.xcarchive diagnostics/result.xcresult symbols/app.dSYM].each do |path|
        write(root, path, "artifact")
        assert_rule(root, path, "Apple build or diagnostic artifact")
      end
    end
  end

  def test_rejects_archive_suffixed_apple_artifacts
    with_repository do |root|
      %w[diagnostics/result.xcresult.zip symbols/app.dSYM.zip build/app.xcarchive.zip build/app.ipa.zip].each do |path|
        write(root, path, "archive")
        assert_rule(root, path, "archive-suffixed Apple artifact")
      end
    end
  end

  def test_rejects_generic_archives
    with_repository do |root|
      %w[exports/data.zip exports/data.tar exports/data.gz exports/data.7z].each do |path|
        write(root, path, "archive")
        assert_rule(root, path, "generic archive")
      end
    end
  end

  def test_rejects_compressed_backup_variants_as_archives_and_inventory_data
    with_repository do |root|
      path = "backups/items.json.gz"
      write(root, path, "compressed")
      error = validation_error(root, [path])

      assert_includes error.message, "generic archive"
      assert_includes error.message, "inventory data outside approved synthetic fixtures"
    end
  end

  def test_rejects_unknown_binary_files
    with_repository do |root|
      path = "fixtures/payload.dat"
      write(root, path, "prefix\0payload".b)
      assert_rule(root, path, "unapproved binary file")
    end
  end

  def test_accepts_reviewed_png_and_jpeg_assets_with_valid_signatures
    with_repository do |root|
      png = "HomeStuffInventoryApp/Resources/Assets.xcassets/Test.imageset/image.png"
      jpeg = "HomeStuffInventoryApp/Resources/Assets.xcassets/Test.imageset/image.jpeg"
      write(root, png, "\x89PNG\r\n\x1A\n\0payload".b)
      write(root, jpeg, "\xFF\xD8\xFF\0payload".b)
      assert_valid(root, [png, jpeg])
    end
  end

  def test_rejects_absolute_macos_home_paths
    with_repository do |root|
      path = "notes.txt"
      write(root, path, "/" + "Users/example/work\n")
      assert_rule(root, path, "absolute macOS home path")
    end
  end

  def test_rejects_absolute_linux_home_paths
    with_repository do |root|
      path = "notes.txt"
      write(root, path, "/" + "home/example/work\n")
      assert_rule(root, path, "absolute Linux home path")
    end
  end

  def test_rejects_app_store_connect_key_filenames
    with_repository do |root|
      path = "notes.txt"
      write(root, path, "Auth" + "Key_ABCDEFGHIJ.p8\n")
      assert_rule(root, path, "App Store Connect key filename")
    end
  end

  def test_rejects_git_lfs_pointers
    with_repository do |root|
      path = "asset.dat"
      write(root, path, "version https://git-lfs" + ".github.com/spec/v1\n")
      assert_rule(root, path, "Git LFS pointer")
    end
  end

  def test_rejects_inventory_data_in_suspicious_filenames
    with_repository do |root|
      path = "fixtures/household-items.json"
      write(root, path, "{}\n")
      assert_rule(root, path, "inventory data outside approved synthetic fixtures")
    end
  end

  def test_rejects_application_generated_extensionless_backup_filenames
    with_repository do |root|
      paths = [
        "Home-Stuff-Inventory-Backup-2026-07-21T11-30-00.000Z",
        "Home-Stuff-Inventory-Backup-2026-07-21T11-30-00Z",
        "Home-Stuff-Inventory-Backup-renamed",
        "home-stuff-inventory-backup-anything",
        "fixtures/Home-Stuff-Inventory-Backup-2026-07-21T11-30-00.000Z",
        "Backups/Home-Stuff-Inventory-Backup-2026-07-21T11-30-00.000Z",
        "HOME-STUFF-INVENTORY-BACKUP-ANYTHING"
      ]

      paths.each do |path|
        write(root, path, "inventory backup payload")
        assert_rule(root, path, "application-generated inventory backup")
      end
    end
  end

  def test_rejects_exact_application_generated_readable_export_filename
    with_repository do |root|
      path = "Home-Stuff-Inventory-2026-07-21.json"
      write(root, path, "{}\n")
      assert_rule(root, path, "inventory data outside approved synthetic fixtures")
    end
  end

  def test_allows_ordinary_non_data_product_document
    with_repository do |root|
      path = "docs/Home-Stuff-Inventory-architecture.md"
      write(root, path, "Architecture notes.\n")
      assert_valid(root, [path])
    end
  end

  def test_rejects_data_under_suspicious_directories
    with_repository do |root|
      %w[
        Backups/items.json
        backups/items.csv
        exports/data.plist
        inventory/items.json
        user-data/home-items.tsv
        personal-data/items.sqlite
      ].each do |path|
        write(root, path, "data\n")
        assert_rule(root, path, "inventory data outside approved synthetic fixtures")
      end
    end
  end

  def test_source_inventory_directories_do_not_trigger_data_path_rule
    with_repository do |root|
      path = "HomeStuffInventoryApp/InventoryData/schema.json"
      write(root, path, "{}\n")
      assert_valid(root, [path])
    end
  end

  def test_prefix_collision_does_not_bypass_fixture_allowlist
    with_repository do |root|
      path = "docs/data/portability-recovery-v1-malicious/data.json"
      write(root, path, "{}\n")
      assert_rule(root, path, "unapproved synthetic data fixture")
    end
  end

  def test_traversal_like_path_does_not_bypass_fixture_allowlist
    with_repository do |root|
      path = "docs/data/portability-recovery-v1/../real-export.json"
      assert_rule(root, path, "non-normalized repository path")
    end
  end

  def test_text_with_uncommon_extension_is_still_content_scanned
    with_repository do |root|
      path = "fixtures/readable.dat"
      write(root, path, "/" + "home/example/private\n")
      assert_rule(root, path, "absolute Linux home path")
    end
  end

  def test_error_messages_never_include_matched_contents
    with_repository do |root|
      path = "notes.txt"
      marker = "sensitive-marker-never-print"
      write(root, path, "/" + "Users/#{marker}/work\n")
      error = validation_error(root, [path])

      assert_includes error.message, path
      assert_includes error.message, "absolute macOS home path"
      refute_includes error.message, marker
    end
  end

  private

  def with_repository
    Dir.mktmpdir("public-surface-validation") do |root|
      seed_real_fixtures(root)
      yield root
    end
  end

  def with_real_fixtures
    with_repository do |root|
      files = PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_FILES.to_a
      yield root, files
    end
  end

  def seed_real_fixtures(root)
    PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_FILES.each do |path|
      write(root, path, File.binread(File.join(REPOSITORY_ROOT, path)))
    end
  end

  def write(root, path, contents)
    absolute_path = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(absolute_path))
    File.binwrite(absolute_path, contents)
  end

  def assert_valid(root, paths)
    assert PublicSurfaceValidation.validate!(root: root, tracked_files: candidate_paths(paths))
  end

  def assert_rule(root, path, rule)
    error = validation_error(root, [path])
    assert_includes error.message, rule
  end

  def validation_error(root, paths)
    raw_validation_error(root, candidate_paths(paths))
  end

  def raw_validation_error(root, paths)
    assert_raises(RuntimeError) do
      PublicSurfaceValidation.validate!(root: root, tracked_files: paths)
    end
  end

  def candidate_paths(paths)
    PublicSurfaceValidation::APPROVED_SYNTHETIC_DATA_FILES.to_a | paths
  end

  def git(root, *arguments)
    _output, error, status = Open3.capture3("git", *arguments, chdir: root)
    raise "Git command failed: git #{arguments.first}: #{error}" unless status.success?
  end
end
