#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"

class PublicSecurityGatesTest < Minitest::Test
  WORKFLOW_PATH = ".github/workflows/validation.yml"

  def test_security_gates_run_in_hosted_classification_job_before_change_classification
    block = workflow_job("classify-changes")
    validator_index = block.index("- name: Validate tracked public surface")
    candidate_index = block.index("- name: Prepare exact tracked candidate")
    policy_index = block.index("- name: Prepare pinned Gitleaks policy")
    boundary_index = block.index("- name: Verify trusted Gitleaks boundary")
    gitleaks_index = block.index("- name: Scan tracked candidate with pinned Gitleaks")
    classification_index = block.index("- name: Classify changed files")

    refute_nil validator_index
    refute_nil candidate_index
    refute_nil policy_index
    refute_nil boundary_index
    refute_nil gitleaks_index
    refute_nil classification_index
    assert_operator validator_index, :<, candidate_index
    assert_operator candidate_index, :<, policy_index
    assert_operator policy_index, :<, boundary_index
    assert_operator boundary_index, :<, gitleaks_index
    assert_operator gitleaks_index, :<, classification_index
    assert_includes block, "runs-on: ubuntu-latest"
    assert_includes block, "submodules: false"
    refute_includes block, "runs-on: [self-hosted"
    refute_match(/^\s+if:/, workflow_step(block, "Validate tracked public surface"))
    refute_match(/^\s+if:/, workflow_step(block, "Prepare exact tracked candidate"))
    refute_match(/^\s+if:/, workflow_step(block, "Prepare pinned Gitleaks policy"))
    refute_match(/^\s+if:/, workflow_step(block, "Verify trusted Gitleaks boundary"))
    refute_match(/^\s+if:/, workflow_step(block, "Scan tracked candidate with pinned Gitleaks"))
  end

  def test_candidate_preparation_uses_exact_index_helper_without_git_archive
    block = workflow_job("classify-changes")
    step = workflow_step(block, "Prepare exact tracked candidate")

    assert_includes step, 'ruby .github/scripts/prepare_tracked_public_candidate.rb "$RUNNER_TEMP/public-candidate"'
    refute_includes block, "git archive"
    refute_includes block, "cp -R"
    refute_includes block, "rsync"
  end

  def test_recurring_gitleaks_gate_is_pinned_redacted_and_artifact_free
    block = workflow_job("classify-changes")
    policy_step = workflow_step(block, "Prepare pinned Gitleaks policy")
    boundary_step = workflow_step(block, "Verify trusted Gitleaks boundary")
    scan_step = workflow_step(block, "Scan tracked candidate with pinned Gitleaks")

    assert_includes policy_step, 'GITLEAKS_VERSION: "8.30.1"'
    assert_includes policy_step, 'GITLEAKS_LINUX_X64_SHA256: "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"'
    assert_includes policy_step, "https://github.com/gitleaks/gitleaks/releases/download/v"
    assert_includes policy_step, "sha256sum --check --status"
    assert_includes policy_step, 'trusted_config="$RUNNER_TEMP/gitleaks-ci.toml"'
    assert_includes policy_step, 'trusted_ignore="$RUNNER_TEMP/gitleaks-ci.ignore"'
    assert_includes policy_step, "'[extend]' 'useDefault = true'"
    assert_includes policy_step, ': > "$trusted_ignore"'
    assert_includes boundary_step, "verify_gitleaks_security_boundary.rb"
    assert_includes scan_step, '"$RUNNER_TEMP/gitleaks" dir "$RUNNER_TEMP/public-candidate"'
    assert_includes scan_step, '--config "$RUNNER_TEMP/gitleaks-ci.toml"'
    assert_includes scan_step, '--gitleaks-ignore-path "$RUNNER_TEMP/gitleaks-ci.ignore"'
    assert_includes scan_step, "--ignore-gitleaks-allow"
    assert_includes scan_step, "--redact=100"
    assert_includes scan_step, "--exit-code 1"
    refute_includes block, "$RUNNER_TEMP/public-candidate/.gitleaks.toml"
    refute_includes block, "$RUNNER_TEMP/public-candidate/.gitleaksignore"
    refute_includes block, "upload-artifact"
    refute_includes scan_step, "--report-path"
  end

  def test_fixture_changes_require_hosted_ci_validation
    step = workflow_step(workflow_job("classify-changes"), "Classify changed files")

    assert_includes step, "docs/data/portability-recovery-v1/*|docs/data/portability-recovery-contract.md)"
    fixture_case = step[/docs\/data\/portability-recovery-v1\/\*\|docs\/data\/portability-recovery-contract\.md\).*?;;/m]
    refute_nil fixture_case
    assert_includes fixture_case, "ci_validation_required=true"
    refute_includes fixture_case, "app_validation_required=true"
  end

  def test_validation_workflow_covers_pull_requests_and_main_pushes
    workflow = File.read(WORKFLOW_PATH)
    assert_match(/^on:\n  pull_request:\n  push:\n    branches:\n      - main$/m, workflow)
  end

  def test_validator_test_remains_in_public_automation_checks
    runner = File.read(".github/scripts/support/public_automation_contract.rb")
    assert_includes runner, "test_validate_public_surface.rb"
    assert_includes runner, "test_prepare_tracked_public_candidate.rb"
    assert_includes runner, "test_public_security_gates.rb"
    assert_includes runner, "test_verify_gitleaks_security_boundary.rb"
  end

  private

  def workflow_job(name)
    workflow = File.read(WORKFLOW_PATH)
    match = workflow.match(/^  #{Regexp.escape(name)}:\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\n|\z)/m)
    refute_nil match, "Missing workflow job #{name}"
    match[0]
  end

  def workflow_step(job, name)
    match = job.match(/^      - name: #{Regexp.escape(name)}\n(?<body>.*?)(?=^      - name: |\z)/m)
    refute_nil match, "Missing workflow step #{name}"
    match[0]
  end
end
