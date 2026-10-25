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

    @Test func filterMenuScaleFixtureRequiresSampleModeAndItsExplicitArgument() {
        let sample = SampleDataConfiguration.launchArgument
        let scale = InventoryFilterMenuScaleFixture.launchArgument
        #expect(!InventoryFilterMenuScaleFixture.isEnabled(arguments: []))
        #expect(!InventoryFilterMenuScaleFixture.isEnabled(arguments: [sample]))
        #expect(!InventoryFilterMenuScaleFixture.isEnabled(arguments: [scale]))
        #expect(InventoryFilterMenuScaleFixture.isEnabled(arguments: [sample, scale]))
    }

    @Test func filterMenuScaleFixtureSeedsDeterministicLinkedGraphAndMissingControls() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try InventoryFilterMenuScaleFixture.seed(in: context)
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())
        let categories = try context.fetch(FetchDescriptor<InventoryCustomCategory>())
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let regularItems = items.filter { $0.name.hasPrefix("Filter Item ") }
        let suffixes = (1...40).map { String(format: "%02d", $0) }

        #expect(locations.count == 40 && places.count == 40 && categories.count == 40)
        #expect(items.count == 42 && regularItems.count == 40)
        let locationNames: Set<String> = Set(locations.map(\.name))
        let placeNames: Set<String> = Set(places.map(\.name))
        let categoryNames: Set<String> = Set(categories.map(\.name))
        let itemNames: Set<String> = Set(regularItems.map(\.name))
        let expectedLocationNames: Set<String> = Set(suffixes.map { "Filter Location \($0)" })
        let expectedPlaceNames: Set<String> = Set(suffixes.map { "Filter Place \($0)" })
        let expectedCategoryNames: Set<String> = Set(suffixes.map { "Filter Category \($0)" })
        let expectedItemNames: Set<String> = Set(suffixes.map { "Filter Item \($0)" })
        #expect(locationNames == expectedLocationNames)
        #expect(placeNames == expectedPlaceNames)
        #expect(categoryNames == expectedCategoryNames)
        #expect(itemNames == expectedItemNames)
        #expect(places.allSatisfy { $0.parentPlaceID == nil })
        let linkedGraphIsValid: Bool = regularItems.allSatisfy { item in
            let suffix = String(item.name.suffix(2))
            guard let location = locations.first(where: { $0.name == "Filter Location \(suffix)" }),
                  let place = places.first(where: { $0.id == item.placeID }) else { return false }
            return item.locationName == location.name && place.locationID == location.id
                && place.name == "Filter Place \(suffix)" && item.containerName == place.name
                && item.category == "Filter Category \(suffix)" && item.quantity == 1
        }
        #expect(linkedGraphIsValid)

        let missingPlace = try #require(items.first { $0.name == "Filter Missing Place Item" })
        let missingLocation = try #require(items.first { $0.name == "Filter Missing Location Item" })
        #expect(missingPlace.locationName == "Filter Location 01")
        #expect(missingLocation.locationName.isEmpty)
        #expect([missingPlace, missingLocation].allSatisfy {
            $0.containerName == nil && $0.placeID == nil && $0.category == "Filter Category 01"
        })
        let missingPlaceMatches: [InventoryItem] = InventorySearch.matchingItems(
            in: items, query: "", filters: .init(locationName: "Filter Location 01", place: .missing)
        )
        let missingPlaceIDs: [UUID] = missingPlaceMatches.map(\.id)
        #expect(missingPlaceIDs == [missingPlace.id])
        let anyPlaceMatches: [InventoryItem] = InventorySearch.matchingItems(
            in: items, query: "", filters: .init(locationName: "Filter Location 01")
        )
        let anyPlaceIDs: Set<UUID> = Set(anyPlaceMatches.map(\.id))
        let namedPlaceItems: [InventoryItem] = regularItems.filter { $0.locationName == "Filter Location 01" }
        let namedPlaceIDs: [UUID] = namedPlaceItems.map(\.id)
        let expectedAnyPlaceIDs: Set<UUID> = Set([missingPlace.id] + namedPlaceIDs)
        #expect(anyPlaceIDs == expectedAnyPlaceIDs)
        let missingLocationMatches: [InventoryItem] = InventorySearch.matchingItems(
            in: items, query: "", filters: .init(locationName: InventoryBrowseVocabulary.default.missingLocationName)
        )
        let missingLocationIDs: [UUID] = missingLocationMatches.map(\.id)
        #expect(missingLocationIDs == [missingLocation.id])

        func identities(in context: ModelContext) throws -> [String: UUID] {
            let locations: [(String, UUID)] = try context.fetch(FetchDescriptor<StorageLocation>()).map { ("location:" + $0.name, $0.id) }
            let places: [(String, UUID)] = try context.fetch(FetchDescriptor<InventoryPlace>()).map { ("place:" + $0.name, $0.id) }
            let categories: [(String, UUID)] = try context.fetch(FetchDescriptor<InventoryCustomCategory>()).map { ("category:" + $0.name, $0.id) }
            let items: [(String, UUID)] = try context.fetch(FetchDescriptor<InventoryItem>()).map { ("item:" + $0.name, $0.id) }
            return Dictionary(uniqueKeysWithValues: locations + places + categories + items)
        }
        let firstIDs = try identities(in: context)
        let uniqueIDCount: Int = Set(firstIDs.values).count
        #expect(firstIDs.count == 162 && uniqueIDCount == 162)
        let secondContainer = try InventoryModelContainer.make(inMemory: true)
        let secondContext = ModelContext(secondContainer)
        try InventoryFilterMenuScaleFixture.seed(in: secondContext)
        let secondIDs: [String: UUID] = try identities(in: secondContext)
        #expect(secondIDs == firstIDs)
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
