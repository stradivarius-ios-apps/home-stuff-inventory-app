import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryPlaceReconcilerTests {
    @Test func samePlaceNameInDifferentLocationsCreatesDistinctStablePlaces() throws {
        let context = try makeContext()
        let kitchen = InventoryItem(name: "Tea", locationName: "Kitchen", containerName: "Shelf")
        let office = InventoryItem(name: "Paper", locationName: "Office", containerName: "Shelf")
        context.insert(kitchen)
        context.insert(office)
        try context.save()

        try InventoryPlaceReconciler.reconcile(in: context)

        let places = try context.fetch(FetchDescriptor<InventoryPlace>())
        #expect(places.count == 2)
        #expect(kitchen.placeID != office.placeID)
        #expect(Set(places.map(\.name)) == ["Shelf"])
    }

    @Test func caseAndWhitespaceDuplicatesCollapseOnlyInsideOneLocation() throws {
        let context = try makeContext()
        let first = InventoryItem(name: "One", locationName: " Hall ", containerName: " Shelf ")
        let second = InventoryItem(name: "Two", locationName: "hall", containerName: "shelf")
        let accented = InventoryItem(name: "Three", locationName: "Hall", containerName: "Šhelf")
        [first, second, accented].forEach(context.insert)
        try context.save()

        try InventoryPlaceReconciler.reconcile(in: context)

        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).count == 2)
        #expect(first.placeID == second.placeID)
        #expect(first.placeID != accented.placeID)
    }

    @Test func missingLocationOrPlaceStaysUnlinked() throws {
        let context = try makeContext()
        let missingLocation = InventoryItem(name: "One", locationName: "", containerName: "Shelf")
        let missingPlace = InventoryItem(name: "Two", locationName: "Hall", containerName: " ")
        [missingLocation, missingPlace].forEach(context.insert)
        try context.save()

        try InventoryPlaceReconciler.reconcile(in: context)

        #expect(missingLocation.placeID == nil)
        #expect(missingPlace.placeID == nil)
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).isEmpty)
    }

    @Test func missingReusableLocationIsCreatedOnceWithoutChangingLegacyItemText() throws {
        let context = try makeContext()
        let first = InventoryItem(name: "One", locationName: " Hall ", containerName: "Shelf")
        let second = InventoryItem(name: "Two", locationName: "hall", containerName: "Shelf")
        [first, second].forEach(context.insert)
        try context.save()

        try InventoryPlaceReconciler.reconcile(in: context)
        try InventoryPlaceReconciler.reconcile(in: context)

        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).count == 1)
        #expect(first.locationName == " Hall ")
        #expect(second.locationName == "hall")
        #expect(first.containerName == "Shelf")
        #expect(second.containerName == "Shelf")
    }

    @Test func invalidPlaceIconResolvesToBoxDefault() {
        #expect(PlaceIconCatalog.normalizedIconID(nil) == "box")
        #expect(PlaceIconCatalog.normalizedIconID("legacy-symbol") == "box")
        #expect(PlaceIconCatalog.symbolName(for: "legacy-symbol") == "shippingbox")
        #expect(PlaceIconCatalog.symbolName(for: "drawer") == "cabinet.fill")
        #expect(PlaceIconCatalog.symbolName(for: nil) == "shippingbox")
    }

    @Test func maintenanceIsIdempotentWithoutTimestampChurn() throws {
        let context = try makeContext()
        let item = InventoryItem(name: "One", locationName: "Hall", containerName: "Shelf")
        context.insert(item)
        try context.save()

        try InventoryPlaceReconciler.reconcile(in: context)
        let place = try #require(context.fetch(FetchDescriptor<InventoryPlace>()).first)
        let createdAt = place.createdAt
        let updatedAt = place.updatedAt
        try InventoryPlaceReconciler.reconcile(in: context)

        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).map(\.id) == [place.id])
        #expect(place.createdAt == createdAt)
        #expect(place.updatedAt == updatedAt)
    }

    @Test func legacyOpenHistoryReconcilesToStablePlaceAndRepairsDuplicateCounts() throws {
        let context = try makeContext()
        let item = InventoryItem(name: "One", locationName: "Hall", containerName: "Shelf")
        context.insert(item)
        try context.save()
        try InventoryPlaceReconciler.reconcile(in: context)
        let identity = InventoryPlaceIdentity.make(for: item).rawValue
        context.insert(InventoryPlaceOpenRecord(placeIdentity: identity, openCount: -2, lastOpenedAt: .distantPast))
        context.insert(InventoryPlaceOpenRecord(placeIdentity: identity, openCount: 4, lastOpenedAt: Date(timeIntervalSince1970: 20)))
        try context.save()

        try InventoryPlaceOpenPersistence.repairPersistedRecords(in: context)
        try InventoryPlaceOpenPersistence.repairPersistedRecords(in: context)

        let record = try #require(context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(record.placeID == item.placeID)
        #expect(record.openCount == 4)
        #expect(record.lastOpenedAt == Date(timeIntervalSince1970: 20))
    }

    @Test func failedBackfillSaveRollsBackLinksAndLeavesInventoryReadable() throws {
        let context = try makeContext()
        let item = InventoryItem(name: "One", locationName: "Hall", containerName: "Shelf")
        context.insert(item)
        try context.save()

        #expect(throws: InventoryPlaceReconcilerError.saveFailed) {
            try InventoryPlaceReconciler.reconcile(in: context, save: { _ in throw SaveFailure() })
        }
        #expect(item.placeID == nil)
        #expect(item.locationName == "Hall")
        #expect(item.containerName == "Shelf")
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).isEmpty)
    }

    @Test func editingLegacyPlaceTextClearsAnOtherwiseStaleStableLink() {
        let linkedPlaceID = UUID()
        let item = InventoryItem(name: "One", locationName: "Hall", containerName: "Shelf", placeID: linkedPlaceID)

        item.applyUserEdit(
            name: "One",
            category: InventoryCategory.miscellaneous.rawValue,
            locationName: "Hall",
            containerName: "Drawer",
            iconID: nil,
            quantity: 1,
            condition: InventoryCondition.unknown.rawValue,
            tags: [],
            notes: ""
        )

        #expect(item.placeID == nil)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private struct SaveFailure: Error {}
}
