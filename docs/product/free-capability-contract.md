# Free Capability Contract

Status: Canonical repository contract
Parent sub-epic: historical task #386
Parent epic: historical task #380
Implementation task: historical task #390

## Purpose

This document is the enforceable minimum for the Home Stuff Inventory Free tier. It refines the approved [monetization model](monetization-model.md) without changing shipped UI or claiming that deferred capabilities already exist.

Every capability in the matrix is protected from monetization gates. `InventoryFreeCapability` and `InventoryFreeAccessPolicy` are the production policy boundary; the policy is intentionally independent from StoreKit, SwiftData, Search, persistence filtering, and UI presentation.

## Canonical capability matrix

`Implemented` describes the repository today.

| Policy capability | Protected Free workflow | Implementation | Owning screen / logic surface |
|---|---|---|---|
| `unlimitedItems` | Keep any number of personal Items; no count gate, truncation, or retroactive allowance | Implemented | `Views/InventoryListView.swift`; `InventoryData/InventoryItem.swift`; `Persistence/InventoryModelContainer.swift` |
| `createItem` | Create an Item with a name and any supported optional fields | Implemented | `Views/InventoryItemFormView.swift`; `InventoryPresentation/InventoryItemDraft.swift` |
| `viewItem` | Open and read an Item | Implemented | `Views/InventoryListView.swift`; `Views/Inventory/InventoryItemDetailSurfaces.swift`; `InventoryPresentation/InventoryItemDetailViewModel.swift` |
| `editItem` | Edit an Item and its supported fields | Implemented | `Views/InventoryListView.swift`; `Views/InventoryItemFormView.swift`; `InventoryPresentation/InventoryItemDraft.swift` |
| `deleteItem` | Delete an Item through the ordinary destructive flow | Implemented | `Views/InventoryListView.swift` |
| `manageLocations` | Create, rename, use, and remove reusable Locations under existing safety rules | Implemented | `Views/InventoryListManagementView.swift`; `Views/InventoryListManagementState.swift`; `InventoryLogic/InventoryListManagement.swift` |
| `managePlaces` | Enter, edit, browse, and ordinarily use exact Places | Implemented | `Views/InventoryItemFormView.swift`; `Views/Locations/LocationPlacesListView.swift`; `InventoryLogic/InventoryBrowseSummaries.swift` |
| `relocateSingleItem` | Move one Item by changing its Location and/or Place | Implemented | `Views/InventoryItemFormView.swift`; `InventoryPresentation/InventoryItemDraft.swift` |
| `searchSupportedFields` | Search across Item name, Category, Location, Place, Tags, and Notes, including current missing-value guidance terms | Implemented | `Views/InventoryListView.swift`; `InventoryLogic/InventorySearch.swift` |
| `filterByCategory` | Filter Inventory by Category | Implemented | `Views/InventoryListView.swift`; `InventoryLogic/InventorySearch.swift`; `InventoryPresentation/InventoryFilterContext.swift` |
| `filterByLocation` | Filter Inventory by Location | Implemented | `Views/InventoryListView.swift`; `InventoryLogic/InventorySearch.swift`; `InventoryPresentation/InventoryFilterContext.swift` |
| `browseLocationPlaceItem` | Browse the complete `Location → Place → Item` hierarchy | Implemented | `Views/Locations/`; `InventoryLogic/InventoryBrowseSummaries.swift`; `InventoryPresentation/LocationPlaceSummary.swift` |
| `editNotes` | Add, read, and edit basic Item Notes | Implemented | `Views/Inventory/InventoryNotesEditorView.swift`; `InventoryPresentation/InventoryNotesEditorState.swift` |
| `editTags` | Add, read, edit, and remove basic Item Tags | Implemented | `Views/InventoryItemFormView.swift`; `InventoryPresentation/InventoryItemDraft.swift` |
| `editQuantity` | Add, read, and edit basic Item Quantity | Implemented | `Views/InventoryItemFormView.swift`; `Views/Inventory/InventoryItemDetailSurfaces.swift`; `InventoryPresentation/InventoryItemDraft.swift` |
| `editCondition` | Add, read, and edit basic Item Condition | Implemented | `Views/InventoryItemFormView.swift`; `Views/Inventory/InventoryItemDetailSurfaces.swift`; `InventoryPresentation/InventoryItemDraft.swift` |
| `manageReusableValues` | Manage reusable Location and Category values under existing in-use and default-value protections | Implemented | `Views/InventoryListManagementView.swift`; `InventoryLogic/InventoryListManagement.swift` |
| `guideMissingLocation` | See and act on guidance when an Item has no Location | Implemented | `Views/InventoryListView.swift`; `Views/InventoryEmptyStateView.swift`; `InventoryPresentation/InventoryEmptyStateViewModel.swift`; `InventoryLogic/InventorySearch.swift` |
| `guideMissingPlace` | See missing-Place guidance while retaining ordinary Item and Place access | Implemented | `Views/InventoryListView.swift`; `Views/Inventory/InventoryItemDetailSurfaces.swift`; `InventoryLogic/InventorySearch.swift` |
| `viewExistingRecords` | Read every existing personal record and premium-created content after any entitlement change | Implemented as a data rule | All record-detail surfaces; `InventoryData/`; `Persistence/InventoryModelContainer.swift` |
| `exportInventory` | Produce a readable export of user-owned Inventory data | Implemented | `Views/Settings/SettingsHomeView.swift`; `InventoryLogic/InventoryReadableExportService.swift` |
| `backUpInventory` | Create a safe manual backup | Implemented | `Views/Settings/SettingsHomeView.swift`; `Views/Settings/InventoryBackupDocument.swift`; `InventoryLogic/InventoryBackup.swift` |
| `restoreInventory` | Validate and atomically restore a compatible backup without losing the current recoverable state | Implemented | `Views/Settings/SettingsHomeView.swift`; `Views/Settings/InventoryBackupRestorePreflightView.swift`; `InventoryLogic/InventoryBackupRestore.swift`; `InventoryLogic/InventoryBackupRecoveryStore.swift` |

