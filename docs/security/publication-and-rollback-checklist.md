# Clean Repository Publication And Rollback Checklist

Every item is fail-closed. Record reviewer, UTC timestamp, exact public commit SHA,
and non-sensitive evidence link beside each completed step. A checkbox in this file
is a procedure template, not evidence by itself.

## Staging prerequisites

- [ ] MIT code scope, `BRAND.md` exclusions, external-contribution acceptance,
      DCO-without-CLA, the explicit decision not to adopt a formal Code of Conduct,
      latest-release-only security support,
      GitHub Private Vulnerability Reporting, and the public-product/private-release
      ownership split match the approved decision record.
- [ ] Public issues are available for ordinary contribution questions. Maintainers
      can block/report abusive accounts and lock abusive or spam conversations. These
      controls are not presented as a private moderation channel.
- [ ] SEC-PUB-02, SEC-PUB-03, SEC-PUB-05, and SEC-PUB-06 are integrated and their
      final contracts pass from the selected source state.
- [ ] PR #635 (governance) and PR #636 (bootstrap) are non-draft and merged. Record
      both exact merge commit SHAs outside this repository until merge, then prove the
      final source commit descends from both and bind their files to the recomputed
      candidate path-set/snapshot identity.
- [ ] After the semantic SEC-PUB-02 rebase, `test_public_governance.rb` is listed in
      `PublicAutomationContract::PUBLIC_CHECKS`; the public runner file closure contains
      both it and `validate_public_governance.rb`. The integrated public check runner
      passes from the exact final source SHA.
- [ ] SEC-PUB-07 records the post-dependency delta, final candidate identity, clean
      root commit, approved noreply identity, and clean-history scans.
- [ ] The destination is the new non-fork repository
      `stradivarius-ios-apps/home-stuff-inventory-app`; no old Git/GitHub history,
      releases, issues, comments, attachments, caches, artifacts, or fork relation
      were copied.
- [ ] Required hosted check names were observed on the clean repository's exact
      commit and copied into the public and private handoff contracts; Full Test has
      a release-SHA trigger/exact-source proof, and the private verifier binds each
      successful check to the expected GitHub Actions source app.
- [ ] Install the DCO GitHub App only for the canonical public repository, enable
      compulsory sign-off for web-based commits, observe the exact check name/source
      app on a signed and unsigned test pull request, then add that exact check to the
      `main` ruleset. No convenience override is used.
- [ ] `Classify changed files` and `CI workflow validation` are observed as
      unconditional candidates. `Classify changed files` owns the tracked-public-
      surface check, exact candidate preparation, trusted Gitleaks boundary, and
      candidate scan; there is no separate `Public candidate boundary` check.
      `Build and test`, `Code coverage`, and `Full Test Suite` remain outside the
      global required set unless their conditional/event semantics are supported and
      tested by the selected ruleset mechanism.
- [ ] Default Actions permissions are read-only, reviewed actions are full-SHA pinned,
      and only explicitly reviewed jobs receive scoped writes.
- [ ] The exact `main` and `v*` ruleset configuration is reviewed and ready to apply
      immediately after visibility changes. Private staging on the current plan does
      not support rulesets, so this is not recorded as tested or complete.
- [ ] The controlled fork scenario, full hosted CI commands, and non-admin
      sensitive-path test are prepared. Private-repository billing limits prevent
      treating a staging run as publication evidence.
- [ ] The exact security-feature sequence and compensating-control template are ready
      for secret scanning/push protection, private vulnerability reporting, dependency
      graph/alerts/updates, code scanning, dependency review, and advisory access.
- [ ] GitHub Private Vulnerability Reporting opens the private advisory form linked
      from `SECURITY.md`; no vulnerability report is routed to a public issue.
- [ ] The private repository remains private; its runner group and release environment
      are restricted, ordinary development is frozen, and the exact public SHA/tag
      checkout is the only build input.
- [ ] SEC-PUB-09 returns `GO` for the repo-side candidate with the private-staging
      provider limitations explicitly recorded, and the maintainer separately
      authorizes publication through the controlled publication-and-verification window.

## Publication and immediate verification

- [ ] Record the pre-change destination settings inventory without secret values.
- [ ] Change visibility only under the separate maintainer authorization.
- [ ] Immediately set Actions default permissions to read-only, disable workflow PR
      approvals, apply the reviewed action policy, and enable the supported security
      features. If any control cannot be applied, start containment without waiting
      for hosted CI.
- [ ] Apply and re-read the reviewed `main` and `v*` rulesets: pull-request-only
      changes, exact required checks, owner approval for sensitive paths, stale
      approval dismissal, conversation resolution, no force-push, no deletion, and
      the minimum recorded maintainer bypass set.
- [ ] Re-read visibility, rulesets, tag protection, Actions permissions, security
      features, issue/reporting links, and merge settings from GitHub.
- [ ] Repeat a non-admin sensitive-path pull request and a controlled fork pull request.
- [ ] Run the complete hosted validation set on the exact public commit.
- [ ] Create and verify a protected release tag on the approved exact SHA without
      triggering signing or upload.
- [ ] Run the separately authorized non-uploading private release validation and prove
      its build source is the isolated public checkout.
- [ ] Freeze ordinary private development and update contributor-facing canonical links.

## Rollback triggers

Contain immediately if any required rule, hosted check, reporting route, security
feature, fork isolation, exact-SHA/tag validation, or private-source rejection is
missing or bypassable.

## Rollback actions

1. Disable public Actions to stop further untrusted execution.
2. Do not dispatch the private release workflow; stop any pending release before a
   self-hosted job receives source.
3. Return the destination to private only if that exact action was pre-authorized by
   the maintainer; otherwise restrict interaction and request authorization.
4. Preserve non-sensitive evidence and the clean root commit. Never copy private
   audit data, credentials, logs, caches, or signing artifacts into the destination.
5. Revoke only credentials proven exposed under the separately authorized credential
   response procedure. Do not perform broad deletion or rotation by assumption.
6. Fix or revert the failed control in staging, repeat the full checklist, obtain a
   fresh SEC-PUB-09 `GO`, and obtain a new maintainer publication authorization.

Rollback does not authorize making the historical private repository public, using
it for ordinary product development, synchronizing branches, or releasing from its
retained source tree.
