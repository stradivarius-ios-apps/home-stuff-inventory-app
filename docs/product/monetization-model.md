# Home Stuff Inventory Monetization Model

Status: Approved product concept; premium implementation deferred; protected Free portability implemented
Parent epic: historical task #380
Initialization task: historical task #381

## Purpose

This document records the approved monetization and premium-access model for Home Stuff Inventory before StoreKit, paywalls, CloudKit, subscriptions, or premium features are implemented. The protected Free core, including readable export, complete manual backup, and compatible atomic restore, is implemented independently of that deferred premium work.

It is a product and architecture guardrail. Its StoreKit, paywall, CloudKit, subscription, and premium-feature sections describe deferred functionality and do not authorize implementation by themselves; the Free core section describes the protected behavior already present in the repository. Every future premium capability requires a separate issue with explicit product behavior, data rules, privacy impact, localization, accessibility, validation, and release scope.

## Product decision

Home Stuff Inventory remains one iOS application with:

- one existing Bundle ID: `com.stradivarius23.HomeStuffInventoryApp`;
- one App Store listing;
- one codebase;
- one compatible inventory data model;
- one upgrade path inside the existing application.

Do not create a separate `Home Stuff Pro` application.

The planned product structure is:

```text
Home Stuff Inventory
├── Free core
├── Home Stuff Pro — one-time lifetime unlock
└── Family & Sync — future auto-renewable subscription
```

The structural decision is approved. The premium features, StoreKit products, prices, and rollout dates remain unimplemented until separately approved.

## Guiding principles

Home Stuff Inventory is a private, location-first household utility built around one primary question:

> Where did I put this thing?

Monetization must preserve that value rather than weaken it.

The model follows these principles:

1. The user must not feel that they are renting access to their own local inventory.
2. The free product must remain a useful and complete location-first inventory utility.
3. Payment unlocks advanced workflows or continuing services, not ownership of user-created data.
4. Advanced local functionality is appropriate for a one-time lifetime purchase.
5. Recurring payment is reserved for genuine continuing value, specifically sync and household sharing.
6. Premium access must not be embedded into core inventory persistence, search, or data ownership rules.
7. Downgrade and expiry behavior must be safe, predictable, and non-destructive.
8. Paywalls should appear in context after the user understands the feature value.
9. Deferred features must never be advertised as shipped before they are implemented and reviewed.
10. Every future monetization change must preserve the English and Ukrainian product experience.

## Free core contract

The Free tier must continue to answer the core product question without requiring payment, an account, or network access.

At minimum, Free retains:

- unlimited basic Items;
- Locations and Places;
- add, edit, and delete flows;
- ordinary relocation of one Item;
- local Search across supported item and storage fields;
- Category and Location filters;
- the complete `Location → Place → Item` browsing flow;
- basic Notes, Tags, Quantity, Condition, icons, and reusable-value management;
- basic guidance for Items that have no Location or no exact Place;
- access to every existing personal inventory record;
- a safe manual complete backup, compatible atomic restore, and readable JSON export path.

The following are not valid premium gates:

- Search;
- ordinary Place use;
- ordinary single-item movement;
- viewing existing records;
- editing the user's personal local inventory;
- reading content created while premium access was active;
- exporting or recovering user-owned data;
- a retroactive Item-count limit for the current product.

Free may show discoverable premium actions, but invoking those actions must never corrupt, hide, or reduce existing free data.

## Home Stuff Pro — lifetime unlock

`Home Stuff Pro` is planned as a non-consumable In-App Purchase inside the existing application.

It represents advanced local workflows whose value does not depend on an ongoing hosted service. A valid lifetime purchase permanently grants local Pro access for the purchasing Apple account under StoreKit rules.

Potential Home Stuff Pro scope includes:

- Room Sweep and rapid batch capture;
- bulk Item movement;
- moving the contents of an entire Place;
- movement history and extended Undo;
- advanced Inventory Inbox and batch cleanup;
- QR labels for Places;
- Spotlight, Siri, App Intents, and Shortcuts integrations;
- Item and Place photos;
- temporary-away, lent, and repair workflows;
- optional consumable quantity tracking and low-stock tools;
- advanced reports and configurable exports.

This list defines the intended boundary between basic inventory and advanced local workflows. It is not an implementation checklist. Each capability requires a separate product task before work begins.

Lifetime Pro must not be launched as a payment for one minor convenience. The initial Pro release should contain a coherent bundle with clear user value.

The exact initial bundle, protected Free adjacency, release gate, and rollback contract are now frozen in the canonical [Home Stuff Pro launch-bundle contract](pro-launch-bundle-contract.md). Capabilities listed here but omitted from that five-capability launch contract remain deferred and are not authorized for implementation or marketing.

## Family & Sync — future subscription

`Family & Sync` is planned as a future auto-renewable subscription inside the same application.

A subscription is appropriate only after the product provides reliable continuing service value. It must not be introduced merely to rent local features that could function indefinitely on-device.

