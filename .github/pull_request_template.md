## Summary

Describe the user-facing or engineering change and why it belongs in the public
product source.

## Validation

List the GitHub-hosted or local checks run for this exact change.

## Public change provenance

- [ ] The branch name uses either a real public issue/task ID or a sanitized no-ID
      `feature/<description>` / `hotfix/<description>` form.
- [ ] The branch, commits, and pull request describe only this concrete public change
      and its validation; they contain no non-public planning identifiers, links,
      codenames, acceptance criteria, roadmap, monetization, timing, or operational
      details.
- [ ] Any `Closes #...` or `Fixes #...` reference points to a real, intentionally
      public issue in this repository. No public issue was invented merely to satisfy
      a naming or linking convention.

## Security and release boundary

- [ ] This change contains no credentials, private keys, tokens, real household
      inventory, exploit details, private runner information, or signing material.
- [ ] Product, version, localization, release-note, and hotfix changes originate in
      this public repository, not in the private release repository.
- [ ] Workflow actions are pinned to reviewed full commit SHAs and permissions are
      read-only by default, with any write permission scoped to one job.
- [ ] Public workflows use GitHub-hosted runners only and do not use
      `pull_request_target` with an untrusted checkout.
- [ ] Sensitive paths have an explicit CODEOWNER maintainer review request.

## Product and localization

- [ ] The change preserves the local-first, privacy-first household inventory scope.
- [ ] New or changed user-facing text includes English and Ukrainian catalog values,
      or localization is unchanged.
- [ ] Every commit includes my own `Signed-off-by:` line and certifies the DCO 1.1;
      this project does not use a CLA.
- [ ] Any product name, icon, logo, screenshot, App Store copy, or design-asset change
      respects `BRAND.md` and has explicit maintainer approval.

Do not place vulnerability details in a pull request. Follow `SECURITY.md` instead.
