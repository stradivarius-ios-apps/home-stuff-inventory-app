#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require_relative "prepare_tracked_public_candidate"

class TrackedPublicCandidateTest < Minitest::Test
  def test_copies_ordinary_tracked_files_from_index_blobs
    with_repository do |root, candidate|
      write(root, "Sources/Feature.swift", "struct Feature {}\n")
      git(root, "add", "Sources/Feature.swift")

      assert_equal 1, prepare(root, candidate)
      assert_equal "struct Feature {}\n", File.binread(File.join(candidate, "Sources/Feature.swift"))
    end
  end

  def test_export_ignore_cannot_remove_tracked_file
    with_repository do |root, candidate|
      write(root, ".gitattributes", "tracked.txt export-ignore\n")
      write(root, "tracked.txt", "scanned\n")
      git(root, "add", ".gitattributes", "tracked.txt")

      prepare(root, candidate)
      assert_equal "scanned\n", File.binread(File.join(candidate, "tracked.txt"))
    end
  end

  def test_ignored_untracked_files_are_not_copied
    with_repository do |root, candidate|
      write(root, ".gitignore", "ignored.txt\n")
      write(root, "tracked.txt", "tracked\n")
      write(root, "ignored.txt", "ignored\n")
      git(root, "add", ".gitignore", "tracked.txt")

      prepare(root, candidate)
      assert File.file?(File.join(candidate, "tracked.txt"))
      refute File.exist?(File.join(candidate, "ignored.txt"))
    end
  end

  def test_handles_spaces_unicode_tabs_and_newlines_in_filenames
    with_repository do |root, candidate|
      paths = ["files/with space.txt", "files/Україна.txt", "files/with\ttab.txt", "files/with\nnewline.txt"]
      paths.each { |path| write(root, path, "present\n") }
      git(root, "add", "--", *paths)

      assert_equal paths.length, prepare(root, candidate)
      paths.each { |path| assert_equal "present\n", File.binread(File.join(candidate, path)) }
    end
  end

  def test_rejects_symbolic_links_without_following_them
    with_repository do |root, candidate|
      write(root, "target.txt", "private target contents\n")
      File.symlink("target.txt", File.join(root, "link.txt"))
      git(root, "add", "link.txt")

      error = assert_raises(TrackedPublicCandidate::PolicyError) { prepare(root, candidate) }
      assert_includes error.message, "link.txt"
      assert_includes error.message, "symbolic link"
      refute_includes error.message, "private target contents"
      refute File.exist?(File.join(candidate, "link.txt"))
    end
  end

  def test_rejects_gitlinks_without_printing_external_configuration
    with_repository do |root, candidate|
      write(root, "ordinary.txt", "ordinary\n")
      git(root, "add", "ordinary.txt")
      git(root, "commit", "-m", "fixture")
      commit = git(root, "rev-parse", "HEAD").strip
      git(root, "update-index", "--add", "--cacheinfo", "160000", commit, "vendor/module")
      external_marker = "external-location-never-print"
      write(root, ".gitmodules", external_marker)

      error = assert_raises(TrackedPublicCandidate::PolicyError) { prepare(root, candidate) }
      assert_includes error.message, "vendor/module"
      assert_includes error.message, "Git submodule gitlink"
      refute_includes error.message, external_marker
      refute File.exist?(File.join(candidate, "vendor/module"))
    end
  end

  def test_rejects_destination_paths_outside_candidate_root
    error = assert_raises(TrackedPublicCandidate::PolicyError) do
      TrackedPublicCandidate.safe_repository_path!("../escape.txt")
    end

    assert_includes error.message, "path escapes candidate root"
  end

  def test_materializes_staged_blob_instead_of_modified_working_tree_contents
    with_repository do |root, candidate|
      write(root, "tracked.txt", "staged\n")
      git(root, "add", "tracked.txt")
      write(root, "tracked.txt", "working tree replacement\n")

      prepare(root, candidate)
      assert_equal "staged\n", File.binread(File.join(candidate, "tracked.txt"))
    end
  end

  private

  def with_repository
    Dir.mktmpdir("tracked-public-candidate") do |workspace|
      root = File.join(workspace, "repository")
      candidate = File.join(workspace, "candidate")
      FileUtils.mkdir_p(root)
      git(root, "init", "--quiet")
      git(root, "config", "user.name", "Fixture Author")
      git(root, "config", "user.email", "fixture@example.invalid")
      yield root, candidate
    end
  end

  def prepare(root, candidate)
    TrackedPublicCandidate.prepare!(repository_root: root, output_root: candidate)
  end

  def write(root, path, contents)
    absolute_path = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(absolute_path))
    File.binwrite(absolute_path, contents)
  end

  def git(root, *arguments)
    output, error, status = Open3.capture3("git", *arguments, chdir: root)
    raise "Git command failed: git #{arguments.first}: #{error}" unless status.success?

    output
  end
end
