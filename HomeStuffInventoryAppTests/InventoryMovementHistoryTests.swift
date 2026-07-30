import Foundation
import CryptoKit
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryMovementHistoryTests {
    @Test func originsRoundTripAndKeepHierarchyDistinctFromDirectContents() {
        let origins: [InventoryMovementOrigin] = [
            .singleItem,
            .selectedItems,
            .storagePlaceDirectContents,
            .roomSweep,
            .hierarchySubtree,
            .undo,
            .unknown("futureMovementOrigin")
        ]

        #expect(origins.map { InventoryMovementOrigin(rawValue: $0.rawValue) } == origins)
        #expect(InventoryMovementOrigin.hierarchySubtree != .storagePlaceDirectContents)
    }

    @Test func groupedMovePersistsStableSnapshotsDeterministicIDsAndTimestamp() throws {
        let context = try makeContext()
        let sourceLocation = StorageLocation(id: id("10000000-0000-0000-0000-000000000001"), name: "Office")
        let destinationLocation = StorageLocation(id: id("10000000-0000-0000-0000-000000000002"), name: "Garage")
        let destinationPlace = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000001"),
            locationID: destinationLocation.id,
            name: "Blue Box"
        )
        let first = item(id: id("30000000-0000-0000-0000-000000000001"), name: "Cable")
        let second = item(id: id("30000000-0000-0000-0000-000000000002"), name: "Tape")
        context.insert(sourceLocation)
        context.insert(destinationLocation)
        context.insert(destinationPlace)
        context.insert(first)
        context.insert(second)
        try context.save()

        let locations = [sourceLocation, destinationLocation]
        let destination = InventoryMovementEndpointSnapshot(
            locationID: destinationLocation.id,
            locationName: destinationLocation.name,
            placeID: destinationPlace.id,
            placeName: destinationPlace.name
        )
        let operationID = id("40000000-0000-0000-0000-000000000001")
        let recordIDs = [
            id("50000000-0000-0000-0000-000000000001"),
            id("50000000-0000-0000-0000-000000000002")
        ]
        let timestamp = Date(timeIntervalSince1970: 1_000)

        let records = try InventoryMovementHistory.move(
            [first, second].map {
                InventoryMovementRequest(
                    item: $0,
                    expectedSource: InventoryMovementEndpointSnapshot(item: $0, locations: locations),
                    destination: destination
                )
            },
            origin: .selectedItems,
            in: context,
            locations: locations,
            operationID: operationID,
            occurredAt: timestamp,
            recordID: { recordIDs[$0] }
        )

        #expect(records.map(\.id) == recordIDs)
        #expect(Set(records.map(\.operationID)) == [operationID])
        #expect(Set(records.map(\.itemID)) == [first.id, second.id])
        #expect(Set(records.map(\.occurredAt)) == [timestamp])
        #expect(records.allSatisfy { $0.origin == .selectedItems })
        #expect(records.allSatisfy { $0.source.locationName == "Office" })
        #expect(records.allSatisfy { $0.destination == destination })
        #expect(first.locationName == "Garage")
        #expect(first.containerName == "Blue Box")
        #expect(first.placeID == destinationPlace.id)
    }

    @Test func failedMoveRollsBackItemsAndRecordsAtomically() throws {
        let context = try makeContext()
        let location = StorageLocation(name: "Office")
        let item = item(id: UUID(), name: "Cable")
        context.insert(location)
        context.insert(item)
        try context.save()
        let source = InventoryMovementEndpointSnapshot(item: item, locations: [location])

        #expect(throws: InventoryMovementFailure.persistenceFailed) {
            try InventoryMovementHistory.move(
                [
                    InventoryMovementRequest(
                        item: item,
                        expectedSource: source,
                        destination: .init(locationID: nil, locationName: "Garage", placeID: nil, placeName: "Shelf")
                    )
                ],
                origin: .singleItem,
                in: context,
                locations: [location],
                persist: { throw TestFailure() }
            )
        }

        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persistedItem.locationName == "Office")
        #expect(persistedItem.containerName == nil)
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func cancellationAndStalePreflightLeaveEverythingUnchanged() throws {
        let context = try makeContext()
        let item = item(id: UUID(), name: "Cable")
        context.insert(item)
        try context.save()
        let source = InventoryMovementEndpointSnapshot(item: item, locations: [])
        let destination = InventoryMovementEndpointSnapshot(
            locationID: nil,
            locationName: "Garage",
            placeID: nil,
            placeName: nil
        )
        let request = InventoryMovementRequest(item: item, expectedSource: source, destination: destination)

        #expect(throws: InventoryMovementFailure.cancelled) {
            try InventoryMovementHistory.move(
                [request],
                origin: .singleItem,
                in: context,
                locations: [],
                isCancelled: { true }
            )
        }
        #expect(item.locationName == "Office")

        let stale = InventoryMovementRequest(
            item: item,
            expectedSource: destination,
            destination: source
        )
        #expect(throws: InventoryMovementFailure.staleSource) {
            try InventoryMovementHistory.move(
                [stale],
                origin: .singleItem,
                in: context,
                locations: []
            )
        }
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func retentionPrunesWholeOperationsDeterministically() throws {
        let context = try makeContext()
        let item = item(id: UUID(), name: "Cable")
        context.insert(item)
        let oldestID = id("40000000-0000-0000-0000-000000000001")
        let tiedEarlierID = id("40000000-0000-0000-0000-000000000002")
        let tiedLaterID = id("40000000-0000-0000-0000-000000000003")
        let source = InventoryMovementEndpointSnapshot(locationID: nil, locationName: "Office", placeID: nil, placeName: nil)
        let destination = InventoryMovementEndpointSnapshot(locationID: nil, locationName: "Garage", placeID: nil, placeName: nil)
        let records = [
            record(id: UUID(), operationID: oldestID, itemID: item.id, date: Date(timeIntervalSince1970: 1), source: source, destination: destination),
            record(id: UUID(), operationID: tiedEarlierID, itemID: item.id, date: Date(timeIntervalSince1970: 2), source: source, destination: destination),
            record(id: UUID(), operationID: tiedLaterID, itemID: item.id, date: Date(timeIntervalSince1970: 2), source: source, destination: destination),
            record(id: UUID(), operationID: tiedLaterID, itemID: UUID(), date: Date(timeIntervalSince1970: 2), source: source, destination: destination)
        ]
        records.forEach(context.insert)

        try InventoryMovementHistory.prune(
            records: records,
            keepingLatestOperations: 2,
            delete: context.delete
        )
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<InventoryMovementRecord>())
        #expect(Set(remaining.map(\.operationID)) == [tiedEarlierID, tiedLaterID])
        #expect(remaining.filter { $0.operationID == tiedLaterID }.count == 2)
    }

    @Test func undoUsesCentralPolicyAndOnlyLatestCompatiblePostState() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let item = item(id: UUID(), name: "Cable")
        context.insert(office)
        context.insert(garage)
        context.insert(item)
        try context.save()
        let source = InventoryMovementEndpointSnapshot(item: item, locations: [office, garage])
        let destination = InventoryMovementEndpointSnapshot(
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil
        )
        let moved = try InventoryMovementHistory.move(
            [.init(item: item, expectedSource: source, destination: destination)],
            origin: .singleItem,
            in: context,
            locations: [office, garage],
            operationID: id("40000000-0000-0000-0000-000000000010"),
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        #expect(
            InventoryMovementHistory.undoAvailability(
                records: moved,
                items: [item],
                locations: [office, garage],
                places: [],
                entitlements: .free
            ) == .accessRequired
        )
        #expect(
            InventoryMovementHistory.undoLatest(
                records: moved,
                items: [item],
                locations: [office, garage],
                places: [],
                entitlements: .free,
                in: context
            ) == .accessRequired
        )
        #expect(item.locationName == "Garage")

        let outcome = InventoryMovementHistory.undoLatest(
            records: moved,
            items: [item],
            locations: [office, garage],
            places: [],
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false),
            in: context,
            operationID: id("40000000-0000-0000-0000-000000000011"),
            occurredAt: Date(timeIntervalSince1970: 11)
        )

        #expect(outcome == .undone(operationID: moved[0].operationID))
        #expect(item.locationName == "Office")
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).contains { $0.origin == .undo })
    }

    @Test func conflictingEditAndMissingSourcePlaceDisableUndoWithoutMutation() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let item = item(id: UUID(), name: "Cable")
        context.insert(office)
        context.insert(garage)
        context.insert(item)
        try context.save()
        let source = InventoryMovementEndpointSnapshot(item: item, locations: [office, garage])
        let destination = InventoryMovementEndpointSnapshot(
            locationID: garage.id,
            locationName: "Garage",
            placeID: nil,
            placeName: nil
        )
        let records = try InventoryMovementHistory.move(
            [.init(item: item, expectedSource: source, destination: destination)],
            origin: .singleItem,
            in: context,
            locations: [office, garage]
        )
        item.applyMovement(.init(locationID: nil, locationName: "Kitchen", placeID: nil, placeName: nil))

        #expect(
            InventoryMovementHistory.undoAvailability(
                records: records,
                items: [item],
                locations: [office, garage],
                places: [],
                entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
            ) == .currentStateChanged
        )
        #expect(item.locationName == "Kitchen")

        item.applyMovement(destination)
        records[0].sourcePlaceID = UUID()
        records[0].sourceLocationID = office.id
        #expect(
            InventoryMovementHistory.undoAvailability(
                records: records,
                items: [item],
                locations: [office, garage],
                places: [],
                entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
            ) == .unsafeRestoration
        )
    }

    @Test func failedUndoRollsBackReverseMutationAndUndoRecord() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let item = item(id: UUID(), name: "Cable")
        context.insert(office)
        context.insert(garage)
        context.insert(item)
        try context.save()
        let source = InventoryMovementEndpointSnapshot(item: item, locations: [office, garage])
        let destination = InventoryMovementEndpointSnapshot(locationID: garage.id, locationName: "Garage", placeID: nil, placeName: nil)
        let records = try InventoryMovementHistory.move(
            [.init(item: item, expectedSource: source, destination: destination)],
            origin: .singleItem,
            in: context,
            locations: [office, garage]
        )

        let outcome = InventoryMovementHistory.undoLatest(
            records: records,
            items: [item],
            locations: [office, garage],
            places: [],
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false),
            in: context,
            persist: { throw TestFailure() }
        )

        #expect(outcome == .failed)
        #expect(try #require(context.fetch(FetchDescriptor<InventoryItem>()).first).locationName == "Garage")
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).count == 1)
    }

    @Test func ordinaryFormMoveIsFreeAtomicAndHistoryRemainsReadableAfterDowngrade() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let item = item(id: UUID(), name: "Cable")
        context.insert(office)
        context.insert(garage)
        context.insert(item)
        try context.save()
        var draft = InventoryItemDraft(item: item)
        draft.locationName = "Garage"
        draft.containerName = "Shelf"

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: item,
            locations: [office, garage],
            places: [],
            in: context,
            occurredAt: Date(timeIntervalSince1970: 20),
            operationID: id("40000000-0000-0000-0000-000000000020"),
            recordID: id("50000000-0000-0000-0000-000000000020")
        )

        #expect(outcome == .saved)
        #expect(InventoryFreeAccessPolicy().availability(of: .relocateSingleItem, entitlementState: .free) == .available)
        let records = try context.fetch(FetchDescriptor<InventoryMovementRecord>())
        #expect(records.count == 1)
        #expect(InventoryMovementHistory.records(for: item.id, from: records).map(\.id) == records.map(\.id))
        #expect(
            InventoryMovementHistory.undoAvailability(
                records: records,
                items: [item],
                locations: [office, garage],
                places: [],
                entitlements: .free
            ) == .accessRequired
        )
    }

    @Test func failedOrdinaryFormMoveCreatesNoRecordAndRestoresContainerCompatibilityValue() throws {
        let context = try makeContext()
        let item = InventoryItem(name: "Cable", locationName: "Office", containerName: "Top drawer")
        context.insert(item)
        try context.save()
        var draft = InventoryItemDraft(item: item)
        draft.locationName = "Garage"
        draft.containerName = "Shelf"

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: item,
            in: context,
            persist: { throw TestFailure() }
        )

        #expect(outcome == .saveFailed)
        let persisted = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persisted.locationName == "Office")
        #expect(persisted.containerName == "Top drawer")
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func movementHistoryRoundTripsThroughCompleteBackupAndReadableExport() throws {
        let context = try makeContext()
        let office = StorageLocation(id: id("10000000-0000-0000-0000-000000000001"), name: "Office")
        let garage = StorageLocation(id: id("10000000-0000-0000-0000-000000000002"), name: "Garage")
        let item = InventoryItem(
            id: id("30000000-0000-0000-0000-000000000001"),
            name: "Cable",
            locationName: "Office",
            createdAt: Date(timeIntervalSince1970: 50)
        )
        context.insert(office)
        context.insert(garage)
        context.insert(item)
        try context.save()
        let source = InventoryMovementEndpointSnapshot(item: item, locations: [office, garage])
        let destination = InventoryMovementEndpointSnapshot(
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: "Shelf"
        )
        _ = try InventoryMovementHistory.move(
            [.init(item: item, expectedSource: source, destination: destination)],
            origin: .singleItem,
            in: context,
            locations: [office, garage],
            operationID: id("40000000-0000-0000-0000-000000000001"),
            occurredAt: Date(timeIntervalSince1970: 100),
            recordID: { _ in self.id("50000000-0000-0000-0000-000000000001") }
        )

        let complete = try InventoryBackupSnapshotter.capture(in: context)
        let metadata = InventoryPortabilityMetadataV1(
            createdAt: Date(timeIntervalSince1970: 200),
            appVersion: "1",
            appBuild: "1"
        )
        let completeData = try InventoryPortabilityEncoder.encode(
            snapshot: complete,
            metadata: metadata,
            artifactType: .completeBackup,
            prettyPrinted: false
        )
        let completeDocument = try InventoryPortabilityEncoder.decodeAndVerify(completeData)
        #expect(completeDocument.schemaVersion == 3)
        #expect(completeDocument.inventory.movementRecords?.count == 1)
        #expect(completeDocument.inventory.movementRecords?.first?.originStorageValue == "singleItem")

        let movementRecords = try context.fetch(FetchDescriptor<InventoryMovementRecord>())
        let readable = InventoryReadableExportService().makeSnapshot(
            items: [item],
            locations: [office, garage],
            customCategories: [],
            movementRecords: movementRecords
        )
        let readableData = try InventoryPortabilityEncoder.encode(
            snapshot: readable,
            metadata: metadata,
            artifactType: .readableExport,
            prettyPrinted: true
        )
        let readableDocument = try InventoryPortabilityEncoder.decodeAndVerify(readableData)
        #expect(readableDocument.inventory.movementRecords?.count == 1)
        #expect(readableDocument.inventory.places.isEmpty)
        #expect(readableDocument.inventory.recentItemViewEvents == nil)

        let replacementContext = try makeContext()
        try InventoryBackupRestoreService.replaceSnapshot(completeDocument.inventory, in: replacementContext)
        let restored = try #require(replacementContext.fetch(FetchDescriptor<InventoryMovementRecord>()).first)
        #expect(restored.id == movementRecords[0].id)
        #expect(restored.source.locationName == "Office")
        #expect(restored.destination.locationName == "Garage")
    }

    @Test func portabilityRejectsOrphanMovementAndReplacementRollsBackInvalidMovement() throws {
        let context = try makeContext()
        let existing = item(id: id("30000000-0000-0000-0000-000000000001"), name: "Existing")
        context.insert(existing)
        try context.save()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let source = InventoryMovementEndpointSnapshot(locationID: nil, locationName: "Office", placeID: nil, placeName: nil)
        let destination = InventoryMovementEndpointSnapshot(locationID: nil, locationName: "Garage", placeID: nil, placeName: nil)
        let orphan = record(
            id: id("50000000-0000-0000-0000-000000000001"),
            operationID: id("40000000-0000-0000-0000-000000000001"),
            itemID: id("30000000-0000-0000-0000-000000000099"),
            date: Date(timeIntervalSince1970: 100),
            source: source,
            destination: destination
        )
        let orphanPortable = InventoryBackupSnapshotter.makeSnapshot(
            locations: [],
            customCategories: [],
            items: [existing],
            places: [],
            viewEvents: [],
            movementRecords: [orphan]
        )
        #expect(throws: InventoryPortabilityCodecError.invalidSchema) {
            try InventoryPortabilityEncoder.encode(
                snapshot: orphanPortable,
                metadata: .init(createdAt: .now, appVersion: "1", appBuild: "1"),
                artifactType: .completeBackup,
                prettyPrinted: false
            )
        }

        let malformed = InventoryPortabilityMovementRecordV1(
            id: "not-a-uuid",
            operationID: id("40000000-0000-0000-0000-000000000002").inventoryPortabilityString,
            itemID: existing.id.inventoryPortabilityString,
            occurredAt: InventoryPortabilityDate.string(from: Date(timeIntervalSince1970: 100)),
            originStorageValue: "singleItem",
            reversedOperationID: nil,
            sourceLocationID: nil,
            sourceLocationName: "Office",
            sourcePlaceID: nil,
            sourcePlaceName: nil,
            destinationLocationID: nil,
            destinationLocationName: "Garage",
            destinationPlaceID: nil,
            destinationPlaceName: nil
        )
        let invalidReplacement = InventoryPortabilitySnapshotV1(
            locations: original.locations,
            customCategories: original.customCategories,
            items: original.items,
            places: original.places,
            recentItemViewEvents: original.recentItemViewEvents,
            movementRecords: [malformed]
        )
        #expect(throws: InventoryBackupRestoreError.invalidRelationships) {
            try InventoryBackupRestoreService.replaceSnapshot(invalidReplacement, in: context)
        }
        #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
    }

    @Test func versionTwoBackupMigratesInMemoryWithEmptyMovementHistory() async throws {
        let snapshot = InventoryPortabilitySnapshotV1(
            locations: [],
            customCategories: [],
            items: [],
            places: [],
            recentItemViewEvents: [],
            movementRecords: []
        )
        let currentData = try InventoryPortabilityEncoder.encode(
            snapshot: snapshot,
            metadata: .init(createdAt: Date(timeIntervalSince1970: 100), appVersion: "1", appBuild: "1"),
            artifactType: .completeBackup,
            prettyPrinted: false
        )
        var root = try #require(JSONSerialization.jsonObject(with: currentData) as? [String: Any])
        root["schemaVersion"] = 2
        var inventory = try #require(root["inventory"] as? [String: Any])
        inventory.removeValue(forKey: "movementRecords")
        root["inventory"] = inventory
        root.removeValue(forKey: "integrity")
        let digest = SHA256.hash(data: try InventoryRFC8785Canonicalizer.data(from: root))
            .map { String(format: "%02x", $0) }
            .joined()
        root["integrity"] = [
            "algorithm": "SHA-256",
            "canonicalization": "RFC8785",
            "digest": digest
        ]
        let versionTwoData = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])

        let plan = try await InventoryBackupRestorePlanner().plan(
            data: versionTwoData,
            currentAppVersion: "1"
        )

        #expect(plan.schemaVersion == 3)
        #expect(plan.document.inventory.movementRecords == [])
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private func item(id: UUID, name: String) -> InventoryItem {
        InventoryItem(id: id, name: name, locationName: "Office")
    }

    private func record(
        id: UUID,
        operationID: UUID,
        itemID: UUID,
        date: Date,
        source: InventoryMovementEndpointSnapshot,
        destination: InventoryMovementEndpointSnapshot
    ) -> InventoryMovementRecord {
        InventoryMovementRecord(
            id: id,
            operationID: operationID,
            itemID: itemID,
            occurredAt: date,
            origin: .singleItem,
            source: source,
            destination: destination
        )
    }

    private func id(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    private struct TestFailure: Error {}
}
