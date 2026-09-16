# Release

After the release-prep pull request has been reviewed and merged into `main`:

1. Open **Actions → Release** and select `main`.
2. Run the workflow with the default settings.
3. Wait for this single run to finish. A green result means the GitHub Release
   exists and the exact build was accepted for TestFlight processing. It does not
   submit the app for review or publish it on the App Store.

The run captures one immutable source SHA and its committed version, reuses the
ordinary validation jobs on that SHA, checks their exact-SHA GitHub Actions evidence,
creates the annotated tag/Release, then dispatches the dedicated private control
plane and waits for its exact run ID. A failed or ambiguous upload must be verified
in App Store Connect before any manual recovery. Never rerun a normal release to
retry an uncertain upload. Lower-level Validation, Create GitHub Release, and
private workflows are recovery/diagnostic tools, not normal release steps.

## Safe pre-production check

Selecting `validation_only` runs the committed identity and validation/check
evidence stages without creating a tag or dispatching the private workflow. Run
this once from `main` after workflow review to confirm the reusable job check-run
names and approved GitHub Actions app identity before enabling the first live
release. A real App Store Connect upload is a separate maintainer-authorized
production validation step.

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
