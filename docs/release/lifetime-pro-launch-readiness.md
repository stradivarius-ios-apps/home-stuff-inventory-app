# Lifetime Pro Launch Readiness

Status: Mandatory release and submission gate

## Scope

This gate applies to the individual, non-consumable Home Stuff Pro lifetime
unlock. The launch bundle contains exactly these five local capabilities:

1. Room Sweep rapid Item capture;
2. movement of explicitly selected Items;
3. movement of the direct Item contents of one Storage Place;
4. readable movement history with bounded extended Undo (history reading is
   Free; initiating extended Undo is unlocked);
5. nested Storage Places.

Sync, sharing, subscriptions, trials, allowances, and a first-launch paywall
are not part of this launch. They must not appear in the
purchase surface, App Store metadata, screenshots, review notes, or release
claims.

The product identifier is
`com.stradivarius23.HomeStuffInventoryApp.pro.lifetime`. The product is an
individual `NonConsumable`; Family Sharing is off. The app must render the
product display name and price supplied by StoreKit. Repository copy must not
claim or hardcode a price.

## Automated candidate gate

Record the exact candidate SHA and retain the hosted check URLs outside this
repository. A checklist mark without a test result for that SHA is not
evidence.

- `PremiumAccessTests` proves that the lifetime launch collection contains
  exactly five capabilities, each gate is centralized, and protected Free
  access is independent from the entitlement result.
- `StoreKitClientTests` and `StoreKitEntitlementServiceTests` prove the exact
  product identifier and local StoreKit product shape, verified purchase and
  restore, pending and cancellation handling, unverified-transaction
  rejection, offline verified ownership, refund/revocation reconciliation,
  update handling, and clean lifecycle restart.
- Room Sweep draft and persistence tests prove one-name validation,
  destination retention, Item-field reset, repeated saves, cancellation,
  atomic failure, entitlement recheck, downgrade readability, and absence of
  fabricated movement history.
- Selected-Item and whole-Storage-Place movement tests prove exact preflight,
  current-source and destination revalidation, direct-content-only scope,
  atomic movement/history, cancellation, entitlement loss, and grouped Undo.
  The whole-place gate includes an empty-place path that does not request
  purchase access and excludes nested child-place contents.
- Movement history tests prove bounded operation retention, readable
  portability, latest-compatible Undo, stale-state refusal, rollback, and
  ordinary single-Item movement remaining Free.
- Hierarchy identity, integrity, mutation, browse/Search, destination, backup,
  restore, readable export, legacy migration, and downgrade suites prove stable
  identity, unbounded paths, sibling-scoped uniqueness, cycle rejection,
  atomic subtree moves, non-cascading deletion, structural Undo, exact
  portability, and read-only hierarchy structure after downgrade.
- `InventoryFreeDowngradeRegressionGateTests` proves all protected Free
  capabilities and previously created user data remain readable, searchable,
  browsable, exportable, backed up, and restorable.
- `LocalizationCatalogTests`, formatting/localization suites, and focused UI
  tests prove that required English and Ukrainian keys are present. Automated
  UI results are interaction evidence, not visual-comparison evidence.
- Purchase-surface UI automation uses an explicit DEBUG-only injected product
  name and display price to prove rendering and interaction deterministically.
  The default and Release paths still use StoreKit. This injection is not
  StoreKit, Sandbox, price-localization, purchase, or restore evidence.
- `PrivacyManifestTests` plus a Release-source capability scan prove the
  reviewed local-only privacy boundary, no tracking, and the single Disk Space
  required-reason declaration.
- The baseline iPhone 17 Debug build, full unit suite, focused UI gate, and all
  required GitHub-hosted checks pass for the exact candidate SHA.

Run the focused launch gate:

