# Home Stuff Pro Launch-Bundle Contract

Status: Canonical implemented scope contract; release activation gated

## Purpose and authority

This document freezes the complete initial `Home Stuff Pro` lifetime-unlock
bundle implemented in the canonical source. It refines the approved
[monetization model](monetization-model.md), must be read together with the
canonical [Free capability contract](free-capability-contract.md), and uses
the [launch-readiness gate](../release/lifetime-pro-launch-readiness.md) for
candidate validation and App Store activation.

The bundle contains exactly five local capabilities:

1. Room Sweep rapid batch capture;
2. movement of explicitly selected Items;
3. movement of all current contents of one Storage Place;
4. movement history with bounded extended Undo;
5. nested Storage Places.

The canonical source contains these five workflows, centralized access policy,
verified StoreKit purchase and restore handling, and one contextual upgrade
surface. Their presence in source does not create an App Store Connect
product, authorize an upload or release, or prove the manual launch gate.
There is no trial or allowance. The non-consumable product identifier is
`com.stradivarius23.HomeStuffInventoryApp.pro.lifetime`; the checked-in
StoreKit price is only a local test fixture and is never repository-approved
product copy.

## Entitlement and gate vocabulary

Monetization must model these independent facts:

- `ownsLifetimePro`: verified ownership of the non-consumable lifetime unlock;
- `hasActiveFamilySubscription`: verified active future Family & Sync subscription.

Local Pro access is `ownsLifetimePro || hasActiveFamilySubscription`. Sync and sharing access is only `hasActiveFamilySubscription`. A scattered or ambiguous `isPremium` flag is forbidden.

The centralized feature policy owns access decisions. StoreKit adapters provide verified state; SwiftData models, persistence queries, Search, and feature views do not infer ownership. Each operation asks policy about its specific capability before creating selection state, presenting an editable Pro flow, or mutating data.

Two activation states apply:

- **Source candidate:** all five entry points and the contextual upgrade
  presentation exist for review, but upload, App Store product activation,
  submission, and release remain blocked until the launch-readiness gate is
  complete for the exact candidate.
- **Released activation:** a user with local Pro access enters the requested
  workflow. A Free user intentionally invoking an approved visible action is
  routed to the one centralized contextual upgrade coordinator. The
  invocation creates no draft, selection, movement, history, or other
  inventory mutation. Dismissal or purchase cancellation returns to the
  unchanged source surface.

There is no first-launch paywall and no automatic interruption of ordinary Free work.

## Frozen capability matrix

The owner paths below describe the implemented responsibility boundaries.
Focused presentation, policy, logic, persistence, and StoreKit owners may be
split further in the same layer, but access policy must not move into inventory
data, Search, or persistence filtering, and unrelated coordinating views must
not absorb feature logic.

