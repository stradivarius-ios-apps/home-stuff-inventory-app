import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupRestorePlannerTests: InventoryBackupRestoreTestCase {
    let support = InventoryBackupRestoreTestSupport()

    @Test func legacyInputIsBoundBeforeMigrationAndCompatibleAtSupportedLimits() async throws {
        let data = try Data(contentsOf: fixtureURL("legacy-compatible-backup-v0.json"))
        let tinyBytes = InventoryPortabilityLimits(maximumDocumentBytes: data.count - 1, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10, maximumRecentItemViewEvents: 10,
            maximumTagsPerItem: 10, maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        await #expect(throws: InventoryBackupRestoreError.fileTooLarge) {
            try await InventoryBackupRestorePlanner(limits: tinyBytes).plan(data: data)
        }
        let noItems = InventoryPortabilityLimits(maximumDocumentBytes: data.count + 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 0, maximumRecentItemViewEvents: 10,
            maximumTagsPerItem: 10, maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        await #expect(throws: InventoryBackupRestoreError.backupTooComplex) {
            try await InventoryBackupRestorePlanner(limits: noItems).plan(data: data)
        }
        let compatible = InventoryPortabilityLimits(maximumDocumentBytes: data.count + 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10, maximumRecentItemViewEvents: 10,
            maximumTagsPerItem: 10, maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        let plan = try await InventoryBackupRestorePlanner(limits: compatible).plan(data: data)
        #expect(plan.schemaVersion == 2)
    }
    @Test func versionOneBackupSynthesizesScopedPlacesAndLinksBeforeRestore() async throws {
        let data = try Data(contentsOf: fixtureURL("ordinary-complete-backup-v1.json"))
        let plan = try await InventoryBackupRestorePlanner().plan(data: data)

        #expect(plan.schemaVersion == 2)
        #expect(plan.document.inventory.places.map(\.name) == ["Desk drawer", "Memory box"])
        #expect(plan.document.inventory.places.allSatisfy { $0.iconID == PlaceIconCatalog.defaultIconID })
        #expect(plan.document.inventory.items.allSatisfy { $0.placeID != nil })
    }
    @Test func plannerRejectsMalformedTruncatedNewerAndIntegrityFailedFiles() async throws {
        let data = try backupData(snapshot: unicodeSnapshot())
        let planner = InventoryBackupRestorePlanner()

        await #expect(throws: InventoryBackupRestoreError.malformedFile) {
            try await planner.plan(data: Data(#"{"inventory":"#.utf8))
        }
        await #expect(throws: InventoryBackupRestoreError.malformedFile) {
            try await planner.plan(data: data.dropLast(data.count / 2))
        }

        let newer = try mutate(data, reseal: false) { $0["schemaVersion"] = 3 }
        await #expect(throws: InventoryBackupRestoreError.unsupportedNewerVersion) {
            try await planner.plan(data: newer)
        }

        let tampered = try mutate(data, reseal: false) { root in
            var inventory = root["inventory"] as! [String: Any]
            var items = inventory["items"] as! [[String: Any]]
            items[0]["name"] = "Changed after signing"
            inventory["items"] = items
            root["inventory"] = inventory
        }
        await #expect(throws: InventoryBackupRestoreError.integrityMismatch) {
            try await planner.plan(data: tampered)
        }

        let readableExport = try InventoryPortabilityEncoder.encode(
            snapshot: InventoryPortabilitySnapshotV1(
                locations: [],
                customCategories: [],
                items: [],
                recentItemViewEvents: nil
            ),
            metadata: InventoryPortabilityMetadataV1(
                createdAt: date,
                appVersion: "1.0",
                appBuild: "1"
            ),
            artifactType: .readableExport,
            prettyPrinted: true
        )
        await #expect(throws: InventoryBackupRestoreError.wrongFileType) {
            try await planner.plan(data: readableExport)
        }
    }
    @Test func relationshipCorruptionIsRejectedBeforeStoreMutation() async throws {
        let data = try backupData(snapshot: unicodeSnapshot())
        let corrupted = try mutate(data, reseal: true) { root in
            var inventory = root["inventory"] as! [String: Any]
            var items = inventory["items"] as! [[String: Any]]
            items[0]["locationID"] = "10000000-0000-0000-0000-000000000099"
            inventory["items"] = items
            root["inventory"] = inventory
        }

        await #expect(throws: InventoryBackupRestoreError.invalidRelationships) {
            try await InventoryBackupRestorePlanner().plan(data: corrupted)
        }
    }
    @Test func plannerRejectsInvalidPlaceParentsIconsDuplicatesAndLinks() async throws {
        let data = try backupData(snapshot: unicodeSnapshot())

        let invalidParent = try mutate(data, reseal: true) { root in
            var inventory = root["inventory"] as! [String: Any]
            var places = inventory["places"] as! [[String: Any]]
            places[0]["locationID"] = "10000000-0000-0000-0000-000000000099"
            inventory["places"] = places
            root["inventory"] = inventory
        }
        let invalidIcon = try mutate(data, reseal: true) { root in
            var inventory = root["inventory"] as! [String: Any]
            var places = inventory["places"] as! [[String: Any]]
            places[0]["iconID"] = "not-a-place-icon"
            inventory["places"] = places
            root["inventory"] = inventory
        }
        let danglingLink = try mutate(data, reseal: true) { root in
            var inventory = root["inventory"] as! [String: Any]
            var items = inventory["items"] as! [[String: Any]]
            items[0]["placeID"] = "50000000-0000-0000-0000-000000000099"
            inventory["items"] = items
            root["inventory"] = inventory
        }
        let duplicateScope = try mutate(data, reseal: true) { root in
            var inventory = root["inventory"] as! [String: Any]
            var places = inventory["places"] as! [[String: Any]]
            var duplicate = places[0]
            duplicate["id"] = "50000000-0000-0000-0000-000000000099"
            places.append(duplicate)
            inventory["places"] = places
            root["inventory"] = inventory
        }
        let crossLocationLink = try mutate(data, reseal: true) { root in
            var inventory = root["inventory"] as! [String: Any]
            var locations = inventory["locations"] as! [[String: Any]]
            var secondLocation = locations[0]
            secondLocation["id"] = "10000000-0000-0000-0000-000000000002"
            secondLocation["name"] = "Elsewhere"
            locations.append(secondLocation)
            var places = inventory["places"] as! [[String: Any]]
            var secondPlace = places[0]
            secondPlace["id"] = "50000000-0000-0000-0000-000000000002"
            secondPlace["locationID"] = secondLocation["id"]
            places.append(secondPlace)
            var items = inventory["items"] as! [[String: Any]]
            items[0]["placeID"] = secondPlace["id"]
            inventory["locations"] = locations
            inventory["places"] = places
            inventory["items"] = items
            root["inventory"] = inventory
        }

        for malformed in [invalidParent, invalidIcon, danglingLink, duplicateScope, crossLocationLink] {
            await #expect(throws: InventoryBackupRestoreError.invalidRelationships) {
                try await InventoryBackupRestorePlanner().plan(data: malformed)
            }
        }
    }
    @Test func placeResourceLimitAndCanonicalOrderingAreDeterministic() throws {
        let snapshot = unicodeSnapshot()
        let first = try InventoryPortabilityEncoder.encode(
            snapshot: snapshot,
            metadata: InventoryPortabilityMetadataV1(createdAt: date, appVersion: "1", appBuild: "1"),
            artifactType: .completeBackup,
            prettyPrinted: false
        )
        let second = try InventoryPortabilityEncoder.encode(
            snapshot: InventoryPortabilitySnapshotV1(
                locations: snapshot.locations.reversed(), customCategories: snapshot.customCategories,
                items: snapshot.items.reversed(), places: snapshot.places.reversed(),
                recentItemViewEvents: snapshot.recentItemViewEvents
            ),
            metadata: InventoryPortabilityMetadataV1(createdAt: date, appVersion: "1", appBuild: "1"),
            artifactType: .completeBackup,
            prettyPrinted: false
        )
        #expect(first == second)

        let limits = InventoryPortabilityLimits(
            maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32, maximumLocations: 10,
            maximumPlaces: 0, maximumCustomCategories: 10, maximumItems: 10,
            maximumRecentItemViewEvents: 10, maximumTagsPerItem: 10,
            maximumUTF8BytesPerString: 100, maximumTotalRecords: 10
        )
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityLimitValidator.validate(snapshot, limits: limits)
        }
    }
    @Test func legacyVersionZeroRejectsNonIntegerAndInvalidSchemaRepresentations() async throws {
        let fixture = try Data(contentsOf: fixtureURL("legacy-compatible-backup-v0.json"))
        let original = try #require(JSONSerialization.jsonObject(with: fixture) as? [String: Any])

        let fixtureText = try #require(String(data: fixture, encoding: .utf8))
        let floatingZeroText = fixtureText.replacingOccurrences(
            of: "\"schemaVersion\": 0,",
            with: "\"schemaVersion\": 0.0,"
        )
        #expect(floatingZeroText != fixtureText)
        await #expect(throws: InventoryBackupRestoreError.malformedFile) {
            try await InventoryBackupRestorePlanner().plan(data: Data(floatingZeroText.utf8))
        }

        for invalidVersion: Any in [0.5, -1, "0", true] {
            var root = original
            root["schemaVersion"] = invalidVersion
            let data = try JSONSerialization.data(withJSONObject: root)

            await #expect(throws: InventoryBackupRestoreError.malformedFile) {
                try await InventoryBackupRestorePlanner().plan(data: data)
            }
        }

        var missingVersion = original
        missingVersion.removeValue(forKey: "schemaVersion")
        await #expect(throws: InventoryBackupRestoreError.malformedFile) {
            try await InventoryBackupRestorePlanner().plan(
                data: JSONSerialization.data(withJSONObject: missingVersion)
            )
        }
    }
    @Test func preflightReportsExactCountsDateVersionAndCompatibilityWarning() async throws {
        let plan = try await InventoryBackupRestorePlanner().plan(
            data: backupData(snapshot: unicodeSnapshot(), appVersion: "9.0"),
            currentAppVersion: "1.0"
        )

        #expect(plan.backupDate == date)
        #expect(plan.appVersion == "9.0")
        #expect(plan.schemaVersion == 2)
        #expect(plan.counts == InventoryBackupRestoreCounts(
            items: 1,
            locations: 1,
            places: 1,
            customCategories: 1,
            recentItemViews: 1
        ))
        #expect(plan.compatibilityWarnings == [.olderAppVersion])
    }
}
