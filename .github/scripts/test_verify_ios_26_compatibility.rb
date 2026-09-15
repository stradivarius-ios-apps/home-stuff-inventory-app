#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require "open3"

class IOS26CompatibilityTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, ".github/scripts/verify_ios_26_compatibility.rb")

  def test_repository_passes_the_26_0_static_gate
    output, status = Open3.capture2e("ruby", SCRIPT, chdir: ROOT)

    assert status.success?, output
    assert_includes output, "iOS 26.0 static compatibility gate passed"
  end

  def test_rejects_a_later_26_x_deployment_target
    with_repository do |root|
      File.write(File.join(root, "HomeStuffInventoryApp.xcodeproj/project.pbxproj"), "IPHONEOS_DEPLOYMENT_TARGET = 26.5;\n")
      output, status = Open3.capture2e("ruby", SCRIPT, chdir: root)

      refute status.success?
      assert_includes output, "deployment target 26.5 is later than iOS 26.0"
    end
  end

  def test_rejects_a_later_26_x_availability_check
    with_repository do |root|
      source = File.join(root, "HomeStuffInventoryApp/Views/Extra.swift")
      FileUtils.mkdir_p(File.dirname(source))
      File.write(source, "if #available(iOS 26.5, *) {}\n")
      output, status = Open3.capture2e("ruby", SCRIPT, chdir: root)

      refute status.success?
      assert_includes output, "requires iOS 26.5"
    end
  end

  private

  def with_repository
    Dir.mktmpdir do |root|
      project = File.join(root, "HomeStuffInventoryApp.xcodeproj")
      views = File.join(root, "HomeStuffInventoryApp/Views/Shared")
      FileUtils.mkdir_p(project)
      FileUtils.mkdir_p(views)
      File.write(File.join(project, "project.pbxproj"), "IPHONEOS_DEPLOYMENT_TARGET = 17.0;\n")
      File.write(File.join(root, "HomeStuffInventoryApp/Views/RootView.swift"), "if #available(iOS 26.0, *) { tabViewSearchActivation(.searchTabSelection) }\n")
      File.write(File.join(views, "InventoryGlassSurfaces.swift"), "if #available(iOS 26.0, *) { content.glassEffect(.regular) }\n")
      yield root
    end
  end
end
