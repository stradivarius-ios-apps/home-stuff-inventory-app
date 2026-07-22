# Portability and Recovery File Contract

Status: Canonical repository contract; version 2 implementation shipped

Parent sub-epic: historical task #386

Parent epic: historical task #380

Implementation task: historical task #389

## Purpose and scope

This document defines the local, versioned file boundary for Home Stuff Inventory portability and recovery. It is the source of truth for the shipped version 2 readable export, complete backup, compatible restore, and their fixtures. Version 1 fixtures remain supported legacy inputs. The contract itself remains implementation-independent; production owners are `InventoryReadableExportService`, `InventoryBackupService`, `InventoryBackupRestoreService`, `InventoryBackupRecoveryStore`, and the Settings file/share surfaces.

The [Free Capability Contract](../product/free-capability-contract.md) classifies readable export, complete backup, and compatible restore as protected Free capabilities. They never require an entitlement, an account, or a network connection. A missing, expired, refunded, or unavailable entitlement cannot remove fields, records, or recovery access.

Two artifacts use the same envelope but serve different purposes:

| `artifactType` | Purpose | Required contents |
|---|---|---|
| `readableExport` | A stable, pretty-printed copy a person can inspect or process with ordinary JSON tools | Every user-authored Item field, reusable Location and custom Category value, stable ID, and relationship; no interaction history |
| `completeBackup` | A lossless machine-restorable snapshot | Everything in `readableExport`, plus all persisted recent Item-view events and any future restorable record introduced by a schema version |

A readable export is not accepted by restore. This prevents a deliberately reduced artifact from being mistaken for a complete backup. Only `completeBackup` can enter the restore pipeline.

## File and envelope

The extension is `.json`. A producer writes UTF-8 without a byte-order mark, uses JSON strings for all identifiers and dates, escapes control characters, and emits a trailing newline. A readable export is pretty-printed with two-space indentation. A complete backup may be pretty-printed or compact; whitespace is not significant.

The root object has exactly these schema-owned fields:

```json
{
  "formatIdentifier": "com.stradivarius23.home-stuff-inventory.portability",
  "artifactType": "completeBackup",
    "schemaVersion": 2,
  "integrity": {
    "algorithm": "SHA-256",
    "canonicalization": "RFC8785",
    "digest": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  },
  "metadata": {
    "createdAt": "2026-07-14T09:30:00.000Z",
    "appVersion": "1.0.0",
    "appBuild": "100",
    "platform": "iOS"
  },
  "inventory": {
    "locations": [],
    "customCategories": [],
    "items": [],
    "places": [],
    "recentItemViewEvents": []
  }
}
```

`formatIdentifier`, `artifactType`, `schemaVersion`, `integrity`, `metadata`, and `inventory` are required. `schemaVersion` is an integer. Version `2` is the current emitted version. Producers must never emit version `0`. The `places` collection is required only for a version 2 `completeBackup`; readable export intentionally remains name-centered and does not carry reusable Place metadata.

### Integrity envelope

Every version `1` and version `2` artifact has an `integrity` object with exactly three required string fields:

| Field | Version 1 and 2 value |
|---|---|
| `algorithm` | `SHA-256` |
| `canonicalization` | `RFC8785`, the JSON Canonicalization Scheme defined by RFC 8785 |
| `digest` | 64 lowercase hexadecimal characters containing the 32-byte SHA-256 result |

The digest scope is the entire root JSON object with the root `integrity` member omitted. No other field is omitted. The producer constructs that object in memory, canonicalizes it according to RFC 8785, encodes the canonical text as UTF-8 with no byte-order mark or trailing newline, computes SHA-256 over exactly those bytes, inserts the `integrity` object, and only then applies optional pretty-printing to the complete file. Whitespace and object-member order in the stored file therefore do not affect verification; every value and unknown member inside the digest scope does.

A supported reader validates the descriptor values and lowercase digest syntax, removes only the root `integrity` member, repeats the same canonicalization and hash, and compares all 32 digest bytes. `invalidIntegrity` covers a missing/malformed descriptor or unsupported algorithm/canonicalization. `integrityMismatch` covers a well-formed descriptor whose digest does not match. Neither result permits record decoding or mutation.

