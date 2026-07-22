# Home Stuff Pro Launch-Bundle Contract

Status: Canonical repository contract; implementation and release activation deferred
Parent sub-epic: historical task #387
Parent epic: historical task #380
Contract task: historical task #395

## Purpose and authority

This document freezes the complete initial `Home Stuff Pro` lifetime-unlock bundle before entitlement policy, StoreKit, feature gates, purchase surfaces, or bundle workflows are implemented. It refines the approved [monetization model](monetization-model.md) and must be read together with the canonical [Free capability contract](free-capability-contract.md).

The bundle contains exactly five local capabilities:

1. Room Sweep rapid batch capture;
2. movement of explicitly selected Items;
3. movement of all current contents of one Place;
4. movement history with bounded extended Undo;
5. advanced Inventory Inbox batch cleanup.

This contract authorizes only the separately scoped implementation issues linked below. It does not claim that any capability ships today, add a trial or allowance, choose a product identifier or price, create an App Store Connect product, or authorize a visible paywall.

Repository reality at approval time matters: Inventory, Locations/Place browsing, Item Form, and Item Detail exist, but there is no Inventory Inbox screen, Inbox membership policy, or `InventoryInboxView.swift` in the app. The launch bundle approves advanced Inbox batch cleanup as a future Pro capability; it does not retroactively make its missing basic Free prerequisite implemented.

## Entitlement and gate vocabulary

Monetization must model these independent facts:

- `ownsLifetimePro`: verified ownership of the non-consumable lifetime unlock;
- `hasActiveFamilySubscription`: verified active future Family & Sync subscription.

Local Pro access is `ownsLifetimePro || hasActiveFamilySubscription`. Sync and sharing access is only `hasActiveFamilySubscription`. A scattered or ambiguous `isPremium` flag is forbidden.

The centralized feature policy owns access decisions. StoreKit adapters provide verified state; SwiftData models, persistence queries, Search, and feature views do not infer ownership. Each operation asks policy about its specific capability before creating selection state, presenting an editable Pro flow, or mutating data.

Two release states apply:

- **Before launch activation:** all five production entry points and contextual upgrade presentations remain absent or release-disabled for every entitlement state. Documentation, policy fixtures, and deterministic test hosts do not make a capability available.
- **After launch activation:** a user with local Pro access enters the requested workflow. A Free user intentionally invoking an approved visible action is routed to the one centralized contextual upgrade coordinator. The invocation creates no draft, selection, movement, history, or other inventory mutation. Dismissal or purchase cancellation returns to the unchanged source surface.

There is no first-launch paywall and no automatic interruption of ordinary Free work.

## Frozen capability matrix

The owner paths below are the required responsibility boundaries for their implementation tasks. `Existing` means the path is present in the repository at contract approval; `planned new` means the path is a future owner, not a statement of shipped behavior. A task may split a listed owner into smaller focused files in the same layer, but it must not move access policy into inventory data, Search, or persistence filtering, or grow an unrelated coordinating view to absorb feature logic.

