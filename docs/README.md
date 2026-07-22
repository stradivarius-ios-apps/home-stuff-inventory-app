# Documentation Architecture

Status: Active documentation authority map

This index defines which repository documents are authoritative, which are operational runbooks, and which are retained evidence. GitHub issues own task scope and progress; source code and tests own implemented behavior. A document must not be treated as proof that a deferred feature ships.

## Lifecycle Terms

- **Active** — maintained whenever its update trigger occurs.
- **Release gate** — revalidated for each affected release or submission.
- **Historical guardrail** — concise completed direction retained to prevent regressions; current approved tasks may supersede it explicitly.
- **Audit evidence** — dated validation facts retained in the private historical archive, separate from this clean public Git history and from current operational gates.
- **Fixture** — machine-consumed compatibility evidence; change only with its owning format contract and tests.

## Authority Map

| Artifact | Authority | Lifecycle | Owner | Update trigger | Replacement / retention rule |
| --- | --- | --- | --- | --- | --- |
| [`../README.md`](../README.md) | Shipped product overview and repository entry point | Active | Product maintainer | Shipped capability, platform, build, or top-level routing changes | Keep concise; route detailed policy to the owning document |
| [`../AGENTS.md`](../AGENTS.md) | Repository-wide agent and contribution constraints | Active | Repository maintainer | Product guardrail, workflow, structure, localization, or validation policy changes | No secondary agent-policy document may override it |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Released and prepared version history | Active | Release maintainer | Release preparation or shipped release | Retain all released entries |
| [`product/free-capability-contract.md`](product/free-capability-contract.md) | Protected Free capability boundary | Active | Product owner | Free access, gating, or downgrade behavior changes | Supersede only through an approved product decision |
| [`product/monetization-model.md`](product/monetization-model.md) | Monetization principles and capability allocation | Active | Product owner | Monetization decision changes | Deferred capabilities remain explicitly unimplemented |
| [`product/pro-launch-bundle-contract.md`](product/pro-launch-bundle-contract.md) | Approved Pro launch-bundle contract | Active pre-implementation contract | Product owner | Approved Pro scope or dependency issue changes | Shipped source becomes behavioral authority after implementation; retain contract history |
| [`data/portability-recovery-contract.md`](data/portability-recovery-contract.md) | Readable export, backup, restore, compatibility, and recovery behavior | Active | Data/persistence owner | File schema, validation, restore, recovery, or retention behavior changes | Persisted compatibility changes require a migration plan |
| [`data/portability-recovery-v1/README.md`](data/portability-recovery-v1/README.md) and adjacent JSON files | Version 1 fixture semantics and exact compatibility inputs | Fixture | Data/persistence owner | Format-version or compatibility-test changes | Never rewrite an accepted fixture in place when a new version is required |
| [`privacy/app-store-privacy-disclosures.md`](privacy/app-store-privacy-disclosures.md) | Current App Store privacy and export-compliance answers | Release gate | Privacy/release owner | Data flow, dependency, entitlement, capability, required-reason API, or encryption changes; every submission | Historical validation belongs in audit records, not in this current-state checklist |
| [`privacy/public-pages.md`](privacy/public-pages.md) | Routing and content contract for external Privacy and Support pages | Release gate | Privacy/release owner plus public-pages repository owner | Public URL or shipped privacy-facing behavior changes; every submission | Public copy remains in the separate public repository |
| [`security/public-repository-trust-boundary.md`](security/public-repository-trust-boundary.md) | Canonical public source authority and immutable exact-SHA/tag private release handoff | Active trust-boundary contract | Repository security maintainer | Source ownership, release provenance, or public/private responsibility changes | Keep private host, credential, signing-asset, and incident details outside public source |
| [`security/public-governance-decisions.md`](security/public-governance-decisions.md) | Approved license, brand, contribution, security-support, and repository governance decisions | Active governance contract | Repository maintainer | Approved governance policy changes | Provider enforcement remains separately verified before cutover |
| [`release/free-downgrade-regression-gate.md`](release/free-downgrade-regression-gate.md) | Free and downgrade release regression gate | Release gate | Product/release owner | Free boundary, Pro gating, persistence, or release validation changes | Must remain aligned with the Free capability contract |
| [`../fastlane/README.md`](../fastlane/README.md) | Repository-managed App Store metadata and local validation guide | Active guide | Product/release owner | Metadata fields, locales, or validation behavior changes | Credentialed audit and publication remain in the private release control plane |
| `../fastlane/metadata/{en-GB,uk}/*.txt` | Reviewed repository-managed App Store localized values | Active release input | Product/release owner | Approved listing copy or URL changes | Keep locales paired; app name and release notes remain App Store-managed |
| [`../AppStoreAssets/README.md`](../AppStoreAssets/README.md) | Hosted non-signing screenshot capture, ordering, and validation contract | Active guide | Release/design owner | Screenshot set, device slot, locale, or public capture workflow changes | Generated screenshots are not retained in Git; credentialed publication remains private |
| [`../AppStoreAssets/AppStoreMetadata.md`](../AppStoreAssets/AppStoreMetadata.md) | Human review baseline for App Store positioning and listing claims | Release gate | Product/release owner | Listing claims, branding, screenshots, URLs, or shipped capabilities change | Fastlane text files own uploaded localized field values |
| [`design/README.md`](design/README.md) | Current shipped visual direction, semantic hierarchy, and design-code ownership | Active guide | Design/UI owner | Approved visual direction, semantic role, or shared design-code change | Replace current guidance in place; former delivery and audit material remains only in the private historical archive |

## Conflict Resolution

Use the narrowest current authority. For shipped behavior, source and tests beat descriptive documentation. For task scope, the approved GitHub issue beats historical concepts. For release operations, the active runbook beats an audit record. When two active documents conflict, stop and reconcile the owning documents in the same task rather than silently choosing one.