| Capability and task | Entry point and flow | Free invocation | Entitlement | Data created or changed | Downgrade visibility | Offline behavior | Failure and cancellation | Owner files |
|---|---|---|---|---|---|---|---|---|
| Room Sweep rapid batch capture | A secondary action on a Storage Place item-list opens rapid repeated Item capture with the destination retained between saves. | Check access before creating sweep state; ordinary Add Item remains Free. | Local Pro | Each successful save creates one ordinary Item and any applicable movement record. | Saved Items remain fully usable Free; only starting a new sweep is disabled. | Local after verified access. | Each save is atomic; cancellation discards only the unsaved draft. | Focused Room Sweep presentation, state, and service owners reusing the ordinary Item form contract. |
| Selected-Item bulk movement | Native selection in Inventory opens a shared destination picker and exact preflight. | Check access before selection state; ordinary one-Item movement remains Free. | Local Pro | Atomically moves only confirmed Item IDs and records one grouped operation. | Items and history remain readable/editable; new bulk movement and extended Undo are disabled. | Local after verified access. | Any validation or write failure moves none; cancellation changes nothing. | Focused bulk-move presentation plus shared movement service and record model. |
| Whole-Storage-Place contents movement | A Storage Place action opens the shared destination picker and exact current-content preflight. | Empty places never trigger a paywall; otherwise check access before editable move state. | Local Pro | Atomically moves direct Item contents only; it does not rename, move, merge, or delete the Storage Place or nested child places. | Items and history remain usable Free; ordinary one-Item movement remains Free. | Local after verified access. | Re-resolve before commit; changed source, invalid destination, lost access, or write failure moves none. | Focused Storage Place movement presentation plus the shared movement service. |
| Movement history and bounded extended Undo | Item Detail shows readable history; only the most recent compatible grouped operation may be undone. | History and ordinary one-Item movement are Free; check access before extended Undo. | Local Pro only for initiating extended Undo | Successful movements create bounded, backward-compatible records; Undo reverses atomically and records the result. | History remains readable and current Item state remains editable. | Local after verified access. | Incompatible current state, an ineligible operation, or unsafe restoration disables Undo without mutation. | Focused history UI and shared movement/history data and logic owners. |
| Nested Storage Places | Storage Places form an unbounded `Location → Storage Place → Storage Place → … → Item` tree. A subtree can be moved atomically within or across Locations. Names are unique only among siblings. | Free can create and fully manage only flat top-level places. Existing tree-participating places remain visible but their name, icon, parent, hierarchy, move, and delete operations are read-only. Items remain visible, editable, searchable, exportable, recoverable, and individually movable to or from existing nested destinations. | Local Pro for creating or structurally editing a hierarchy | Adds parent/child relationships and changes a subtree destination without changing stable identities. Deletion never cascades. | Loss of access preserves the tree as read-only while flat top-level places and all ordinary Item operations retain Free editing. | Local after verified access; no network required. | Reject cycles, invalid destinations, sibling-name conflicts, cascade deletion, or partial subtree moves. Bounded Undo applies only to the latest compatible structural operation. | Versioned hierarchy schema and integrity rules; focused mutation service, destination picker, browse/Search presentation, backup/restore/export, and gate coverage. |

## Protected Free adjacency

The launch bundle is additive. It cannot reduce, slow, hide, relabel as Pro, or route through a purchase check any protected Free capability in `InventoryFreeCapability` or the Free capability contract.

In particular, these adjacent workflows stay Free in every entitlement, loading, offline, failed, pending, cancelled, refunded, revoked, restored, and future subscription state:

- unlimited ordinary Items and ordinary one-Item creation with the current one-name minimum;
- viewing, editing, deleting, searching, filtering, exporting, backing up, restoring, and recovering user-owned records;
- ordinary movement of one Item by editing its Location and/or Storage Place;
- ordinary Location and flat top-level Storage Place creation, management, browsing, and `Location → Storage Place → Item` navigation;
- current Search, Category and Location filters, current root Tab Bar, and current Inventory/Locations navigation;
- current missing-Location/Storage-Place guidance;
- reading every Item and every result created through Room Sweep, bulk movement, whole-Storage-Place movement, history, Undo, or nested hierarchy;
- full ordinary Item editing and individual movement to or from an existing nested destination, even while hierarchy structure is read-only;
- readable movement history, even when initiating extended Undo is unavailable.

The policy may disable a new Pro operation. It may not filter SwiftData, alter Search results, hide a row because of its creation origin, replace a real store with an empty one, impose an Item-count limit, or make export/recovery dependent on StoreKit.

## Existing-surface flow map

No new root destination is authorized. Implementations remain anchored to current product surfaces:

- **Inventory:** the top-level list may expose selected-Item movement through native selection mode; Search and filters remain unchanged.
- **Locations and Storage Places:** one secondary menu attached to the existing Storage Place item-list toolbar is the entry for Room Sweep and whole-place movement. Hierarchy navigation extends this existing surface without a new root destination.
- **Item Form:** Room Sweep reuses current draft semantics, validation, managed-value options, and destination language; it does not replace ordinary creation.
- **Item Detail:** history is a focused readable section or existing property/list-card surface; extended Undo is a native action and does not introduce a timeline design system.
- **Settings:** after the full activation gate passes, one `Home Stuff Pro` row may show current state and intentionally open the shared upgrade surface. Existing export, backup, restore, and other Settings rows remain Free and unchanged.

All visible implementation must use native SwiftUI navigation, sheets, toolbars, menus, forms, list selection, confirmations, semantic colors and type, SF Symbols, platform spacing, current backgrounds, and established Inventory card/hero/row/glass primitives. Preserve the palette, Search, and root Tab Bar. Do not add a custom navigation/tab bar, design system, decorative gradient, copied glass recipe, celebratory treatment, countdown, discount badge, or unrelated redesign.

