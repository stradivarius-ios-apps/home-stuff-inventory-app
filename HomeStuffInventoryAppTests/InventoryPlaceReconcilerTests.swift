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

    @Test func legacyFlatPlaceRemainsTopLevelWithoutIdentityOrTextChanges() throws {
        let context = try makeContext()
        let location = StorageLocation(id: fixedUUID(1), name: " Hall ")
        let createdAt = Date(timeIntervalSince1970: 10)
        let updatedAt = Date(timeIntervalSince1970: 20)
        let place = InventoryPlace(
            id: fixedUUID(2),
            locationID: location.id,
            name: " Drawer ",
            iconID: "drawer",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let item = InventoryItem(
            id: fixedUUID(3),
            name: "Cable",
            locationName: " Hall ",
            containerName: " Drawer ",
            placeID: place.id
        )
        context.insert(location)
        context.insert(place)
        context.insert(item)
        try context.save()

        let report = try InventoryPlaceReconciler.reconcile(in: context)

        #expect(report == InventoryPlaceRepairReport())
        #expect(place.id == fixedUUID(2))
        #expect(place.parentPlaceID == nil)
        #expect(place.name == "Drawer")
        #expect(place.iconID == "drawer")
        #expect(place.createdAt == createdAt)
        #expect(place.updatedAt == updatedAt)
        #expect(item.placeID == place.id)
        #expect(item.locationName == " Hall ")
        #expect(item.containerName == " Drawer ")
    }

    @Test func hierarchyRepairIsNonDestructiveDeterministicAndIdempotent() throws {
        let context = try makeContext()
        let firstLocation = StorageLocation(id: fixedUUID(10), name: "Home")
        let secondLocation = StorageLocation(id: fixedUUID(11), name: "Garage")
        let missingParent = InventoryPlace(
            id: fixedUUID(20),
            locationID: firstLocation.id,
            parentPlaceID: fixedUUID(99),
            name: "Missing parent"
        )
        let foreignParent = InventoryPlace(id: fixedUUID(21), locationID: secondLocation.id, name: "Foreign")
        let crossLocation = InventoryPlace(
            id: fixedUUID(22),
            locationID: firstLocation.id,
            parentPlaceID: foreignParent.id,
            name: "Cross-location"
        )
        let selfParent = InventoryPlace(
            id: fixedUUID(23),
            locationID: firstLocation.id,
            parentPlaceID: fixedUUID(23),
            name: "Self"
        )
        let cycleFirst = InventoryPlace(id: fixedUUID(24), locationID: firstLocation.id, name: "Cycle A")
        let cycleSecond = InventoryPlace(
            id: fixedUUID(25),
            locationID: firstLocation.id,
            parentPlaceID: cycleFirst.id,
            name: "Cycle B"
        )
        cycleFirst.parentPlaceID = cycleSecond.id
        let duplicateFirst = InventoryPlace(id: fixedUUID(30), locationID: firstLocation.id, name: " Box ")
        let duplicateSecond = InventoryPlace(id: fixedUUID(31), locationID: firstLocation.id, name: "box")
        let duplicateThird = InventoryPlace(id: fixedUUID(32), locationID: firstLocation.id, name: "BOX")
        let firstItem = InventoryItem(
            id: fixedUUID(40),
            name: "First Item",
            locationName: firstLocation.name,
            containerName: duplicateFirst.name,
            placeID: duplicateFirst.id
        )
        let secondItem = InventoryItem(
            id: fixedUUID(41),
            name: "Second Item",
            locationName: firstLocation.name,
            containerName: duplicateSecond.name,
            placeID: duplicateSecond.id
        )
        let places = [
            missingParent, foreignParent, crossLocation, selfParent, cycleFirst, cycleSecond,
            duplicateFirst, duplicateSecond, duplicateThird
        ]
        [firstLocation, secondLocation].forEach(context.insert)
        places.forEach(context.insert)
        [firstItem, secondItem].forEach(context.insert)
        try context.save()

        let firstReport = try InventoryPlaceReconciler.reconcile(in: context)
        let parentSnapshot = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.parentPlaceID) })
        let secondReport = try InventoryPlaceReconciler.reconcile(in: context)

        #expect(firstReport.missingParentsRemoved == 1)
        #expect(firstReport.crossLocationParentsRemoved == 1)
        #expect(firstReport.selfParentsRemoved == 1)
        #expect(firstReport.cyclesBroken == 1)
        #expect(firstReport.siblingCollisionsReparented == 2)
        #expect(secondReport == InventoryPlaceRepairReport())
        #expect(Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.parentPlaceID) }) == parentSnapshot)
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).count == places.count)
        #expect(firstItem.placeID == duplicateFirst.id)
        #expect(secondItem.placeID == duplicateSecond.id)
        #expect(firstItem.name == "First Item")
        #expect(secondItem.name == "Second Item")
        #expect(Set(places.map(\.id)).count == places.count)

        for place in places {
            #expect(InventoryPlaceHierarchy.path(for: place, places: places).status == .complete)
        }
        let siblingScopes = places.map {
            "\($0.locationID.uuidString)|\($0.parentPlaceID?.uuidString ?? "top")|\(InventoryNormalizedName.place($0.name).comparisonKey)"
        }
        #expect(Set(siblingScopes).count == siblingScopes.count)
    }

    @Test func equalNamesUnderDifferentParentsNeedNoRepair() throws {
        let context = try makeContext()
        let location = StorageLocation(name: "Home")
        let firstParent = InventoryPlace(locationID: location.id, name: "First")
        let secondParent = InventoryPlace(locationID: location.id, name: "Second")
        let firstBox = InventoryPlace(locationID: location.id, parentPlaceID: firstParent.id, name: "Box")
        let secondBox = InventoryPlace(locationID: location.id, parentPlaceID: secondParent.id, name: "box")
        context.insert(location)
        [firstParent, secondParent, firstBox, secondBox].forEach(context.insert)
        try context.save()

        let report = try InventoryPlaceReconciler.reconcile(in: context)

        #expect(report == InventoryPlaceRepairReport())
        #expect(firstBox.parentPlaceID == firstParent.id)
        #expect(secondBox.parentPlaceID == secondParent.id)
    }

    @Test func parentChildGrandchildAndDirectItemsCoexistThroughMaintenance() throws {
        let context = try makeContext()
        let location = StorageLocation(name: "Home")
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let child = InventoryPlace(locationID: location.id, parentPlaceID: parent.id, name: "Drawer")
        let grandchild = InventoryPlace(locationID: location.id, parentPlaceID: child.id, name: "Box")
        let directParentItem = InventoryItem(
            name: "Manual",
            locationName: location.name,
            containerName: parent.name,
            placeID: parent.id
        )
        let directGrandchildItem = InventoryItem(
            name: "Cable",
            locationName: location.name,
            containerName: grandchild.name,
            placeID: grandchild.id
        )
        context.insert(location)
        [parent, child, grandchild].forEach(context.insert)
        [directParentItem, directGrandchildItem].forEach(context.insert)
        try context.save()

        let report = try InventoryPlaceReconciler.reconcile(in: context)

        #expect(report == InventoryPlaceRepairReport())
        #expect(parent.parentPlaceID == nil)
        #expect(child.parentPlaceID == parent.id)
        #expect(grandchild.parentPlaceID == child.id)
        #expect(directParentItem.placeID == parent.id)
        #expect(directGrandchildItem.placeID == grandchild.id)
        #expect(
            InventoryPlaceHierarchy.path(for: grandchild, places: [grandchild, parent, child]).placeIDs
                == [parent.id, child.id, grandchild.id]
        )
    }

    @Test func validNestedStableLinkWinsOverStaleCompatibilityText() throws {
        let context = try makeContext()
        let location = StorageLocation(name: "Home")
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let child = InventoryPlace(locationID: location.id, parentPlaceID: parent.id, name: "Current drawer")
        let item = InventoryItem(
            name: "Cable",
            locationName: location.name,
            containerName: "Former drawer",
            placeID: child.id
        )
        context.insert(location)
        [parent, child].forEach(context.insert)
        context.insert(item)
        try context.save()

        let firstReport = try InventoryPlaceReconciler.reconcile(in: context)
        let secondReport = try InventoryPlaceReconciler.reconcile(in: context)
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())

        #expect(firstReport == InventoryPlaceRepairReport())
        #expect(secondReport == InventoryPlaceRepairReport())
        #expect(places.count == 2)
        #expect(Set(places.map(\.id)) == [parent.id, child.id])
        #expect(child.parentPlaceID == parent.id)
        #expect(item.placeID == child.id)
        #expect(item.containerName == "Former drawer")
        #expect(item.locationName == "Home")
    }

    @Test func failedHierarchyRepairSaveRestoresPersistedLinksAndItems() throws {
        let context = try makeContext()
        let location = StorageLocation(name: "Home")
        let placeID = fixedUUID(70)
        let selfParent = InventoryPlace(
            id: placeID,
            locationID: location.id,
            parentPlaceID: placeID,
            name: "Drawer"
        )
        let item = InventoryItem(
            name: "Cable",
            locationName: location.name,
            containerName: selfParent.name,
            placeID: selfParent.id
        )
        context.insert(location)
        context.insert(selfParent)
        context.insert(item)
        try context.save()

        #expect(throws: InventoryPlaceReconcilerError.saveFailed) {
            try InventoryPlaceReconciler.reconcile(in: context, save: { _ in throw SaveFailure() })
        }
        #expect(selfParent.parentPlaceID == selfParent.id)
        #expect(item.placeID == selfParent.id)
        #expect(item.name == "Cable")
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

    private func fixedUUID(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }

    private struct SaveFailure: Error {}
}