| Capability and task | Entry point and flow | Free invocation | Entitlement | Data created or changed | Downgrade visibility | Offline behavior | Failure and cancellation | Owner files |
|---|---|---|---|---|---|---|---|---|
| Room Sweep rapid batch capture (historical task #399) | One new secondary toolbar menu attached to the existing Place item-list surface contains `Room Sweep`; the action opens a native sheet/navigation stack with that Location/Place preselected for confirmation. The user may clear the optional Place, then repeatedly saves Items with the current one-name minimum and existing draft fields. The existing Add Item button stays a direct one-tap Free action. | After activation, route to the contextual upgrade coordinator before creating the sweep draft. Before activation, no production entry point. | Local Pro | Each successful save creates one ordinary Item. It retains the confirmed destination between saves and clears Item-specific fields. When relocation history applies, the save also creates its approved movement record. | Every saved Item remains an ordinary visible, searchable, editable, movable, exportable, and recoverable Free record. Associated history remains readable. Starting a new sweep is disabled without access. | Fully local after verified ownership has been established; no network, account, or server dependency. | Each Item save is atomic and immediately visible. A failed save creates neither partial Item nor history. Cancellation keeps already-saved Items and discards only the unsaved draft. Duplicate names follow ordinary creation rules. | Existing entry anchor: `Views/Locations/LocationScopedItemsListView.swift`; existing reuse: `Views/InventoryItemFormView.swift`, `InventoryPresentation/InventoryItemDraft.swift`; new focused owners: `Views/Locations/PlaceRoomSweepView.swift`, `InventoryPresentation/InventoryRoomSweepState.swift`, `InventoryLogic/InventoryRoomSweepService.swift`. |
| Selected-Item bulk movement (historical task #400) | Native selection/edit mode in the top-level Inventory list only; a toolbar action opens the shared destination picker and a preflight showing selected count, source scope, and destination. Only explicitly selected IDs move. | Check access before selection mode or selection state is created. A visible intentional action routes to contextual upgrade; no Item is selected or changed. | Local Pro | Atomically updates Location/Place for the explicit Item set and creates one grouped movement operation with per-Item records. Other Item fields and identity are unchanged. | Moved Items and their history remain visible and editable. Ordinary single-Item movement remains Free. Starting another bulk move or extended Undo is disabled without access. | Fully local after verified ownership; current Search and filters continue to work offline and only help find candidates. | Cancellation clears selection and changes nothing. A validation, destination, entitlement-before-commit, or write failure moves none and creates no history. Filtered-out or unselected Items never move. Same-destination Items are handled and disclosed deterministically. | Existing entry anchor: `Views/InventoryListView.swift`; planned new focused owners: `Views/Inventory/InventoryBulkMoveView.swift`, `InventoryPresentation/InventoryBulkMoveState.swift`; planned new shared mutation owners: `InventoryLogic/InventoryMovementService.swift`, `InventoryData/InventoryMovementRecord.swift`. |
| Whole-Place contents movement (historical task #401) | One `Move Place Contents` action in the same new secondary toolbar menu attached to the existing Place item-list surface opens the destination picker and preflight shared with bulk movement. The preflight shows the exact current Item count and destination. | An empty Place shows the ordinary calm empty explanation and never a paywall. For a non-empty Place, check access before editable move state; a visible intentional action routes Free to contextual upgrade without mutation. | Local Pro | Atomically changes Location/Place for every Item whose current Place matches the confirmed source and creates one grouped movement operation. The Place definition is not renamed, moved, merged, or deleted. | All moved Items and history remain readable and ordinary per-Item movement remains Free. Starting another whole-Place move or extended Undo is disabled without access. | Fully local after verified ownership; source resolution and commit do not require network access. | Re-resolve immediately before commit. If contents changed after preflight, destination disappeared, entitlement was lost, or any validation/write fails, move none and require refreshed confirmation. Identical destination is a localized no-op. Cancellation changes nothing. | Existing entry anchor: `Views/Locations/LocationScopedItemsListView.swift`; new focused owners: `Views/Locations/PlaceMoveContentsView.swift`, `InventoryPresentation/InventoryPlaceMoveState.swift`; new shared mutation owners: `InventoryLogic/InventoryMovementService.swift`, `InventoryData/InventoryMovementRecord.swift`. |
| Movement history and bounded extended Undo (historical task #398) | A focused readable history section appears only in existing Item Detail. Extended Undo is available from that section for only the most recent eligible grouped operation and uses native confirmation/error presentation. | Ordinary single-Item movement remains Free. Reading existing history is Free. Invoking eligible extended Undo after activation routes a Free user to contextual upgrade before mutation. | Local Pro only for initiating extended Undo; history creation/readability is a data-integrity concern and cannot hide movement results | Successful movements create backward-compatible bounded records containing stable Item identity, from/to Location and Place snapshots, timestamp, operation/group ID, and origin (`single`, `bulk`, `placeMove`, or `roomSweep`). Undo creates the approved reversing state/history atomically. | History created while access existed remains readable. Current Item state remains visible/editable. Downgrade never prunes records merely because access changed. New extended Undo is disabled, while ordinary Free relocation remains usable. | History recording, pruning, eligibility, and Undo are local-only. Previously verified local Pro supports Undo offline. | Cancelled or failed mutations create no history. Undo is unavailable if current data no longer matches the operation post-state, the operation is not most recent/eligible, or safe restoration is impossible; explain this without changing data. Retention is deterministic and bounded. | Existing entry anchors: `Views/Inventory/InventoryItemDetailSurfaces.swift`, `InventoryPresentation/InventoryItemDetailViewModel.swift`; planned new focused owner: `Views/Inventory/InventoryMovementHistoryView.swift`; planned new data/logic owners: `InventoryData/InventoryMovementRecord.swift`, `InventoryLogic/InventoryMovementService.swift`, `InventoryLogic/InventoryMovementHistory.swift`. |
| Advanced Inventory Inbox batch cleanup (historical task #402) | After a separately approved basic Free Inbox prerequisite exists, an explicit native batch mode on that planned Inventory Inbox supports only: common Location, common Place valid for that Location, common Category, and marking selected missing fields for individual follow-up. Every operation has count/field preflight. No Inbox surface ships today. | The future ordinary single-Item Inbox review/edit prerequisite must be Free and ungated. Once both surfaces are approved and implemented, check access before Pro batch selection/state; a visible intentional batch action routes Free to contextual upgrade without mutation. | Local Pro for batch mode only; the planned basic Inbox is Free | Atomically updates only the confirmed fields on explicitly selected Items and recomputes membership using the separately approved basic Inbox rules. Non-empty values are preserved unless the user explicitly chooses `Replace existing values` for that operation. | Resulting Items and fields are ordinary visible, searchable, editable Free data. Once implemented, single-Item Inbox handling stays Free. Starting a new batch is disabled without access. | Fully local after verified ownership; no inference, server, or network dependency. | Cancellation or validation/write failure changes none. Invalid Location/Place pairs stop the operation. Hidden, filtered-out, or unselected Items are untouched. Membership is recomputed only after successful commit. If the Free Inbox prerequisite is still missing when #402 begins, implementation stops for an approved dependency/scope decision. | Planned prerequisite owner (new; not present today): `Views/Inventory/InventoryInboxView.swift` plus separately approved membership logic. Planned Pro owners (new): `Views/Inventory/InventoryInboxBatchCleanupView.swift`, `InventoryPresentation/InventoryInboxBatchState.swift`, `InventoryLogic/InventoryInboxBatchCleanup.swift`. #402 cannot implicitly create, scope, or gate the missing Free prerequisite and does not authorize a new root tab or navigation system. |

## Protected Free adjacency

The launch bundle is additive. It cannot reduce, slow, hide, relabel as Pro, or route through a purchase check any protected Free capability in `InventoryFreeCapability` or the Free capability contract.

In particular, these adjacent workflows stay Free in every entitlement, loading, offline, failed, pending, cancelled, refunded, revoked, restored, and future subscription state:

- unlimited ordinary Items and ordinary one-Item creation with the current one-name minimum;
- viewing, editing, deleting, searching, filtering, exporting, backing up, restoring, and recovering user-owned records;
- ordinary movement of one Item by editing its Location and/or Place;
- ordinary Location and Place creation, management, browsing, and `Location → Place → Item` navigation;
- current Search, Category and Location filters, current root Tab Bar, and current Inventory/Locations navigation;
- current missing-Location/Place guidance and, if a basic Inventory Inbox is separately approved and implemented, its ordinary single-Item review and editing; the planned Free prerequisite can never become a Pro gate;
- reading every Item and every result created through Room Sweep, bulk movement, whole-Place movement, history, Undo, or Inbox cleanup;
- readable movement history, even when initiating extended Undo is unavailable.

The policy may disable a new Pro operation. It may not filter SwiftData, alter Search results, hide a row because of its creation origin, replace a real store with an empty one, impose an Item-count limit, or make export/recovery dependent on StoreKit.

## Existing-surface flow map

No new root destination is authorized. Implementations remain anchored to current product surfaces:

- **Inventory:** the top-level list may expose selected-Item movement through native selection mode; Search and filters remain unchanged.
- **Locations and Place:** one new secondary menu attached to the existing Place item-list toolbar is the single entry for Room Sweep and whole-Place movement, without changing its hero, direct Add Item button, or Item list composition.
- **Item Form:** Room Sweep reuses current draft semantics, validation, managed-value options, and destination language; it does not replace ordinary creation.
- **Item Detail:** history is a focused readable section or existing property/list-card surface; extended Undo is a native action and does not introduce a timeline design system.
- **Inbox (planned prerequisite, not shipped):** no Inbox surface or membership policy exists in the current repository. A separate approved Free task must define and implement ordinary single-Item review before #402 attaches the four-operation Pro batch mode. #402 must stop for a dependency/scope decision if that prerequisite is absent; it cannot quietly implement it, gate it, invent membership rules, or create a new tab. The later batch mode is not a spreadsheet or arbitrary multi-field editor.
- **Settings:** after the full activation gate passes, one `Home Stuff Pro` row may show current state and intentionally open the shared upgrade surface. Existing export, backup, restore, and other Settings rows remain Free and unchanged.

All visible implementation must use native SwiftUI navigation, sheets, toolbars, menus, forms, list selection, confirmations, semantic colors and type, SF Symbols, platform spacing, current backgrounds, and established Inventory card/hero/row/glass primitives. Preserve the palette, Search, and root Tab Bar. Do not add a custom navigation/tab bar, design system, decorative gradient, copied glass recipe, celebratory treatment, countdown, discount badge, or unrelated redesign.

## Entitlement lifecycle, offline, and failure map

Verified ownership is the authority for enabling a Pro operation. The implementation may retain only a separately specified last-known verified access state for safe offline startup; it cannot fabricate ownership from UI state, SwiftData, a user-editable preference, or a failed/unverified transaction.

| State or event | Required behavior |
|---|---|
| Entitlements loading or unavailable with no established verified ownership | Keep all Free workflows usable. Do not begin a Pro operation or mutate Pro state. Show only the later approved non-blocking contextual status when intentionally invoked. |
| Verified Lifetime Pro | Permit all five local operations after the launch gate is active. No network is required for the workflows themselves. |
| Verified active Family subscription | Permit the same local Pro operations. Sync/sharing remains a separate subscription-only policy and is not part of this bundle. |
| Offline after verified ownership was established | Preserve local Pro access under the reconciliation rules approved by the StoreKit task. Queue no server work because these five workflows are local. |
| Purchase pending | Keep the invoked context without starting the operation. Free data and navigation remain usable. Later verified success may enable continuation; pending state never grants access itself. |
| Purchase cancelled | Dismiss or return quietly to the unchanged source context; no error alert and no mutation. |
| Product load, purchase, verification, or restore failure | Explain the later approved actionable outcome without changing Inventory data or blocking Free. An unverified transaction never grants access. |
| Refund or revocation | Reconcile access and disable new Pro operations when no other qualifying entitlement exists. Never hide or delete prior results or history. |
| Restore succeeds | Recompute the two independent entitlement facts from verified transactions and restore corresponding access without data migration. |
| Restore finds no qualifying purchase | Keep Free behavior and all records unchanged; do not describe this as data loss. |
| Entitlement changes during an operation | Recheck immediately before commit. A revoked operation fails atomically; previously committed operations and records remain. |
| Feature cancellation or app interruption | Follow the capability-specific atomicity rule. Never infer purchase cancellation from feature cancellation, and never leave partial batch state committed. |

StoreKit purchase/restore lifecycle behavior belongs to historical task #397 and historical task #403. Contextual presentation belongs to historical task #404. No feature view calls StoreKit directly.

## Localization and accessibility gate

Every user-facing title, description, count, destination summary, button, menu action, status, validation message, error, empty explanation, accessibility label, and help text introduced by later tasks must have English and Ukrainian values in `HomeStuffInventoryApp/Resources/Localizable.xcstrings`. Store product display name and price come from StoreKit localization and are never hardcoded.

Every affected flow must pass:

- Dynamic Type without clipped required actions or hidden state;
- predictable VoiceOver reading and focus order, including selection counts and preflight changes;
- explicit labels and help for icon-only controls;
- at least 44-point interactive targets;
- light and dark appearance;
- Reduce Motion, Reduce Transparency, and Increase Contrast;
- status and selection communication that does not rely on color alone.

This documentation task adds no strings or UI. These requirements become release blockers for their implementation tasks.

## Privacy and App Store boundary

The five launch capabilities are local SwiftData workflows. They require no new account, backend, network upload, analytics, ads, tracking, CloudKit, Photos, Camera, microphone, contacts, location service, notification permission, or new sensitive-data permission. Their records remain part of the user's local Inventory and its Free export/backup/restore path.

StoreKit implementation later requires the In-App Purchase capability, a configured non-consumable, verified transactions, Restore Purchases, localized IAP metadata, and App Review notes/test steps. The final release assessment must confirm the privacy manifest and App Store privacy disclosures still match actual behavior. Public privacy/support pages remain in their separate public repository.

Marketing, screenshots, release notes, review notes, and support copy may describe only capabilities that pass the launch gate. They must not hardcode price, use the planning USD hypothesis as a claim, advertise Family & Sync, or imply that any deferred Pro idea ships.

## Frozen launch gate

No production Pro feature entry point, contextual paywall, Settings purchase row, IAP marketing, App Store screenshot, or release claim may ship until all of the following are complete and independently reviewed:

1. this contract and the protected Free capability policy;
2. centralized independent entitlement state and per-feature access policy;
3. verified StoreKit product/transaction client and deterministic test configuration;
4. all five bundle capabilities, including atomic movement/history foundations;
5. purchase, explicit restore, entitlement reconciliation, refund/revocation, pending, cancellation, verification-failure, and offline behavior;
6. the single contextual upgrade coordinator and Settings surface, using StoreKit-localized product display name and price;
7. English and Ukrainian localization, accessibility/adaptive-state evidence, and light/dark and accessibility-setting checks for every affected flow;
8. protected Free regression evidence, data readability after downgrade, migration/legacy-store coverage, atomic failure/cancellation tests, localization tests, baseline simulator build, and focused UI flows;
9. privacy-manifest/disclosure assessment, IAP metadata and App Review notes, staged activation, release evidence, and rollback rehearsal required by historical task #405.

Passing only StoreKit or one bundle feature does not open the gate. DEBUG/test presets must be unavailable from release UI. App Store Connect upload or deployment still requires explicit maintainer authorization.

## Schema compatibility, release, and rollback

This contract itself changes no source, schema, persisted model, permission, capability, or shipped behavior and needs no migration.

Later movement/history work must provide a backward-compatible schema and migration for existing Items and exact `containerName` Place values. Room Sweep and cleanup results use ordinary Item data. Every persisted addition must remain readable by the release that created it and covered by versioned backup/restore/export rules.

Activation is staged only after the frozen launch gate passes. A rollback may hide or disable new Pro operation entry points and purchase presentation in a follow-up release. It must not:

- delete or hide Items, movement records, history, cleanup results, or ownership evidence;
- disable ordinary Free creation, movement, Search, browse, export, backup, restore, or recovery, or disable ordinary single-Item Inbox handling after that separately approved Free prerequisite exists;
- make prior Pro-created content unreadable;
- silently downgrade or destructively rewrite the persistence schema;
- prevent a valid lifetime purchase from being restorable when the purchase path returns.

Any persisted schema that an older rollback build cannot safely read blocks that rollback build; the implementation task must instead supply a compatible reader/migration or roll forward with entry points disabled.

## Explicitly deferred and not authorized

Everything outside the five-item matrix is deferred. In particular, this contract does **not** authorize:

- QR labels, QR scanning, barcodes, deep links for labels, or printable label workflows;
- Spotlight, Siri, App Intents, Shortcuts, widgets, controls, or reminders;
- Item or Place photos, Camera or Photos access, OCR, scanning, or AI identification/categorization;
- temporary-away, lent, borrowed, repair, reservation, due-date, or notification workflows;
- consumable quantity history, low-stock tracking, shopping lists, replenishment, price tracking, or reports;
- configurable/advanced exports beyond the protected readable export, backup, and recovery paths;
- bulk edit beyond the four approved Inbox cleanup operations; bulk delete, merge, arbitrary spreadsheet/grid editing, templates, or automation;
- unlimited history, audit logs, history editing/deletion, warehouse/employee checkout, procurement, insurance, marketplace, or enterprise features;
- Free trials, feature allowances, introductory offers, discounts, pricing experiments, promo codes, or a hard/first-launch paywall;
- a separate paid application, new Bundle ID, account system, custom backend, analytics, ads, or tracking;
- CloudKit, personal sync, Family & Sync purchase, household sharing, invitations, roles, permissions, or subscription comparison/presentation;
- product identifiers, price tiers, App Store Connect creation, deployment/upload, or public marketing/legal/support publication;
- changes to the current palette, Search, root Tab Bar, navigation architecture, or unrelated screens.

A deferred idea requires its own approved contract and implementation issue. It cannot enter the bundle through refactoring, convenience scope, test fixtures, placeholder UI, App Store copy, or paywall marketing.

## Change control

Adding, removing, combining, renaming, or changing the entitlement of a launch capability is a product decision. It requires an explicit issue updating parent epic #380, the monetization model, this contract, the Free adjacency review, entitlement mapping, data/downgrade behavior, localization/accessibility scope, privacy/App Store impact, release evidence, and rollback plan.

Implementation PRs may make only the behavior listed for their capability and must preserve unspecified appearance and behavior. If a task cannot implement this contract as written, it must stop for approval rather than choose an alternative.
