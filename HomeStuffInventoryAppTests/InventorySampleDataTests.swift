import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

#if DEBUG
@MainActor
struct InventorySampleDataTests {
    @Test func sampleCatalogCoversExpectedHouseholdItems() {
        let sampleItems = InventorySampleData.items
        let sampleNames = Set(sampleItems.map(\.name))

        #expect(sampleItems.count == 10)
        #expect(sampleNames.contains("USB-C to HDMI adapter"))
        #expect(sampleNames.contains("Precision screwdriver set"))
        #expect(sampleNames.contains("CR2032 batteries"))
        #expect(sampleNames.contains("Ethernet cable 5m"))
        #expect(sampleNames.contains("Old router"))
        #expect(sampleNames.contains("Thermal paste"))
        #expect(sampleNames.contains("Drill bits"))
        #expect(sampleNames.contains("Bike pump"))
        #expect(sampleNames.contains("Spare charging cables"))
        #expect(sampleNames.contains("Cable ties"))
    }

    @Test func sampleItemsHaveMeaningfulFieldsForListAndDetailTesting() {
        for sampleItem in InventorySampleData.items {
            #expect(!sampleItem.name.isEmpty)
            #expect(!sampleItem.category.isEmpty)
            #expect(!sampleItem.locationName.isEmpty)
            #expect(!sampleItem.containerName.isEmpty)
            #expect(sampleItem.quantity > 0)
            #expect(!sampleItem.condition.isEmpty)
            #expect(!sampleItem.tags.isEmpty)
            #expect(!sampleItem.notes.isEmpty)
        }
    }

    @Test func sampleSeederLoadsItemsOnceIntoDevelopmentContainer() throws {
        let container = try InventoryModelContainer.makeSample(inMemory: true)
        let context = ModelContext(container)

        try InventorySampleDataSeeder.seedIfNeeded(in: context)

        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        #expect(items.count == InventorySampleData.items.count)
        #expect(locations.contains { $0.name == "Balcony cabinet" })
        #expect(items.contains { $0.name == "Bike pump" && $0.locationName == "Entryway" })
        #expect(items.contains { $0.name == "CR2032 batteries" && $0.quantity == 4 })
    }

    @Test func recentItemsLayoutFixtureRequiresItsExplicitLaunchArgument() {
        #expect(!InventoryRecentItemsLayoutFixture.isEnabled(arguments: []))
        #expect(InventoryRecentItemsLayoutFixture.isEnabled(arguments: [
            InventoryRecentItemsLayoutFixture.launchArgument
        ]))
    }

    @Test func recentItemsLayoutFixtureClampsExplicitScreenshotItemCount() {
        #expect(InventoryRecentItemsLayoutFixture.itemCount(arguments: []) == InventoryRecentItemsLayoutFixture.items.count)
        #expect(InventoryRecentItemsLayoutFixture.itemCount(arguments: [
            InventoryRecentItemsLayoutFixture.itemCountLaunchArgument, "1"
        ]) == 1)
        #expect(InventoryRecentItemsLayoutFixture.itemCount(arguments: [
            InventoryRecentItemsLayoutFixture.itemCountLaunchArgument, "3"
        ]) == 3)
        #expect(InventoryRecentItemsLayoutFixture.itemCount(arguments: [
            InventoryRecentItemsLayoutFixture.itemCountLaunchArgument, "99"
        ]) == InventoryRecentItemsLayoutFixture.items.count)
        #expect(InventoryRecentItemsLayoutFixture.itemCount(arguments: [
            InventoryRecentItemsLayoutFixture.itemCountLaunchArgument, "0"
        ]) == 1)
    }

    @Test func recentItemsLayoutFixtureSeedsDeterministicLocationPlaceItemsAndEvents() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        try InventoryRecentItemsLayoutFixture.seed(in: context, now: now)

        let items = try context.fetch(FetchDescriptor<InventoryItem>())
            .filter { InventoryRecentItemsLayoutFixture.items.map(\.id).contains($0.id) }
        let events = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
            .filter { InventoryRecentItemsLayoutFixture.items.map(\.eventID).contains($0.id) }
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let seededItemIDs = items.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let expectedItemIDs = InventoryRecentItemsLayoutFixture.items.map(\.id).sorted { $0.uuidString < $1.uuidString }

        #expect(items.count == 5)
        #expect(seededItemIDs == expectedItemIDs)
        #expect(items.allSatisfy { $0.locationName == InventoryRecentItemsLayoutFixture.locationName })
        #expect(items.allSatisfy { $0.containerName == InventoryRecentItemsLayoutFixture.placeName })
        #expect(locations.filter { $0.name == InventoryRecentItemsLayoutFixture.locationName }.count == 1)
        #expect(events.count == 4)
        #expect(events.allSatisfy { event in
            guard let fixtureItem = InventoryRecentItemsLayoutFixture.items.first(where: { $0.eventID == event.id }) else {
                return false
            }
            return event.itemID == fixtureItem.id
                && event.viewedAt == now.addingTimeInterval(-fixtureItem.recencyOffset)
        })

        let location = InventoryBrowseSummaries.locationSummaries(
            from: items,
            storageLocations: locations,
            recentViewEvents: events,
            now: now
        )
        .first { $0.name == InventoryRecentItemsLayoutFixture.locationName }
        let recentItems = location?.previewGroups.first {
            $0.kind == InventoryBrowseSummaries.PreviewGroup.Kind.recentItem
        }

        #expect(recentItems?.visibleItems.map(\.title) == Array(InventoryRecentItemsLayoutFixture.items.prefix(3).map(\.name)))
        #expect(recentItems?.hiddenCount == 1)
    }

    @Test func recentItemsLayoutFixtureIsIdempotentForItemsLocationsAndEvents() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        try InventoryRecentItemsLayoutFixture.seed(in: context, now: Date(timeIntervalSince1970: 1_800_000_000))
        try InventoryRecentItemsLayoutFixture.seed(in: context, now: Date(timeIntervalSince1970: 1_800_000_010))

        let itemIDs = Set(InventoryRecentItemsLayoutFixture.items.map(\.id))
        let eventIDs = Set(InventoryRecentItemsLayoutFixture.items.map(\.eventID))
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let events = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())

        #expect(items.filter { itemIDs.contains($0.id) }.count == 5)
        #expect(events.filter { itemIDs.contains($0.itemID) }.count == 4)
        #expect(events.filter { eventIDs.contains($0.id) }.count == 4)
        #expect(locations.filter { $0.name == InventoryRecentItemsLayoutFixture.locationName }.count == 1)
    }
}
#endif
