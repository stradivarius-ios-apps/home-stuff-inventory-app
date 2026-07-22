#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"

class PublicGovernanceValidator
  CANONICAL_REPOSITORY = "stradivarius-ios-apps/home-stuff-inventory-app"
  PRIVATE_REPORTING_URL = "https://github.com/#{CANONICAL_REPOSITORY}/security/advisories/new"
  PUBLIC_AUTOMATION_CHECK = "test_public_governance.rb"
  PUBLIC_AUTOMATION_FILE_CLOSURE = %w[
    .github/scripts/test_public_governance.rb
    .github/scripts/validate_public_governance.rb
  ].freeze
  REQUIRED_FILES = (%w[
    LICENSE
    BRAND.md
    DCO
    SECURITY.md
    CONTRIBUTING.md
    .github/CODEOWNERS
    .github/pull_request_template.md
    .github/workflows/validation.yml
    .github/ISSUE_TEMPLATE/config.yml
    .github/ISSUE_TEMPLATE/bug_report.yml
    .github/ISSUE_TEMPLATE/feature_request.yml
    docs/security/public-governance-decisions.md
    docs/security/public-repository-trust-boundary.md
    docs/security/publication-and-rollback-checklist.md
    docs/security/public-repository-settings-plan.json
  ] + PUBLIC_AUTOMATION_FILE_CLOSURE).freeze
  REQUIRED_OWNER_PATTERNS = %w[
    *
    /.github/CODEOWNERS
    /.github/workflows/**
    /.github/scripts/**
    /scripts/ci/**
    /SECURITY.md
    /CONTRIBUTING.md
    /LICENSE*
    /BRAND.md
    /DCO
    /docs/security/**
    /docs/privacy/**
    /HomeStuffInventoryApp.xcodeproj/**
    /fastlane/**
    /CHANGELOG.md
    /HomeStuffInventoryApp/InventoryLogic/InventoryBackup*
    /HomeStuffInventoryApp/Resources/PrivacyInfo.xcprivacy
    /docs/data/**
  ].freeze
  REQUIRED_GLOBAL_CHECK_CANDIDATES = [
    "Classify changed files",
    "CI workflow validation"
  ].freeze
  REQUIRED_BOUNDARY_STEPS = [
    "Validate tracked public surface",
    "Prepare exact tracked candidate",
    "Verify trusted Gitleaks boundary",
    "Scan tracked candidate with pinned Gitleaks"
  ].freeze
  CONDITIONAL_CHECK_CANDIDATES = [
    "Build and test",
    "Code coverage",
    "Full Test Suite"
  ].freeze

  def initialize(root = File.expand_path("../..", __dir__))
    @root = File.expand_path(root)
  end

  def validate!
    require_files!
    validate_license_and_brand_scope!
    validate_dco_policy!
    validate_security_policy!
    validate_contribution_gate!
    validate_issue_forms!
    validate_pull_request_template!
    validate_codeowners!
    validate_decisions!
    validate_trust_boundary!
    validate_checklist!
    validate_settings_plan!
    true
  end

  private

  def require_files!
    missing = REQUIRED_FILES.reject { |path| File.file?(absolute(path)) }
    fail_validation("missing governance files: #{missing.join(', ')}") unless missing.empty?
  end

  def validate_security_policy!
    policy = read("SECURITY.md")
    require_text!(policy, PRIVATE_REPORTING_URL, "SECURITY.md private reporting route")
    require_text!(policy, "Do not open a public issue", "SECURITY.md public-disclosure prohibition")
    require_text!(policy, "Only the latest release distributed through the Apple App Store is supported",
                  "SECURITY.md latest-release-only policy")
    require_text!(policy, "does not promise a fixed acknowledgement or remediation SLA",
                  "SECURITY.md response expectation")
    require_text!(policy, "Private Vulnerability Reporting must be enabled and verified before publication",
                  "SECURITY.md PVR gate")
    fail_validation("SECURITY.md must not use a public issue as a security fallback") if
      policy.match?(/open (?:a )?public issue.*(?:security|vulnerab)/i)
  end

  def validate_contribution_gate!
    policy = read("CONTRIBUTING.md")
    require_text!(policy, "accepts external contributions", "external contribution policy")
    require_text!(policy, "Developer Certificate of Origin 1.1", "DCO policy")
    require_text!(policy, "does not use a Contributor License Agreement", "no-CLA policy")
    require_text!(policy, "git commit --signoff", "DCO sign-off instructions")
    require_text!(policy, "BRAND.md", "reserved brand guidance")
    fail_validation("CONTRIBUTING.md must not retain the rejected-contribution staging policy") if
      policy.include?("pull requests are not accepted")
    require_text!(policy, "SECURITY.md", "private security reporting guidance")
  end

  def validate_license_and_brand_scope!
    license = read("LICENSE")
    ["MIT License", "Copyright (c) 2026 Home Stuff Inventory contributors",
     "Permission is hereby granted, free of charge", "THE SOFTWARE IS PROVIDED \"AS IS\""].each do |term|
      require_text!(license, term, "MIT license")
    end

    brand = read("BRAND.md")
    ["MIT License", "product name", "app icons", "screenshots", "App Store listing copy",
     "design artwork", "All rights are reserved", "Forks and redistributed builds must replace"].each do |term|
      require_text!(brand, term, "brand carve-out")
    end
  end

  def validate_dco_policy!
    dco = read("DCO")
    ["Version 1.1", "The Linux Foundation and its contributors",
     "changing it is not allowed", "Developer's Certificate of Origin 1.1",
     "including my sign-off"].each do |term|
      require_text!(dco, term, "DCO 1.1 policy")
    end
  end

  def validate_issue_forms!
    config = yaml(".github/ISSUE_TEMPLATE/config.yml")
    fail_validation("blank public issues must remain disabled") unless config["blank_issues_enabled"] == false
    links = Array(config["contact_links"])
    fail_validation("issue configuration is missing the private vulnerability route") unless
      links.any? { |link| link["url"] == PRIVATE_REPORTING_URL }

    %w[bug_report.yml feature_request.yml].each do |name|
      form = yaml(".github/ISSUE_TEMPLATE/#{name}")
      fail_validation("#{name} must contain a body") unless form["body"].is_a?(Array) && !form["body"].empty?
      text = read(".github/ISSUE_TEMPLATE/#{name}")
      require_text!(text, "real household inventory", "#{name} private-data warning")
    end
  end

  def validate_pull_request_template!
    template = read(".github/pull_request_template.md")
    ["credentials", "private release repository", "GitHub-hosted runners", "CODEOWNER",
     "SECURITY.md", "Signed-off-by:", "DCO 1.1", "BRAND.md"].each do |term|
      require_text!(template, term, "pull request template boundary")
    end
    fail_validation("pull request template needs security checkboxes") if template.scan(/- \[ \]/).length < 7
  end

  def validate_codeowners!
    owners = {}
    read(".github/CODEOWNERS").each_line.with_index(1) do |line, number|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      fields = line.split
      pattern = fields.shift
      fail_validation("CODEOWNERS line #{number} uses unsupported negation or range syntax") if
        pattern.start_with?("!") || pattern.include?("[") || pattern.include?("]")
      fail_validation("CODEOWNERS line #{number} has no valid owner") if
        fields.empty? || fields.any? { |owner| !owner.match?(/\A@[A-Za-z0-9-]+(?:\/[A-Za-z0-9_.-]+)?\z/) }
      owners[pattern] = fields
    end

    missing = REQUIRED_OWNER_PATTERNS - owners.keys
    fail_validation("CODEOWNERS is missing protected patterns: #{missing.join(', ')}") unless missing.empty?
    fail_validation("CODEOWNERS must not depend on an unresolved owner placeholder") if
      owners.values.flatten.any? { |owner| owner.match?(/SET_|TODO|TBD/i) }
  end

  def validate_decisions!
    decisions = read("docs/security/public-governance-decisions.md")
    require_text!(decisions, CANONICAL_REPOSITORY, "canonical repository decision")
    unresolved_count = decisions.scan("UNRESOLVED — BLOCKER").length
    fail_validation("no maintainer policy decision may remain unresolved") unless unresolved_count.zero?
    ["MIT", "DCO 1.1", "no CLA",
     "Latest Apple App Store release only", "Product work is canonical public"].each do |term|
      require_text!(decisions, term, "approved governance decision")
    end
    ["APPROVED — NOT ADOPTED", "no moderator team or separate enforcement process",
     "public GitHub issues", "block, report, and conversation-locking controls",
     "GitHub Private Vulnerability Reporting"].each do |term|
      require_text!(decisions, term, "no-Code-of-Conduct community policy")
    end
    fail_validation("formal Code of Conduct contradicts the approved decision") if
      File.exist?(absolute("CODE_OF_CONDUCT.md"))
  end

  def validate_trust_boundary!
    boundary = read("docs/security/public-repository-trust-boundary.md")
    [CANONICAL_REPOSITORY, "GitHub-hosted runners", "full immutable commit SHA",
     "protected release tag", "isolated detached checkout", "no mirror branch",
     "must never use a self-hosted runner", "Fork pull requests", "SECURITY.md"].each do |term|
      require_text!(boundary, term, "public/private trust boundary")
    end
  end

  def validate_checklist!
    checklist = read("docs/security/publication-and-rollback-checklist.md")
    ["SEC-PUB-09 returns `GO`", "authorizes publication", "controlled fork pull request",
     "Disable public Actions", "Return the destination to private only if",
     "isolated public checkout"].each do |term|
      require_text!(checklist, term, "publication and rollback checklist")
    end
    fail_validation("publication checklist must remain uncompleted in staging") if checklist.include?("- [x]")
  end

  def validate_settings_plan!
    plan = JSON.parse(read("docs/security/public-repository-settings-plan.json"))
    fail_validation("settings plan schema is unsupported") unless plan["schema_version"] == 1
    fail_validation("settings plan targets the wrong repository") unless
      plan["destination_repository"] == CANONICAL_REPOSITORY
    fail_validation("settings plan must remain plan-only") unless plan["mode"] == "plan-only"
    fail_validation("settings application is not authorized") unless plan["apply_allowed"] == false
    fail_validation("publication is not authorized") unless plan["publication_authorized"] == false

    observed = plan.fetch("observed_staging_state")
    fail_validation("staging destination must remain recorded as private") unless observed["visibility"] == "private"
    fail_validation("staging Actions write default must remain visible as a blocker") unless
      observed["actions_default_workflow_permissions"] == "write"

    checks = plan.dig("required_checks", "global_candidates_not_authorized_for_rulesets")
    fail_validation("the recorded global check candidates changed without coordinated review") unless
      checks == REQUIRED_GLOBAL_CHECK_CANDIDATES
    boundary = plan.dig("required_checks", "boundary_coverage")
    expected_boundary = {
      "check" => "Classify changed files",
      "unconditional_steps" => REQUIRED_BOUNDARY_STEPS,
      "separate_check" => "not-present-and-not-required"
    }
    fail_validation("the unconditional public boundary ownership changed without coordinated review") unless
      boundary == expected_boundary

    validation = yaml(".github/workflows/validation.yml")
    classify = validation.dig("jobs", "classify-changes")
    fail_validation("Classify changed files must remain an unconditional job") unless
      classify.is_a?(Hash) && !classify.key?("if") && classify["name"] == "Classify changed files"
    step_names = Array(classify["steps"]).map { |step| step["name"] }
    missing_boundary_steps = REQUIRED_BOUNDARY_STEPS - step_names
    fail_validation("Classify changed files lost an unconditional public boundary step") unless
      missing_boundary_steps.empty?
    conditional = plan.dig("required_checks", "conditional_not_global")
    fail_validation("conditional checks must remain outside the global required set") unless
      conditional.is_a?(Hash) && conditional.keys == CONDITIONAL_CHECK_CANDIDATES
    fail_validation("required checks must remain blocked until observed in the clean repository") unless
      plan.dig("required_checks", "state").start_with?("blocked-")
    blockers = plan.dig("required_checks", "blockers")
    fail_validation("required-check integration blockers must remain explicit") unless
      blockers.is_a?(Array) && blockers.length == 4 && blockers.any? { |item| item.include?("source app") }

    actions = plan.dig("desired_controls", "actions")
    fail_validation("public Actions must default to read-only") unless actions["default_workflow_permissions"] == "read"
    fail_validation("public workflows must require immutable action pins") unless actions["require_full_commit_sha_pins"] == true
    fail_validation("public self-hosted runners must be prohibited") unless actions["self_hosted_runners"] == "prohibited"

    policy_stack = plan.fetch("policy_stack")
    expected_policy_stack = {
      "code_license" => "MIT",
      "brand_materials" => "reserved-see-BRAND.md",
      "external_contributions" => "accepted",
      "dco" => "mandatory-version-1.1",
      "cla" => "not-used",
      "code_of_conduct" => "not-adopted-no-moderator-team-or-process",
      "community_abuse_controls" => "GitHub-block-report-lock",
      "supported_security_versions" => "latest-Apple-App-Store-release-only",
      "security_reporting" => "GitHub-Private-Vulnerability-Reporting",
      "product_work" => "canonical-public-repository-only",
      "release_signing_runner_operations" => "retained-private"
    }
    fail_validation("approved policy stack drifted") unless policy_stack == expected_policy_stack

    dco = plan.dig("required_checks", "dco")
    fail_validation("DCO provider check must remain fail-closed until observed") unless
      dco == {
        "policy" => "mandatory-per-commit-signoff-no-CLA",
        "state" => "blocked-until-repository-scoped-app-is-installed-and-check-is-observed",
        "candidate_name" => "DCO",
        "required_source_app" => "record-exact-observed-source-app-before-ruleset",
        "maintainer_override" => "emergency-only-never-for-convenience"
      }

    gates = plan.fetch("gates")
    expected_gate_states = {
      "maintainer_policy_decisions" => "approved",
      "private_release_file_decision" => "approved-pending-final-disposition-evidence",
      "dco_provider_check" => "blocked"
    }
    fail_validation("resolved policy gates or sole moderation blocker drifted") unless
      gates.slice(*expected_gate_states.keys) == expected_gate_states
    remaining_gates = gates.reject { |key, _| expected_gate_states.key?(key) }
    fail_validation("all remaining pre-publication gates must remain blocked or required") unless
      remaining_gates.values.all? { |state| state == "blocked" || state.end_with?("required") }

    identities = plan.fetch("integration_identities")
    fail_validation("governance/bootstrap integration identities must remain blocked until merge") unless
      identities.keys == %w[governance_pr bootstrap_pr] &&
      identities["governance_pr"] == { "number" => 635, "state" => "blocked-until-merged", "merge_commit_sha" => nil } &&
      identities["bootstrap_pr"] == { "number" => 636, "state" => "blocked-until-merged", "merge_commit_sha" => nil }

    serialized = JSON.generate(plan)
    fail_validation("settings plan must contain states only, never credential values") if
      serialized.match?(/gh[pousr]_[A-Za-z0-9]{12,}|-----BEGIN [A-Z ]+PRIVATE KEY-----/)
  rescue JSON::ParserError, KeyError => error
    fail_validation("invalid settings plan: #{error.message}")
  end

  def yaml(path)
    value = YAML.safe_load(read(path), permitted_classes: [], permitted_symbols: [], aliases: false)
    fail_validation("#{path} must contain a YAML mapping") unless value.is_a?(Hash)
    value
  rescue Psych::Exception => error
    fail_validation("invalid YAML in #{path}: #{error.message}")
  end

  def require_text!(text, expected, context)
    fail_validation("#{context} is missing #{expected.inspect}") unless text.include?(expected)
  end

  def read(path)
    File.read(absolute(path), encoding: "UTF-8")
  end

  def absolute(path)
    File.join(@root, path)
  end

  def fail_validation(message)
    raise ArgumentError, message
  end
end

if $PROGRAM_NAME == __FILE__
  root = ARGV.fetch(0, File.expand_path("../..", __dir__))
  PublicGovernanceValidator.new(root).validate!
  puts "Public governance contract passed. Settings remain plan-only and publication is not authorized."
end