The input-only version `0` compatibility profile predates this integrity envelope and may omit it. Its entire schema is validated before migration and it receives a version `2` integrity envelope whenever it is subsequently written as a new backup. Future versions must retain this envelope or define their replacement before implementation; the backup implementation issue historical task #392 consumes this exact algorithm and byte scope.

Metadata describes the producer and is not restored into SwiftData:

| Field | Type | Rule |
|---|---|---|
| `createdAt` | string | Required UTC timestamp using the date rule below |
| `appVersion` | string | Required source `CFBundleShortVersionString`; informational, not a compatibility decision |
| `appBuild` | string | Required source `CFBundleVersion`; informational, not a compatibility decision |
| `platform` | string | Required and currently `iOS`; informational |

Device name, account data, locale, file path, and hardware identifiers must not be recorded. Compatibility is determined only by `formatIdentifier`, `artifactType`, and `schemaVersion`, never by app version or build.

## Version 2 inventory schema

All UUIDs use canonical lowercase `8-4-4-4-12` text. A producer preserves persisted IDs and never regenerates them during export or backup. A restore preserves those IDs. Duplicate IDs within or across record collections are invalid.

All dates are UTC RFC 3339 strings with exactly three fractional-second digits: `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`. Dates represent an instant, not the exporting device's time zone. `updatedAt` must not precede `createdAt`.

Required string fields may be empty only where the current model supports a missing value. Optional fields may be omitted or `null`; readers treat both as `nil`. Required fields that are missing or `null` are invalid. JSON numbers must be finite integers where an integer is specified. Strings and arrays are preserved exactly unless a rule below explicitly requires normalization.

### Locations

`inventory.locations` contains every `StorageLocation` record:

```json
{
  "id": "10000000-0000-0000-0000-000000000001",
  "name": "Home",
  "iconID": "house",
  "notes": "Main residence",
  "createdAt": "2026-07-01T08:00:00.000Z",
  "updatedAt": "2026-07-02T08:00:00.000Z"
}
```

`id`, `name`, `notes`, `createdAt`, and `updatedAt` are required. `name` must contain a non-whitespace character. `iconID` is optional and preserves the persisted catalog identifier. Location names must be unique under the app's existing location comparison rules; ambiguous reusable values are invalid.

### Custom categories

`inventory.customCategories` contains every `InventoryCustomCategory` record:

```json
{
  "id": "20000000-0000-0000-0000-000000000001",
  "name": "Keepsakes",
  "createdAt": "2026-07-01T08:00:00.000Z",
  "updatedAt": "2026-07-02T08:00:00.000Z"
}
```

All fields are required. `name` must contain a non-whitespace character. Custom Category names must be unique under the app's existing Category comparison rules and cannot collide with a built-in Category or one of its shipped English/Ukrainian aliases.

### Items and string-backed relationships

`inventory.items` contains every `InventoryItem` record:

```json
{
  "id": "30000000-0000-0000-0000-000000000001",
  "name": "USB-C cable",
  "categoryStorageValue": "cablesAndAdapters",
  "customCategoryID": null,
  "locationName": "Home",
  "locationID": "10000000-0000-0000-0000-000000000001",
  "placeName": "Desk drawer",
  "placeID": "50000000-0000-0000-0000-000000000001",
  "iconID": "cable.connector",
  "quantity": 2,
  "conditionStorageValue": "good",
  "tags": ["USB-C", "spare"],
  "notes": "1 m braided cable",
  "createdAt": "2026-07-01T08:00:00.000Z",
  "updatedAt": "2026-07-02T08:00:00.000Z"
}
```

All fields except `customCategoryID`, `locationID`, `placeName`, `placeID`, and `iconID` are required.

