# Security Policy

## Report a vulnerability privately

Do not open a public issue, pull request, discussion, or comment for a suspected
vulnerability. Do not publish exploit details, credentials, private keys, tokens,
private user data, or information about the private release environment.

Use GitHub's private vulnerability reporting form for this repository:

<https://github.com/stradivarius-ios-apps/home-stuff-inventory-app/security/advisories/new>

If that form is unavailable, stop and do not substitute a public GitHub surface.
Private Vulnerability Reporting must be enabled and verified before publication.

Include a concise impact description, affected version or commit, reproduction
steps, and any suggested mitigation. Share the minimum data needed to reproduce
the issue; never include real household inventory or another person's data.

## Response and supported versions

Only the latest release distributed through the Apple App Store is supported with
security fixes. Older releases, development snapshots, and pre-release builds are
not supported. Users should update to the latest available release before reporting
or validating a suspected vulnerability.

The project does not promise a fixed acknowledgement or remediation SLA. The
maintainer reviews GitHub Private Vulnerability Reports and coordinates accepted
reports privately on a best-effort basis.

Public disclosure must be coordinated with the maintainer after a fix or explicit
disclosure decision. Private reports must not be converted to public issues merely
because the project has no fixed response SLA.

## Security boundary

This repository contains public product source and GitHub-hosted validation only.
Signing and App Store upload are performed by a separate private release control
plane from an exact verified commit SHA and protected release tag. Public workflows
must never receive signing credentials or access to the private repository.