```sh
xcodebuild test \
  -project "HomeStuffInventoryApp.xcodeproj" \
  -scheme "HomeStuffInventoryApp" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug \
  -only-testing:HomeStuffInventoryAppTests/PremiumAccessTests \
  -only-testing:HomeStuffInventoryAppTests/PremiumUpgradeCoordinatorTests \
  -only-testing:HomeStuffInventoryAppTests/StoreKitClientTests \
  -only-testing:HomeStuffInventoryAppTests/StoreKitEntitlementServiceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryItemDraftTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryItemFormPersistenceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBulkMovementTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryPlaceContentsMovementTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryMovementHistoryTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryPlaceIdentityTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryPlaceMutationPersistenceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryHierarchyBrowseIntegrationTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryReadableExportServiceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupRestoreTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryBackupRestoreServiceTests \
  -only-testing:HomeStuffInventoryAppTests/InventoryFreeDowngradeRegressionGateTests \
  -only-testing:HomeStuffInventoryAppTests/PrivacyManifestTests \
  -only-testing:HomeStuffInventoryAppTests/LocalizationCatalogTests
```

Also run the complete unit suite, the focused Free UI gate in
[`free-downgrade-regression-gate.md`](free-downgrade-regression-gate.md), and
these focused launch UI tests:

- `InventoryBrowseDetailUITests/testFirstLaunchDoesNotPresentProUpgrade`;
- `InventoryBrowseDetailUITests/testPlaceContentsMovementActionDistinguishesAccessGateFromEmptyState`;
- `InventoryBrowseDetailUITests/testScopedRoomSweepUsesSharedUpgradeWithoutBlockingOrdinaryAddItem`;
- `InventoryBrowseDetailUITests/testItemDetailMovementHistoryIsReadableWithoutUpgrade`;
- `InventorySettingsUITests/testFreeGlobalHistoryPresentsExtendedUndoUpgradeFromCurrentSheet`;
- `InventorySettingsUITests/testFreeHierarchyDirectoryStaysReadableAndRoutesOnlyIntentionalStructuralActionsToUpgrade`;
- `InventorySettingsUITests/testUkrainianHierarchyReadOnlyStateAndContextualUpgradeRemainAccessible`.

Then run the baseline build. The final pull request must list exact pass counts
and hosted checks rather than changing this current procedure into a dated
evidence log.

## Manual evidence still required

The following evidence requires a maintainer and must remain recorded as
pending until it is actually performed:

- On-device or simulator review in English and Ukrainian, light and dark
  appearance, supported large accessibility text sizes, VoiceOver, Reduce
  Motion, Reduce Transparency, and Increase Contrast for the purchase surface
  and all five workflows.
- Sandbox purchase success, cancellation, Ask to Buy/pending, explicit
  restore, a clean install, reinstall restore, an update from the prior
  production version with existing Inventory data, a second sandbox device,
  product-unavailable, interrupted-network, offline relaunch after verified
  ownership, refund, and revocation scenarios.
- Credentialed comparison of the App Store Connect product and localized
  metadata with the reviewed values below.
- App Review screenshot and final notes that match the submitted build.
- Resolution of the public Privacy Policy and Support URLs and comparison of
  their English/Ukrainian copy with the candidate.

Do not substitute local StoreKit configuration results for Sandbox evidence or
automated accessibility identifiers for manual visual and assistive-technology
review.

## App Store Connect product draft

These are reviewed inputs, not proof that App Store Connect has been changed:

| Field | Value |
| --- | --- |
| Reference name | `Home Stuff Pro Lifetime` |
| Product ID | `com.stradivarius23.HomeStuffInventoryApp.pro.lifetime` |
| Type | Non-Consumable |
| Family Sharing | Off |
| English display name | `Home Stuff Pro` |
| English description | `Unlock five advanced local inventory tools.` |
| Ukrainian display name | `Home Stuff Pro` |
| Ukrainian description | `Відкрийте п’ять локальних Pro-можливостей.` |

