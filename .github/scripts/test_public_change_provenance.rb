#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"

class PublicChangeProvenanceTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  AGENTS_PATH = File.join(ROOT, "AGENTS.md")
  TEMPLATE_PATH = File.join(ROOT, ".github/pull_request_template.md")
  WORKFLOWS_PATH = File.join(ROOT, ".github/workflows")

  def test_current_public_change_provenance_contract
    assert_empty validation_errors(
      agents: File.read(AGENTS_PATH),
      template: File.read(TEMPLATE_PATH),
      workflows: workflow_contents
    )
  end

  def test_rejects_missing_sanitized_no_id_branch_route
    errors = validation_errors(
      agents: valid_agents.sub("feature/<short-kebab-description>", "feature/TASK-000_<description>")
    )

    assert_includes errors, "sanitized no-ID branch convention is missing"
  end

  def test_rejects_invented_public_issue_route
    errors = validation_errors(
      agents: valid_agents.sub(
        "Do not open or invent a public issue merely to satisfy",
        "Open a public issue to satisfy"
      )
    )

    assert_includes errors, "invented public issues are not prohibited"
  end

  def test_rejects_missing_non_public_planning_boundary
    errors = validation_errors(
      agents: valid_agents.sub(
        "Do not publish non-public planning identifiers",
        "Publish planning identifiers"
      )
    )

    assert_includes errors, "non-public planning disclosure boundary is missing"
  end

  def test_rejects_unqualified_issue_closing_syntax
    errors = validation_errors(
      agents: valid_agents.sub(
        "only when that number is a real, intentionally public issue in this repository",
        "for every change"
      )
    )

    assert_includes errors, "issue-closing syntax is not limited to real public issues"
  end

  def test_rejects_non_hosted_workflow_route
    errors = validation_errors(
      workflows: workflow_contents.merge(
        "unsafe.yml" => "runs-on: self-hosted\n"
      )
    )

    assert_includes errors, "public workflows must use GitHub-hosted runners"
  end

  private

  def validation_errors(agents: valid_agents, template: valid_template, workflows: workflow_contents)
    errors = []
    errors << "sanitized no-ID branch convention is missing" unless
      agents.include?("feature/<short-kebab-description>") &&
      agents.include?("hotfix/<short-kebab-description>")
    errors << "invented public issues are not prohibited" unless
      agents.include?("Do not open or invent a public issue merely to satisfy")
    errors << "non-public planning disclosure boundary is missing" unless
      agents.include?("Do not publish non-public planning identifiers") &&
      agents.include?("Public commits and pull requests must be self-contained")
    errors << "issue-closing syntax is not limited to real public issues" unless
      agents.include?("only when that number is a real, intentionally public issue in this repository")
    errors << "pull request checklist does not enforce public-safe provenance" unless
      template.include?("Public change provenance") &&
      template.include?("No public issue was invented merely to satisfy")

    if workflows.values.any? { |text| text.match?(/\bself-hosted\b/i) }
      errors << "public workflows must use GitHub-hosted runners"
    end
    errors
  end

  def valid_agents
    @valid_agents ||= File.read(AGENTS_PATH)
  end

  def valid_template
    @valid_template ||= File.read(TEMPLATE_PATH)
  end

  def workflow_contents
    @workflow_contents ||= Dir.glob(File.join(WORKFLOWS_PATH, "*.{yml,yaml}")).to_h do |path|
      [File.basename(path), File.read(path)]
    end
  end
end
