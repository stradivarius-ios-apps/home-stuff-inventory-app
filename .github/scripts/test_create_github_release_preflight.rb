#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "create_github_release_preflight"

class CreateGitHubReleasePreflightTest < Minitest::Test
  def test_version_normalization_and_validation
    assert_nil GitHubReleasePreflight.normalize_version("")
    assert_equal "1.2.3", GitHubReleasePreflight.normalize_version("1.2.3")
    assert_equal "1.2.3", GitHubReleasePreflight.normalize_version("v1.2.3")
    ["1.2", "01.2.3", "v1.2.3.4"].each do |version|
      assert_raises(RuntimeError) { GitHubReleasePreflight.normalize_version(version) }
    end
  end

  def test_normal_source_and_explicit_sha_recovery
    assert_equal "main", GitHubReleasePreflight.validate_source_ref!("main", false)
    sha = "A" * 40
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_source_ref!(sha, false) }
    assert_equal sha.downcase, GitHubReleasePreflight.validate_source_ref!(sha, true)
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_source_ref!("feature/release-prep", true) }
    captured = "a" * 40
    assert_equal captured, GitHubReleasePreflight.validate_source_ref!(captured, false, trusted_release_sha: captured)
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_source_ref!("b" * 40, false, trusted_release_sha: captured) }
    assert_raises(RuntimeError) { ensure_source_matches!(captured, "b" * 40, trusted_release_sha: captured) }
    ensure_source_matches!(captured, captured, trusted_release_sha: captured)
  end

  def test_changelog_extracts_finalized_entry
    changelog = <<~MD
      # Changelog

      ## 1.2.3 - 2026-07-10

      ### Changed

      - Improved Locations.

      ## 1.2.2 - 2026-06-01

      - Previous.
    MD
    entry = GitHubReleasePreflight.changelog_entry!(changelog, "1.2.3")
    assert_includes entry, "Improved Locations"
    refute_includes entry, "Previous"
  end

  def test_changelog_rejects_missing_unreleased_todo_and_empty_notes
    inputs = [
      ["# Changelog\n", "missing"],
      ["# Changelog\n\n## 1.2.3 — Unreleased\n\n- Note.\n", "unreleased"],
      ["# Changelog\n\n## 1.2.3\n\n- TODO: note.\n", "todo"],
      ["# Changelog\n\n## 1.2.3 - 2026-07-10\n\nNo bullets.\n", "empty"]
    ]
    inputs.each { |content, _case| assert_raises(RuntimeError) { GitHubReleasePreflight.changelog_entry!(content, "1.2.3") } }
  end

  def test_target_must_be_newer_than_latest_tag
    GitHubReleasePreflight.ensure_newer!("1.2.3", ["1.2.2", "1.0.0"])
    assert_raises(RuntimeError) { GitHubReleasePreflight.ensure_newer!("1.2.3", ["1.2.3"]) }
    assert_raises(RuntimeError) { GitHubReleasePreflight.ensure_newer!("1.2.2", ["1.2.3"]) }
  end

  def test_existing_protected_tag_must_be_annotated_and_exact_on_remote
    sha = "a" * 40
    object = "b" * 40
    tag = "v1.2.3"
    remote = "#{object}\trefs/tags/#{tag}\n#{sha}\trefs/tags/#{tag}^{}\n"
    valid = { type: "tag\n", object: "#{object}\n", target: "#{sha}\n", remote: remote }

    GitHubReleasePreflight.validate_existing_tag!(tag, sha, **valid)
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag!(tag, sha, **valid.merge(type: "commit\n")) }
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag!(tag, sha, **valid.merge(target: "#{'c' * 40}\n")) }
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag!(tag, sha, **valid.merge(object: "#{'c' * 40}\n")) }
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag!(tag, sha, **valid.merge(remote: "#{object}\trefs/tags/#{tag}\n")) }
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag!(tag, sha, **valid.merge(remote: remote.sub(sha, "c" * 40))) }
  end

  def test_existing_protected_tag_requires_trusted_sha_and_remote_checks
    GitHubReleasePreflight.validate_existing_tag_mode!(trusted_release_sha: "a" * 40, skip_remote_checks: false)
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag_mode!(trusted_release_sha: "", skip_remote_checks: false) }
    assert_raises(RuntimeError) { GitHubReleasePreflight.validate_existing_tag_mode!(trusted_release_sha: "a" * 40, skip_remote_checks: true) }
  end

  def test_project_setting_must_be_unique
    project = "MARKETING_VERSION = 1.2.3;\nMARKETING_VERSION = 1.2.3;\n"
    assert_equal "1.2.3", GitHubReleasePreflight.unique_project_value!(project, "MARKETING_VERSION")
    assert_raises(RuntimeError) do
      GitHubReleasePreflight.unique_project_value!("MARKETING_VERSION = 1.2.3;\nMARKETING_VERSION = 2.0.0;", "MARKETING_VERSION")
    end
  end

  def test_preflight_summary_includes_release_handoff_values
    Dir.mktmpdir do |directory|
      path = File.join(directory, "summary.md")
      previous = ENV["GITHUB_STEP_SUMMARY"]
      ENV["GITHUB_STEP_SUMMARY"] = path
      write_summary(marketing_version: "1.2.3", tag: "v1.2.3", source_ref: "main", source_sha: "a" * 40)
      assert_includes File.read(path), "Marketing version: `1.2.3`"
      assert_includes File.read(path), "Source ref: `main`"
    ensure
      ENV["GITHUB_STEP_SUMMARY"] = previous
    end
  end
end