Readable export, complete backup, and compatible atomic restore are shipped Settings workflows. They remain available in every entitlement state, including missing or unavailable entitlement state, and never accept a readable export as a restore source.

## Forbidden gates

The following gates are forbidden, including indirect gates implemented through hidden rows, disabled navigation, query predicates, record-count limits, or unreadable data formats:

- Item counts or ordinary Item CRUD;
- Search across any currently supported field;
- Category or Location filters;
- ordinary Location or Place use;
- ordinary movement of one Item;
- viewing or editing existing personal records;
- reading data created while a paid entitlement was active;
- export, backup, restore, and recovery of user-owned data.

Monetization policy must remain outside SwiftData models, persistence queries, Search matching and ranking, data migrations, and destructive operations. A missing or changed entitlement cannot delete, hide, truncate, replace, or make existing user data unreadable.

## Entitlement, offline, and failure behavior

`InventoryEntitlementState` represents the six approved product states without importing or interpreting StoreKit. The policy fixture covers Free, Lifetime Pro, active Family & Sync, combined active access, expired subscription with no Lifetime Pro, expired subscription with Lifetime Pro, and `nil` for no loaded StoreKit state.

Free policy resolution is deterministic:

- success always resolves every canonical capability to `available`;
- no StoreKit state, offline launch, interrupted loading, verification failure, billing failure, refund, or subscription expiry resolves the same Free result;
- purchase cancellation or a pending purchase does not change Free access or mutate Inventory data;
- an entitlement transition may disable separately approved premium creation, automation, bulk operations, or ongoing services, but cannot change the result for a capability in this contract;
- recovery never silently substitutes an empty store, filters persisted records, or discards pending local data;
- later entitlement recovery may restore premium access, but Free access never waits for that recovery.

The personal local Inventory remains usable without an account or network connection. Future adapters may translate verified StoreKit state into `InventoryEntitlementState`; they must not introduce StoreKit types into this policy or its deterministic unit tests.

## Extension and change control

Adding a capability to Free is allowed. The same change must add its stable `InventoryFreeCapability` case, matrix row with owners, and policy fixture entry.

Removing, narrowing, renaming, or gating a protected capability is a product decision, not a refactor. It requires all of the following before implementation:

1. an explicit product-decision issue;
2. an update to parent epic historical task #380;
3. an update to `docs/product/monetization-model.md` and this canonical contract;
4. explicit data ownership, downgrade, offline, recovery, privacy, localization, accessibility, release, and rollback review.

Code cleanup, StoreKit integration, paywall work, or a premium-feature issue cannot implicitly weaken this contract.

## Privacy, release, and rollback

This contract adds no permission, entitlement, network access, data collection, tracking, privacy-manifest entry, App Store metadata, or visible UI. It does not require English or Ukrainian string changes and does not change accessibility behavior.

Ship future gates only at capability boundaries outside inventory storage and retrieval. A rollback may turn off newly introduced premium creation, automation, bulk operations, or continuing services. It must preserve schema compatibility, local readability, export/recovery access, and all existing data. This task adds no persisted model or schema, so its policy and documentation can be rolled back without data migration; future implementations remain bound by the approved product contract until a product-decision issue changes it.
