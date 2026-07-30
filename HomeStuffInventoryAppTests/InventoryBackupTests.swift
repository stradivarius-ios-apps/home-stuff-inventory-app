import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupTests {
    private let createdAt = Date(timeIntervalSince1970: 1_752_000_000)
    private let updatedAt = Date(timeIntervalSince1970: 1_752_003_600)

    @Test func completeBackupGenerationRejectsFinalByteOverflowBeforeReturningData() async throws {
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 1, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10, maximumRecentItemViewEvents: 10,
            maximumTagsPerItem: 10, maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        let snapshot = InventoryPortabilitySnapshotV1(locations: [], customCategories: [], items: [], recentItemViewEvents: [])
        await #expect(throws: InventoryPortabilityCodecError.documentTooLarge) {
            try await InventoryBackupEncoderService(limits: limits).encode(snapshot: snapshot, metadata: metadata)
        }
    }

    @Test func completeBackupRoundTripsEveryPersistedRecordAndRelationship() async throws {
        let fixture = try makeFixture()
        let snapshot = try InventoryBackupSnapshotter.capture(in: fixture.context)
        let data = try await InventoryBackupEncoderService().encode(
            snapshot: snapshot,
            metadata: metadata
        )
        let document = try InventoryPortabilityEncoder.decodeAndVerify(data)

        #expect(document.artifactType == .completeBackup)
        #expect(document.schemaVersion == 3)
        #expect(document.metadata == metadata)
        #expect(document.inventory == snapshot)
        #expect(document.inventory.locations.count == 1)
        #expect(document.inventory.customCategories.count == 1)
        #expect(document.inventory.items.count == 2)
        #expect(document.inventory.recentItemViewEvents?.count == 1)
        #expect(document.inventory.items[0].locationID == fixture.location.id.inventoryPortabilityString)
        #expect(document.inventory.items[0].customCategoryID == fixture.category.id.inventoryPortabilityString)
        #expect(document.inventory.items[0].placeName == "  Шухляда 📦  ")
        #expect(document.inventory.items[0].tags == ["Кабелі", "naïve 🧰"])
        #expect(data.last == 0x0A)
    }

    @Test func capturedSnapshotRemainsConsistentAfterTheLiveStoreChanges() async throws {
        let fixture = try makeFixture()
        let snapshot = try InventoryBackupSnapshotter.capture(in: fixture.context)

        fixture.item.name = "Changed after snapshot"
        fixture.location.name = "Changed location"
        fixture.context.delete(fixture.viewEvent)
        try fixture.context.save()

        let data = try await InventoryBackupEncoderService().encode(
            snapshot: snapshot,
            metadata: metadata
        )
        let inventory = try InventoryPortabilityEncoder.decodeAndVerify(data).inventory

        #expect(inventory.items.contains { $0.name == "Паяльник 🔧" })
        #expect(inventory.items.contains { $0.locationName == "Майстерня" })
        #expect(inventory.locations.contains { $0.name == "Майстерня" })
        #expect(inventory.recentItemViewEvents?.count == 1)
        #expect(fixture.item.name == "Changed after snapshot")
    }

    @Test func capturingABackupDoesNotSavePendingStoreChanges() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let persistedItem = InventoryItem(
            name: "Persisted item",
            locationName: "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(persistedItem)
        try context.save()

        let pendingItem = InventoryItem(
            name: "Pending item",
            locationName: "",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(pendingItem)
        #expect(context.hasChanges)

        let snapshot = try InventoryBackupSnapshotter.capture(in: context)

        #expect(snapshot.items.map(\.id).contains(pendingItem.id.inventoryPortabilityString))
        #expect(snapshot.items.map(\.name).sorted() == ["Pending item", "Persisted item"])
        #expect(context.hasChanges)

        let verificationContext = ModelContext(container)
        verificationContext.autosaveEnabled = false
        let storedItems = try verificationContext.fetch(FetchDescriptor<InventoryItem>())
        #expect(storedItems.map(\.id) == [persistedItem.id])
    }

    @Test func largeBackupHasDeterministicOrderingAndCompleteViewHistory() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let location = StorageLocation(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Garage",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(location)

        for index in 0..<1_000 {
            let itemID = deterministicUUID(prefix: 3, index: index)
            let eventID = deterministicUUID(prefix: 4, index: 999 - index)
            context.insert(
                InventoryItem(
                    id: itemID,
                    name: "Item \(index) — річ",
                    category: InventoryCategory.tools.rawValue,
                    locationName: "Garage",
                    containerName: "Shelf \(index % 25)",
                    quantity: index + 1,
                    tags: ["tag-\(index)"],
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
            context.insert(
                InventoryItemViewEvent(
                    id: eventID,
                    itemID: itemID,
                    viewedAt: createdAt.addingTimeInterval(TimeInterval(index))
                )
            )
        }
        try context.save()

        let snapshot = try InventoryBackupSnapshotter.capture(in: context)
        let data = try await InventoryBackupEncoderService().encode(snapshot: snapshot, metadata: metadata)
        let inventory = try InventoryPortabilityEncoder.decodeAndVerify(data).inventory

        #expect(inventory.items.count == 1_000)
        #expect(inventory.recentItemViewEvents?.count == 1_000)
        #expect(inventory.items.map(\.id) == inventory.items.map(\.id).sorted())
        #expect(inventory.recentItemViewEvents?.map(\.viewedAt) == inventory.recentItemViewEvents?.map(\.viewedAt).sorted())
    }

    @Test func integrityTamperingFailsBeforeAChangedRecordCanBeDecoded() async throws {
        let fixture = try makeFixture()
        let snapshot = try InventoryBackupSnapshotter.capture(in: fixture.context)
        let data = try await InventoryBackupEncoderService().encode(snapshot: snapshot, metadata: metadata)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var inventory = try #require(object["inventory"] as? [String: Any])
        var items = try #require(inventory["items"] as? [[String: Any]])
        items[0]["name"] = "Tampered"
        inventory["items"] = items
        object["inventory"] = inventory
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        #expect(throws: InventoryPortabilityCodecError.integrityMismatch) {
            try InventoryPortabilityEncoder.decodeAndVerify(tampered)
        }
    }

    @Test func backupEncodingRejectsAnOrphanViewEvent() throws {
        let snapshot = InventoryPortabilitySnapshotV1(
            locations: [],
            customCategories: [],
            items: [],
            recentItemViewEvents: [
                InventoryPortabilityRecentItemViewEventV1(
                    id: deterministicUUID(prefix: 4, index: 1).inventoryPortabilityString,
                    itemID: deterministicUUID(prefix: 3, index: 1).inventoryPortabilityString,
                    viewedAt: InventoryPortabilityDate.string(from: createdAt)
                )
            ]
        )

        #expect(throws: InventoryPortabilityCodecError.invalidSchema) {
            try InventoryPortabilityEncoder.encode(
                snapshot: snapshot,
                metadata: metadata,
                artifactType: .completeBackup,
                prettyPrinted: false
            )
        }
    }

    @Test func backupAfterDeletingViewedItemRoundTripsWithoutOrphanEvents() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = InventoryItem(name: "Cable", locationName: "Desk")
        context.insert(item)
        try context.save()
        try InventoryRecentItemViews.recordView(of: item, in: context, viewedAt: updatedAt)

        try InventoryItemMutationPersistence.delete(item, in: context)

        let snapshot = try InventoryBackupSnapshotter.capture(in: context)
        let data = try await InventoryBackupEncoderService().encode(snapshot: snapshot, metadata: metadata)
        let document = try InventoryPortabilityEncoder.decodeAndVerify(data)
        #expect(document.inventory.items.isEmpty)
        #expect(document.inventory.recentItemViewEvents?.isEmpty == true)
    }

    @Test func cancellationAndDestinationFailuresHaveDistinctOutcomes() {
        #expect(InventoryBackupExportFailure.fromPreparation(CancellationError()) == nil)
        #expect(InventoryBackupExportFailure.fromPreparation(InventoryPortabilityCodecError.invalidSchema) == .encoding)
        #expect(InventoryBackupExportFailure.fromDestination(CocoaError(.userCancelled)) == nil)
        #expect(InventoryBackupExportFailure.fromDestination(CocoaError(.fileWriteOutOfSpace)) == .lowStorage)
        #expect(
            InventoryBackupExportFailure.fromDestination(
                NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ENOSPC.rawValue))
            ) == .lowStorage
        )
        #expect(
            InventoryBackupExportFailure.fromDestination(
                NSError(
                    domain: NSCocoaErrorDomain,
                    code: CocoaError.Code.fileWriteUnknown.rawValue,
                    userInfo: [NSUnderlyingErrorKey: CocoaError(.fileWriteOutOfSpace)]
                )
            ) == .lowStorage
        )
        #expect(InventoryBackupExportFailure.fromDestination(CocoaError(.fileWriteNoPermission)) == .destination)
    }

    @Test func backupCreationIsIdenticalAcrossEveryEntitlementState() async throws {
        let fixture = try makeFixture()
        let snapshot = try InventoryBackupSnapshotter.capture(in: fixture.context)
        let policy = InventoryFreeAccessPolicy()
        let states: [InventoryEntitlementState?] = [nil] + InventoryEntitlementState.allCases.map(Optional.some)
        var encodedFiles = Set<Data>()

        for state in states {
            #expect(policy.availability(of: .backUpInventory, entitlementState: state) == .available)
            encodedFiles.insert(
                try await InventoryBackupEncoderService().encode(snapshot: snapshot, metadata: metadata)
            )
        }

        #expect(encodedFiles.count == 1)
    }

    @Test func suggestedFilenameIsStableAndContainsNoExternalPath() {
        #expect(
            InventoryBackupFilename.suggested(for: createdAt)
                == "Home-Stuff-Inventory-Backup-2025-07-08T18-40-00.000Z"
        )
        #expect(!InventoryBackupFilename.suggested(for: createdAt).contains("/"))
    }

    @Test func completeBackupPreservesScopedPlaceIdentityIconsAndItemLinks() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let firstLocation = StorageLocation(name: "Garage", createdAt: createdAt, updatedAt: updatedAt)
        let secondLocation = StorageLocation(name: "Workshop", createdAt: createdAt, updatedAt: updatedAt)
        let firstPlace = InventoryPlace(locationID: firstLocation.id, name: "Shelf", iconID: "shelf", createdAt: createdAt, updatedAt: updatedAt)
        let secondPlace = InventoryPlace(locationID: secondLocation.id, name: "Shelf", iconID: "drawer", createdAt: createdAt, updatedAt: updatedAt)
        let firstItem = InventoryItem(name: "Drill", locationName: "Garage", containerName: "Shelf", placeID: firstPlace.id, createdAt: createdAt, updatedAt: updatedAt)
        let secondItem = InventoryItem(name: "Clamp", locationName: "Workshop", containerName: "Shelf", placeID: secondPlace.id, createdAt: createdAt, updatedAt: updatedAt)
        [firstLocation, secondLocation].forEach(context.insert)
        [firstPlace, secondPlace].forEach(context.insert)
        [firstItem, secondItem].forEach(context.insert)
        try context.save()

        let snapshot = try InventoryBackupSnapshotter.capture(in: context)
        let document = try InventoryPortabilityEncoder.decodeAndVerify(
            try await InventoryBackupEncoderService().encode(snapshot: snapshot, metadata: metadata)
        )

        #expect(document.inventory.places.map(\.name) == ["Shelf", "Shelf"])
        #expect(Set(document.inventory.places.map(\.locationID)).count == 2)
        #expect(Set(document.inventory.places.map(\.iconID)) == ["shelf", "drawer"])
        #expect(Set(document.inventory.items.compactMap(\.placeID)) == Set(document.inventory.places.map(\.id)))
    }

    private var metadata: InventoryPortabilityMetadataV1 {
        InventoryPortabilityMetadataV1(
            createdAt: createdAt,
            appVersion: "1.2.3",
            appBuild: "456"
        )
    }

    private func makeFixture() throws -> Fixture {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let location = StorageLocation(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Майстерня",
            iconID: "hammer",
            notes: "Для ремонту 🛠️",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let category = InventoryCustomCategory(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            name: "Електроніка для хобі",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let item = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            name: "Паяльник 🔧",
            category: category.name,
            locationName: location.name,
            containerName: "  Шухляда 📦  ",
            iconID: "wrench.and.screwdriver",
            quantity: 2,
            condition: InventoryCondition.good.rawValue,
            tags: ["Кабелі", "naïve 🧰"],
            notes: "Температура 350 °C\nОбережно",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let builtInItem = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
            name: "Cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "",
            containerName: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let viewEvent = InventoryItemViewEvent(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            itemID: item.id,
            viewedAt: updatedAt
        )

        context.insert(location)
        context.insert(category)
        context.insert(item)
        context.insert(builtInItem)
        context.insert(viewEvent)
        try context.save()

        return Fixture(
            context: context,
            location: location,
            category: category,
            item: item,
            viewEvent: viewEvent
        )
    }

    private func deterministicUUID(prefix: Int, index: Int) -> UUID {
        UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", prefix, index + 1))!
    }
}

@MainActor
private struct Fixture {
    let context: ModelContext
    let location: StorageLocation
    let category: InventoryCustomCategory
    let item: InventoryItem
    let viewEvent: InventoryItemViewEvent
}
