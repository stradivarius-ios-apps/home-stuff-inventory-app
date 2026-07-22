#!/usr/bin/env ruby
# frozen_string_literal: true

module ReleaseScreenshotRef
  module_function

  def resolve(input)
    value = input.to_s.strip
    raise ArgumentError, "An explicit release branch, tag, or full commit SHA is required." if value.empty?
    return value.downcase if value.match?(/\A[0-9a-fA-F]{40}\z/)

    allowed = value.match?(%r{\A(?:refs/(?:heads|tags)/)?[A-Za-z0-9][A-Za-z0-9._/-]*\z})
    safe = !value.include?("..") && !value.include?("@{") && !value.include?("//") &&
      !value.end_with?("/", ".", ".lock") && value.split("/").none? { |part| part.start_with?(".") }
    return value if allowed && safe

    raise ArgumentError, "Unsupported or unsafe release ref: #{value.inspect}"
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
