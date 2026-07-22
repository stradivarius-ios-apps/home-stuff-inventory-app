#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "open3"
require "pathname"
require "set"

module PublicSurfaceValidation
  MAX_TRACKED_FILE_BYTES = 5 * 1024 * 1024
  SYNTHETIC_DATA_NAMESPACE = "docs/data/portability-recovery-v1"

  APPROVED_SYNTHETIC_DATA_SHA256 = {
    "docs/data/portability-recovery-v1/empty-readable-export-v1.json" =>
      "7e438619c8bdd5469981ea2221db9c0df398451a9278893bc2624b93c3eb0e3f",
    "docs/data/portability-recovery-v1/legacy-compatible-backup-v0.json" =>
      "3c4dd57f5f36b99fc8ee41a4078ce0d8f14de1092abe3abd56cbe9098d03d9f0",
    "docs/data/portability-recovery-v1/malformed-truncated-backup.json" =>
      "2f6a6440fd4dbc38079129c16ec3db7b7ca03d5502b3e2cc65e3e09b7058f891",
    "docs/data/portability-recovery-v1/ordinary-complete-backup-v1.json" =>
      "a0af440f22575a2ed11caa4b3b7da4e1452b4d7924689462e0adc66e6f9b78d1",
    "docs/data/portability-recovery-v1/unicode-readable-export-v1.json" =>
      "0ebefc5cb556d05ba21fd7f0d80d7a9215da634e1cf785908c3a97b44c5a7350",
    "docs/data/portability-recovery-v1/unsupported-newer-backup-v2.json" =>
      "f3ec18543ffb7f20db2324f4048065a741c8a17a8654b7260f7c9765441f7e9b"
  }.freeze
  APPROVED_SYNTHETIC_DATA_FILES = APPROVED_SYNTHETIC_DATA_SHA256.keys.to_set.freeze

  APPROVED_BINARY_ASSET_ROOTS = Set.new([
    "HomeStuffInventoryApp/Resources/Assets.xcassets/"
  ]).freeze
  APPROVED_IMAGE_EXTENSIONS = Set.new(%w[.png .jpg .jpeg]).freeze

  DATA_EXTENSIONS = /\.(?:json|csv|tsv|plist|xml|sqlite|sqlite3|db)(?:\.(?:zip|gz))?\z/i
  SUSPICIOUS_DATA_SEGMENTS = Set.new(%w[
    inventory
    backup
    backups
    export
    exports
    household
    user-data
    userdata
    personal-data
  ]).freeze

  PATH_RULES = {
    "private audit evidence directory" => %r{\A\.audit-private(?:/|\z)}i,
    "Git submodule configuration" => %r{\A\.gitmodules\z}i,
    "pull-request-controlled Gitleaks configuration" => %r{\A\.gitleaks\.toml\z}i,
    "pull-request-controlled Gitleaks ignore file" => %r{\A\.gitleaksignore\z}i,
    "signing material" => /(?:\.p8|\.pem|\.key|\.p12|\.cer|\.mobileprovision)\z/i,
    "archive-suffixed Apple artifact" => /\.(?:xcresult|dSYM|xcarchive|ipa|mobileprovision)\.(?:zip|tar|tgz|gz|7z|rar)\z/i,
    "Apple build or diagnostic artifact" => /(?:\.ipa|\.xcarchive|\.dSYM|\.xcresult)(?:\z|\/)/i,
    "generic archive" => /\.(?:zip|tar|tgz|gz|7z|rar)\z/i,
    "environment secret file" => %r{(?:\A|/)\.env(?:\..*)?\z}i,
    "runner state or log" => %r{(?:\.log\z|(?:\A|/)(?:_work|_diag|actions-runner)(?:/|\z))}i,
    "temporary evidence directory" => %r{\ATemporaryEvidence(?:/|\z)}i,
    "retired multi-repository secret helper" => %r{\Ascripts/ci/set-app-store-connect-repo-secrets\.sh\z}i
  }.freeze

  CONTENT_RULES = {
    "absolute macOS home path" => %r{/Users/[A-Za-z0-9._-]+/},
    "absolute Linux home path" => %r{/home/[A-Za-z0-9._-]+/},
    "App Store Connect key filename" => /AuthKey_[A-Z0-9]{10}\.p8/,
    "Git LFS pointer" => /\Aversion https:\/\/git-lfs\.github\.com\/spec\/v1(?:\r?\n|\z)/
  }.freeze

  module_function

  def violations(root:, tracked_files:)
    input_paths = tracked_files.map(&:to_s)
    normalized_tracked_paths = input_paths.filter_map { |path| normalized_repository_path(path) }.to_set
    failures = missing_approved_fixture_violations(normalized_tracked_paths)

    failures + input_paths.flat_map do |input_path|
      path = input_path.to_s
      normalized_path = normalized_repository_path(path)
      failures = path_violations(path, normalized_path: normalized_path)
      failures + (normalized_path ? content_violations(root, normalized_path) : [])
    end
  end

  def missing_approved_fixture_violations(normalized_tracked_paths)
    (APPROVED_SYNTHETIC_DATA_FILES - normalized_tracked_paths).sort.map do |path|
      { path: path, rule: "approved synthetic fixture content mismatch" }
    end
  end

  def tracked_candidate_files(repository_root)
    tracked_output, error, status = Open3.capture3(
      "git", "ls-files", "-z", "--cached", "--others", "--exclude-standard",
      chdir: repository_root
    )
    raise "Unable to enumerate tracked public surface: #{error}" unless status.success?

    tracked_output.split("\0").reject(&:empty?)
  end

  def validate!(root:, tracked_files:)
    failures = violations(root: root, tracked_files: tracked_files)
    return true if failures.empty?

    details = failures.map { |failure| "- #{failure.fetch(:path)}: #{failure.fetch(:rule)}" }.join("\n")
    raise "Tracked public-surface validation failed:\n#{details}"
  end

  def normalized_repository_path(path)
    return nil if path.empty? || path.include?("\0")

    pathname = Pathname.new(path)
    return nil if pathname.absolute?

    normalized = pathname.cleanpath.to_s
    return nil if normalized == ".." || normalized.start_with?("../") || normalized != path

    normalized
  end

  def path_violations(path, normalized_path: normalized_repository_path(path))
    return [{ path: path, rule: "non-normalized repository path" }] unless normalized_path

    failures = PATH_RULES.filter_map do |rule, pattern|
      { path: normalized_path, rule: rule } if normalized_path.match?(pattern)
    end

    if application_generated_backup_path?(normalized_path)
      failures << { path: normalized_path, rule: "application-generated inventory backup" }
    end

    if unapproved_synthetic_data_path?(normalized_path)
      failures << { path: normalized_path, rule: "unapproved synthetic data fixture" }
    elsif suspicious_data_path?(normalized_path) && !APPROVED_SYNTHETIC_DATA_FILES.include?(normalized_path)
      failures << { path: normalized_path, rule: "inventory data outside approved synthetic fixtures" }
    end
    failures
  end

  def application_generated_backup_path?(path)
    File.basename(path).match?(/\Ahome-stuff-inventory-backup-/i)
  end

  def unapproved_synthetic_data_path?(path)
    path.match?(DATA_EXTENSIONS) &&
      path.downcase.start_with?(SYNTHETIC_DATA_NAMESPACE.downcase) &&
      !APPROVED_SYNTHETIC_DATA_FILES.include?(path)
  end

  def suspicious_data_path?(path)
    return false unless path.match?(DATA_EXTENSIONS)

    segments = path.downcase.split("/")
    filename = segments.pop
    stem = filename.sub(DATA_EXTENSIONS, "")
    filename_tokens = stem.split(/[^a-z0-9]+/)

    segments.any? { |segment| SUSPICIOUS_DATA_SEGMENTS.include?(segment) } ||
      filename_tokens.any? { |token| SUSPICIOUS_DATA_SEGMENTS.include?(token) }
  end

  def content_violations(root, path)
    absolute_path = File.expand_path(path, root)
    repository_root = File.expand_path(root)
    return [{ path: path, rule: "path escapes repository root" }] unless absolute_path.start_with?("#{repository_root}/")
    return [{ path: path, rule: "symbolic link" }] if File.symlink?(absolute_path)
    if APPROVED_SYNTHETIC_DATA_FILES.include?(path) && !File.file?(absolute_path)
      return [{ path: path, rule: "approved synthetic fixture content mismatch" }]
    end
    return [] unless File.file?(absolute_path)

    size = File.size(absolute_path)
    return [{ path: path, rule: "tracked file exceeds 5 MiB review limit" }] if size > MAX_TRACKED_FILE_BYTES

    contents = File.binread(absolute_path)
    if APPROVED_SYNTHETIC_DATA_FILES.include?(path) &&
       Digest::SHA256.hexdigest(contents) != APPROVED_SYNTHETIC_DATA_SHA256.fetch(path)
      return [{ path: path, rule: "approved synthetic fixture content mismatch" }]
    end

    if binary_contents?(contents)
      return [] if approved_binary_asset?(path, contents)
      return [{ path: path, rule: "unapproved binary file" }]
    end

    text = contents.dup.force_encoding(Encoding::UTF_8)
    CONTENT_RULES.filter_map do |rule, pattern|
      { path: path, rule: rule } if text.match?(pattern)
    end
  end

  def binary_contents?(contents)
    contents.include?("\0") || !contents.dup.force_encoding(Encoding::UTF_8).valid_encoding?
  end

  def approved_binary_asset?(path, contents)
    extension = File.extname(path).downcase
    return false unless APPROVED_IMAGE_EXTENSIONS.include?(extension)
    return false unless APPROVED_BINARY_ASSET_ROOTS.any? { |root| path.start_with?(root) }

    case extension
    when ".png"
      contents.start_with?("\x89PNG\r\n\x1A\n".b)
    when ".jpg", ".jpeg"
      contents.start_with?("\xFF\xD8\xFF".b)
    else
      false
    end
  end
end

if $PROGRAM_NAME == __FILE__
  repository_root, error, status = Open3.capture3("git", "rev-parse", "--show-toplevel")
  abort error unless status.success?
  repository_root = repository_root.strip

  PublicSurfaceValidation.validate!(
    root: repository_root,
    tracked_files: PublicSurfaceValidation.tracked_candidate_files(repository_root)
  )
  puts "Tracked public surface passed high-risk path and content checks."
end
