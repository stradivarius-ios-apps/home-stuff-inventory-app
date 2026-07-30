# GitHub-Hosted Public CI

Status: Canonical contract for ordinary CI in the public product repository.

## Hosted environment

Ordinary app validation and Full Test build/UI jobs use the reviewed Apple Silicon
`macos-26` GitHub-hosted runner. Screenshot jobs retain the standard
`macos-26-intel` runner for their existing capture contracts. Every macOS workflow selects
`/Applications/Xcode_26.6.app/Contents/Developer` with
`sudo xcode-select --switch` and then verifies both `xcodebuild -version` and
`xcode-select -p`. The reviewed toolchain contract is:

- Xcode 26.6, build `17F113`;
- iOS 26.5 Simulator runtime;
- iPhone 17 for build, test, coverage, Full Test Validation, and PR screenshots;
- iPhone 14 Plus for the existing 6.5-inch App Store screenshot contract.

`.github/scripts/configure_hosted_xcode.sh` selects the pinned toolchain, completes its
required first-launch setup, and fails instead of changing runner class when the selected
image no longer provides this contract. Update the runner image contract through review;
never add a self-hosted fallback.

The locked Fastlane smoke job runs on `ubuntu-latest` and provisions Ruby 4.0.5 and
Bundler 2.7.2 through the full-SHA-pinned `ruby/setup-ruby` action. Moving this
platform-independent load test away from constrained macOS capacity removes runner
queueing without changing the lockfile contract. The job deliberately performs a clean
locked install: measured bundle execution is short, so an additional cache is not
justified without before/after evidence. It does not depend on an image's default Ruby
or an assumed runner tool-cache path. Simulator creation uses the exact
`com.apple.CoreSimulator.SimRuntime.iOS-26-5` identifier rather than a display name.

