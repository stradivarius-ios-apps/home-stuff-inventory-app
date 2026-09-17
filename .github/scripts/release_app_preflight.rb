#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "openssl"
require_relative "release_private_handoff"

module ReleaseAppPreflight
  REPOSITORY = ReleasePrivateHandoff::REPOSITORY
  WORKFLOW = ReleasePrivateHandoff::WORKFLOW
  PERMISSIONS = { "actions" => "write", "metadata" => "read" }.freeze

  module_function

  def require_configuration!(app_id:, installation_id:, actor:, private_key:)
    raise "App ID is missing or malformed." unless app_id.match?(/\A[1-9]\d*\z/)
    raise "Installation ID is missing or malformed." unless installation_id.match?(/\A[1-9]\d*\z/)
    raise "App actor is missing or malformed." unless actor.match?(/\A[a-z0-9-]+\[bot\]\z/)
    raise "App private key is missing." if private_key.empty?
  end

  def app_jwt!(app_id:, private_key:)
    now = Time.now.to_i
    payload = [
      { alg: "RS256", typ: "JWT" },
      { iat: now - 60, exp: now + 540, iss: app_id }
    ].map { |part| [JSON.generate(part)].pack("m0").tr("+/", "-_").delete("=") }.join(".")
    signature = OpenSSL::PKey::RSA.new(private_key).sign(OpenSSL::Digest::SHA256.new, payload)
    "#{payload}.#{[signature].pack('m0').tr('+/', '-_').delete('=')}"
  end

  def validate_installation!(installation, app_id:, installation_id:, actor:)
    raise "Wrong App installation identity." unless
      installation.fetch("id") == installation_id.to_i &&
      installation.fetch("app_id") == app_id.to_i &&
      actor == "#{installation.fetch('app_slug')}[bot]"
    raise "Installation has an unexpected owner or scope." unless
      installation.fetch("account").fetch("login") == "stradivarius-ios-apps" &&
      installation.fetch("target_type") == "Organization" &&
      installation.fetch("repository_selection") == "selected" &&
      installation.fetch("suspended_at").nil?
    raise "Installation permissions exceed the reviewed handoff." unless installation.fetch("permissions") == PERMISSIONS
  end

  def validate_repositories!(response)
    names = response.fetch("repositories").map { |repo| repo.fetch("full_name") }
    raise "Installation token has unexpected repository reach." unless
      response.fetch("total_count") == 1 && names == [REPOSITORY]
  end

  def run!(app_id:, installation_id:, actor:, private_key:,
    api: ReleasePrivateHandoff.method(:request!), mint: ReleasePrivateHandoff.method(:installation_token!))
    require_configuration!(app_id: app_id, installation_id: installation_id, actor: actor, private_key: private_key)
    jwt = app_jwt!(app_id: app_id, private_key: private_key)
    installation = api.call(:get, "/app/installations/#{installation_id}", token: jwt)
    validate_installation!(installation, app_id: app_id, installation_id: installation_id, actor: actor)

    token = mint.call(app_id: app_id, installation_id: installation_id, private_key: private_key)
    repositories = api.call(:get, "/installation/repositories?per_page=100", token: token)
    validate_repositories!(repositories)
    workflow = api.call(:get, "/repos/#{REPOSITORY}/actions/workflows/#{WORKFLOW}", token: token)
    raise "Private release workflow is not visible to the installation token." unless
      workflow.fetch("id") == ReleasePrivateHandoff::WORKFLOW_ID

    puts "Release App bridge preflight passed: exact private repository, Actions write, Metadata read."
    true
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    ReleaseAppPreflight.run!(
      app_id: ENV.fetch("RELEASE_APP_ID"),
      installation_id: ENV.fetch("RELEASE_APP_INSTALLATION_ID"),
      actor: ENV.fetch("RELEASE_APP_ACTOR"),
      private_key: ENV.fetch("RELEASE_APP_PRIVATE_KEY")
    )
  rescue StandardError => error
    warn "Release App bridge preflight failed (#{error.class})."
    exit 1
  end
end
