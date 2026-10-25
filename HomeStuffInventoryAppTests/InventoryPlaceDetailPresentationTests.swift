import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

struct InventoryPlaceDetailPresentationTests {
    private let location = StorageLocation(name: "Office")

    @Test(arguments: [0, 1, 4, 5])
    func realTopLevelLeafUsesSimpleLayout(itemCount: Int) {
        let model = InventoryPlace(locationID: location.id, name: "Drawer")
        let summary = summary(model, count: itemCount)
        #expect(usesSimple(summary, places: [model]))
    }

    @Test func normalizedLocationContextMatches() {
        let model = InventoryPlace(locationID: location.id, name: "Drawer")
        #expect(usesSimple(summary(model, locationName: " OFFICE "), places: [model]))
        #expect(!usesSimple(summary(model, locationName: "Garage"), places: [model]))
    }

    @Test func nestedLeafAndMalformedParentsKeepExtendedLayout() {
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let child = InventoryPlace(locationID: location.id, parentPlaceID: parent.id, name: "Drawer")
        // The summary deliberately has the default one-component path and no parent ID.
        #expect(!usesSimple(summary(child), places: [parent, child]))
        #expect(!usesSimple(summary(child), places: [child]))
        child.parentPlaceID = child.id
        #expect(!usesSimple(summary(child), places: [child]))
        let crossLocationParent = InventoryPlace(locationID: UUID(), name: "Other cabinet")
        child.parentPlaceID = crossLocationParent.id
        #expect(!usesSimple(summary(child), places: [crossLocationParent, child]))
    }

    @Test func childrenAndUnequalCountsKeepExtendedLayout() {
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let child = InventoryPlace(locationID: location.id, parentPlaceID: parent.id, name: "Drawer")
        #expect(!usesSimple(summary(parent, childCount: 1), places: [parent, child]))
        #expect(!usesSimple(summary(parent, recursiveCount: 1), places: [parent]))
        #expect(!usesSimple(summary(parent), places: [parent, child], children: [summary(child)]))
    }

    @Test func unresolvedAndMissingContextsKeepExtendedLayout() {
        let model = InventoryPlace(locationID: location.id, name: "Drawer")
        #expect(!usesSimple(summary(model), places: []))
        #expect(!usesSimple(summary(model), places: [model], locations: []))
        #expect(!usesSimple(summary(model, missingPlace: true), places: [model]))
        #expect(!usesSimple(summary(model, missingLocation: true), places: [model]))
        #expect(!usesSimple(summary(nil), places: [model]))
        let unresolved = InventoryPlace(locationID: UUID(), name: "Drawer")
        #expect(!usesSimple(summary(unresolved), places: [unresolved]))
    }

    @Test @MainActor func shippedRecentFixtureResolvesRealLeafAfterNormalMaintenance() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try InventoryRecentItemsLayoutFixture.seed(in: context)
        try InventoryPlaceReconciler.reconcile(in: context)
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let events = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
        let selectedLocation = try #require(InventoryBrowseSummaries.locationSummaries(
            from: items, storageLocations: locations
        ).first { $0.name == InventoryRecentItemsLayoutFixture.locationName })
        let selected = try #require(InventoryBrowseSummaries.placeSummaries(
            in: items, matching: selectedLocation, places: places, recentViewEvents: events
        ).first)
        let detail = InventoryBrowseSummaries.placeDetailSummary(
            in: items, matching: selected, places: places, recentViewEvents: events
        )
        #expect(items.count == 5)
        #expect(events.count == 4)
        #expect(items.allSatisfy { $0.placeID == selected.placeID && $0.placeID != nil })
        #expect(InventoryPlaceDetailPresentation.usesSimpleLeafLayout(
            selectedPlace: selected, detailPlace: detail, places: places,
            locations: locations, childPlaces: []
        ))
    }

    private func usesSimple(
        _ summary: InventoryBrowseSummaries.PlaceSummary,
        places: [InventoryPlace],
        locations: [StorageLocation]? = nil,
        children: [InventoryBrowseSummaries.PlaceSummary] = []
    ) -> Bool {
        InventoryPlaceDetailPresentation.usesSimpleLeafLayout(
            selectedPlace: summary, detailPlace: summary, places: places,
            locations: locations ?? [location], childPlaces: children
        )
    }

    private func summary(
        _ model: InventoryPlace?, count: Int = 0, recursiveCount: Int? = nil,
        childCount: Int = 0, locationName: String = "Office",
        missingPlace: Bool = false, missingLocation: Bool = false
    ) -> InventoryBrowseSummaries.PlaceSummary {
        .init(
            id: model?.id.uuidString ?? "legacy", placeID: model?.id,
            name: model?.name ?? "Drawer", itemCount: count,
            directItemCount: count, recursiveItemCount: recursiveCount ?? count,
            childPlaceCount: childCount, locationID: locationName,
            locationName: locationName, isMissingLocation: missingLocation,
            isMissingPlace: missingPlace
        )
    }
}
