import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryReadableExportServiceTests {
    private let timestamp = Date(timeIntervalSince1970: 1_752_489_000)

    @Test func emptyInventoryProducesTruthfulVerifiedReadableDocument() throws {
        let artifact = try service().export(
            items: [],
            locations: [],
            customCategories: [],
            createdAt: timestamp,
            artifactID: UUID(uuidString: "90000000-0000-0000-0000-000000000001")!
        )
        defer { artifact.cleanup() }

        let data = try Data(contentsOf: artifact.url)
        let document = try InventoryPortabilityEncoder.decodeAndVerify(data)
        #expect(document.artifactType == .readableExport)
        #expect(document.inventory.items.isEmpty)
        #expect(document.inventory.locations.isEmpty)
        #expect(document.inventory.customCategories.isEmpty)
        #expect(document.inventory.recentItemViewEvents == nil)
        #expect(data.last == 0x0A)
    }

    @Test func fullExportPreservesUnicodeEveryFieldAndOptionalValues() throws {
        let fixture = fullFixture()
        let artifact = try service().export(
            items: fixture.items,
            locations: fixture.locations,
            customCategories: fixture.categories,
            createdAt: timestamp
        )
        defer { artifact.cleanup() }

        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))
        let item = try #require(document.inventory.items.first {
            $0.id == "30000000-0000-0000-0000-000000000002"
        })
        #expect(item.name == "Кабель USB-C — запасний")
        #expect(item.categoryStorageValue == "Пам’ятні речі")
        #expect(item.customCategoryID == "20000000-0000-0000-0000-000000000002")
        #expect(item.locationName == "Кімната 🏠")
        #expect(item.locationID == "10000000-0000-0000-0000-000000000002")
        #expect(item.placeName == "Шухляда №2")
        #expect(item.quantity == 3)
        #expect(item.conditionStorageValue == InventoryCondition.good.rawValue)
        #expect(item.tags == ["USB-C", "запас"])
        #expect(item.notes == "Для подорожей. Не загубити!")
        #expect(item.createdAt == "2025-07-14T10:30:00.000Z")
        #expect(item.updatedAt == "2025-07-14T10:30:00.000Z")
    }

    @Test func outputIsDeterministicAndSortedByLowercaseUUID() throws {
        let fixture = fullFixture()
        let first = try service().export(
            items: fixture.items.reversed(),
            locations: fixture.locations.reversed(),
            customCategories: fixture.categories.reversed(),
            createdAt: timestamp
        )
        let second = try service().export(
            items: fixture.items,
            locations: fixture.locations,
            customCategories: fixture.categories,
            createdAt: timestamp
        )
        defer {
            first.cleanup()
            second.cleanup()
        }

        #expect(try Data(contentsOf: first.url) == Data(contentsOf: second.url))
        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: first.url))
        #expect(document.inventory.items.map(\.id) == document.inventory.items.map(\.id).sorted())
    }

    @Test func trimsEmptyReadablePlaceWithoutChangingSourceItem() throws {
        let item = InventoryItem(name: "Adapter", locationName: "", containerName: "  ", notes: "")
        let originalUpdatedAt = item.updatedAt
        let artifact = try service().export(
            items: [item],
            locations: [],
            customCategories: [],
            createdAt: timestamp
        )
        defer { artifact.cleanup() }

        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))
        #expect(document.inventory.items.first?.placeName == nil)
        #expect(item.containerName == "  ")
        #expect(item.updatedAt == originalUpdatedAt)
    }

    @Test func injectedWriteFailuresAreTypedAndRemovePartialDirectory() throws {
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.write = { _, _ in throw CocoaError(.fileWriteUnknown) }
        let service = InventoryReadableExportService(fileSystem: fileSystem)

        #expect(throws: InventoryReadableExportError.destinationWriteFailed) {
            try service.export(items: [], locations: [], customCategories: [], createdAt: timestamp)
        }

        fileSystem.write = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        #expect(throws: InventoryReadableExportError.lowStorage) {
            try InventoryReadableExportService(fileSystem: fileSystem)
                .export(items: [], locations: [], customCategories: [], createdAt: timestamp)
        }
    }

    @Test func generationLimitFailureCreatesNoExportArtifact() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var fileSystem = InventoryReadableExportFileSystem()
        fileSystem.temporaryDirectory = { directory }
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 1, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10,
            maximumRecentItemViewEvents: 10, maximumTagsPerItem: 10,
            maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        #expect(throws: InventoryReadableExportError.unsupportedPortabilityLimits) {
            try InventoryReadableExportService(fileSystem: fileSystem, bundle: Bundle(for: TestBundleMarker.self), limits: limits)
                .export(items: [], locations: [], customCategories: [], createdAt: timestamp)
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func exportHasNoEntitlementOrNetworkDependency() throws {
        for state in InventoryEntitlementState.allCases {
            #expect(
                InventoryFreeAccessPolicy().availability(of: .exportInventory, entitlementState: state) == .available
            )
        }
        let artifact = try service().export(
            items: [InventoryItem(name: "Offline item", locationName: "Home")],
            locations: [],
            customCategories: [],
            createdAt: timestamp
        )
        defer { artifact.cleanup() }
        #expect(FileManager.default.fileExists(atPath: artifact.url.path))
    }

    @Test func readableExportPreservesTheCompleteNestedPlacePathWithoutEntitlement() throws {
        let location = StorageLocation(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Workshop",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let root = InventoryPlace(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!,
            locationID: location.id,
            name: "Cabinet",
            iconID: "cabinet",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let child = InventoryPlace(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
            locationID: location.id,
            parentPlaceID: root.id,
            name: "Drawer",
            iconID: "drawer",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let leaf = InventoryPlace(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
            locationID: location.id,
            parentPlaceID: child.id,
            name: "Cable box",
            iconID: "box",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let item = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            name: "Adapter",
            locationName: location.name,
            containerName: leaf.name,
            placeID: leaf.id,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let artifact = try service().export(
            items: [item],
            locations: [location],
            customCategories: [],
            places: [leaf, root, child],
            createdAt: timestamp
        )
        defer { artifact.cleanup() }
        let document = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))

        #expect(document.schemaVersion == 4)
        #expect(document.inventory.places.map(\.id) == [leaf.id, child.id, root.id].map(\.inventoryPortabilityString))
        #expect(document.inventory.places.map(\.parentPlaceID) == [
            child.id.inventoryPortabilityString,
            root.id.inventoryPortabilityString,
            nil
        ])
        #expect(document.inventory.items.first?.placeID == leaf.id.inventoryPortabilityString)
    }

    private func service() -> InventoryReadableExportService {
        InventoryReadableExportService(bundle: Bundle(for: TestBundleMarker.self))
    }

    private func fullFixture() -> (
        items: [InventoryItem],
        locations: [StorageLocation],
        categories: [InventoryCustomCategory]
    ) {
        let location = StorageLocation(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Кімната 🏠",
            notes: "Основне місце",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let category = InventoryCustomCategory(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            name: "Пам’ятні речі",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let item = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
            name: "Кабель USB-C — запасний",
            category: category.name,
            locationName: location.name,
            containerName: "Шухляда №2",
            quantity: 3,
            condition: InventoryCondition.good.rawValue,
            tags: ["USB-C", "запас"],
            notes: "Для подорожей. Не загубити!",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let earlierItem = InventoryItem(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            name: "Empty optionals",
            locationName: "",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return ([item, earlierItem], [location], [category])
    }
}

private final class TestBundleMarker {}
