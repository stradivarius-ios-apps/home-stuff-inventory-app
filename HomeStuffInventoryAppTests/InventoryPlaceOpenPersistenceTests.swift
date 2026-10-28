import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryPlaceOpenPersistenceTests {
    @Test func firstAndRepeatedOpenPersistOneAggregateWithInjectedTime() throws {
        let context = try makeContext()
        let identity = InventoryPlaceIdentity.make(locationName: "Hall", placeName: "Shelf")
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)

        try InventoryPlaceOpenPersistence.recordOpen(for: identity, in: context, now: first)
        try InventoryPlaceOpenPersistence.recordOpen(for: identity, in: context, now: second)

        let records = try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>())
        #expect(records.count == 1)
        #expect(records[0].openCount == 2)
        #expect(records[0].lastOpenedAt == second)
    }

    @Test func stablePlaceIDKeepsOneHistoryAggregateAcrossRenameIdentityChanges() throws {
        let context = try makeContext()
        let placeID = UUID()
        try InventoryPlaceOpenPersistence.recordOpen(for: .make(locationName: "Office", placeName: "Old Drawer"), placeID: placeID, in: context, now: Date(timeIntervalSince1970: 1))
        try InventoryPlaceOpenPersistence.recordOpen(for: .make(locationName: "Office", placeName: "New Drawer"), placeID: placeID, in: context, now: Date(timeIntervalSince1970: 2))

        let record = try #require(context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(record.openCount == 2)
        #expect(record.placeID == placeID)
        #expect(record.placeIdentity == InventoryPlaceIdentity.make(locationName: "Office", placeName: "New Drawer").rawValue)
    }

    @Test func registrationStateRecordsOnceButFreshStateRecordsAgain() throws {
        let context = try makeContext()
        let identity = InventoryPlaceIdentity.make(locationName: "Hall", placeName: "Shelf")
        let registration = InventoryPlaceOpenRegistration()
        try registration.registerIfNeeded(identity: identity, in: context, now: Date(timeIntervalSince1970: 1))
        try registration.registerIfNeeded(identity: identity, in: context, now: Date(timeIntervalSince1970: 2))
        try InventoryPlaceOpenRegistration().registerIfNeeded(identity: identity, in: context, now: Date(timeIntervalSince1970: 3))

        let record = try #require(context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(record.openCount == 2)
        #expect(record.lastOpenedAt == Date(timeIntervalSince1970: 3))
    }

    @Test func repairMergesDuplicatesRepairsCountsSaturatesAndPrunesOrphans() throws {
        let context = try makeContext()
        let item = InventoryItem(name: "Tape", locationName: "Hall", containerName: "Shelf")
        let identity = InventoryPlaceIdentity.make(for: item)
        context.insert(item)
        context.insert(InventoryPlaceOpenRecord(placeIdentity: identity.rawValue, openCount: -4, lastOpenedAt: .distantPast))
        context.insert(InventoryPlaceOpenRecord(placeIdentity: identity.rawValue, openCount: Int.max, lastOpenedAt: Date(timeIntervalSince1970: 9)))
        context.insert(InventoryPlaceOpenRecord(placeIdentity: "location:named:other|place:named:x", openCount: 4, lastOpenedAt: .now))
        try context.save()

        try InventoryPlaceOpenPersistence.repairPersistedRecords(in: context)
        try InventoryPlaceOpenPersistence.repairPersistedRecords(in: context)

        let records = try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>())
        #expect(records.count == 1)
        #expect(records[0].openCount == Int.max)
        #expect(records[0].lastOpenedAt == Date(timeIntervalSince1970: 9))
    }

    @Test func failedSaveRollsBackInsertAndUpdate() throws {
        let context = try makeContext()
        let identity = InventoryPlaceIdentity.make(locationName: "Hall", placeName: "Shelf")
        let failure: InventoryPlaceOpenPersistence.SaveOperation = { _ in throw TestFailure() }

        #expect(throws: InventoryPlaceOpenPersistenceError.saveFailed) {
            try InventoryPlaceOpenPersistence.recordOpen(for: identity, in: context, now: .now, save: failure)
        }
        #expect(try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).isEmpty)

        try InventoryPlaceOpenPersistence.recordOpen(for: identity, in: context, now: Date(timeIntervalSince1970: 1))
        #expect(throws: InventoryPlaceOpenPersistenceError.saveFailed) {
            try InventoryPlaceOpenPersistence.recordOpen(for: identity, in: context, now: Date(timeIntervalSince1970: 2), save: failure)
        }
        let record = try #require(context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(record.openCount == 1)
        #expect(record.lastOpenedAt == Date(timeIntervalSince1970: 1))
    }

    @Test func additiveSchemaOpensExistingInventoryAndRecentViewRecordsWithoutDataLoss() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let writer = ModelContext(container)
        let location = StorageLocation(name: "Hall")
        let category = InventoryCustomCategory(name: "Household")
        let item = InventoryItem(name: "Tape", category: "Household", locationName: "Hall", containerName: "Shelf")
        let event = InventoryItemViewEvent(itemID: item.id, viewedAt: Date(timeIntervalSince1970: 10))
        writer.insert(location)
        writer.insert(category)
        writer.insert(item)
        writer.insert(event)
        try writer.save()

        let reopened = ModelContext(container)
        #expect(try reopened.fetch(FetchDescriptor<StorageLocation>()).map(\.id) == [location.id])
        #expect(try reopened.fetch(FetchDescriptor<InventoryCustomCategory>()).map(\.id) == [category.id])
        #expect(try reopened.fetch(FetchDescriptor<InventoryItem>()).map(\.id) == [item.id])
        #expect(try reopened.fetch(FetchDescriptor<InventoryItemViewEvent>()).map(\.id) == [event.id])
        #expect(try reopened.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).isEmpty)
    }

    @Test func placeOpenRowsDoNotChangeReadableOrCompleteBackupPayloadsOrSchemaVersion() async throws {
        let context = try makeContext()
        let location = StorageLocation(name: "Hall")
        let category = InventoryCustomCategory(name: "Household")
        let item = InventoryItem(name: "Tape", category: "Household", locationName: "Hall", containerName: "Shelf")
        let event = InventoryItemViewEvent(itemID: item.id, viewedAt: Date(timeIntervalSince1970: 10))
        context.insert(location)
        context.insert(category)
        context.insert(item)
        context.insert(event)
        try context.save()
        let metadata = InventoryPortabilityMetadataV1(createdAt: Date(timeIntervalSince1970: 20), appVersion: "1", appBuild: "1")

        let readableBefore = try InventoryPortabilityEncoder.encode(
            snapshot: InventoryReadableExportService().makeSnapshot(items: [item], locations: [location], customCategories: [category]),
            metadata: metadata,
            artifactType: .readableExport,
            prettyPrinted: true
        )
        let completeBefore = try await InventoryBackupEncoderService().encode(
            snapshot: InventoryBackupSnapshotter.capture(in: context), metadata: metadata
        )

        context.insert(InventoryPlaceOpenRecord(placeIdentity: InventoryPlaceIdentity.make(for: item).rawValue, openCount: 9, lastOpenedAt: .now))
        try context.save()

        let readableAfter = try InventoryPortabilityEncoder.encode(
            snapshot: InventoryReadableExportService().makeSnapshot(items: [item], locations: [location], customCategories: [category]),
            metadata: metadata,
            artifactType: .readableExport,
            prettyPrinted: true
        )
        let completeAfter = try await InventoryBackupEncoderService().encode(
            snapshot: InventoryBackupSnapshotter.capture(in: context), metadata: metadata
        )

        #expect(readableAfter == readableBefore)
        #expect(completeAfter == completeBefore)
        #expect(try InventoryPortabilityEncoder.decodeAndVerify(readableAfter).schemaVersion == 4)
        #expect(try InventoryPortabilityEncoder.decodeAndVerify(completeAfter).schemaVersion == 4)
        #expect(String(decoding: completeAfter, as: UTF8.self).contains("placeIdentity") == false)
    }

    @Test(arguments: [0, 1, 2, 3])
    func restoredSameNameBranchesSurvivePersistentStartup(recordScenario: Int) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("place-open-startup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("inventory.store")
        let recoveryStore = InventoryBackupRecoveryStore(directory: directory.appendingPathComponent("recovery"))
        let snapshot = sameNameBranchSnapshot()
        let schema = try InventoryModelContainer.make(inMemory: true).schema

        // This helper returns no live models or contexts, releasing the writer before reopen.
        try await restoreBranches(snapshot, schema: schema, storeURL: storeURL,
                                  recoveryStore: recoveryStore, recordScenario: recordScenario)
        let first = try loadBranches(snapshot, schema: schema, storeURL: storeURL,
                                     recoveryStore: recoveryStore)
        let second = try loadBranches(snapshot, schema: schema, storeURL: storeURL,
                                      recoveryStore: recoveryStore)
        #expect(second == first)
        let boxes = snapshot.places.filter { $0.name == "Box" }
        switch recordScenario {
        case 1:
            #expect(first.count == 2)
            for (offset, box) in boxes.enumerated() {
                let record = try #require(first.first { $0.placeID?.inventoryPortabilityString == box.id })
                #expect(record.openCount == offset + 4)
                #expect(record.lastOpenedAt == Date(timeIntervalSince1970: Double(offset + 10)))
            }
        case 3:
            let record = try #require(first.first)
            #expect(first.count == 1)
            #expect(record.placeID?.inventoryPortabilityString == snapshot.places.first { $0.name == "Cabinet A" }?.id)
            #expect(record.openCount == 9)
        default:
            #expect(first.isEmpty)
        }

        if recordScenario == 2 {
            let container = try persistentContainer(schema: schema, at: storeURL)
            let context = ModelContext(container)
            for box in boxes {
                let record = try InventoryPlaceOpenPersistence.recordOpen(
                    for: .make(locationName: "Kitchen", placeName: "Box"),
                    placeID: try #require(UUID(uuidString: box.id)), in: context
                )
                #expect(record.openCount == 1)
            }
            #expect(try context.fetchCount(FetchDescriptor<InventoryPlaceOpenRecord>()) == 2)
        }
    }

    private func sameNameBranchSnapshot() -> InventoryPortabilitySnapshotV1 {
        let date = Date(timeIntervalSince1970: 1_752_000_000)
        let location = StorageLocation(name: "Kitchen", createdAt: date, updatedAt: date)
        let parents = ["Cabinet A", "Cabinet B"].map {
            InventoryPlace(locationID: location.id, name: $0, createdAt: date)
        }
        let boxes = parents.map {
            InventoryPlace(locationID: location.id, parentPlaceID: $0.id, name: "Box", createdAt: date)
        }
        let items = boxes.enumerated().map { offset, box in
            InventoryItem(name: "Cable \(offset)", locationName: location.name,
                          containerName: box.name, placeID: box.id, createdAt: date)
        }
        return InventoryBackupSnapshotter.makeSnapshot(
            locations: [location], customCategories: [], items: items,
            places: parents + boxes, viewEvents: []
        )
    }

    private func persistentContainer(schema: Schema, at url: URL) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
    }

    private func restoreBranches(
        _ snapshot: InventoryPortabilitySnapshotV1, schema: Schema, storeURL: URL,
        recoveryStore: InventoryBackupRecoveryStore, recordScenario: Int
    ) async throws {
        let support = InventoryBackupRestoreTestSupport()
        let plan = try await support.makePlan(snapshot: snapshot)
        #expect(plan.document.schemaVersion == 4)
        let container = try persistentContainer(schema: schema, at: storeURL)
        let context = ModelContext(container)
        _ = try await InventoryBackupRestoreService().restore(
            plan, in: context, metadataSource: support.metadataSource, recoveryStore: recoveryStore
        )
        let boxes = snapshot.places.filter { $0.name == "Box" }
        if recordScenario == 1 {
            for (offset, box) in boxes.enumerated() {
                context.insert(InventoryPlaceOpenRecord(
                    placeIdentity: InventoryPlaceIdentity.make(locationName: "Kitchen", placeName: "Box").rawValue,
                    placeID: try #require(UUID(uuidString: box.id)), openCount: offset + 4,
                    lastOpenedAt: Date(timeIntervalSince1970: Double(offset + 10))
                ))
            }
        } else if recordScenario == 2 || recordScenario == 3 {
            context.insert(InventoryPlaceOpenRecord(
                placeIdentity: InventoryPlaceIdentity.make(
                    locationName: "Kitchen", placeName: recordScenario == 2 ? "Box" : "Cabinet A"
                ).rawValue, openCount: 9, lastOpenedAt: Date(timeIntervalSince1970: 20)
            ))
        }
        try context.save()
    }

    private func loadBranches(
        _ snapshot: InventoryPortabilitySnapshotV1, schema: Schema, storeURL: URL,
        recoveryStore: InventoryBackupRecoveryStore
    ) throws -> [InventoryBackupRecoveryPlaceOpenRecord] {
        let result = InventoryModelContainer.loadLive(
            makePersistentContainer: { try persistentContainer(schema: schema, at: storeURL) },
            recoverPendingRestore: { try InventoryBackupRecoveryCoordinator.recoverIfNeeded(container: $0, store: recoveryStore) },
            arguments: []
        )
        guard case let .success(container) = result else {
            Issue.record("Restored hierarchy must load with production startup maintenance")
            return []
        }
        let context = ModelContext(container)
        #expect(try InventoryBackupSnapshotter.capture(in: context) == snapshot)
        return try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { InventoryBackupRecoveryPlaceOpenRecord(
                id: $0.id, placeIdentity: $0.placeIdentity, placeID: $0.placeID,
                openCount: $0.openCount, lastOpenedAt: $0.lastOpenedAt
            ) }
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private struct TestFailure: Error {}
}
