#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module ReleasePrivateHandoff
  REPOSITORY = "stradivarius-ios-apps/home-stuff-inventory"
  WORKFLOW = "private-public-release.yml"
  WORKFLOW_ID = 318196942
  SHA = /\A[0-9a-f]{40}\z/
  TAG = /\Av(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/
  POLL_SECONDS = 30
  TIMEOUT_SECONDS = 8_400

  module_function

  def require_identity!(sha:, tag:, run_id:)
    raise "Expected exact lowercase public SHA." unless SHA.match?(sha)
    raise "Expected exact release tag." unless TAG.match?(tag)
    raise "Expected numeric public workflow run ID." unless run_id.match?(/\A[1-9]\d*\z/)
  end

  def request!(method, path, token:, body: nil)
    uri = URI("https://api.github.com#{path}")
    request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
    request = request_class.new(uri)
    request["Accept"] = "application/vnd.github+json"
    request["X-GitHub-Api-Version"] = "2026-03-10"
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body) if body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.request(request)
    end
    raise "GitHub release handoff API returned HTTP #{response.code}." unless response.code.to_i == 200 || response.code.to_i == 201

    JSON.parse(response.body)
  end

  def installation_token!(app_id:, installation_id:, private_key:)
    now = Time.now.to_i
    jwt = [
      { alg: "RS256", typ: "JWT" },
      { iat: now - 60, exp: now + 540, iss: app_id }
    ].map { |part| [JSON.generate(part)].pack("m0").tr("+/", "-_").delete("=") }.join(".")
    signature = OpenSSL::PKey::RSA.new(private_key).sign(OpenSSL::Digest::SHA256.new, jwt)
    jwt = "#{jwt}.#{[signature].pack('m0').tr('+/','-_').delete('=')}"
    response = request!(:post, "/app/installations/#{installation_id}/access_tokens", token: jwt,
      body: { repositories: ["home-stuff-inventory"], permissions: { actions: "write" } })
    token = response.fetch("token")
    raise "Installation token response is invalid." if token.to_s.empty?
    token
  end

  def validate_dispatch!(response)
    id = response.fetch("workflow_run_id")
    raise "Dispatch did not return an exact workflow run ID." unless id.is_a?(Integer) && id.positive?
    expected = "https://api.github.com/repos/#{REPOSITORY}/actions/runs/#{id}"
    raise "Dispatch returned an unexpected run URL." unless response.fetch("run_url") == expected
    id
  end

  def validate_run!(run, id:, private_sha:, app_actor:)
    raise "Private run identity mismatch." unless run.fetch("id") == id && run.fetch("workflow_id") == WORKFLOW_ID
    raise "Private run was not dispatched on trusted main." unless run.fetch("event") == "workflow_dispatch" && run.fetch("head_branch") == "main" && run.fetch("head_sha") == private_sha
    raise "Private run actor mismatch." unless run.fetch("actor").fetch("login") == app_actor
    status = run.fetch("status")
    return :waiting unless status == "completed"
    raise "Private release failed or was cancelled: #{run.fetch('conclusion')}. Upload state requires maintainer verification before retry." unless run.fetch("conclusion") == "success"
    :success
  end

  def stage_status_from_jobs!(jobs)
    names = jobs.fetch("jobs").filter_map { |job| job["name"] if job["name"].to_s.start_with?("Release stage status / ") }
    raise "Private stage summary is missing or ambiguous." unless names.one?
    fields = names.first.delete_prefix("Release stage status / ").split(";").to_h { |field| field.split("=", 2) }
    allowed = { "archive" => %w[success failed not-run], "upload" => %w[success failed not-requested], "screenshots" => %w[success failed not-requested], "metadata" => %w[published already_correct recovered_partial failed not-requested], "readiness" => %w[ready_for_app_review pending_processing failed not-requested] }
    raise "Private stage summary is invalid." unless fields.keys.sort == allowed.keys.sort && fields.all? { |key, value| allowed.fetch(key).include?(value) }
    fields
  end

  def execute!(sha:, tag:, public_run_id:, app_id:, installation_id:, private_key:, app_actor:)
    require_identity!(sha: sha, tag: tag, run_id: public_run_id)
    raise "App actor must be a named bot." unless app_actor.match?(/\A[a-z0-9-]+\[bot\]\z/)
    raise "App identity is missing." unless app_id.match?(/\A[1-9]\d*\z/) && installation_id.match?(/\A[1-9]\d*\z/)

    token = installation_token!(app_id: app_id, installation_id: installation_id, private_key: private_key)
    response = request!(:post, "/repos/#{REPOSITORY}/actions/workflows/#{WORKFLOW}/dispatches", token: token,
      body: { ref: "main",
        inputs: {
          public_source_sha: sha, public_release_tag: tag, upload: "true",
          publish_metadata: "true", publish_screenshots: "true", verify_readiness: "true", public_run_id: public_run_id
        } })
    id = validate_dispatch!(response)
    File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |out| out.puts "private_run_id=#{id}" }
    puts "Private release dispatched; awaiting its exact returned run ID."

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    refreshed = started
    private_sha = nil
    loop do
      raise "Private release timed out; upload state requires maintainer verification before retry." if Process.clock_gettime(Process::CLOCK_MONOTONIC) - started > TIMEOUT_SECONDS
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) - refreshed > 2_700
        token = installation_token!(app_id: app_id, installation_id: installation_id, private_key: private_key)
        refreshed = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
      run = request!(:get, "/repos/#{REPOSITORY}/actions/runs/#{id}", token: token)
      private_sha ||= run.fetch("head_sha")
      raise "Private workflow SHA is invalid." unless SHA.match?(private_sha)
      if validate_run!(run, id: id, private_sha: private_sha, app_actor: app_actor) == :success
        jobs = request!(:get, "/repos/#{REPOSITORY}/actions/runs/#{id}/jobs?per_page=100", token: token)
        stages = stage_status_from_jobs!(jobs)
        File.open(ENV.fetch("GITHUB_OUTPUT"), "a") { |out| stages.each { |key, value| out.puts "private_#{key}=#{value}" } }
        return id
      end
      sleep POLL_SECONDS
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    ReleasePrivateHandoff.execute!(
      sha: ENV.fetch("PUBLIC_SOURCE_SHA"), tag: ENV.fetch("PUBLIC_RELEASE_TAG"), public_run_id: ENV.fetch("PUBLIC_RUN_ID"),
      app_id: ENV.fetch("RELEASE_APP_ID"), installation_id: ENV.fetch("RELEASE_APP_INSTALLATION_ID"),
      private_key: ENV.fetch("RELEASE_APP_PRIVATE_KEY"), app_actor: ENV.fetch("RELEASE_APP_ACTOR")
    )
  rescue StandardError => error
    warn "Private handoff failed: #{error.message}"
    exit 1
  end
end
