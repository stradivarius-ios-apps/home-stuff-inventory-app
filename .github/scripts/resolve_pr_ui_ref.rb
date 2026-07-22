#!/usr/bin/env ruby
# frozen_string_literal: true

module PRUIRef
  module_function

  SHA_PATTERN = /\A[0-9a-fA-F]{40}\z/
  FULL_REF_PATTERN = %r{\Arefs/(?:heads|tags)/[A-Za-z0-9._/-]+\z}
  PULL_REF_PATTERN = %r{\Arefs/pull/([1-9][0-9]*)/head\z}
  BARE_REF_PATTERN = %r{\A[A-Za-z0-9][A-Za-z0-9._/-]*\z}

  def resolve(input)
    value = input.to_s.strip
    raise ArgumentError, "A pull request number, branch, tag, or full commit SHA is required." if value.empty?

    return "refs/pull/#{value}/head" if value.match?(/\A[1-9][0-9]*\z/)
    return value.downcase if value.match?(SHA_PATTERN)
    return value if value.match?(PULL_REF_PATTERN) && safe_ref?(value)
    return value if value.match?(FULL_REF_PATTERN) && safe_ref?(value)
    return value if value.match?(BARE_REF_PATTERN) && safe_ref?(value)

    raise ArgumentError, "Unsupported or unsafe pull request/ref value: #{value.inspect}"
  end

  def safe_ref?(value)
    !value.include?("..") &&
      !value.include?("@{") &&
      !value.include?("//") &&
      !value.end_with?("/", ".", ".lock") &&
      value.split("/").none? { |part| part.empty? || part.start_with?(".") }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    puts PRUIRef.resolve(ARGV.fetch(0, ""))
  rescue ArgumentError => error
    warn error.message
    exit 2
  end
end
