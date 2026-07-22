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
        #expect(try InventoryPortabilityEncoder.decodeAndVerify(readableAfter).schemaVersion == 2)
        #expect(try InventoryPortabilityEncoder.decodeAndVerify(completeAfter).schemaVersion == 2)
        #expect(String(decoding: completeAfter, as: UTF8.self).contains("placeIdentity") == false)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private struct TestFailure: Error {}
}
