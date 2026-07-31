# Free and Downgrade Regression Gate

Status: Mandatory release gate

## Purpose

Run this gate before activating, changing, or releasing any monetization behavior. It enforces the canonical [Free capability contract](../product/free-capability-contract.md) across all six entitlement states and verifies that results created by premium workflows remain ordinary user-owned Inventory data after downgrade.

The gate is deterministic and offline. It must not use live StoreKit, App Store, CloudKit, accounts, or network fixtures.

## Mandatory CI and local checklist

- [ ] `InventoryFreeDowngradeRegressionGateTests` passes. It must enumerate exactly the six canonical entitlement states and every `InventoryFreeCapability`.
- [ ] `PremiumAccessTests` and `InventoryFreeAccessPolicyTests` pass so premium availability can change without changing Free access.
- [ ] Portability suites pass: readable export, complete backup, restore, integrity, interruption, and recovery.
- [ ] `InventorySmokeUITests/testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement` and `testFreeReleaseGateBrowseAndPortabilityWithoutEntitlement` pass for launch, basic Item creation, Search, Location/Storage-Place browsing, edit, ordinary single-Item movement, export, backup, and restore. Backup UI automation verifies that the native action remains enabled; `InventoryBackupTests` deterministically exercise preparation because XCTest does not own the system file-exporter destination UI.
- [ ] Settings disclosure tests cover English and Ukrainian, while the maximum Dynamic Type flow and free release gate retain accessibility and portability interaction coverage. Screenshot attachments are diagnostic only and are not visual-comparison evidence.
- [ ] Localization tests pass even when no strings changed.
- [ ] The baseline iPhone 17 Debug build passes.
- [ ] The repository Full Test Validation workflow passes for the exact release SHA.
- [ ] The release PR confirms no new permission, entitlement, App Store metadata, external URL retention, network dependency, or persisted schema change. The privacy manifest contains the reviewed Disk Space / `E174.1` declaration required by atomic restore and no unaudited category; any further manifest or data-flow change requires matching privacy, compatibility, and rollback review.

Run the focused local gate:

```sh
xcodebuild test \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug \
  -only-testing:HomeStuffInventoryAppTests/InventoryFreeDowngradeRegressionGateTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryFreeAccessPolicyTests \
  -only-testing:HomeStuffInventoryAppTests/PremiumAccessTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryReadableExportServiceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryPortabilityCodecTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupRestorePlannerTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupRestoreServiceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupRecoveryTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupRecoveryArtifactProtectionTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupLegacyMigrationTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupFileReaderTests \
  -only-testing:HomeStuffInventoryAppTests/PrivacyManifestTests \
  -only-testing:HomeStuffInventoryAppTests/LocalizationCatalogTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryLocalizationFormattingTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryListManagementLocalizationTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryItemIconLocalizationTests
```

Run the focused UI gate:

```sh
xcodebuild test \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement \
  -only-testing:HomeStuffInventoryAppUITests/InventorySmokeUITests/testFreeReleaseGateBrowseAndPortabilityWithoutEntitlement
```

Run the baseline build:

```sh
xcodebuild build \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug
```

## Failure triage

1. Record the exact SHA, failed test, entitlement state, capability, and deterministic fixture. Keep the failing result bundle and portability artifact; do not substitute live service state.
2. If a Free capability is unavailable, an existing record is absent, or export/backup/restore omits owned data, block the release. Inspect policy routing, SwiftData fetches, Search/filter predicates, and portability snapshot creation before changing a fixture.
3. If only a premium creation or automation assertion fails, inspect the centralized `PremiumAccessPolicy`. Do not weaken `InventoryFreeAccessPolicy` or add entitlement checks to models, persistence, Search, export, backup, restore, or ordinary CRUD.
4. If a UI path fails, reproduce without entitlement using the same launch arguments. Distinguish an accessibility identifier or timing failure from a real hidden, disabled, or unreachable Free action. Do not add visible test controls.
5. If integrity, interruption, or recovery fails, preserve the current store and durable safety backup. Do not retry with an empty store or bypass verification.
6. Rerun the focused failed suite, then the entire focused gate, then Full Test Validation for the exact candidate SHA.

## Release and rollback rule

A rollback may remove or disable new premium creation, automation, bulk operations, or continuing services. It must preserve schema compatibility and keep every existing Item, Location, Storage Place, nested relationship, Category, view event, readable export, backup, restore, and recovery path available. Without verified Pro, hierarchy structure may be read-only, but ordinary Item use and flat Storage Place management remain Free. Failure of that guarantee blocks both release and rollback until the data remains readable and recoverable.
