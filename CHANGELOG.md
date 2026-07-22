# Changelog

All notable user-facing and release-track changes for Home Stuff Inventory are recorded here.

## 1.2.8

### Fixed

- Fix Ukrainian category overflow UI assertion (#613).

## 1.2.7

### Changed

- Document integrated soft-cabinet validation (#608).
- SCU-04: Reduce repeated Inventory row chrome (#607).
- Streamline new item quick capture (#606).
- Rebalance item detail content (#605).
- Simplify Location detail Place index (#604).
- Expose plural localization keys to catalog tests (#603).
- Clarify SCU contract routing (#602).

## 1.2.6

### Changed

- Replace detail hero cards with identity headers (#591).
- Document gh sandbox fallback (#592).

### Internal

- TASK-588: Stabilize release UI validation tests (#589).

## 1.2.5

### Changed

- PLM-06: Audit Place management integration (774a2d9).
- PLM-05: Add grouped Place management to Settings (#585).
- PLM-04: Integrate reusable Place identity and icons across Item flows (#584).
- Make Places portable in backups (#583).
- PLM-03: Add scoped Place management transactions (#582).
- PLM-01: Add persistent Place identity, icons, and legacy backfill (#581).
- Refine identity glyph alignment (#573).

## 1.2.4

### Changed

- Validate tonal and glyph refresh (#567).
- Migrate approved content icons to glyph treatment (#566).
- Build Recent Items shelf (#565).
- Add containerless content glyph primitive (#564).
- Calibrate light tonal surfaces (#563).

### Internal

- Streamline Full Validation UI coverage (#570).
- Reorder App Store screenshots (#568).

## 1.2.3

### Changed

- Delay pristine Name validation (#547).
- Apply Item semantic surface to Search results (#548).
- Restore item storage semantic accents (#546).

### Internal

- Update App Store screenshot story and capture list (#552).
- Create localized App Store demo data set (#551).

## 1.2.2

### Changed

- Optimize Full Test Validation execution (#514).
- Remove CAF evidence record (44bd044).
- Validate Item identity and card affordances (0a25a0e).
- Remove custom card disclosure chevrons (e0e7c1e).
- Distinguish Item and Location heroes (688d760).
- Remap Item and Place surface roles (14f30b9).

## 1.2.1

### Changed

- Document final Cabinet Atlas evidence (#501).
- Validate accessible adaptive layouts (#500).
- Apply the Places spatial index (#499).
- Adapt the Recent Items container (#498).
- Separate Item identity from the storage answer (#496).
- Establish Location detail hierarchy (#497).
- Refine compact Inventory Item card (#495).
- Refine Location overview card (#494).
- Add semantic Item, Location, Place, and neutral surface roles (#493).
- Persist Cabinet Atlas contract and implementation map (#492).

## 1.2.0

### Changed

- Extract SwiftData transaction ownership from views (#479).
- Localize list-management persistence failures (#476).
- Reconcile RHM audit records (#475).
- Remove localized vocabulary from inventory logic (#474).
- Serialize Settings data transfer operations (#473).
- Record the final repository health regression (#466).
- Apply approved documentation retention cleanup (#469).
- Present Settings data file alerts reliably (#468).
- Consolidate reusable preview support (#463).
- Split portability restore and browse summaries (#462).
- Complete inventory detail routing (#461).
- Restore inventory layer boundaries (#458).
- Establish canonical documentation architecture (#456).
- Reorganize characterization tests by system (#455).
- Require independent orchestrator review (#454).
- Exercise item portability limit boundaries (#440).
- Update export smoke tests for disclosure (#439).
- Test recovery artifact protection requests (#438).

### Internal

- Decompose App Store deployment automation behind contracts (#464).
- Extract item form workflow boundaries (#460).
- Cover data transfer workflow outcomes (#459).
- Restore UI smoke CI contract (#457).

## 1.1.4

### Added

- Add readable local inventory export for user-controlled access to item data.
- Add complete manual local backup and compatible atomic restore from Settings.

### Changed

- Refresh Inventory, Locations, Item Detail, Item forms, and Settings with the native Soft Cabinet visual direction.
- Make compact inventory cards and richer Location cards easier to scan while preserving Location and Place context.
- Add a concise Settings introduction and clearer item-form section hierarchy.
- Keep export, backup, restore, Search, browsing, and existing-record access available in the Free core.

### Fixed

- Improve adaptive layout and accessibility behavior across the refreshed screens.
- Validate backup compatibility and restore capacity before replacing local inventory data.

### Internal

- Align privacy disclosures with local export, backup, restore, and the required disk-space API declaration.
- Add regression coverage for Free capability and downgrade behavior.

## 1.1.3

### Changed

- Clear nested scroll content above root chrome (#355).
- Reduce repeated Place row emphasis (#354).
- Stabilize managed Location and Category rows (#353).
- Avoid duplicate App Store screenshot uploads (#346).

### Fixed

- Fix orphaned Recent items tile rows (#352).

## 1.1.2

### Internal

- Publish release screenshots directly (#344).

## 1.1.1

### Changed

- Replace SwiftData startup fatal error with recovery screen (e9afa61).
- Centralize built-in category alias resolution (c50e6e9).
- Open items that block managed value deletion (bae8117).
- Review existing Place when Location changes (895fcdf).
- Protect unsaved Item form changes (0a167ab).
- Keep reusable value creation open until saved (224f9cc).
- Make Recent items use recency-first ranking (b285be9).
- Normalize and deduplicate item tags (05ab028).
- Make Notes editing explicit and reliable (f1518b9).
- Add tokenized cross-field search and deterministic ranking (0a030d8).
- Reconcile reusable and item-derived Locations (8d1695f).

### Internal

- Align App Store metadata locales (#314).
- Audit App Store Connect metadata safely (#313).
- Add read-only App Store metadata comparison (#312).

## 1.1.0

### Changed

- Harden UI automation simulator isolation (#308).
- SC-09: Align Settings and list management with Soft Cabinet (#305).
- SC-08: Align item forms and pickers with Soft Cabinet (#304).
- SC-07: Redesign item detail for Soft Cabinet (#303).
- SC-06: Redesign Inventory and Search results for Soft Cabinet (#302).
- Align Place detail and scoped item lists with Soft Cabinet (#301).
- Redesign Location detail for Soft Cabinet (#300).
- Redesign Locations overview for Soft Cabinet (#299).
- Extend shared Soft Cabinet UI primitives (#298).
- Bump actions/download-artifact from 6.0.0 to 8.0.1 (#279).
- Establish Soft Cabinet appearance roles (#296).
- Bump actions/checkout from 5.0.1 to 7.0.0 (#280).
- Bump actions/upload-artifact from 4.6.2 to 7.0.1 (#281).
- Document Soft Cabinet visual direction (#284).
- Restyle Place Detail item rows (#260).
- Start 1.0.1 changelog (#258).
- Audit released app documentation (#256).
- Unify detail title handoff helper (#255).
- Update public privacy and support URLs (#254).

### Fixed

- Fix CI action version validation (#297).
- Fix clipped Place hero card shadow (#282).

### Internal

- Align release workflow handoffs (#310).
- Complete cross-theme visual QA and release evidence (#306).
- Harden release validation compatibility (#278).
- Consolidate release automation contracts (#276).
- Add staged release pipeline orchestration (#274).
- Publish App Store metadata and screenshots (#273).
- Add GitHub Release creation workflow (#272).
- Add release version preparation workflow (#271).
- Automate release App Store screenshots (#270).
- Add PR UI screenshot workflow (#269).
- Define CI deployment versioning policy (#257).
- Update CI after organization migration (#253).
- Unlock runner keychain before deployment archive (#246).
- Add App Store Connect secret helper (#245).

## 1.0.1

### What's New draft

Improved release reliability after the repository migration, updated public support and privacy links, and refined navigation title behavior in item and place detail screens.

### Changed

- Updated public Support and Privacy Policy links to the `stradivarius-ios-apps.github.io` pages after the repository migration.
- Refreshed release, App Store, privacy, CI, and repository documentation so it describes the current released app state instead of pre-release or old-namespace assumptions.
- Bumped the committed project marketing version to `1.0.1` for the next patch upload line after the `1.0.0 (1)` App Store baseline.
- Kept deployment workflow `version` and `build_number` inputs blank for the normal `1.0.1` path so CI uses the committed marketing version and resolves the next safe upload build number from App Store Connect state.

### Fixed

- Made detail-screen navigation title handoff behavior consistent across item lists, place-scoped lists, and iOS version paths.
- Updated CI workflows and deployment runner setup after the organization migration.
- Unlocked the runner keychain before App Store Connect deployment archives so signing assets are available during export/upload preparation.

### Internal

- Added an App Store Connect repository secret helper script for runner setup.
- Hardened App Store Connect build-number resolution so blank deployment inputs safely use the committed marketing version and the next valid upload build number.
- Started this lightweight release-note record so future App Store Connect "What's New" text does not need to be reconstructed from merged PRs.

## 1.0.0 - 2026-06-24

### Added

- Released the initial local-first Home Stuff Inventory app for personal household inventory tracking.
- Added Location-first browsing, exact Place context, broad item search, item details, add/edit/delete flows, local list management, and English/Ukrainian localization.
- Documented the no-account, no-backend, no-analytics, no-ads, no-tracking privacy posture for the first release.
