# Release

After the release-prep pull request has been reviewed and merged into `main`, a
maintainer authorized to run release CI opens **Actions → Release**, selects
`main`, and leaves `validation_only` off. The trusted GitHub Actions release
identity is the only ruleset bypass allowed to create `v*` tags. Developers and
branches cannot create them; tag update, deletion, force-update, and retargeting
remain prohibited. The workflow first fails fast unless the committed version is
strict SemVer, newer than the latest valid release tag, has finalized changelog
and localized What’s New entries, and has neither a tag nor GitHub Release.

The workflow captures one immutable source SHA, validates it, creates an
annotated `vMAJOR.MINOR.PATCH` tag directly at that SHA, verifies its direct
commit target and remote peeled commit, creates the GitHub Release, and then
dispatches the private control plane. A green result means the GitHub Release
   exists and the private control plane completed its exact build, repository-owned
   metadata, and screenshot preparation stages. Its redacted provider summary records
   whether the build reached readiness or remains processing. It does not submit the
   app for review or publish it on the App Store.

The run checks exact-SHA GitHub Actions evidence before any release mutation,
then dispatches the dedicated private control plane and waits for its exact run ID.
A failed or ambiguous upload must be verified
in App Store Connect before any manual recovery. Never rerun a normal release to
retry an uncertain upload. Lower-level Validation, Create GitHub Release, and
private workflows are recovery/diagnostic tools, not normal release steps.

## Safe pre-production check

Selecting `validation_only` runs the same fail-fast preflight and validation/check
evidence stages without creating a tag, GitHub Release, or dispatching the private
workflow. If a run is interrupted after tag creation but before GitHub Release
creation, rerun **Release** from `main`: it verifies that the existing tag is
annotated, directly targets the captured SHA, and peels remotely to that SHA, then
creates only the missing GitHub Release. Any conflicting, lightweight, nested, or
ambiguous tag stops for maintainer review; never move, replace, force-update, or
delete it. A real App Store Connect upload is a separate maintainer-authorized
production step.

## Handoff configuration

The dedicated GitHub App must be installed only on the private release repository,
with `Actions: write` and unavoidable metadata read, and no other repository
permissions. Set `RELEASE_APP_ID`, `RELEASE_APP_INSTALLATION_ID`, and
`RELEASE_APP_ACTOR` as variables and `RELEASE_APP_PRIVATE_KEY` as a secret only
in this repository's `release-orchestration` Environment. Its deployment branch
policy must allow exactly `main`, with no wait timer or reviewers. Configure the
same expected `RELEASE_APP_ACTOR` as a private `private-release` environment
variable. Rotate and revoke the App key on the maintainer's credential schedule.
Signing, keychain, and App Store Connect secrets remain solely private.

The App installation token is restricted to the private repository and
`Actions: write`, and is refreshed while waiting for the exact returned
`workflow_run_id`. A token cannot dispatch any other private mutation workflow:
the private repository permits only its reviewed release-control dispatch, which
verifies the App actor, the initiating public run and successful public prerequisites,
then independently rechecks public tag/SHA lineage and required check-runs.
