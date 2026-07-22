#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require_relative "support/release_contract"

module GitHubReleasePreflight
  PROJECT_PATH = ReleaseContract::PROJECT_PATH
  CHANGELOG_PATH = ReleaseContract::CHANGELOG_PATH
  IDENTIFIER = ReleaseContract::IDENTIFIER
  SEMVER = ReleaseContract::SEMVER
  SHA = ReleaseContract::SHA

  module_function

  def tuple(version)
    ReleaseContract.tuple(version)
  end

  def normalize_version(input)
    ReleaseContract.normalize_version(input, allow_leading_v: true)
  end

  def unique_project_value!(content, setting)
    ReleaseContract.project_value!(content, setting)
  end

  def validate_source_ref!(source_ref, allow_recovery)
    return "main" if source_ref == "main"
    raise "Non-main recovery requires explicit maintainer approval." unless allow_recovery
    raise "Recovery source_ref must be an exact 40-character commit SHA." unless source_ref.match?(SHA)

    source_ref.downcase
  end

  def changelog_entry!(content, version)
    ReleaseContract.finalized_changelog_entry!(content, version)
  end

  def ensure_newer!(target, tag_versions)
    latest = tag_versions.max_by { |version| tuple(version) }
    return unless latest
    raise "Target version #{target} must be newer than latest tag v#{latest}." unless (tuple(target) <=> tuple(latest)).positive?
  end
end

def run!(*command, allow_failure: false, env: {})
  stdout, stderr, status = Open3.capture3(env, *command)
  return [stdout, stderr, status] if allow_failure || status.success?

  raise "Command failed: #{command.join(' ')}\n#{stderr}#{stdout}"
end

def valid_tag_versions
  stdout, = run!("git", "tag", "--list", "v*")
  ReleaseContract.valid_tag_versions(stdout.lines)
end

def ensure_source_matches!(source_ref, source_sha)
  if source_ref == "main"
    main_sha, = run!("git", "rev-parse", "origin/main")
    raise "Checked-out source #{source_sha} is not current origin/main #{main_sha.strip}." unless main_sha.strip == source_sha
  elsif source_ref != source_sha
    raise "Recovery source #{source_ref} resolved to unexpected SHA #{source_sha}."
  end
end

def ensure_tag_and_release_missing!(tag, source_sha, skip_remote_checks)
  _stdout, _stderr, local_status = run!("git", "show-ref", "--verify", "--quiet", "refs/tags/#{tag}", allow_failure: true)
  if local_status.success?
    existing_sha, = run!("git", "rev-list", "-n", "1", tag)
    if existing_sha.strip == source_sha
      raise "Annotated tag #{tag} already exists at #{source_sha}. If its GitHub Release is missing, verify the tag and create the Release with --verify-tag; do not retag."
    end
    raise "Tag #{tag} already exists at #{existing_sha.strip}; refusing to retarget it to #{source_sha}."
  end
  return if skip_remote_checks

  remote_tags, remote_errors, remote_status = run!(
    "git", "ls-remote", "--tags", "origin", "refs/tags/#{tag}", "refs/tags/#{tag}^{}",
    allow_failure: true
  )
  raise "Unable to check remote tag #{tag}: #{remote_errors}" unless remote_status.success?
  unless remote_tags.strip.empty?
    lines = remote_tags.lines.map { |line| line.split("\t", 2) }
    peeled = lines.find { |_sha, ref| ref.to_s.strip.end_with?("^{}") }
    existing_sha = (peeled || lines.first).first
    if existing_sha == source_sha
      raise "Tag #{tag} already exists on origin at #{source_sha}. Verify/create only the missing GitHub Release; do not retag."
    end
    raise "Tag #{tag} already exists on origin at #{existing_sha}; refusing to retarget it to #{source_sha}."
  end

  stdout, stderr, release_status = run!(
    "gh", "release", "view", tag, "--repo", ENV.fetch("GITHUB_REPOSITORY"), "--json", "url",
    allow_failure: true, env: { "GH_TOKEN" => ENV.fetch("GH_TOKEN") }
  )
  return if !release_status.success? && "#{stdout}#{stderr}".match?(/not found|HTTP 404/i)
  raise "GitHub Release #{tag} already exists." if release_status.success?

  raise "Unable to verify GitHub Release absence: #{stdout}#{stderr}"
end

def write_output(name, value)
  path = ENV["GITHUB_OUTPUT"]
  return if path.to_s.empty?
  File.open(path, "a") { |file| file.puts "#{name}=#{value}" }
end

def write_summary(marketing_version:, tag:, source_ref:, source_sha:)
  path = ENV["GITHUB_STEP_SUMMARY"]
  return if path.to_s.empty?

  File.open(path, "a") do |summary|
    summary.puts "## GitHub Release preflight"
    summary.puts
    summary.puts "- Marketing version: `#{marketing_version}`"
    summary.puts "- Tag: `#{tag}`"
    summary.puts "- Source ref: `#{source_ref}`"
    summary.puts "- Source commit: `#{source_sha}`"
    summary.puts "- Release notes: finalized `CHANGELOG.md` entry"
  end
end

def main(argv)
  options = { target: "", source_ref: "main", allow_recovery: false, notes: "release-notes.md", skip_remote_checks: false }
  OptionParser.new do |parser|
    parser.on("--target-version VERSION") { |value| options[:target] = value }
    parser.on("--source-ref REF") { |value| options[:source_ref] = value }
    parser.on("--allow-non-main-source-ref") { options[:allow_recovery] = true }
    parser.on("--release-notes PATH") { |value| options[:notes] = value }
    parser.on("--release-body-path PATH") { |value| options[:notes] = value }
    parser.on("--skip-remote-checks") { options[:skip_remote_checks] = true }
  end.parse!(argv)

  source_ref = GitHubReleasePreflight.validate_source_ref!(options[:source_ref].to_s.strip, options[:allow_recovery])
  source_sha, = run!("git", "rev-parse", "HEAD")
  source_sha = source_sha.strip
  ensure_source_matches!(source_ref, source_sha)

  project = File.read(GitHubReleasePreflight::PROJECT_PATH)
  marketing_version = ReleaseContract.project_marketing_version!(project)
  override = GitHubReleasePreflight.normalize_version(options[:target])
  raise "Target override #{override} does not exactly match committed MARKETING_VERSION #{marketing_version}." if override && override != marketing_version

  tag = ReleaseContract.tag_for(marketing_version)
  GitHubReleasePreflight.ensure_newer!(marketing_version, valid_tag_versions)
  notes = GitHubReleasePreflight.changelog_entry!(File.read(GitHubReleasePreflight::CHANGELOG_PATH), marketing_version)
  ensure_tag_and_release_missing!(tag, source_sha, options[:skip_remote_checks])
  File.write(options[:notes], "#{notes}\n")

  write_output("marketing_version", marketing_version)
  write_output("tag_name", tag)
  write_output("source_ref", source_ref)
  write_output("source_sha", source_sha)
  write_summary(marketing_version: marketing_version, tag: tag, source_ref: source_ref, source_sha: source_sha)
  puts "GitHub Release preflight passed for #{tag} at #{source_sha}."
end

if $PROGRAM_NAME == __FILE__
  begin
    main(ARGV)
  rescue StandardError => error
    warn "Create GitHub Release preflight failed: #{error.message}"
    exit 1
  end
end