- `name` must contain a non-whitespace character.
- `categoryStorageValue` preserves `InventoryItem.category`. A built-in Category uses its stable raw value, such as `tools`. A custom Category uses its name and supplies the matching `customCategoryID`. Unknown persisted values remain readable and recoverable; they are not silently replaced with `miscellaneous`.
- `customCategoryID` is required for a Category matching a reusable custom Category and must reference a record whose name matches `categoryStorageValue` under existing comparison rules. It is `null` for built-in or unmatched legacy values.
- `locationName` preserves `InventoryItem.locationName` and may be empty for an Item whose Location is missing.
- `locationID` references the unique reusable Location matching `locationName`. It is required when such a Location exists and is `null` when `locationName` is empty or represents an unmatched legacy value. A non-null reference and name must agree.
- `placeName` maps to the persisted compatibility field `containerName`. A `completeBackup` writes the persisted value exactly, including an empty or whitespace-only legacy string, and writes `null` only when `containerName` is `nil`; restore writes that exact value back. A non-restorable `readableExport` may trim the display value and write `null` when the result is empty.
- `placeID` is optional compatibility linkage to a reusable Place. When present it must reference a Place in the same backup, whose parent `locationID` equals the Item `locationID` and whose normalized name equals `placeName`; no restore may bind an Item to a same-named Place in a different Location.
- `quantity` is an integer of at least `1`.
- `conditionStorageValue` preserves `InventoryItem.condition`. Built-in values use their stable raw values (`new`, `good`, `worn`, `needsRepair`, or `unknown`). An unmatched legacy value remains readable and recoverable.
- `tags` preserves the persisted display spelling and order. Empty or whitespace-only tags and duplicates under `InventoryTagNormalization` are invalid.
- `notes` is required and may be empty.

### Places

`inventory.places` is required for a version 2 `completeBackup` and contains every reusable `InventoryPlace` record. It is excluded from readable export.

```json
{
  "id": "50000000-0000-0000-0000-000000000001",
  "locationID": "10000000-0000-0000-0000-000000000001",
  "name": "Desk drawer",
  "iconID": "drawer",
  "createdAt": "2026-07-01T08:00:00.000Z",
  "updatedAt": "2026-07-02T08:00:00.000Z"
}
```

All Place fields are required. `locationID` must reference a Location. The normalized `(locationID, name)` pair must be unique, while equal names under different Locations remain distinct. `iconID` is a normalized member of `PlaceIconCatalog`; invalid IDs are rejected at the portable boundary. Restore creates Locations, then Places, then Item links. Stable ID references coexist with compatibility names: rollback to an older binary leaves `locationName` and `containerName` readable even though that binary does not understand the additive Place model.

### Recent Item-view events

`recentItemViewEvents` is required for `completeBackup` and forbidden for `readableExport`. It contains every persisted `InventoryItemViewEvent`:

```json
{
  "id": "40000000-0000-0000-0000-000000000001",
  "itemID": "30000000-0000-0000-0000-000000000001",
  "viewedAt": "2026-07-03T08:00:00.000Z"
}
```

All fields are required. `itemID` must reference an Item in the same backup. An orphan event is invalid. Readable export intentionally excludes local interaction history while retaining all user-authored inventory content.

## Deterministic ordering

Object member order is not semantically significant. Producers should use the example order for readable diffs. Collection order is not a relationship and restores must not infer UI order from it.

For deterministic output, `locations`, `customCategories`, `places`, and `items` sort by lowercase UUID text ascending. `recentItemViewEvents` sort by `viewedAt` ascending, then lowercase UUID text ascending. `tags` retain their persisted user-visible order. Readers accept any collection order and detect duplicates independently of adjacency.

## Validation and failure rules

Validation is read-only and completes before any persistent-store mutation. It proceeds in this order:

1. read bytes without changing Inventory;
2. require valid UTF-8 and one complete JSON root object, rejecting malformed, truncated, or trailing non-whitespace content;
3. validate `formatIdentifier`, then `artifactType`, then the integer `schemaVersion`; reject an unsupported newer version before interpreting its integrity or records;
4. for supported versions `1` and `2`, validate the integrity descriptor and digest before decoding `metadata`, `inventory`, or any record; version `0` follows its fully specified legacy validation path;
5. validate required fields, JSON types, UUIDs, dates, value invariants, and artifact-specific collections;
6. build complete ID indexes and reject every duplicate, dangling reference, name/reference mismatch, ambiguous reusable name, and orphan event;
7. calculate the space needed for the staged store and pre-restore safety copy;
8. report one deterministic failure result and leave the live store byte-for-byte and logically unchanged.

