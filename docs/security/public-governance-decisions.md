# Public Governance Decision Record

Status: policy stack approved; provider and integration gates remain fail-closed.
Publication is not authorized.

Canonical destination: `stradivarius-ios-apps/home-stuff-inventory-app`.

The maintainer approved the policy stack on 2026-07-22. No policy decision or contact
value remains unresolved.

| Decision | State | Approved policy |
| --- | --- | --- |
| Code license | **APPROVED** | MIT applies to code, tests, automation, configuration, synthetic fixtures, and ordinary technical documentation; see `LICENSE` and `BRAND.md` |
| Brand and reserved materials | **APPROVED** | Product name, icon, logo, screenshots, App Store copy, and design assets are excluded from MIT and remain reserved |
| External contributions | **APPROVED** | Accepted through pull requests in the canonical public repository |
| DCO / CLA | **APPROVED** | DCO 1.1 sign-off is mandatory for every contributed commit; no CLA |
| Code of Conduct | **APPROVED — NOT ADOPTED** | No formal Code of Conduct because there is no moderator team or separate enforcement process |
| Supported security versions | **APPROVED** | Latest Apple App Store release only; no fixed response SLA; GitHub Private Vulnerability Reporting on a best-effort basis |
| Canonical repository | **APPROVED** | `https://github.com/stradivarius-ios-apps/home-stuff-inventory-app` |
| Public/private ownership | **APPROVED** | Product work is canonical public; release provenance, signing, export/upload, self-hosted runner operations, credentials, and private audit evidence remain private |

## DCO enforcement decision

Install a repository-scoped DCO GitHub App, enable GitHub's web-based commit sign-off
policy, observe the exact DCO check name and source application on the clean public
repository, and only then add that observed check to the `main` ruleset. Maintainers
must not use an override to bypass a missing sign-off for convenience. The DCO check
is a provider gate until installed and observed; it is not hard-coded as an active
required check in staging.

## Community interaction decision

Ordinary contribution questions use public GitHub issues. Abuse and spam are handled
with GitHub's block, report, and conversation-locking controls. This is not a private
moderation process and does not create a moderation contact. Suspected vulnerabilities,
credentials, exploit details, or private user data must still use GitHub Private
Vulnerability Reporting as defined in `SECURITY.md`, never a public issue.

## File-boundary decision

The SEC-PUB-06 disposition and final post-dependency delta must implement the approved
ownership split. Private release workflows, signing/export/upload code, runner
operations, credential procedures, and private audit evidence must not enter the
public candidate. Public product code, tests, localization, versioning, release notes,
and hotfixes must not originate in the private repository after cutover.

No approved legal, brand, contribution, security-support, repository-identity, or
public/private ownership decision remains open.
