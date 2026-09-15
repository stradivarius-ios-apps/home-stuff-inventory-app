#!/usr/bin/env ruby
# frozen_string_literal: true

# Static release gate: iOS 26 behavior must remain available from 26.0, not a later point release.
module IOS26Compatibility
  module_function

  PROJECT_PATH = "HomeStuffInventoryApp.xcodeproj/project.pbxproj"
  REQUIRED_GUARDS = {
    "HomeStuffInventoryApp/Views/RootView.swift" => ["if #available(iOS 26.0, *)", "tabViewSearchActivation"],
    "HomeStuffInventoryApp/Views/Shared/InventoryGlassSurfaces.swift" => ["if #available(iOS 26.0, *)", ".glassEffect("]
  }.freeze

  def fail!(message)
    warn "iOS 26 compatibility gate failed: #{message}"
    exit 1
  end

  def point_release_after_26_0?(version)
    major, minor = version.split(".", 2).map(&:to_i)
    major == 26 && minor.to_i.positive?
  end

  def validate_deployment_targets!(root)
    project = File.read(File.join(root, PROJECT_PATH))
    targets = project.scan(/IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+);/).flatten
    fail!("#{PROJECT_PATH} has no explicit IPHONEOS_DEPLOYMENT_TARGET") if targets.empty?

    targets.each do |target|
      fail!("deployment target #{target} is later than iOS 26.0") if Gem::Version.new(target) > Gem::Version.new("26.0")
    end
  end

  def validate_availability_checks!(root)
    Dir.glob(File.join(root, "HomeStuffInventoryApp/**/*.swift")).sort.each do |path|
      File.read(path).scan(/(?:#|@)available\(iOS\s+(\d+(?:\.\d+)?)/).flatten.each do |version|
        next unless point_release_after_26_0?(version)

        fail!("#{path.delete_prefix("#{root}/")} requires iOS #{version}; use a 26.0 API or add a runtime fallback")
      end
    end
  end

  def validate_known_native_guards!(root)
    REQUIRED_GUARDS.each do |relative_path, markers|
      source = File.read(File.join(root, relative_path))
      markers.each do |marker|
        fail!("#{relative_path} is missing required iOS 26.0 guard evidence: #{marker}") unless source.include?(marker)
      end
    end
  end

  def validate!(root = Dir.pwd)
    validate_deployment_targets!(root)
    validate_availability_checks!(root)
    validate_known_native_guards!(root)
    puts "iOS 26.0 static compatibility gate passed."
  end
end

IOS26Compatibility.validate! if __FILE__ == $PROGRAM_NAME
