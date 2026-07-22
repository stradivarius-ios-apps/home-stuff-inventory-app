#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "optparse"
require_relative "support/release_contract"

module ReleaseVersionPreparation
  PROJECT_PATH = ReleaseContract::PROJECT_PATH
  CHANGELOG_PATH = ReleaseContract::CHANGELOG_PATH
  IDENTIFIER = ReleaseContract::IDENTIFIER
  SEMVER = ReleaseContract::SEMVER

  module_function

  def tuple(version)
    ReleaseContract.tuple(version)
  end

  def compare(left, right)
    ReleaseContract.compare(left, right)
  end

  def valid_tag_versions(tags)
    ReleaseContract.valid_tag_versions(tags)
  end

  def latest_version!(tags)
    versions = valid_tag_versions(tags)
    raise "No valid vMAJOR.MINOR.PATCH release tag exists." if versions.empty?

    versions.max_by { |version| tuple(version) }
  end

  def project_marketing_version!(content)
    ReleaseContract.project_marketing_version!(content)
  end

  def changelog_has_version?(content, version)
    ReleaseContract.changelog_has_version?(content, version)
  end

  def resolve_target!(input:, latest_version:, changelog:)
    requested = input.to_s.strip
    if requested.empty?
      major, minor, patch = tuple(latest_version)
      return "#{major}.#{minor}.#{patch + 1}"
    end

    raise "Target version must not include a leading v." if requested.start_with?("v")
    raise "Target version must use strict MAJOR.MINOR.PATCH SemVer without leading zeroes." unless requested.match?(SEMVER)
    raise "Target version #{requested} must be higher than latest release #{latest_version}." unless compare(requested, latest_version).positive?
    raise "CHANGELOG.md already contains release #{requested}." if changelog_has_version?(changelog, requested)

    requested
  end

  def update_marketing_version(content, target)
    current_build_versions = content.scan(/CURRENT_PROJECT_VERSION\s*=\s*([^;]+);/).flatten
    updated = content.gsub(/MARKETING_VERSION\s*=\s*[^;]+;/, "MARKETING_VERSION = #{target};")
    updated_build_versions = updated.scan(/CURRENT_PROJECT_VERSION\s*=\s*([^;]+);/).flatten
    raise "CURRENT_PROJECT_VERSION changed unexpectedly." unless current_build_versions == updated_build_versions

    updated
  end

  def release_entry(version, grouped_changes)
    raise "No release-relevant changes exist for #{version}." if grouped_changes.values.all?(&:empty?)

    lines = ["## #{version}", ""]
    grouped_changes.each do |section, changes|
      next if changes.empty?

      lines << "### #{section}" << ""
      changes.each { |change| lines << "- #{change}" }
      lines << ""
    end
    lines.join("\n").rstrip
  end

  def update_changelog(content, version, grouped_changes)
    raise "CHANGELOG.md must start with '# Changelog'." unless content.start_with?("# Changelog")
    raise "CHANGELOG.md already contains release #{version}." if changelog_has_version?(content, version)

    first_release = content.index(/^## /)
    raise "CHANGELOG.md must contain at least one existing release entry." unless first_release

    introduction = content[0...first_release].rstrip
    history = content[first_release..].lstrip
    "#{introduction}\n\n#{release_entry(version, grouped_changes)}\n\n#{history}"
  end

  def branch_name(version)
    "feature/ad_hoc_prepare-release-#{version.tr('.', '-')}"
  end

  def validate_publish_options!(push:, create_pr:, repository:)
    raise "--create-pr requires --push." if create_pr && !push
    raise "--create-pr requires GITHUB_REPOSITORY or --repository." if create_pr && repository.to_s.empty?
  end

  def github_merge_boilerplate?(subject)
    subject.to_s.match?(/\AMerge pull request #\d+ from /i)
  end

  def normalized_change_subject!(subject:, second_parent_subject: nil)
    merge_reference = subject.to_s[/\AMerge pull request #(\d+) from /i, 1]
    normalized = if merge_reference
                   second_parent_subject.to_s.strip
                 else
                   subject.to_s.strip
                 end
    if normalized.empty? || github_merge_boilerplate?(normalized)
      raise "Release notes must not contain GitHub merge boilerplate: #{subject}"
    end

    if merge_reference && !normalized.match?(/\s+\(#\d+\)\z/)
      "#{normalized} (##{merge_reference})"
    else
      normalized
    end
  end
end

def run!(*command, allow_failure: false, env: {})
  stdout, stderr, status = Open3.capture3(env, *command)
  return [stdout, stderr, status] if allow_failure || status.success?

  raise "Command failed: #{command.join(' ')}\n#{stderr}"
end

def clean_worktree!
  stdout, = run!("git", "status", "--porcelain")
  raise "Working tree must be clean before release preparation." unless stdout.empty?
end

def tags
  stdout, = run!("git", "tag", "--list", "v*")
  stdout.lines.map(&:strip)
end

def categorized_changes(latest_tag)
  stdout, = run!("git", "log", "--first-parent", "--format=%h%x1f%P%x1f%s%x1e", "#{latest_tag}..HEAD")
  groups = { "Changed" => [], "Fixed" => [], "Internal" => [] }
  stdout.split("\x1e").each do |record|
    hash, parents, subject = record.split("\x1f", 3).map { |value| value.to_s.strip }
    next if hash.empty? || subject.empty? || subject.match?(/\A(?:Prepare|Bump) release/i)

    parent_shas = parents.split
    second_parent_subject = if parent_shas.length > 1
                              output, = run!("git", "show", "-s", "--format=%s", parent_shas[1])
                              output.strip
                            end
    subject = ReleaseVersionPreparation.normalized_change_subject!(
      subject: subject,
      second_parent_subject: second_parent_subject
    )
    clean_subject = subject.sub(/\s+\(#\d+\)\z/, "")
    reference = subject[/\(#(\d+)\)\z/, 1]
    bullet = reference ? "#{clean_subject} (##{reference})." : "#{clean_subject} (#{hash})."
    section = if clean_subject.match?(/\A(?:Fix|Resolve)/i)
                "Fixed"
              elsif clean_subject.match?(/\b(?:CI|workflow|release|docs|runner|coverage|App Store|TestFlight)\b/i)
                "Internal"
              else
                "Changed"
              end
    groups.fetch(section) << bullet
  end
  groups
end

def remote_branch_exists?(branch)
  stdout, = run!("git", "ls-remote", "--heads", "origin", "refs/heads/#{branch}")
  !stdout.strip.empty?
end

def pr_body(version, latest_tag, changed_files)
  [
    "## Summary",
    "",
    "- Update committed `MARKETING_VERSION` from `#{latest_tag.delete_prefix('v')}` to `#{version}`.",
    "- Add reviewable release notes for `#{version}` to `CHANGELOG.md`.",
    "- Keep `CURRENT_PROJECT_VERSION` unchanged.",
    "",
    "## Maintainer handoff",
    "",
    "Review the generated release notes and merge this PR into `main`.",
    "Then run the release pipeline from `main`.",
    "This workflow does not auto-merge, tag, deploy, publish metadata, submit for review, or release publicly.",
    "",
    "## Validation",
    "",
    "- Strict SemVer and stale/duplicate release checks passed.",
    "- Changed files are limited to #{changed_files.map { |path| "`#{path}`" }.join(", ")}."
  ].join("\n")
end

def write_summary(version:, latest_tag:, branch:, changed_files:, dry_run:)
  path = ENV["GITHUB_STEP_SUMMARY"]
  return if path.to_s.empty?

  File.open(path, "a") do |summary|
    summary.puts "## Prepare Release Version"
    summary.puts
    summary.puts "- Target version: `#{version}`"
    summary.puts "- Latest release tag: `#{latest_tag}`"
    summary.puts "- Release-prep branch: `#{branch}`"
    summary.puts "- Changed files: #{changed_files.map { |file| "`#{file}`" }.join(", ")}"
    summary.puts "- Mode: `#{dry_run ? "dry run" : "draft PR preparation"}`"
    summary.puts
    summary.puts "Review and finalize the changelog before merging; this workflow never tags, deploys, or releases publicly."
  end
end

def main(argv)
  options = { target: "", dry_run: false, push: false, create_pr: false, repository: ENV["GITHUB_REPOSITORY"], base_branch: "main" }
  OptionParser.new do |parser|
    parser.on("--target-version VERSION") { |value| options[:target] = value }
    parser.on("--dry-run") { options[:dry_run] = true }
    parser.on("--push") { options[:push] = true }
    parser.on("--create-pr") { options[:create_pr] = true }
    parser.on("--publish") { options[:push] = true; options[:create_pr] = true }
    parser.on("--repository OWNER/REPO") { |value| options[:repository] = value }
    parser.on("--base-branch BRANCH") { |value| options[:base_branch] = value }
  end.parse!(argv)

  ReleaseVersionPreparation.validate_publish_options!(
    push: options[:push], create_pr: options[:create_pr], repository: options[:repository]
  )

  clean_worktree!
  valid_versions = ReleaseVersionPreparation.valid_tag_versions(tags)
  latest_version = ReleaseVersionPreparation.latest_version!(tags)
  latest_tag = "v#{latest_version}"
  project_content = File.read(ReleaseVersionPreparation::PROJECT_PATH)
  changelog_content = File.read(ReleaseVersionPreparation::CHANGELOG_PATH)
  target = ReleaseVersionPreparation.resolve_target!(
    input: options[:target], latest_version: latest_version, changelog: changelog_content
  )
  raise "Target version #{target} already has a release tag." if valid_versions.include?(target)

  branch = ReleaseVersionPreparation.branch_name(target)
  raise "Release preparation branch #{branch} already exists on origin. Review or recover that branch instead of creating a duplicate." if remote_branch_exists?(branch)

  changes = categorized_changes(latest_tag)
  updated_project = ReleaseVersionPreparation.update_marketing_version(project_content, target)
  updated_changelog = ReleaseVersionPreparation.update_changelog(changelog_content, target, changes)

  if options[:dry_run]
    puts "Dry run: prepare #{target} from #{latest_tag} on #{branch}."
    write_summary(version: target, latest_tag: latest_tag, branch: branch,
                  changed_files: [ReleaseVersionPreparation::CHANGELOG_PATH, ReleaseVersionPreparation::PROJECT_PATH], dry_run: true)
    return
  end

  run!("git", "switch", "-c", branch)
  File.write(ReleaseVersionPreparation::PROJECT_PATH, updated_project)
  File.write(ReleaseVersionPreparation::CHANGELOG_PATH, updated_changelog)
  changed, = run!("git", "diff", "--name-only")
  expected = [ReleaseVersionPreparation::CHANGELOG_PATH, ReleaseVersionPreparation::PROJECT_PATH].sort
  raise "Unexpected release-prep files: #{changed.lines.map(&:strip).sort.join(', ')}" unless changed.lines.map(&:strip).sort == expected

  run!("git", "add", *expected)
  run!("git", "commit", "-m", "Prepare release #{target}")

  if options[:push]
    run!("git", "push", "--set-upstream", "origin", branch)
  end

  if options[:create_pr]
    run!(
      "gh", "pr", "create", "--draft", "--base", options[:base_branch], "--head", branch,
      "--title", "Prepare release #{target}", "--body", pr_body(target, latest_tag, expected),
      env: { "GH_TOKEN" => ENV.fetch("GH_TOKEN"), "GH_REPO" => options[:repository] }
    )
  end

  write_summary(version: target, latest_tag: latest_tag, branch: branch, changed_files: expected, dry_run: false)

  puts "Prepared release #{target} from #{latest_tag} on #{branch}."
end

main(ARGV) if $PROGRAM_NAME == __FILE__
