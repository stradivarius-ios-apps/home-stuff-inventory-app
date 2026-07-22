#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"

module TrackedPublicCandidate
  class PolicyError < StandardError; end

  REGULAR_FILE_MODES = %w[100644 100755].freeze

  module_function

  def prepare!(repository_root:, output_root:)
    repository_root = File.realpath(repository_root)
    output_root = File.expand_path(output_root)
    raise ArgumentError, "Candidate output already exists" if File.exist?(output_root) || File.symlink?(output_root)

    FileUtils.mkdir_p(output_root)
    candidate_root = File.realpath(output_root)
    entries = index_entries(repository_root)

    entries.each do |entry|
      validate_entry!(entry)
      materialize_blob!(repository_root, candidate_root, entry)
    end

    entries.length
  end

  def index_entries(repository_root)
    stdout, _stderr, status = Open3.capture3(
      "git", "ls-files", "-z", "--stage",
      chdir: repository_root,
      binmode: true
    )
    raise PolicyError, "Unable to enumerate tracked candidate: Git index read failed" unless status.success?

    stdout.split("\0".b).reject(&:empty?).map { |record| parse_index_record(record) }
  end

  def parse_index_record(record)
    match = record.match(/\A(?<mode>[0-9]{6}) (?<oid>[0-9a-f]+) (?<stage>[0-3])\t(?<path>.*)\z/m)
    raise PolicyError, "Unable to enumerate tracked candidate: malformed Git index entry" unless match

    {
      mode: match[:mode],
      oid: match[:oid],
      stage: match[:stage],
      path: match[:path]
    }
  end

  def validate_entry!(entry)
    path = entry.fetch(:path)
    reject_path!(path, "non-stage-zero Git index entry") unless entry.fetch(:stage) == "0"

    case entry.fetch(:mode)
    when "120000"
      reject_path!(path, "symbolic link")
    when "160000"
      reject_path!(path, "Git submodule gitlink")
    else
      reject_path!(path, "unsupported Git index file mode") unless REGULAR_FILE_MODES.include?(entry.fetch(:mode))
    end

    safe_repository_path!(path)
  end

  def safe_repository_path!(path)
    pathname = Pathname.new(path)
    normalized = pathname.cleanpath.to_s
    safe = !path.empty? && !path.include?("\0") && !pathname.absolute? &&
      normalized == path && normalized != ".." && !normalized.start_with?("../")
    reject_path!(path, "path escapes candidate root") unless safe

    path
  end

  def materialize_blob!(repository_root, candidate_root, entry)
    path = entry.fetch(:path)
    destination = File.expand_path(path, candidate_root.b)
    reject_path!(path, "path escapes candidate root") unless destination.start_with?("#{candidate_root}/".b)

    FileUtils.mkdir_p(File.dirname(destination))
    resolved_parent = File.realpath(File.dirname(destination))
    reject_path!(path, "path escapes candidate root") unless resolved_parent.start_with?("#{candidate_root}/") || resolved_parent == candidate_root

    contents, _stderr, status = Open3.capture3(
      "git", "cat-file", "blob", entry.fetch(:oid),
      chdir: repository_root,
      binmode: true
    )
    reject_path!(path, "tracked blob unavailable") unless status.success?

    permissions = entry.fetch(:mode) == "100755" ? 0o755 : 0o644
    File.open(destination, File::WRONLY | File::CREAT | File::EXCL, permissions) do |file|
      file.binmode
      file.write(contents)
    end
  end

  def reject_path!(path, rule)
    sanitized_path = path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace).dump
    raise PolicyError, "Tracked candidate preparation failed: #{sanitized_path}: #{rule}"
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby #{File.basename(__FILE__)} OUTPUT_DIRECTORY" unless ARGV.length == 1

  repository_root, _error, status = Open3.capture3("git", "rev-parse", "--show-toplevel")
  abort "Unable to resolve repository root." unless status.success?

  begin
    count = TrackedPublicCandidate.prepare!(
      repository_root: repository_root.strip,
      output_root: ARGV.fetch(0)
    )
    puts "Prepared exact tracked public candidate with #{count} regular files."
  rescue TrackedPublicCandidate::PolicyError, ArgumentError => error
    abort error.message
  end
end