## Entitlement lifecycle, offline, and failure map

Verified ownership is the authority for enabling a Pro operation. The implementation may retain only a separately specified last-known verified access state for safe offline startup; it cannot fabricate ownership from UI state, SwiftData, a user-editable preference, or a failed/unverified transaction.

| State or event | Required behavior |
|---|---|
| Entitlements loading or unavailable with no established verified ownership | Keep all Free workflows usable. Do not begin a Pro operation or mutate Pro state. Show only the implemented non-blocking contextual status when intentionally invoked. |
| Verified Lifetime Pro | Permit all five local operations after the launch gate is active. No network is required for the workflows themselves. |
| Verified active Family subscription | Permit the same local Pro operations. Sync/sharing remains a separate subscription-only policy and is not part of this bundle. |
| Offline after verified ownership was established | Preserve local Pro access under the reconciliation rules approved by the StoreKit task. Queue no server work because these five workflows are local. |
| Purchase pending | Keep the invoked context without starting the operation. Free data and navigation remain usable. Later verified success may enable continuation; pending state never grants access itself. |
| Purchase cancelled | Dismiss or return quietly to the unchanged source context; no error alert and no mutation. |
| Product load, purchase, verification, or restore failure | Show the implemented localized failure outcome and retry action where available, without changing Inventory data or blocking Free. An unverified transaction never grants access. |
| Refund or revocation | Reconcile access and disable new Pro operations when no other qualifying entitlement exists. Never hide or delete prior results or history. |
| Restore succeeds | Recompute the two independent entitlement facts from verified transactions and restore corresponding access without data migration. |
| Restore finds no qualifying purchase | Keep Free behavior and all records unchanged; do not describe this as data loss. |
| Entitlement changes during an operation | Recheck immediately before commit. A revoked operation fails atomically; previously committed operations and records remain. |
| Feature cancellation or app interruption | Follow the capability-specific atomicity rule. Never infer purchase cancellation from feature cancellation, and never leave partial batch state committed. |

StoreKit purchase/restore lifecycle and contextual presentation remain separate responsibilities. No feature view calls StoreKit directly. Restore Purchases must recover a verified lifetime license.

## Localization and accessibility gate

Every user-facing title, description, count, destination summary, button, menu
action, status, validation message, error, empty explanation, accessibility
label, and help text has English and Ukrainian values in
`HomeStuffInventoryApp/Resources/Localizable.xcstrings`. Store product display
name and price come from StoreKit localization and are never hardcoded.

Every affected flow must pass:

- Dynamic Type without clipped required actions or hidden state;
- predictable VoiceOver reading and focus order, including selection counts and preflight changes;
- explicit labels and help for icon-only controls;
- at least 44-point interactive targets;
- light and dark appearance;
- Reduce Motion, Reduce Transparency, and Increase Contrast;
- status and selection communication that does not rely on color alone.

Automated localization and focused UI coverage enforce the source catalog.
Manual visual and assistive-technology evidence remains a release blocker in
the launch-readiness gate.

## Privacy and App Store boundary

The five launch capabilities are local SwiftData workflows. They require no new account, backend, network upload, analytics, ads, tracking, CloudKit, Photos, Camera, microphone, contacts, location service, notification permission, or new sensitive-data permission. Their records remain part of the user's local Inventory and its Free export/backup/restore path.

The implementation uses StoreKit 2 for the exact non-consumable, verified
transactions, explicit Restore Purchases, entitlement updates, and cached
last-known verified lifetime ownership in the system Keychain. It sends no
inventory or transaction data to a developer backend. App Store Connect
product configuration, localized IAP metadata, review screenshot, and
submission attachment are manual maintainer-owned steps. The final release
assessment must confirm the privacy manifest and App Store privacy disclosures
still match actual behavior. Public privacy/support pages remain in their
separate public repository.

Marketing, screenshots, release notes, review notes, and support copy may describe only capabilities that pass the launch gate. They must use StoreKit-localized pricing rather than hardcode or claim a numeric price, must not advertise Family & Sync, and must not imply that any deferred Pro idea ships.

