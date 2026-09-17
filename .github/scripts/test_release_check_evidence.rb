#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require_relative "support/release_check_evidence"

class ReleaseCheckEvidenceTest < Minitest::Test
  C = ReleaseCheckEvidence
  SHA = "a" * 40
  RUN_ID = "35115956674"
  REPOSITORY = "stradivarius-ios-apps/home-stuff-inventory-app"

  def test_requires_all_and_only_exact_orchestrated_check_names
    assert C.validate!(check_runs: check_runs, sha: SHA, run_id: RUN_ID, repository: REPOSITORY)
    legacy = check_runs
    legacy["check_runs"][0]["name"] = "Classify changed files"
    assert_raises(RuntimeError) { C.validate!(check_runs: legacy, sha: SHA, run_id: RUN_ID, repository: REPOSITORY) }

    duplicate = check_runs
    duplicate["check_runs"] << duplicate["check_runs"].first.dup
    assert_raises(RuntimeError) { C.validate!(check_runs: duplicate, sha: SHA, run_id: RUN_ID, repository: REPOSITORY) }
  end

  def test_ignores_checks_from_an_earlier_release_run_on_the_same_sha
    data = check_runs
    earlier = check_runs.fetch("check_runs").map do |check|
      check.merge("details_url" => check.fetch("details_url").sub("/runs/#{RUN_ID}/", "/runs/35100000000/"),
        "conclusion" => "failure")
    end
    data.fetch("check_runs").concat(earlier)

    assert C.validate!(check_runs: data, sha: SHA, run_id: RUN_ID, repository: REPOSITORY)

    data.fetch("check_runs").shift
    assert_raises(RuntimeError) { C.validate!(check_runs: data, sha: SHA, run_id: RUN_ID, repository: REPOSITORY) }
  end

  def test_rejects_wrong_evidence_attributes
    {
      "head_sha" => "b" * 40,
      "conclusion" => "skipped",
      "details_url" => "https://github.com/#{REPOSITORY}/actions/runs/99/job/1"
    }.each do |field, value|
      data = check_runs
      data["check_runs"][0][field] = value
      assert_raises(RuntimeError) { C.validate!(check_runs: data, sha: SHA, run_id: RUN_ID, repository: REPOSITORY) }
    end

    { "slug" => "other-app", "id" => 1 }.each do |field, value|
      data = check_runs
      data["check_runs"][0]["app"][field] = value
      assert_raises(RuntimeError) { C.validate!(check_runs: data, sha: SHA, run_id: RUN_ID, repository: REPOSITORY) }
    end
  end

  private

  def check_runs
    {
      "check_runs" => C::REQUIRED_CHECKS.each_with_index.map do |name, index|
        {
          "name" => name,
          "head_sha" => SHA,
          "conclusion" => "success",
          "app" => { "slug" => C::APPROVED_APP_SLUG, "id" => C::APPROVED_APP_ID },
          "details_url" => "https://github.com/#{REPOSITORY}/actions/runs/#{RUN_ID}/job/#{index}"
        }
      end
    }
  end
end