Select the actual price and storefront availability in App Store Connect.
There is no repository-approved numeric price. Keep the product off sale until
the candidate, metadata, agreements, tax, banking, Sandbox, and review gates
are ready.

Confirm whether the App Store product localization should follow the listing’s
`en-GB` locale or use another supported English locale. The checked-in
`en_US`/`uk_UA` StoreKit configuration is a deterministic local test fixture,
not an App Store Connect locale decision.

App Store Connect configuration is maintainer-owned and is not managed by the
repository metadata lane or the StoreKit fixture:

1. Confirm the Paid Apps Agreement is active and required tax and banking
   information is complete.
2. Confirm the app identifier and signing profile support In-App Purchase.
3. Create one non-consumable with the exact reference name and product
   identifier above. Product identifiers cannot be edited after creation.
4. Leave Family Sharing off.
5. Add the reviewed English and Ukrainian display names and descriptions.
6. Select the approved base country/region, price, tax category, and storefront
   availability. Recheck the policy for adding future storefronts.
7. Add the review screenshot and final review notes from the submitted build.
8. For the first In-App Purchase, attach and submit it with the app version
   that first exposes the purchase.
9. Create a dedicated Sandbox tester and complete every manual scenario in
   this gate before submission.

Do not configure App Store Server Notifications URLs for this local-only
release; there is no approved developer backend to receive them. A promoted
In-App Purchase image is optional and is not part of this gate.

## App Review notes draft

Home Stuff Inventory is a local-only personal inventory app. Home Stuff Pro is
one non-consumable lifetime purchase and does not require an account.

To find the purchase and restore controls, open Settings, then Home Stuff Pro.
The purchase surface shows the StoreKit-localized product name and price and
offers Restore Purchases.

The unlock contains exactly five local capabilities:

1. Open Locations, open a Storage Place, then use its secondary actions menu
   to choose Room Sweep and save several Items quickly.
2. In Inventory, enter selection mode, select Items, and choose Move.
3. In the same Storage Place menu, choose Move Contents for a place that has
   direct Items.
4. Movement history remains readable without purchase. Open Settings, then
   Movement History, and use Pro extended Undo for the latest compatible
   grouped operation.
5. Open Settings, then Storage Places, and create or restructure nested
   Storage Places.

Without the purchase, ordinary Item creation, viewing, editing, deletion,
Search, filters, single-Item movement, Locations, flat Storage Places,
movement-history reading, export, backup, restore, and recovery remain
available. Dismissing or cancelling purchase changes no Inventory data.
Refund or revocation disables new Pro operations without hiding or deleting
existing records.

The app has no account, backend, analytics, ads, tracking, or cloud sync.
Inventory and purchase-enabled workflows operate locally. Use the review
account’s Sandbox environment to purchase or restore the non-consumable.

Before submission, replace any navigation wording that does not exactly match
the candidate and attach the required review screenshot. Do not include a
numeric price in review notes.

## Staged activation and rollback

Activation is fail-closed:

1. Merge all five capability implementations, the shared contextual upgrade
   coordinator, and this gate.
2. Pass the complete automated candidate gate and record the exact SHA.
3. Configure and verify the non-consumable and its metadata in App Store
   Connect; complete the manual evidence above.
4. Submit the non-consumable with the app version that first exposes it.
5. Upload or submit only through a separately authorized release operation.

Stop activation if the product cannot load, any Free workflow is gated, a
premium mutation can commit without verified access, any candidate check
fails, or required manual evidence is missing.

A rollback is a follow-up build that hides or disables purchase presentation
and new Pro operation entry points. It must preserve the current data schema,
stable identifiers, nested relationships, movement history, entitlement
reconciliation, readable export, backup, restore, and every protected Free
workflow. It must never delete, flatten, hide, or destructively rewrite user
data. Keep valid lifetime ownership restorable when the purchase surface
returns. If an older build cannot read the current schema, roll forward with
entry points disabled instead of shipping the incompatible older build.
