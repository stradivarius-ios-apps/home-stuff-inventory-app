import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupRestoreServiceTests: InventoryBackupRestoreTestCase {
    let support = InventoryBackupRestoreTestSupport()

    @Test func validUnicodeBackupReplacesRatherThanMergesAndRoundTripsExactly() async throws {
        let target = try makeTargetContext()
        let expected = unicodeSnapshot()
        let plan = try await makePlan(snapshot: expected)

        _ = try await InventoryBackupRestoreService().restore(
            plan,
            in: target,
            metadataSource: metadataSource,
            recoveryStore: try makeRecoveryStore()
        )

        #expect(try InventoryBackupSnapshotter.capture(in: target) == expected)
        #expect(try target.fetch(FetchDescriptor<InventoryItem>()).allSatisfy { $0.name != "Existing Item" })
    }
    @Test func nestedHierarchyRestoresExactlyWithoutEntitlementAndInvalidReplacementIsAtomic() async throws {
        let target = try makeTargetContext()
        let expected = nestedSnapshot()

        for entitlementState in InventoryEntitlementState.allCases {
            #expect(
                InventoryFreeAccessPolicy().availability(
                    of: .restoreInventory,
                    entitlementState: entitlementState
                ) == .available
            )
        }

        _ = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: expected),
            in: target,
            metadataSource: metadataSource,
            recoveryStore: try makeRecoveryStore()
        )

        let restored = try InventoryBackupSnapshotter.capture(in: target)
        #expect(restored == expected)
        #expect(
            restored.places.compactMap(\.parentPlaceID) == [
                "50000000-0000-0000-0000-000000000002",
                "50000000-0000-0000-0000-000000000003"
            ]
        )

        var invalidPlaces = expected.places
        invalidPlaces[0] = InventoryPortabilityPlaceV1(
            id: invalidPlaces[0].id,
            locationID: invalidPlaces[0].locationID,
            parentPlaceID: "50000000-0000-0000-0000-000000000099",
            name: invalidPlaces[0].name,
            iconID: invalidPlaces[0].iconID,
            createdAt: invalidPlaces[0].createdAt,
            updatedAt: invalidPlaces[0].updatedAt
        )
        let invalid = InventoryPortabilitySnapshotV1(
            locations: expected.locations,
            customCategories: expected.customCategories,
            items: expected.items,
            places: invalidPlaces,
            recentItemViewEvents: expected.recentItemViewEvents,
            movementRecords: expected.movementRecords
        )

        #expect(throws: InventoryBackupRestoreError.invalidRelationships) {
            try InventoryBackupRestoreService.replaceSnapshot(invalid, in: target)
        }
        #expect(try InventoryBackupSnapshotter.capture(in: target) == expected)
    }
    @Test func emptyBackupReplacesTheWholeDatasetWithEmptyCollections() async throws {
        let target = try makeTargetContext()
        let empty = InventoryPortabilitySnapshotV1(
            locations: [],
            customCategories: [],
            items: [],
            recentItemViewEvents: []
        )

        _ = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: empty),
            in: target,
            metadataSource: metadataSource,
            recoveryStore: try makeRecoveryStore()
        )

        #expect(try InventoryBackupSnapshotter.capture(in: target) == empty)
    }
    @Test func successfulRestoreDeletesPriorPlaceOpenPersonalization() async throws {
        let target = try makeTargetContext()
        let existing = try #require(target.fetch(FetchDescriptor<InventoryItem>()).first)
        target.insert(InventoryPlaceOpenRecord(placeIdentity: InventoryPlaceIdentity.make(for: existing).rawValue, openCount: 4, lastOpenedAt: date))
        try target.save()

        _ = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: unicodeSnapshot()), in: target,
            metadataSource: metadataSource, recoveryStore: try makeRecoveryStore()
        )

        #expect(try target.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).isEmpty)
    }
    @Test func successfulLegacyBackupReplacementDeletesStalePlaceCatalogRecords() async throws {
        let target = try makeTargetContext()
        let existingLocation = try #require(target.fetch(FetchDescriptor<StorageLocation>()).first)
        let stalePlace = InventoryPlace(locationID: existingLocation.id, name: "Stale shelf")
        target.insert(stalePlace)
        try target.save()

        _ = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: unicodeSnapshot()), in: target,
            metadataSource: metadataSource, recoveryStore: try makeRecoveryStore()
        )

        let places = try target.fetch(FetchDescriptor<InventoryPlace>())
        #expect(!places.contains { $0.id == stalePlace.id })
        #expect(places.contains { $0.name == "Шухляда 📦" })
    }
    @Test func cancellationAtEveryStagePreservesTheOriginalDataset() async throws {
        await #expect(throws: CancellationError.self) {
            try await InventoryBackupRestorePlanner().plan(
                data: backupData(snapshot: unicodeSnapshot()),
                stageObserver: { stage in
                    if stage == .decoding { throw CancellationError() }
                }
            )
        }

        for cancelledStage in [
            InventoryBackupRestoreStage.recoverySnapshot,
            .beforeReplacement,
            .replacing,
            .verification
        ] {
            let context = try makeTargetContext()
            let original = try InventoryBackupSnapshotter.capture(in: context)
            let plan = try await makePlan(snapshot: unicodeSnapshot())

            await #expect(throws: CancellationError.self) {
                try await InventoryBackupRestoreService().restore(
                    plan,
                    in: context,
                    metadataSource: metadataSource,
                    recoveryStore: try makeRecoveryStore(),
                    stageObserver: { stage in
                        if stage == cancelledStage { throw CancellationError() }
                    }
                )
            }
            #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
        }
    }
    @Test func injectedWriteFailureRollsBackWithoutPartialStagingData() async throws {
        let context = try makeTargetContext()
        let pending = InventoryItem(name: "Pending local edit", locationName: "")
        context.insert(pending)
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let plan = try await makePlan(snapshot: unicodeSnapshot())

        await #expect(throws: InventoryBackupRestoreError.replacementFailed) {
            try await InventoryBackupRestoreService().restore(
                plan,
                in: context,
                metadataSource: metadataSource,
                recoveryStore: try makeRecoveryStore(),
                stageObserver: { stage in
                    if stage == .verification {
                        throw InventoryBackupRestoreError.replacementFailed
                    }
                }
            )
        }

        #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
        #expect(context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).contains { $0.id == pending.id })
    }
    @Test func precommitRestoreFailureKeepsPriorPlaceOpenPersonalization() async throws {
        let context = try makeTargetContext()
        let existing = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        let record = InventoryPlaceOpenRecord(placeIdentity: InventoryPlaceIdentity.make(for: existing).rawValue, openCount: 4, lastOpenedAt: date)
        context.insert(record)
        try context.save()

        await #expect(throws: InventoryBackupRestoreError.replacementFailed) {
            try await InventoryBackupRestoreService().restore(
                try await makePlan(snapshot: unicodeSnapshot()), in: context,
                metadataSource: metadataSource, recoveryStore: try makeRecoveryStore(),
                stageObserver: { stage in if stage == .verification { throw InventoryBackupRestoreError.replacementFailed } }
            )
        }

        let restoredRecord = try #require(context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(restoredRecord.id == record.id)
        #expect(restoredRecord.openCount == 4)
    }
    @Test func postcommitRecoveryRestoresPriorPlaceOpenPersonalization() async throws {
        let context = try makeTargetContext()
        let existing = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        let record = InventoryPlaceOpenRecord(placeIdentity: InventoryPlaceIdentity.make(for: existing).rawValue, openCount: 4, lastOpenedAt: date)
        context.insert(record)
        try context.save()

        await #expect(throws: InventoryBackupRestoreError.verificationFailed) {
            try await InventoryBackupRestoreService().restore(
                try await makePlan(snapshot: unicodeSnapshot()), in: context,
                metadataSource: metadataSource, recoveryStore: try makeRecoveryStore(),
                stageObserver: { stage in if stage == .reopenVerification { throw InventoryBackupRestoreError.verificationFailed } }
            )
        }

        let restoredRecord = try #require(context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(restoredRecord.id == record.id)
        #expect(restoredRecord.openCount == 4)
    }
    @Test func lowStorageAndGenericSafetyWriteFailuresPreserveOriginalDataset() async throws {
        for (writeError, expectedError) in [
            (CocoaError(.fileWriteOutOfSpace) as any Error, InventoryBackupRestoreError.lowStorage),
            (CocoaError(.fileWriteUnknown) as any Error, .recoverySnapshotFailed)
        ] {
            let context = try makeTargetContext()
            let pending = InventoryItem(name: "Unsaved", locationName: "")
            context.insert(pending)
            let original = try InventoryBackupSnapshotter.capture(in: context)
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("inventory-restore-write-failure-\(UUID().uuidString)")
            let store = InventoryBackupRecoveryStore(directory: directory) { _, _ in
                throw writeError
            }

            await #expect(throws: expectedError) {
                try await InventoryBackupRestoreService().restore(
                    try await makePlan(snapshot: unicodeSnapshot()),
                    in: context,
                    metadataSource: metadataSource,
                    recoveryStore: store
                )
            }
            #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
            #expect(context.hasChanges)
            #expect(try context.fetch(FetchDescriptor<InventoryItem>()).contains { $0.id == pending.id })
        }

        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let store = InventoryBackupRecoveryStore(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("inventory-restore-capacity-\(UUID().uuidString)"),
            durableWrite: { _, _ in throw CocoaError(.fileWriteUnknown) },
            availableCapacity: { _ in 0 }
        )
        await #expect(throws: InventoryBackupRestoreError.lowStorage) {
            try await InventoryBackupRestoreService().restore(
                try await makePlan(snapshot: unicodeSnapshot()),
                in: context,
                metadataSource: metadataSource,
                recoveryStore: store
            )
        }
        #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
    }
    @Test func restoreAvailabilityAndResultsAreIndependentOfEntitlementAndNetwork() async throws {
        let policy = InventoryFreeAccessPolicy()
        let states: [InventoryEntitlementState?] = [nil] + InventoryEntitlementState.allCases.map(Optional.some)
        let plan = try await makePlan(snapshot: unicodeSnapshot())

        for state in states {
            #expect(policy.availability(of: .restoreInventory, entitlementState: state) == .available)
            let context = try makeTargetContext()
            _ = try await InventoryBackupRestoreService().restore(
                plan,
                in: context,
                metadataSource: metadataSource,
                recoveryStore: try makeRecoveryStore()
            )
            #expect(try InventoryBackupSnapshotter.capture(in: context) == plan.document.inventory)
        }
    }
    @Test func largeDatasetRestoresEveryRecordWithDeterministicIdentity() async throws {
        let timestamp = InventoryPortabilityDate.string(from: date)
        let items = (0..<1_000).map { index in
            InventoryPortabilityItemV1(
                id: String(format: "30000000-0000-0000-0000-%012d", index + 1),
                name: "Річ (index) 🧰",
                categoryStorageValue: InventoryCategory.tools.rawValue,
                customCategoryID: nil,
                locationName: "",
                locationID: nil,
                placeName: index.isMultiple(of: 2) ? "Shelf (index % 20)" : nil,
                iconID: nil,
                quantity: index + 1,
                conditionStorageValue: InventoryCondition.unknown.rawValue,
                tags: ["tag-(index)"],
                notes: "",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        }
        let snapshot = InventoryPortabilitySnapshotV1(
            locations: [],
            customCategories: [],
            items: items,
            recentItemViewEvents: []
        )
        let context = try makeTargetContext()

        _ = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: snapshot),
            in: context,
            metadataSource: metadataSource,
            recoveryStore: try makeRecoveryStore()
        )

        let restored = try InventoryBackupSnapshotter.capture(in: context)
        #expect(restored == snapshot)
        #expect(restored.items.count == 1_000)
    }
}