Duplicate IDs are never merged, overwritten, or regenerated. Malformed or truncated input is never partially decoded. A readable export, an unsupported schema, or a backup with any invalid record is never partially restored. There is no best-effort mode and no silent fallback to an empty Inventory.

Unknown metadata members may be ignored. Unknown members inside `inventory` or any restorable record are rejected because silently discarding possible user-owned data would make a round trip lossy. A future producer must increment `schemaVersion` before adding restorable collections or record fields. This rule makes unknown-data handling explicit rather than dependent on decoder defaults.

Implementations may apply defensive file-size, nesting, or record-count limits, but exceeding a limit is a non-mutating validation failure. Limits must be documented, deterministic, and large enough for unlimited Free Items; they cannot act as monetization gates.

The service boundary returns exactly one terminal outcome:

| Outcome | Meaning |
|---|---|
| `success` | The requested export/backup file is durable, or restore committed, reopened, and verified the complete candidate store |
| `cancelled` | Cancellation was accepted before the commit boundary; no live Inventory mutation occurred |
| `invalidEncoding` | Input is not UTF-8 as specified |
| `malformedJSON` | JSON is truncated, malformed, has trailing content, or has no complete root object |
| `wrongFormat` | `formatIdentifier` is not this contract's identifier |
| `wrongArtifactType` | The artifact is recognized but is not permitted for the requested operation |
| `unsupportedNewerVersion` | The integer schema version is newer than the installed reader |
| `invalidIntegrity` | A supported schema requires integrity data but its descriptor or digest syntax is missing, malformed, or unsupported |
| `integrityMismatch` | The recomputed digest differs from the well-formed stored digest |
| `invalidSchema` | A required field, value, ID, date, or relationship is invalid |
| `generationFailed` | Export/backup snapshotting, deterministic ordering, JSON encoding, canonicalization, or digest generation failed before destination commit |
| `lowStorage` | Required safety-copy and staging capacity is unavailable |
| `destinationWriteFailed` | A non-capacity filesystem, permission, coordination, close, sync, or destination-replacement failure prevented a durable export/backup |
| `safetyCopyFailed` | A durable and validated pre-restore backup could not be created |
| `stagingFailed` | Candidate construction or verification failed before commit |
| `recoveryRequired` | Commit/reopen verification failed and automatic recovery could not select a verified store |

Validation order defines failure precedence, so the same bytes and supported reader version produce the same outcome. Diagnostic detail may identify a field or record but must not expose private inventory content to analytics or logs. There is no outcome that reports success after a partial export, partial backup, or unverified restore.

## Compatibility and schema evolution

The version matrix is normative:

| Input | Version 2 reader behavior |
|---|---|
| Version `1` readable export | Read/inspect/export only; reject restore because it is intentionally incomplete |
| Version `1` complete backup | Verify, deterministically synthesize scoped default-icon Places and Item links, then restore atomically |
| Version `2` complete backup | Validate and restore Place IDs, parent IDs, icons, and Item links atomically |
| Version `0` legacy backup | Validate, migrate in memory to version `2` with scoped Places and links, then use the normal atomic restore path |
| Version greater than `2` | Reject as `unsupportedNewerVersion`; preserve the file and current Inventory unchanged |
| Negative, fractional, string, or missing version | Reject as malformed |

Versions `0` and `1` are input-only compatibility profiles for the former string-backed Place model. Their fixtures retain the former shape; after integrity validation where available, restore preserves Item text and deterministically creates one default-box Place per normalized Location+Place scope, never merging equal names across Locations. Missing Location or Place remains unlinked. The migration must not mutate the live store and a producer must never emit version `0` or `1`.

Every future schema version must document:

- its new and changed fields, migration to the then-current model, and whether downgrade readers reject it;
- whether fields are user-authored, reusable, derived, or interaction history;
- validation, relationship, ordering, and rollback behavior;
- deterministic fixtures for success, malformed input, and unsupported-newer input.

Backward readers may migrate older supported backups. Older readers always reject newer versions before mutation. A newer app may continue to emit an older version only when it can do so without dropping or transforming user-owned data.

