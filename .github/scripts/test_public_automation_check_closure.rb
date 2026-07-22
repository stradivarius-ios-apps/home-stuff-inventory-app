#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "yaml"
require_relative "support/public_automation_contract"

class PublicAutomationCheckClosureTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_public_runner_has_a_complete_public_only_ruby_file_closure
    closure = PublicAutomationContract.public_runner_file_closure(repository_root: ROOT)

    PublicAutomationContract::PRIVATE_ONLY_FILES.each do |private_path|
      refute_includes closure, private_path
    end
    closure.each { |path| assert File.file?(File.join(ROOT, path)), "missing public runner file #{path}" }
  end

  def test_public_runner_reports_the_canonical_file_closure
    expected = PublicAutomationContract.public_runner_file_closure(repository_root: ROOT)
    output, status = Open3.capture2e("ruby", ".github/scripts/run_public_automation_checks.rb", "--list-files", chdir: ROOT)

    assert status.success?, output
    assert_equal expected, output.lines(chomp: true)
  end

  def test_declared_non_ruby_and_workflow_helpers_are_in_the_candidate_closure
    closure = PublicAutomationContract.public_runner_file_closure(repository_root: ROOT)

    PublicAutomationContract::PUBLIC_NON_RUBY_HELPERS.each do |path|
      assert_includes closure, path
    end
    PublicAutomationContract::PUBLIC_HOSTED_WORKFLOWS.each do |path|
      assert_includes closure, path
    end
  end

  def test_public_workflow_ownership_is_explicit_and_hosted
    assert_equal ".github/workflows/release-app-store-screenshots.yml",
                 PublicAutomationContract::CANONICAL_RELEASE_SCREENSHOT_WORKFLOW
    assert_includes PublicAutomationContract::PUBLIC_HOSTED_WORKFLOWS,
                    PublicAutomationContract::CANONICAL_RELEASE_SCREENSHOT_WORKFLOW

    PublicAutomationContract::PUBLIC_HOSTED_WORKFLOWS.each do |path|
      text = File.read(File.join(ROOT, path))
      refute_includes text, "self-hosted", "#{path} is not public-hosted"
      workflow = YAML.load_file(File.join(ROOT, path))
      workflow.fetch("jobs").each do |job_name, job|
        next unless job.key?("runs-on")

        assert_includes %w[ubuntu-latest macos-26-intel], job.fetch("runs-on"),
                        "#{path}:#{job_name} is not on a reviewed GitHub-hosted runner"
      end
    end
  end

  def test_validation_invokes_only_the_public_runner
    validation = File.read(File.join(ROOT, ".github/workflows/validation.yml"))

    assert_equal 2, validation.scan("ruby .github/scripts/run_public_automation_checks.rb").length
    refute_includes validation, "run_release_automation_checks.rb"
  end
end