The source references for this reviewed contract are GitHub's
[hosted-runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
and the [`macos-26` image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).

## Pull-request baseline

`Validation` uses `pull_request`, not `pull_request_target`. It runs for
same-repository and external-fork pull requests with read-only `GITHUB_TOKEN`
permissions and no repository or environment secrets. It also supports explicit manual
dispatch. It does not run again on a push to protected `main`: the required pull-request
check validates GitHub's merge ref, while the separate `Advanced CodeQL` workflow
performs pull-request, post-merge, and weekly security analysis. `PR UI Screenshots`
is manual-only so routine pull requests do not consume a separate macOS runner;
dispatch it with a pull-request number, branch, tag, or full commit SHA when visual
review is needed.

## CodeQL advanced setup

`.github/workflows/codeql.yml` preserves the existing `actions`, `python`, `ruby`, and
`swift` coverage and the remote-and-local source threat model on pull requests, every
`main` push, and the weekly schedule. Interpreted languages use CodeQL's no-build mode
on `ubuntu-latest`. Swift uses a reviewed manual Release build on `macos-26`: one unsigned
`iphoneos`/`arm64` target, `-Onone`, single-file compilation, and six fixed Swift driver
batches. It does not skip Swift based on changed paths.

The manual Swift build was selected from hosted measurements against Default Setup:

- eight Default Setup runs: 19:14–50:24, median 27:26;
- three identical single-file manual-build runs: 13:50–21:48, median 20:49;
- one whole-module comparison: 26:18.

This reduces the observed median Swift critical path by 6:37, or approximately 24%,
without reducing analyzed source coverage or changing Release compilation conditions.

A follow-up exact-SHA comparison on the standard three-core hosted runner measured three
default-batch jobs at 18:02–22:25 (median 21:36) and three six-batch jobs at 17:26–22:48
(median 18:25). The fixed six-batch configuration reduced the total median by 3:11 and
the build-step median by 3:08. Every valid run scanned the same 114 of 173 Swift files.

The repository variable `ADVANCED_CODEQL_ENABLED` is a deliberate transition and
rollback gate. Switch setup modes in this order so every protected `main` SHA remains
covered:

1. Merge the reviewed workflow while Default Setup remains enabled and the variable is
   absent or not `true`. GitHub rejects Advanced Setup workflow runs with
   `startup_failure` while Default Setup owns CodeQL; this expected staging result is
   not scan evidence.
2. Confirm Default Setup successfully analyzed the merge SHA.
3. Disable Default Setup, set `ADVANCED_CODEQL_ENABLED` to `true`, manually dispatch
   `Advanced CodeQL` on that same `main` SHA, and require all four language jobs to
   succeed.
4. Keep the variable enabled for future `main` pushes and weekly scans.

For rollback, first set the variable to `false`, enable Default Setup, and confirm its
analysis succeeds before removing the advanced workflow. Never leave both setup modes
inactive.

Validation remains path-aware:

- every run performs tracked-surface security checks, changed-file classification,
  workflow validation, metadata validation, and non-signing release-contract checks;
- CI-relevant changes run workflow/release-contract checks, the hosted app baseline,
  and the locked Ruby 4.0.5, Bundler 2.7.2, and Fastlane 2.237.0 smoke check;
- app-relevant changes build coverage-enabled test products once, run the complete
  `HomeStuffInventoryAppTests` target and the process-group-bounded PR UI smoke through
  `test-without-building` on one isolated simulator, and enforce the 90% owned-code
  coverage gate from that authoritative unit/localization result;
- Manual PR UI Screenshots captures synthetic repository-owned EN/UK light/dark fixtures
  when visual review is requested.

The stable `Code coverage` job is a lightweight check over the combined app job rather
than a second macOS build and test pass. The required `CI workflow validation` check is
the final read-only aggregator for every path-selected contract, Fastlane, app, and
coverage phase. A failed build, unit/localization suite, empty successful result,
coverage threshold, or UI smoke therefore fails the required PR check after available
diagnostics and simulator cleanup are retained. The app job summary reports external
runner queue, setup/simulator, build, unit/localization, UI, coverage, cleanup, and total
critical-path durations.

Full Test Validation is intentionally outside the pull-request baseline. Ordinary
commits and documentation changes do not run the full unit and UI matrix. The workflow
runs for protected version tags matching `v*`, explicit maintainer dispatch, or a
reusable release-workflow call. It builds once, runs the complete unit/localization
target, packages only the immutable test products, and fans the explicit 72-test UI
manifest into 18 Apple Silicon matrix shards. Each shard restores the same products,
runs four methods with `test-without-building`, and owns one ephemeral simulator on
its runner. This avoids the CoreSimulator accessibility-service contention observed
when two XCTest sessions shared one runner while keeping each shard independently
bounded with its own result bundle, log, status, diagnostics, and cleanup. A final
`Full Test Suite` aggregator remains the stable release-verification check.

`Classify changed files` is also the unconditional public boundary check: it validates
the tracked public surface, prepares the exact candidate, verifies the trusted Gitleaks
configuration, and scans that candidate. There is no separate `Public candidate
boundary` check in the clean public repository.

No timeout, unavailable runtime, large workload, or hosted failure may reroute to a
self-hosted runner. Public workflows must not mirror branches, copy source artifacts,
or push commits to the historical private repository.

## Stable checks and exact-SHA evidence

These workflow/job names are public contracts for branch protection and read-only
release verification:

| Workflow | Stable job/check name |
| --- | --- |
| Validation | Classify changed files |
| Validation | CI workflow validation |
| Validation | Locked Fastlane smoke test |
| Validation | Build and test |
| Validation | Code coverage |
| Advanced CodeQL | CodeQL (actions), CodeQL (python), CodeQL (ruby) |
| Advanced CodeQL | CodeQL (swift) |
| Full Test Validation | Full Test Suite |
| PR UI Screenshots | Capture PR UI screenshots |
| Release App Store Screenshots | Capture release App Store screenshots |

Each lane records or verifies the checked-out commit. For pull-request lanes,
`${{ github.sha }}` is the tested merge commit supplied by GitHub. Manually or
reusably dispatched exact-SHA lanes reject a checkout that resolves to a different
commit. Full Test Validation exposes `validated_commit`; release screenshots expose
`source_sha`. A private release verifier can read workflow/check results for this SHA
without write access and without receiving a source-tree artifact.

Full Test Validation runs automatically only when a protected release tag matching `v*` is pushed.
That event checks out only `${{ github.sha }}` and rejects any `source_ref` override;
manual and reusable calls retain their existing explicit-ref behavior. Before publication,
exercise this path in the clean staging repository and record public check metadata proving:

- the Full Test Validation check run `head_sha` equals the commit resolved by the release tag;
- the observed GitHub Actions app identity and app name are the expected first-party check producer;
- the stable check name is `Full Test Suite` and its conclusion is `success`.

Tag protection and the private verifier's required-check configuration remain provider
and SEC-PUB-03 responsibilities; this public workflow does not set either policy.

Release App Store Screenshots supports both manual and reusable dispatch. Both paths
require either a protected strict `vMAJOR.MINOR.PATCH` tag or an exact full commit SHA;
branch names and other mutable refs fail before checkout. The lane remains hosted,
read-only, non-signing, and secretless.

## Failure diagnostics and cleanup

Simulator jobs create uniquely named ephemeral devices, wait for boot completion, and
always shut down and delete them. `xcodebuild` exit status remains authoritative even
when output is captured. Ordinary Validation rejects successful zero-test unit and UI
results and reports its critical-path timing. Full Test Validation rejects duplicate UI
identifiers and successful zero-test results and reports unit/UI totals and timing in
the job summary.

Public artifacts are limited to synthetic screenshots, failure diagnostics already
owned by the repository, and the Full Test lane's compressed immutable `Build/Products`
payload. Matrix jobs consume that payload only to run `test-without-building`; it is
downloaded by immutable artifact ID through the Actions REST API so the lane remains
compatible with the organization's restricted action allowlist. It is retained for
one day, while diagnostics are retained for three days. Artifact names
use commit SHA or GitHub run identifiers, never free-form user input. Do not upload
the wider DerivedData tree, the source tree, signing metadata, credentials, private
host details, or household data.

## Private release boundary

Signing, archive export, App Store Connect credential use, and TestFlight deployment
are not ordinary public CI. They remain disabled or protected in the historical
private release control plane until its dedicated release-boundary work is complete.
The public repository never receives release credentials, and hosted public jobs never
invoke the private repository.

Run the repository contract suite after changing workflows:

```sh
ruby .github/scripts/run_public_automation_checks.rb
```

This public runner is the only automation suite invoked by `validation.yml`, including
the locked Fastlane smoke job. Its machine-readable ownership and check list live in
`.github/scripts/support/public_automation_contract.rb`. The owned hosted workflows are
`validation.yml`, `full-tests.yml`, `pr-ui-screenshots.yml`,
`release-app-store-screenshots.yml`, `prepare-release-version.yml`, and
`create-github-release.yml`. In particular, standalone App Store screenshot capture is
canonical public hosted functionality, not part of the private release workflow set.

Use `ruby .github/scripts/run_public_automation_checks.rb --list-files` to print the
complete Ruby runner/check/dependency closure that the clean public candidate must retain.
The historical private release repository may run
`.github/scripts/run_release_automation_checks.rb`; that suite first verifies the public
contract and then adds private-only signing, publication, and release-pipeline checks.