Premium-created fields and records remain visible, readable, and included in readable export and complete backup after downgrade. Entitlement may stop separately approved premium creation or automation, but it never controls decoding, queries, serialization, validation, restore, or migration. If an installed version understands a field, absence of entitlement is not a reason to omit it. If an older version does not understand the schema, it rejects the whole restore rather than deleting the field.

## Atomic restore, recovery, and cancellation

Export and backup first capture one internally consistent snapshot, deterministically order and encode it, compute and self-verify its integrity envelope, and write a temporary file beside the selected destination. They do not expose or replace the destination until encoding is complete. Cancellation is accepted through snapshotting, encoding, digest generation, and temporary-file writing; it removes only the incomplete temporary file. Once destination commit begins, cancellation is deferred. Success is reported only after the file is closed, its contents are durably synchronized, it is atomically moved/replaced at the destination, required directory metadata is synchronized where the platform supports it, and the committed file can be reopened and pass integrity verification. Capacity exhaustion returns `lowStorage`; all other destination/durability failures return `destinationWriteFailed`, preserve any prior destination, and never report a partial file as success.

After validation succeeds, restore follows one transaction boundary:

1. verify there is enough local storage for the original live store, a durable complete pre-restore safety backup, a staged restored store, and normal filesystem overhead;
2. create and validate the safety backup using the current supported `completeBackup` schema and a separate durable snapshot of local Place-open history, preserving both at a recovery location before staging mutations;
3. construct the candidate store in an isolated temporary location, migrate in memory where required, and validate its record counts, IDs, relationships, and ability to reopen;
4. keep the live store available and unchanged until the candidate and safety backup are durable;
5. atomically replace or switch the live store, then reopen and verify it before reporting success;
6. retain the durable safety backup in the app recovery directory for interruption recovery; cleanup failure cannot invalidate a successful restore.

Low storage before the commit boundary is a failure with no live-store mutation. The app must not delete the current store, safety backup, user-selected input, or unrelated files to make room. A low-storage or write failure while staging removes only incomplete temporary artifacts when safe.

Cancellation is accepted during reading, validation, safety-copy creation, and staging. It removes incomplete temporary artifacts and leaves the live store unchanged. Once the atomic commit begins, cancellation is deferred until reopen verification finishes; the result is then success or a recovered failure, never a half-committed state.

After interruption or crash, startup selects only a store that passed the commit marker and reopen validation. If the new store cannot be verified, it restores the durable pre-restore safety copy and its paired local Place-open-history snapshot. A verified candidate intentionally resets that local personalization because it is not portable Inventory content. It never substitutes an empty store. Failure to recover either candidate is surfaced as a recovery-required state while preserving all available files for explicit action.

## Fixtures and expected outcomes

Fixtures live in [`portability-recovery-v1/`](portability-recovery-v1/README.md):

| Fixture | Expected result |
|---|---|
| `empty-readable-export-v1.json` | Valid readable export; zero user records; not restorable |
| `ordinary-complete-backup-v1.json` | Valid complete backup with reusable values, relationships, and a view event |
| `unicode-readable-export-v1.json` | Valid readable export preserving English, Ukrainian, emoji, diacritics, and JSON escapes |
| `legacy-compatible-backup-v0.json` | Valid input-only legacy backup; deterministic in-memory migration to version `2` |
| `malformed-truncated-backup.json` | Invalid/truncated JSON; reject before schema validation or mutation |
| `unsupported-newer-backup-v2.json` | Historical filename; well-formed recognized backup with unsupported schema version 3, rejected before record decoding or mutation |

Fixtures use fixed IDs and timestamps and must not be rewritten with generated values.

## Privacy, release, and rollback

The shipped workflows are local-only and add no account, network request, analytics, tracking, or sensitive-device permission. They use user-selected destinations/sources or the system share surface. Backups contain private household data and are not uploaded by the app; any destination or recipient chosen in the system UI is controlled by the user.

Readable export shipped through historical task #391, complete backup through historical task #392, and compatible atomic restore through historical task #393. A future rollback may disable new premium creation or automation, but must keep readable export, complete backup, compatible restore, local Inventory access, and all understood premium-created data available. Once a schema is emitted in production, its reader and recovery path cannot be removed without an explicit migration and product decision.