## Frozen launch gate

No upload, App Store product activation, submission, screenshot publication,
marketing claim, or release may proceed until all of the following are
complete and independently reviewed for the exact candidate:

1. this contract and the protected Free capability policy;
2. centralized independent entitlement state and per-feature access policy;
3. verified StoreKit product/transaction client and deterministic test configuration;
4. all five bundle capabilities, including atomic movement/history foundations;
5. purchase, explicit restore, entitlement reconciliation, refund/revocation, pending, cancellation, verification-failure, and offline behavior;
6. the single contextual upgrade coordinator and Settings surface, using StoreKit-localized product display name and price;
7. English and Ukrainian localization, accessibility/adaptive-state evidence, and light/dark and accessibility-setting checks for every affected flow;
8. protected Free regression evidence, data readability after downgrade, migration/legacy-store coverage, atomic failure/cancellation tests, localization tests, baseline simulator build, and focused UI flows;
9. privacy-manifest/disclosure assessment, IAP metadata and App Review notes, staged activation, release evidence, and rollback rehearsal.

Passing only StoreKit or one bundle feature does not open the gate. DEBUG/test presets must be unavailable from release UI. App Store Connect upload or deployment still requires explicit maintainer authorization.

## Schema compatibility, release, and rollback

The implemented movement/history and hierarchy models use backward-compatible
schemas and migrations for existing Items and exact `containerName`
compatibility values. Room Sweep results use ordinary Item data. Persisted
additions remain covered by versioned readable export, backup, restore, and
legacy-store tests.

Activation is staged only after the frozen launch gate passes. A rollback may hide or disable new Pro operation entry points and purchase presentation in a follow-up release. It must not:

- delete or hide Items, Storage Place relationships, movement records, history, or ownership evidence;
- disable ordinary Free creation, movement, Search, browse, export, backup, restore, or recovery;
- make prior Pro-created content unreadable;
- silently downgrade or destructively rewrite the persistence schema;
- prevent a valid lifetime purchase from being restorable when the purchase path returns.

Any persisted schema that an older rollback build cannot safely read blocks
that rollback build. Roll forward with entry points disabled unless a
compatible reader or migration is independently reviewed.

## Explicitly deferred and not authorized

Everything outside the five-item matrix is deferred. In particular, this contract does **not** authorize:

- QR labels, QR scanning, barcodes, deep links for labels, or printable label workflows;
- Spotlight, Siri, App Intents, Shortcuts, widgets, controls, or reminders;
- Item or Storage Place photos, Camera or Photos access, OCR, scanning, or AI identification/categorization;
- temporary-away, lent, borrowed, repair, reservation, due-date, or notification workflows;
- consumable quantity history, low-stock tracking, shopping lists, replenishment, price tracking, or reports;
- configurable/advanced exports beyond the protected readable export, backup, and recovery paths;
- arbitrary bulk edit, bulk delete, merge, spreadsheet/grid editing, templates, or automation;
- unlimited history, audit logs, history editing/deletion, warehouse/employee checkout, procurement, insurance, marketplace, or enterprise features;
- Free trials, feature allowances, introductory offers, discounts, pricing experiments, promo codes, or a hard/first-launch paywall;
- a separate paid application, new Bundle ID, account system, custom backend, analytics, ads, or tracking;
- CloudKit, personal sync, Family & Sync purchase, household sharing, invitations, roles, permissions, or subscription comparison/presentation;
- App Store Connect creation, deployment/upload, or public marketing/legal/support publication;
- changes to the current palette, Search, root Tab Bar, navigation architecture, or unrelated screens.

A deferred idea requires its own approved contract and implementation issue. It cannot enter the bundle through refactoring, convenience scope, test fixtures, placeholder UI, App Store copy, or paywall marketing.

## Change control

Adding, removing, combining, renaming, or changing the entitlement of a launch capability is a product decision. It requires an explicit approved change updating the monetization model, this contract, the Free adjacency review, entitlement mapping, data/downgrade behavior, localization/accessibility scope, privacy/App Store impact, release evidence, and rollback plan.

Implementation PRs may make only the behavior listed for their capability and must preserve unspecified appearance and behavior. If a task cannot implement this contract as written, it must stop for approval rather than choose an alternative.
