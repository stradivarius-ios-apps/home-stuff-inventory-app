#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "tmpdir"
require_relative "validate_public_governance"

class PublicGovernanceTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../..", __dir__)

  def setup
    @temporary = Dir.mktmpdir("public-governance-test")
    PublicGovernanceValidator::REQUIRED_FILES.each do |path|
      destination = File.join(@temporary, path)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(REPOSITORY_ROOT, path), destination)
    end
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def test_current_governance_contract_passes
    assert PublicGovernanceValidator.new(@temporary).validate!
  end

  def test_governance_check_and_validator_join_public_automation_file_closure_after_sec_pub_02
    assert_equal "test_public_governance.rb", PublicGovernanceValidator::PUBLIC_AUTOMATION_CHECK
    assert_equal %w[
      .github/scripts/test_public_governance.rb
      .github/scripts/validate_public_governance.rb
    ], PublicGovernanceValidator::PUBLIC_AUTOMATION_FILE_CLOSURE

    contract_path = File.join(REPOSITORY_ROOT, ".github/scripts/support/public_automation_contract.rb")
    skip "SEC-PUB-02 public automation split is not present before semantic rebase" unless File.file?(contract_path)

    require contract_path
    assert_includes PublicAutomationContract::PUBLIC_CHECKS,
                    PublicGovernanceValidator::PUBLIC_AUTOMATION_CHECK
    closure = PublicAutomationContract.public_runner_file_closure(repository_root: REPOSITORY_ROOT)
    PublicGovernanceValidator::PUBLIC_AUTOMATION_FILE_CLOSURE.each do |path|
      assert_includes closure, path
    end
  end

  def test_missing_governance_validator_fails_file_closure
    FileUtils.rm(file(".github/scripts/validate_public_governance.rb"))

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, ".github/scripts/validate_public_governance.rb"
  end

  def test_public_issue_security_fallback_is_rejected
    replace("SECURITY.md", PublicGovernanceValidator::PRIVATE_REPORTING_URL,
            "https://github.com/stradivarius-ios-apps/home-stuff-inventory-app/issues/new")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "private reporting route"
  end

  def test_settings_cannot_be_marked_applyable_or_published
    path = file("docs/security/public-repository-settings-plan.json")
    plan = JSON.parse(File.read(path))
    plan["apply_allowed"] = true
    plan["publication_authorized"] = true
    File.write(path, JSON.pretty_generate(plan))

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "application is not authorized"
  end

  def test_sensitive_codeowner_coverage_is_required
    replace(".github/CODEOWNERS", "/.github/workflows/** @Stradivarius23\n", "")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "/.github/workflows/**"
  end

  def test_placeholder_license_is_rejected
    File.write(file("LICENSE"), "placeholder")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "MIT license"
  end

  def test_no_maintainer_policy_decision_may_remain_unresolved
    replace("docs/security/public-governance-decisions.md", "**APPROVED**", "**UNRESOLVED — BLOCKER**")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "no maintainer policy decision"
  end

  def test_formal_code_of_conduct_is_rejected_by_approved_decision
    File.write(file("CODE_OF_CONDUCT.md"), "unapproved formal policy\n")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "contradicts the approved decision"
  end

  def test_dco_check_cannot_be_pretended_active_before_provider_observation
    path = file("docs/security/public-repository-settings-plan.json")
    plan = JSON.parse(File.read(path))
    plan.dig("required_checks", "dco")["state"] = "enabled"
    File.write(path, JSON.pretty_generate(plan))

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "DCO provider check"
  end

  def test_absent_public_candidate_check_cannot_be_reintroduced
    path = file("docs/security/public-repository-settings-plan.json")
    plan = JSON.parse(File.read(path))
    plan.dig("required_checks", "global_candidates_not_authorized_for_rulesets") << "Public candidate boundary"
    File.write(path, JSON.pretty_generate(plan))

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "global check candidates"
  end

  def test_classification_check_must_retain_the_embedded_public_boundary
    replace(".github/workflows/validation.yml", "      - name: Scan tracked candidate with pinned Gitleaks\n", "")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "unconditional public boundary step"
  end

  def test_blank_public_issues_are_rejected
    replace(".github/ISSUE_TEMPLATE/config.yml", "blank_issues_enabled: false", "blank_issues_enabled: true")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "blank public issues"
  end

  def test_completed_staging_checklist_is_rejected
    replace("docs/security/publication-and-rollback-checklist.md", "- [ ]", "- [x]")

    error = assert_raises(ArgumentError) { validate }
    assert_includes error.message, "must remain uncompleted"
  end

  private

  def validate
    PublicGovernanceValidator.new(@temporary).validate!
  end

  def replace(path, before, after)
    target = file(path)
    content = File.read(target)
    raise "missing test fixture text: #{before}" unless content.include?(before)

    File.write(target, content.sub(before, after))
  end

  def file(path)
    File.join(@temporary, path)
  end
end
