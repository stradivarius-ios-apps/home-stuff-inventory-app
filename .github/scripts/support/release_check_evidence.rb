# frozen_string_literal: true

module ReleaseCheckEvidence
  REQUIRED_CHECKS = [
    "Validate exact release source / Classify changed files",
    "Validate exact release source / CI workflow validation",
    "Validate exact release source / Build and test",
    "Validate exact release source / Code coverage"
  ].freeze
  APPROVED_APP_SLUG = "github-actions"
  APPROVED_APP_ID = 15_368

  module_function

  def validate!(check_runs:, sha:, run_id:, repository:)
    raise "Release SHA is invalid." unless sha.match?(/\A[0-9a-f]{40}\z/)
    raise "Release run ID is invalid." unless run_id.match?(/\A[1-9]\d*\z/)
    expected_prefix = "https://github.com/#{repository}/actions/runs/#{run_id}/"
    matching = check_runs.fetch("check_runs").select { |check| REQUIRED_CHECKS.include?(check["name"]) }

    raise "Required release checks must be exactly the four configured names." unless
      matching.length == REQUIRED_CHECKS.length && matching.map { |check| check["name"] }.sort == REQUIRED_CHECKS.sort

    matching.each do |check|
      raise "Required release check has the wrong SHA." unless check["head_sha"] == sha
      raise "Required release check did not succeed." unless check["conclusion"] == "success"
      raise "Required release check has an unapproved app slug." unless check.dig("app", "slug") == APPROVED_APP_SLUG
      raise "Required release check has an unapproved app ID." unless check.dig("app", "id") == APPROVED_APP_ID
      raise "Required release check is not associated with this Release run." unless check["details_url"].to_s.start_with?(expected_prefix)
    end

    true
  end
end
