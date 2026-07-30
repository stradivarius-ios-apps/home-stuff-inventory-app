# Portability and Recovery Fixtures

These deterministic files exercise the canonical [Portability and Recovery File Contract](../portability-recovery-contract.md) and the shipped version 1 codecs, readable export, backup, migration, and restore tests. The files remain immutable documentation/test inputs; production file I/O and restore live under `HomeStuffInventoryApp/InventoryLogic/` and `HomeStuffInventoryApp/Views/Settings/`.

Every well-formed version 1 fixture carries the contract's RFC 8785 / SHA-256 integrity envelope. The lowercase digest covers the RFC 8785 canonical UTF-8 bytes of the complete root object with only the root `integrity` member omitted. Version 0 may omit integrity by compatibility rule; the malformed fixture cannot reach integrity validation; the unsupported version 2 fixture is rejected by version precedence before its illustrative future envelope is interpreted.

| File | Expected classification |
|---|---|
| `empty-readable-export-v1.json` | valid version 1 readable export; restore rejects the artifact type |
| `ordinary-complete-backup-v1.json` | valid and restorable version 1 complete backup |
| `unicode-readable-export-v1.json` | valid version 1 readable export with lossless EN/UK/Unicode content |
| `legacy-compatible-backup-v0.json` | valid input-only version 0 backup; migrate in memory before restore |
| `malformed-truncated-backup.json` | invalid JSON; reject without mutation |
| `unsupported-newer-backup-v2.json` | Historical filename; valid JSON and recognized format with schema version 4, rejected without decoding records or mutation |

Validate the well-formed JSON fixtures from the repository root with:

```sh
jq empty docs/data/portability-recovery-v1/{empty-readable-export-v1,ordinary-complete-backup-v1,unicode-readable-export-v1,legacy-compatible-backup-v0,unsupported-newer-backup-v2}.json
```

The malformed fixture must fail parsing:

```sh
! jq empty docs/data/portability-recovery-v1/malformed-truncated-backup.json
```

For these fixtures, whose member names are ASCII and numbers are integers, `jq -cS` produces the same canonical bytes as RFC 8785. Verify each version 1 digest by comparing its stored `integrity.digest` with the SHA-256 result of `jq -j -cS 'del(.integrity)' <file>` (the `-j` is required so no trailing newline enters the digest scope). Also assert that the legacy fixture's second Item retains `containerName == "   "`; normalization would make the complete-backup compatibility fixture lossy.

Do not auto-format the malformed fixture: its missing closing array/object delimiters are intentional.