The future subscription is expected to include:

- all Home Stuff Pro capabilities while the subscription is active;
- private synchronization between the user's devices;
- shared household inventory;
- shared Locations, Places, and Items;
- participant and permission management;
- offline-first synchronization;
- conflict handling and recovery;
- safe and understandable expiry behavior.

Personal sync must be stable before shared household work begins. The subscription must not be created in App Store Connect until sync architecture, privacy implications, data ownership, expiry behavior, and App Review scope are separately approved.

The annual plan should be the primary subscription presentation. A monthly option may exist as a lower-commitment alternative, not as the main product proposition.

## Entitlement model

Do not represent monetization with one ambiguous `isPremium` flag.

Future implementation should model at least two independent facts:

- whether the user owns the non-consumable Lifetime Pro purchase;
- whether the user has an active Family & Sync subscription.

The intended access matrix is:

| State | Local Pro features | Sync | Shared household |
|---|---:|---:|---:|
| Free | No | No | No |
| Lifetime Pro | Yes | No | No |
| Active Family & Sync subscription | Yes | Yes | Yes |
| Lifetime Pro and active subscription | Yes | Yes | Yes |
| Subscription expired, Lifetime Pro owned | Yes | No | No |
| Subscription expired, no Lifetime Pro | No | No | No |

Conceptually:

```swift
struct InventoryEntitlements: Equatable {
    var ownsLifetimePro: Bool
    var hasActiveFamilySubscription: Bool

    var hasLocalProFeatures: Bool {
        ownsLifetimePro || hasActiveFamilySubscription
    }

    var hasSyncAndSharing: Bool {
        hasActiveFamilySubscription
    }
}
```

This example communicates the access relationship only. It is not approved production code or a required final API.

## Data ownership and downgrade safety

A paywall, cancelled purchase, billing issue, refund, or expired subscription must never delete or hide user-created data.

Future implementation must preserve these rules:

- no Item, Location, Place, photo, movement record, quantity record, backup, or shared record is deleted only because access changes;
- existing records remain readable;
- the user's personal local inventory remains usable;
- export and recovery remain available;
- content created through a premium workflow remains visible after downgrade;
- creation, automation, bulk operations, or ongoing services may be disabled when entitlement is absent;
- restoring a valid purchase restores corresponding access without requiring a destructive migration;
- loss of network access must not make the local personal inventory unusable;
- subscription expiry must not silently replace the user's real inventory with an empty store.

Family & Sync expiry requires a separate detailed contract before implementation. That contract must define:

- the local snapshot retained on each device;
- read-only versus editable shared content;
- pending local changes;
- ownership of shared records;
- participant removal;
- household owner expiry;
- reactivation behavior;
- export or copy-to-personal options;
- conflict resolution after reactivation.

## Paywall experience principles

The default model is contextual freemium, not a first-launch hard paywall.

A future paywall should appear when the user:

- intentionally invokes a premium workflow;
- exceeds a clearly communicated free allowance for a premium feature trial;
- opens the upgrade surface in Settings;
- enables sync;
- attempts to create or join a shared household.

A future paywall must:

- explain the concrete result of the selected feature;
- distinguish Lifetime Pro from Family & Sync;
- use StoreKit-localized product names, periods, and prices;
- clearly identify recurring billing;
- provide Restore Purchases;
- provide Manage Subscription when applicable;
- support English and Ukrainian;
- support Dynamic Type, VoiceOver, light and dark appearances, Reduce Motion, Reduce Transparency, and Increase Contrast;
- handle purchase success, cancellation, pending approval, verification failure, restore, refund, expiry, and offline states.

A paywall must not interrupt:

- first launch;
- creation of the first basic Item;
- basic Search;
- opening existing inventory;
- ordinary single-item movement;
- access to recovery or export.

Paywall copy should describe the outcome, for example `Move several items at once`, rather than relying on vague labels such as `Unlock Premium`.

## Future technical architecture direction

When implementation is separately approved, use StoreKit 2 in the existing application.

Expected responsibility boundaries include:

```text
Monetization/
  StoreProductID
  StoreKitClient
  StoreKitEntitlementService
  InventoryEntitlements
  PremiumFeature
  PremiumAccessPolicy
  PaywallContext
```

The exact file names and types remain subject to implementation design, but the separation of concerns is required:

- StoreKit integration loads products, performs purchases, observes updates, restores purchases, and validates transactions;
- entitlement state derives from verified StoreKit transactions rather than a user-editable local boolean;
- a centralized access policy maps entitlements to premium capabilities;
- contextual paywall coordination remains separate from inventory business logic;
- inventory models do not know about prices, products, or paywall presentation;
- Search and persistence do not silently omit records because of entitlement state;
- deterministic StoreKit configuration and DEBUG test states support UI and integration testing;
- focused tests use abstractions or test StoreKit sessions rather than requiring live purchases.

