# frozen_string_literal: true

module AppStoreConnectScreenshotUploadGuard
  POLL_INTERVAL_SECONDS = 15
  CONSISTENCY_TIMEOUT_SECONDS = 120

  class ConsistencyTimeoutError < StandardError; end
  class ProcessingError < StandardError; end

  class ConsistencyWaiter
    def initialize(
      poll_interval: POLL_INTERVAL_SECONDS,
      timeout: CONSISTENCY_TIMEOUT_SECONDS,
      sleeper: ->(seconds) { sleep(seconds) },
      clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    )
      @poll_interval = poll_interval
      @timeout = timeout
      @sleeper = sleeper
      @clock = clock
    end

    def wait
      started_at = @clock.call

      loop do
        return if yield

        elapsed = @clock.call - started_at
        break if elapsed >= @timeout

        @sleeper.call([@poll_interval, @timeout - elapsed].min)
      end

      raise ConsistencyTimeoutError,
            "App Store Connect did not confirm every screenshot within #{@timeout} seconds. " \
            "No screenshots were retried to avoid duplicates; rerun the publish_app_store_connect stage safely."
    end
  end

  module UploadRetryGuard
    EXPECTED_RETRY_UPLOAD_PARAMETERS = [
      [:req, :iterator],
      [:req, :states],
      [:req, :number_of_screenshots],
      [:req, :tries],
      [:req, :timeout_seconds],
      [:req, :localizations],
      [:req, :screenshots_per_language]
    ].freeze

    def retry_upload_screenshots_if_needed(
      iterator,
      states,
      _number_of_screenshots,
      _tries,
      _timeout_seconds,
      _localizations,
      screenshots_per_language
    )
      return if screenshots_per_language.empty?

      fail_for_processing_errors!(iterator, states)

      waiter = consistency_waiter
      waiter.wait do
        consistent = screenshots_consistent?(iterator, screenshots_per_language)
        fastlane_ui.message(
          consistent ?
            "App Store Connect confirmed every uploaded screenshot." :
            "Waiting #{POLL_INTERVAL_SECONDS} seconds for App Store Connect screenshot consistency; " \
            "no files will be re-uploaded."
        )
        consistent
      end
    rescue ConsistencyTimeoutError, ProcessingError => error
      fastlane_ui.user_error!(error.message)
    end

    private

    def fastlane_ui
      FastlaneCore::UI
    end

    def consistency_waiter
      ConsistencyWaiter.new
    end

    def screenshots_consistent?(iterator, screenshots_per_language)
      remote_screenshots = iterator.each_app_screenshot.map { |_, _, screenshot| screenshot }
      fail_for_remote_processing_errors!(remote_screenshots)

      remote_checksums = remote_screenshots
                         .select(&:complete?)
                         .map(&:source_file_checksum)
                         .compact
                         .to_h { |checksum| [checksum, true] }

      local_checksums = iterator.each_local_screenshot(screenshots_per_language)
                                .map { |_, _, screenshot| Deliver::UploadScreenshots.calculate_checksum(screenshot.path) }

      local_checksums.all? { |checksum| remote_checksums[checksum] }
    end

    def fail_for_processing_errors!(iterator, states)
      return unless states.fetch("FAILED", 0).positive?

      errors = iterator.each_app_screenshot
                       .map { |_, _, screenshot| screenshot }
                       .select(&:error?)
                       .flat_map(&:error_messages)
      details = errors.empty? ? "App Store Connect reported a failed screenshot." : errors.join(", ")
      raise ProcessingError, "#{details} No screenshots were retried to avoid duplicates."
    end

    def fail_for_remote_processing_errors!(remote_screenshots)
      failed = remote_screenshots.select(&:error?)
      return if failed.empty?

      details = failed.flat_map(&:error_messages)
      message = details.empty? ? "App Store Connect reported a failed screenshot." : details.join(", ")
      raise ProcessingError, "#{message} No screenshots were retried to avoid duplicates."
    end
  end

  class << self
    def install!
      return if @installed

      require "deliver/upload_screenshots" unless defined?(Deliver::UploadScreenshots)
      verify_fastlane_compatibility!
      Deliver::UploadScreenshots.prepend(UploadRetryGuard)
      @installed = true
    end

    def verify_fastlane_compatibility!
      parameters = Deliver::UploadScreenshots.instance_method(:retry_upload_screenshots_if_needed).parameters
      return true if parameters == UploadRetryGuard::EXPECTED_RETRY_UPLOAD_PARAMETERS

      raise "Unsupported fastlane Deliver::UploadScreenshots#retry_upload_screenshots_if_needed signature: " \
            "expected #{UploadRetryGuard::EXPECTED_RETRY_UPLOAD_PARAMETERS.inspect}, got #{parameters.inspect}. " \
            "Update the screenshot upload guard before upgrading fastlane."
    end
  end
end
