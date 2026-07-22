#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "prepare_release_version"

class PrepareReleaseVersionTest < Minitest::Test
  CHANGELOG = "# Changelog\n\nRelease notes introduction.\n\n## 1.0.0 - 2026-01-01\n\n### Added\n\n- Initial.\n"

  def test_blank_input_resolves_next_patch
    assert_equal "1.2.4", ReleaseVersionPreparation.resolve_target!(
      input: "", latest_version: "1.2.3", changelog: CHANGELOG
    )
  end

  def test_explicit_higher_version_is_allowed
    assert_equal "1.3.0", ReleaseVersionPreparation.resolve_target!(
      input: "1.3.0", latest_version: "1.2.3", changelog: CHANGELOG
    )
  end

  def test_stale_malformed_duplicate_and_unfinished_versions_are_rejected
    ["1.2.3", "1.2.2", "v1.2.4", "01.2.4", "1.2"].each do |input|
      assert_raises(RuntimeError) do
        ReleaseVersionPreparation.resolve_target!(
          input: input, latest_version: "1.2.3", changelog: CHANGELOG
        )
      end
    end

  end

  def test_explicit_target_can_supersede_an_untagged_marketing_version
    assert_equal "1.0.2", ReleaseVersionPreparation.resolve_target!(
      input: "1.0.2", latest_version: "1.0.0",
      changelog: "# Changelog\n\n## 1.0.1\n"
    )
  end

  def test_project_update_preserves_build_number
    project = "MARKETING_VERSION = 1.0.0;\nCURRENT_PROJECT_VERSION = 7;\nMARKETING_VERSION = 1.0.0;\nCURRENT_PROJECT_VERSION = 7;\n"
    updated = ReleaseVersionPreparation.update_marketing_version(project, "1.0.1")
    assert_equal 2, updated.scan("MARKETING_VERSION = 1.0.1;").length
    assert_equal 2, updated.scan("CURRENT_PROJECT_VERSION = 7;").length
  end

  def test_changelog_preserves_history_and_requires_usable_notes
    changes = { "Changed" => ["Improve Locations (#12)."], "Fixed" => [], "Internal" => [] }
    updated = ReleaseVersionPreparation.update_changelog(CHANGELOG, "1.0.1", changes)
    assert_includes updated, "## 1.0.1"
    assert_includes updated, "- Improve Locations (#12)."
    assert_includes updated, "## 1.0.0 - 2026-01-01"
    assert_operator updated.index("Release notes introduction."), :<, updated.index("## 1.0.1")

    assert_raises(RuntimeError) do
      ReleaseVersionPreparation.update_changelog(
        CHANGELOG, "1.0.1", { "Changed" => [], "Fixed" => [], "Internal" => [] }
      )
    end
    assert_raises(RuntimeError) { ReleaseVersionPreparation.update_changelog("bad", "1.0.1", changes) }
  end

  def test_branch_name_follows_repository_rules
    assert_equal "feature/ad_hoc_prepare-release-1-2-3", ReleaseVersionPreparation.branch_name("1.2.3")
  end

  def test_release_prep_summary_contains_review_handoff
    body = pr_body("1.2.3", "v1.2.2", ["CHANGELOG.md", "HomeStuffInventoryApp.xcodeproj/project.pbxproj"])
    assert_includes body, "Review the generated release notes"
    assert_includes body, "HomeStuffInventoryApp.xcodeproj/project.pbxproj"
  end

  def test_draft_pr_requires_push_and_repository
    assert_raises(RuntimeError) do
      ReleaseVersionPreparation.validate_publish_options!(push: false, create_pr: true, repository: "owner/repo")
    end
    assert_raises(RuntimeError) do
      ReleaseVersionPreparation.validate_publish_options!(push: true, create_pr: true, repository: "")
    end
    ReleaseVersionPreparation.validate_publish_options!(push: true, create_pr: true, repository: "owner/repo")
  end

  def test_github_merge_subject_uses_second_parent_subject
    assert_equal "Add local backup (#123)", ReleaseVersionPreparation.normalized_change_subject!(
      subject: "Merge pull request #123 from owner/feature/example",
      second_parent_subject: "Add local backup"
    )
  end

  def test_github_merge_boilerplate_is_rejected_when_it_cannot_be_normalized
    error = assert_raises(RuntimeError) do
      ReleaseVersionPreparation.normalized_change_subject!(
        subject: "Merge pull request #123 from owner/feature/example",
        second_parent_subject: ""
      )
    end
    assert_includes error.message, "must not contain GitHub merge boilerplate"
  end

  def test_non_merge_subject_is_preserved
    assert_equal "Fix restore validation", ReleaseVersionPreparation.normalized_change_subject!(
      subject: "Fix restore validation"
    )
  end
end