Future premium capability checks should express a specific feature, such as `bulkMove` or `householdSharing`, rather than a broad premium boolean scattered throughout SwiftUI views.

## Privacy and release implications

The current application is local-only and declares no developer-side data collection. The concept document does not change that shipped behavior.

Every future capability must re-evaluate privacy, permissions, entitlements, App Store metadata, and release evidence.

Examples:

- StoreKit requires In-App Purchase configuration, purchase restoration, review notes, and accurate premium metadata;
- CloudKit changes the current no-cloud product behavior and requires a data-flow, privacy, migration, conflict, and recovery review;
- Photos or Camera require permission timing, usage descriptions, local storage rules, and App Store privacy review;
- Spotlight, Siri, App Intents, and Shortcuts require an explicit decision about which inventory fields may leave the app's own UI surface;
- QR scanning requires Camera permission and safe deep-link handling;
- notifications require permission timing and a clear user-controlled purpose;
- arbitrary import and configurable export require separate versioned formats, validation, rollback, and safe treatment of user-selected files; the protected readable export and complete backup/restore format already ship under the portability contract.

App Store screenshots, promotional text, release notes, privacy disclosures, and support documentation must not claim any premium or cloud capability before it is shipped.

## Rollout direction

The approved high-level sequence is:

### Phase 0 — concept initialization

- document this product model;
- create no feature implementation tasks yet;
- make no application or App Store Connect changes.

### Phase 1 — future StoreKit foundation

- define products and entitlement semantics;
- introduce StoreKit 2 infrastructure without gating existing behavior;
- provide restore and deterministic test support;
- verify safe startup and offline behavior.

### Phase 2 — coherent Lifetime Pro launch

- select a valuable initial local feature bundle;
- implement each feature through a separate issue and PR;
- add contextual paywalls only when the bundle is ready;
- preserve the Free core contract.

### Phase 3 — local Pro expansion

- add independently reviewed advanced local workflows;
- maintain compatibility and non-destructive downgrade behavior.

### Phase 4 — personal sync

- design and validate CloudKit-based personal sync separately;
- define migrations, conflict resolution, offline behavior, recovery, and observability;
- do not introduce household sharing before personal sync is stable.

### Phase 5 — Family & Sync subscription

- create subscription products only after ongoing sync value exists;
- implement subscription lifecycle and expiry behavior;
- validate StoreKit and CloudKit interaction.

### Phase 6 — shared household

- define household ownership, invitations, roles, removal, transfer, expiry, and recovery;
- preserve export and local access safeguards.

## Initial pricing hypotheses

The initial planning hypotheses are:

```text
Home Stuff Pro Lifetime: USD 19.99 equivalent tier
Family & Sync Annual: USD 14.99 equivalent tier
Optional monthly alternative: approximately USD 2.99 equivalent tier
```

These values:

- are not committed launch prices;
- do not authorize App Store Connect product creation;
- require regional tier review and product-value validation;
- may be revised before implementation or submission;
- must never be hardcoded into application copy.

The application must display StoreKit-localized pricing when products exist.

## Non-goals

This concept does not authorize:

- a separate paid application;
- a new Bundle ID;
- a hard first-launch paywall;
- a retroactive Item-count limit;
- StoreKit implementation;
- App Store Connect product creation;
- CloudKit or account infrastructure;
- household sharing;
- premium feature implementation;
- UI redesign;
- analytics, ads, or tracking;
- changing the current privacy claims;
- changing App Store metadata to advertise deferred features;
- adding public legal or support pages to the private source repository.

A future business or warehouse product with employees, asset checkout, procurement, audit logs, or a web dashboard would be a different product decision and is outside Home Stuff Inventory's personal household scope.

## Decisions intentionally deferred

The following require later product and technical decisions:

- free trials or feature allowances;
- final product identifiers;
- final App Store price tiers;
- introductory or promotional subscription offers;
- StoreKit Family Sharing configuration;
- whether monthly Family & Sync is offered at launch;
- personal sync data model and migration;
- household identity, ownership, roles, and invitation model;
- refund and revocation UX;
- grace-period and billing-retry behavior;
- subscription expiry behavior for shared households;
- premium feature availability across future Apple platforms;
- telemetry strategy, if any, under the privacy-first model.

No deferred decision should be resolved implicitly inside an unrelated feature PR.

## Requirements for future issues

Every future monetization or premium-capability issue must include:

- the exact user problem and expected value;
- whether the capability belongs to Free, Lifetime Pro, or Family & Sync;
- entitlement and downgrade behavior;
- data ownership and migration rules;
- offline and failure behavior;
- privacy and permission impact;
- English and Ukrainian localization scope;
- accessibility and adaptive-layout requirements;
- App Store metadata and review impact;
- deterministic testing strategy;
- release and rollback plan;
- explicit non-goals;
- a focused PR boundary.

A future issue may refine this concept only when the change is deliberate, documented, and approved. It must not silently weaken the Free core or data-ownership guarantees.
