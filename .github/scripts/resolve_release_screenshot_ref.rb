#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "support/release_contract"

module ReleaseScreenshotRef
  module_function

  def resolve(input)
    value = input.to_s.strip
    raise ArgumentError, "An exact release tag or full commit SHA is required." if value.empty?
    return ReleaseContract.strict_sha!(value, label: "release_ref") if value.match?(ReleaseContract::SHA)

    tag = value.delete_prefix("refs/tags/")
    version = ReleaseContract.tag_version(tag)
    return ReleaseContract.tag_for(version) if version

    raise ArgumentError, "release_ref must be a strict vMAJOR.MINOR.PATCH tag or exact 40-character SHA."
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    puts ReleaseScreenshotRef.resolve(ARGV.fetch(0, ""))
  rescue ArgumentError => error
    warn error.message
    exit 2
  end
end
