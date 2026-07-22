# Home Stuff Inventory

Home Stuff Inventory is a local-first iOS app for tracking household items and remembering where they are stored.

The app is built around a simple problem: you know you own something, but you do not remember where you put it. It helps answer what you have, where it lives, how many you have, and what notes make it easier to find later.

## Current Scope

The current app targets a focused personal household inventory workflow:

- Inventory list for browsing stored household items.
- Unlimited personal Items with no Free-tier count limit.
- Add, edit, and delete item flows.
- Item detail view with Location, exact Storage Place, category, quantity, condition, notes, and dates.
- Tags and recent-item context for faster rediscovery.
- Search across item metadata, including name, category, Location, Storage Place, tags, and notes.
- Category and location filters.
- Locations tab for browsing where items live.
- Settings and list-management areas for reusable Locations, location-scoped Storage Places, categories, conditions, and icons.
- A readable JSON export, complete manual backup, and validated atomic restore from Settings.
- Optional local sample data support for development and first-run testing.
- English and Ukrainian localization.

The app should stay focused on household inventory, not warehouse, retail, marketplace, or enterprise inventory management.

## Privacy Model

Home Stuff Inventory is local-only and privacy-first.

- No account.
- No backend.
- No analytics.
- No ads.
- No tracking.
- No cloud sync unless explicitly added in a future approved task.

Inventory data is stored locally with SwiftData. Privacy Policy and Support pages are published separately from the application source.

Export, backup, and restore are user-initiated local file workflows. The app does not upload those files or require an account, entitlement, backend, cloud service, or network connection to create or use them. A readable export is for inspection; restore accepts only a validated compatible complete backup and preserves a recoverable safety copy before replacing live data.

## Tech Stack

- iOS
- Swift
- SwiftUI
- SwiftData
- Swift Testing
- Xcode project: `HomeStuffInventoryApp.xcodeproj`
- App scheme: `HomeStuffInventoryApp`

The source is organized around `InventoryData`, `InventoryLogic`, `InventoryPresentation`, `Views`, `Persistence`, and `Resources`.

## Build

```sh
xcodebuild build \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug
```

## Test

```sh
xcodebuild test \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug
```

## Localization

User-facing strings are localized in English and Ukrainian. The localization catalog is:

```text
HomeStuffInventoryApp/Resources/Localizable.xcstrings
```

When adding or changing user-facing UI text, update both `en` and `uk` values and run the relevant localization tests.

## Documentation

`AGENTS.md` is the canonical instruction file for Codex and future AI/code agents working in this repository. It contains the product scope, privacy posture, localization rules, persistence guidance, testing expectations, and working style for this app.

The shipped visual direction, semantic hierarchy, and design-code ownership are documented in [`docs/design/README.md`](docs/design/README.md). Current implementation routing and product rules come from `AGENTS.md`, the approved task, and current source. Former delivery and audit records are retained only in the private historical archive and are not transferred in this repository's clean public Git history.

Repository documentation authority, ownership, update triggers, replacements, and retention are indexed in [`docs/README.md`](docs/README.md).

The protected Free boundary is documented in [`docs/product/free-capability-contract.md`](docs/product/free-capability-contract.md), and the shipped file format and recovery guarantees are documented in [`docs/data/portability-recovery-contract.md`](docs/data/portability-recovery-contract.md).

Release history and the next patch-line notes live in `CHANGELOG.md`.

This repository is the only source of product changes and release candidates. Signing
and App Store upload are performed by a separate private release control plane using a
fixed repository identity, full commit SHA, and protected tag. The public contract and
the prohibition on mirrored product branches are documented in
[`docs/security/public-repository-trust-boundary.md`](docs/security/public-repository-trust-boundary.md).
