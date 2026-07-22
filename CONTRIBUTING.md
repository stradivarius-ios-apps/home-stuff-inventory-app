# Contributing

Home Stuff Inventory accepts external contributions through pull requests in the
canonical public repository. Product changes, version changes, localization,
release notes, and hotfixes originate here. The private repository is limited to
release provenance, signing, export, upload, runner operations, and private audit
records.

You may use the issue forms to propose a public, non-sensitive bug report or feature
idea. Search existing issues first and keep proposals centered on the private,
local-first household inventory product. Never include real household inventory,
credentials, vulnerability details, or private release information.

Report suspected vulnerabilities only through the private route in
[`SECURITY.md`](SECURITY.md). A public issue is never an acceptable fallback.

## License and reserved brand materials

Accepted code contributions are licensed under the MIT License in [`LICENSE`](LICENSE).
The product name, icon, logo, screenshots, App Store copy, and design assets are not
licensed under MIT; review [`BRAND.md`](BRAND.md) before contributing or distributing
a fork.

This project requires the [Developer Certificate of Origin 1.1](DCO).
It does not use a Contributor License Agreement. Every commit in a pull request must
include a sign-off created by the contributor who is making the certification:

```text
Signed-off-by: <your name> <the email associated with your commit>
```

Use `git commit --signoff` when creating each commit. A sign-off is a DCO
certification, not a cryptographic signature. Do not sign on behalf of another person.
If a commit is missing or has an incorrect sign-off, amend or rebase the commit and
force-push the contributor branch before review. Maintainers must not bypass the DCO
check for convenience.

## Contribution requirements

Every accepted change must:

- originate in this public repository through a pull request to `main`;
- preserve local-only, privacy-first behavior unless a task explicitly changes it;
- include focused tests for behavior changes and both English and Ukrainian values
  for user-facing text;
- avoid secrets, signing material, private runner details, and real user data;
- pass the required GitHub-hosted checks and sensitive-path owner review.

This project does not adopt a formal Code of Conduct because it has no moderator team
or separate enforcement process. Use public issues for ordinary contribution questions.
Maintainers handle abuse and spam with GitHub's block, report, and conversation-locking
controls. Suspected security vulnerabilities remain private and must use only the route
in [`SECURITY.md`](SECURITY.md), never an ordinary public issue.

Product changes, version changes, release notes, and hotfixes must never originate
in the private release repository.
