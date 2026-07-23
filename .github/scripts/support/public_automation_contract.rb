# frozen_string_literal: true

require "set"

module PublicAutomationContract
  PUBLIC_HOSTED_WORKFLOWS = %w[
    .github/workflows/create-github-release.yml
    .github/workflows/validation.yml
    .github/workflows/full-tests.yml
    .github/workflows/pr-ui-screenshots.yml
    .github/workflows/prepare-release-version.yml
    .github/workflows/release-app-store-screenshots.yml
  ].freeze

  CANONICAL_RELEASE_SCREENSHOT_WORKFLOW = ".github/workflows/release-app-store-screenshots.yml"

  PUBLIC_NON_RUBY_HELPERS = %w[
    .github/scripts/capture_release_app_store_screenshots.sh
    .github/scripts/configure_hosted_xcode.sh
    .github/scripts/create_full_test_simulators.sh
    scripts/ci/check-code-coverage.py
  ].freeze

  PUBLIC_CHECKS = %w[
    test_create_github_release_preflight.rb
    test_hosted_public_ci.rb
    test_prepare_tracked_public_candidate.rb
    test_pr_ui_screenshots.rb
    test_prepare_release_version.rb
    test_public_automation_check_closure.rb
    test_public_governance.rb
    test_public_release_contracts.rb
    test_public_security_gates.rb
    test_release_app_store_screenshots.rb
    test_validate_public_surface.rb
    test_verify_gitleaks_security_boundary.rb
    validate_action_pins.rb
    validate_ci_lanes.rb
    validate_macos_bash_compatibility.rb
    validate_public_release_screenshot_lane.rb
  ].freeze

  FASTLANE_SMOKE_TEST = "test_fastlane_default_actions.rb"
  PUBLIC_RUNTIME_RUBY_FILES = %w[
    full_test_validation.rb
    test_full_test_validation.rb
  ].freeze

  PRIVATE_ONLY_FILES = %w[
    .github/scripts/bootstrap_clean_public_repository.rb
    .github/scripts/prepare_final_public_candidate.rb
    .github/scripts/test_bootstrap_clean_public_repository.rb
    .github/scripts/test_prepare_final_public_candidate.rb
    .github/scripts/test_public_candidate_security.rb
    .github/scripts/test_validate_final_public_candidate.rb
    .github/scripts/validate_final_public_candidate.rb
    .github/scripts/verify_clean_public_cutover.rb
    .github/scripts/test_deploy_app_store_connect_contract.rb
    .github/scripts/test_app_store_connect_screenshot_upload_guard.rb
    .github/scripts/test_publish_app_store_metadata.rb
    .github/scripts/test_release_pipeline_preflight.rb
    .github/scripts/validate_publish_metadata_lane.rb
    .github/scripts/validate_release_pipeline_lane.rb
    .github/scripts/validate_release_screenshot_lane.rb
    .github/scripts/validate_self_hosted_runner_fence.rb
    .github/workflows/deploy-app-store-connect.yml
    .github/workflows/download-app-store-connect-metadata.yml
    .github/workflows/publish-app-store-connect-metadata.yml
    .github/workflows/release-pipeline.yml
    .github/workflows/public-candidate-security.yml
  ].freeze

  module_function

  def ruby_file_closure(repository_root:, include_fastlane: false)
    scripts_root = File.join(repository_root, ".github", "scripts")
    queue = PUBLIC_CHECKS + PUBLIC_RUNTIME_RUBY_FILES
    queue << FASTLANE_SMOKE_TEST if include_fastlane
    visited = Set.new

    until queue.empty?
      relative = queue.shift
      path = File.expand_path(relative, scripts_root)
      raise "Public automation dependency escapes scripts root: #{relative}" unless path.start_with?("#{scripts_root}/")
      raise "Public automation dependency is missing: #{relative}" unless File.file?(path)

      repository_path = path.delete_prefix("#{repository_root}/")
      next unless visited.add?(repository_path)

      File.read(path).scan(/^require_relative\s+["']([^"']+)["']/).flatten.each do |required|
        dependency = File.expand_path(required.end_with?(".rb") ? required : "#{required}.rb", File.dirname(path))
        queue << dependency.delete_prefix("#{scripts_root}/")
      end
    end

    visited.to_a.sort
  end

  def public_runner_file_closure(repository_root:)
    (ruby_file_closure(repository_root: repository_root, include_fastlane: true) + %w[
      .github/scripts/run_public_automation_checks.rb
      .github/scripts/support/public_automation_contract.rb
    ] + PUBLIC_NON_RUBY_HELPERS + PUBLIC_HOSTED_WORKFLOWS).uniq.sort
  end
end
