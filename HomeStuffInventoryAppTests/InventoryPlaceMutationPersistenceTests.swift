import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryPlaceMutationPersistenceTests {
    @Test func childCreationRequiresAccessAndEnforcesSiblingScopedNames() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let otherParent = InventoryPlace(locationID: location.id, name: "Closet")
        context.insert(location)
        context.insert(parent)
        context.insert(otherParent)
        try context.save()

        #expect(throws: InventoryPlaceMutationError.accessRequired) {
            try InventoryPlaceMutationPersistence.createChild(
                named: "Drawer",
                under: .init(place: parent),
                entitlements: .free,
                in: context
            )
        }

        let child = try InventoryPlaceMutationPersistence.createChild(
            named: " Drawer ",
            under: .init(place: parent),
            entitlements: pro,
            in: context
        )
        #expect(child.parentPlaceID == parent.id)
        #expect(child.locationID == location.id)
        #expect(child.name == "Drawer")

        #expect(throws: InventoryPlaceMutationError.duplicateSiblingName("DRAWER")) {
            try InventoryPlaceMutationPersistence.createChild(
                named: "DRAWER",
                under: .init(place: parent),
                entitlements: pro,
                in: context
            )
        }

        let sameNameOtherBranch = try InventoryPlaceMutationPersistence.createChild(
            named: "drawer",
            under: .init(place: otherParent),
            entitlements: pro,
            in: context
        )
        #expect(sameNameOtherBranch.parentPlaceID == otherParent.id)
    }

    @Test func emptyChildNameIsRejectedWithoutCreatingAPlaceholder() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        context.insert(location)
        context.insert(parent)
        try context.save()

        #expect(throws: InventoryPlaceMutationError.emptyName) {
            try InventoryPlaceMutationPersistence.createChild(
                named: " \n ",
                under: .init(place: parent),
                entitlements: pro,
                in: context
            )
        }
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).map(\.id) == [parent.id])
    }

    @Test func downgradeKeepsFlatRenameFreeButNestedHierarchyReadOnly() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let child = InventoryPlace(locationID: location.id, parentPlaceID: parent.id, name: "Drawer")
        let flat = InventoryPlace(locationID: location.id, name: "Shelf")
        let item = InventoryItem(
            name: "Cable",
            locationName: location.name,
            containerName: child.name,
            placeID: child.id
        )
        context.insert(location)
        context.insert(parent)
        context.insert(child)
        context.insert(flat)
        context.insert(item)
        try context.save()

        try InventoryPlaceMutationPersistence.rename(
            .init(place: flat),
            to: "Wall Shelf",
            iconID: "shelf",
            entitlements: .free,
            in: context
        )
        #expect(flat.name == "Wall Shelf")

        #expect(throws: InventoryPlaceMutationError.accessRequired) {
            try InventoryPlaceMutationPersistence.rename(
                .init(place: parent),
                to: "Tall Cabinet",
                iconID: "cabinet",
                entitlements: .free,
                in: context
            )
        }
        #expect(parent.name == "Cabinet")
        #expect(throws: InventoryPlaceMutationError.accessRequired) {
            try InventoryPlaceMutationPersistence.rename(
                .init(place: child),
                to: "Cable Drawer",
                iconID: "drawer",
                entitlements: .free,
                in: context
            )
        }
        #expect(child.name == "Drawer")
        #expect(item.containerName == "Drawer")

        try InventoryPlaceMutationPersistence.rename(
            .init(place: child),
            to: "Cable Drawer",
            iconID: "drawer",
            entitlements: pro,
            in: context
        )
        #expect(child.name == "Cable Drawer")
        #expect(item.containerName == "Cable Drawer")
        #expect(item.placeID == child.id)
    }

    @Test func locationChangingSubtreeMoveIsAtomicAndRecordsOneGroupedMovement() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let root = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(locationID: office.id, parentPlaceID: root.id, name: "Drawer")
        let grandchild = InventoryPlace(locationID: office.id, parentPlaceID: child.id, name: "Box")
        let rootItem = InventoryItem(
            name: "Tape",
            locationName: office.name,
            containerName: root.name,
            placeID: root.id
        )
        let childItem = InventoryItem(
            name: "Cable",
            locationName: office.name,
            containerName: child.name,
            placeID: child.id
        )
        context.insert(office)
        context.insert(garage)
        context.insert(root)
        context.insert(child)
        context.insert(grandchild)
        context.insert(rootItem)
        context.insert(childItem)
        try context.save()
        let operationID = UUID()

        let record = try InventoryPlaceMutationPersistence.moveSubtree(
            .init(place: root),
            toLocationID: garage.id,
            parentPlaceID: nil,
            entitlements: pro,
            in: context,
            operationID: operationID
        )

        #expect(Set([root.locationID, child.locationID, grandchild.locationID]) == [garage.id])
        #expect(root.parentPlaceID == nil)
        #expect(child.parentPlaceID == root.id)
        #expect(grandchild.parentPlaceID == child.id)
        #expect(rootItem.locationName == "Garage")
        #expect(childItem.locationName == "Garage")
        #expect(rootItem.placeID == root.id)
        #expect(childItem.placeID == child.id)
        #expect(record?.id == operationID)
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
        #expect(
            InventoryPlaceMutationPersistence.undoLatest(
                entitlements: pro,
                in: context
            ) == .undone(operationID: operationID)
        )
        #expect(Set([root.locationID, child.locationID, grandchild.locationID]) == [office.id])
        #expect(rootItem.locationName == "Office")
        #expect(childItem.locationName == "Office")
    }

    @Test func sameLocationDetachPreservesStableIdentityAndItemCompatibility() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let parent = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(locationID: office.id, parentPlaceID: parent.id, name: "Drawer")
        let item = InventoryItem(
            name: "Cable",
            locationName: office.name,
            containerName: child.name,
            placeID: child.id
        )
        context.insert(office)
        context.insert(parent)
        context.insert(child)
        context.insert(item)
        try context.save()
        let originalItemUpdatedAt = item.updatedAt

        let record = try InventoryPlaceMutationPersistence.moveSubtree(
            .init(place: child),
            toLocationID: office.id,
            parentPlaceID: nil,
            entitlements: pro,
            in: context
        )

        #expect(child.parentPlaceID == nil)
        #expect(child.locationID == office.id)
        #expect(item.placeID == child.id)
        #expect(item.locationName == "Office")
        #expect(item.containerName == "Drawer")
        #expect(item.updatedAt == originalItemUpdatedAt)
        let operationID = try #require(record?.id)
        #expect(
            InventoryPlaceMutationPersistence.undoLatest(
                entitlements: pro,
                in: context
            ) == .undone(operationID: operationID)
        )
        #expect(child.parentPlaceID == parent.id)
        #expect(item.updatedAt == originalItemUpdatedAt)
    }

    @Test func reparentRejectsCyclesCrossLocationParentsAndDestinationConflicts() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let root = InventoryPlace(locationID: office.id, name: "Box")
        let child = InventoryPlace(locationID: office.id, parentPlaceID: root.id, name: "Drawer")
        let foreignParent = InventoryPlace(locationID: garage.id, name: "Shelf")
        let conflicting = InventoryPlace(locationID: garage.id, name: "Box")
        context.insert(office)
        context.insert(garage)
        context.insert(root)
        context.insert(child)
        context.insert(foreignParent)
        context.insert(conflicting)
        try context.save()

        #expect(throws: InventoryPlaceMutationError.descendantCycle) {
            try InventoryPlaceMutationPersistence.moveSubtree(
                .init(place: root),
                toLocationID: office.id,
                parentPlaceID: child.id,
                entitlements: pro,
                in: context
            )
        }
        #expect(throws: InventoryPlaceMutationError.crossLocationParent) {
            try InventoryPlaceMutationPersistence.moveSubtree(
                .init(place: root),
                toLocationID: office.id,
                parentPlaceID: foreignParent.id,
                entitlements: pro,
                in: context
            )
        }
        #expect(throws: InventoryPlaceMutationError.duplicateSiblingName("Box")) {
            try InventoryPlaceMutationPersistence.moveSubtree(
                .init(place: root),
                toLocationID: garage.id,
                parentPlaceID: nil,
                entitlements: pro,
                in: context
            )
        }
    }

    @Test func destinationParentRequiresCompleteAuthoritativeAncestry() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let moving = InventoryPlace(locationID: office.id, name: "Moving")
        let missingAncestor = InventoryPlace(
            locationID: office.id,
            parentPlaceID: UUID(),
            name: "Missing ancestor"
        )
        let foreignAncestor = InventoryPlace(locationID: garage.id, name: "Foreign")
        let crossLocationChild = InventoryPlace(
            locationID: office.id,
            parentPlaceID: foreignAncestor.id,
            name: "Cross-location child"
        )
        let cycleFirst = InventoryPlace(locationID: office.id, name: "Cycle one")
        let cycleSecond = InventoryPlace(
            locationID: office.id,
            parentPlaceID: cycleFirst.id,
            name: "Cycle two"
        )
        cycleFirst.parentPlaceID = cycleSecond.id
        for model in [office, garage] {
            context.insert(model)
        }
        for model in [
            moving,
            missingAncestor,
            foreignAncestor,
            crossLocationChild,
            cycleFirst,
            cycleSecond
        ] {
            context.insert(model)
        }
        try context.save()

        #expect(throws: InventoryPlaceMutationError.missingParent) {
            try InventoryPlaceMutationPersistence.createChild(
                named: "Child",
                under: .init(place: missingAncestor),
                entitlements: pro,
                in: context
            )
        }
        #expect(throws: InventoryPlaceMutationError.crossLocationParent) {
            try InventoryPlaceMutationPersistence.moveSubtree(
                .init(place: moving),
                toLocationID: office.id,
                parentPlaceID: crossLocationChild.id,
                entitlements: pro,
                in: context
            )
        }
        #expect(throws: InventoryPlaceMutationError.descendantCycle) {
            try InventoryPlaceMutationPersistence.moveSubtree(
                .init(place: moving),
                toLocationID: office.id,
                parentPlaceID: cycleFirst.id,
                entitlements: pro,
                in: context
            )
        }
    }

    @Test func hierarchyUndoRefusesStaleSubtreeWithoutPartialRestoration() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let root = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(locationID: office.id, parentPlaceID: root.id, name: "Drawer")
        context.insert(office)
        context.insert(garage)
        context.insert(root)
        context.insert(child)
        try context.save()

        let movedRecord = try InventoryPlaceMutationPersistence.moveSubtree(
            .init(place: root),
            toLocationID: garage.id,
            parentPlaceID: nil,
            entitlements: pro,
            in: context
        )
        let record = try #require(movedRecord)
        let addedAfterMove = InventoryPlace(
            locationID: garage.id,
            parentPlaceID: child.id,
            name: "New child"
        )
        context.insert(addedAfterMove)
        try context.save()

        #expect(
            InventoryPlaceMutationPersistence.undoLatestAvailability(
                entitlements: pro,
                in: context
            ) == .currentStateChanged
        )
        #expect(
            InventoryPlaceMutationPersistence.undoLatest(
                entitlements: pro,
                in: context
            ) == .currentStateChanged
        )
        #expect(root.locationID == garage.id)
        #expect(child.locationID == garage.id)
        #expect(addedAfterMove.locationID == garage.id)
        #expect(record.undoneAt == nil)
    }

    @Test func failedHierarchyUndoRollsBackEveryPlaceItemAndRecord() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let root = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(locationID: office.id, parentPlaceID: root.id, name: "Drawer")
        let item = InventoryItem(
            name: "Cable",
            locationName: office.name,
            containerName: child.name,
            placeID: child.id
        )
        context.insert(office)
        context.insert(garage)
        context.insert(root)
        context.insert(child)
        context.insert(item)
        try context.save()

        let movedRecord = try InventoryPlaceMutationPersistence.moveSubtree(
            .init(place: root),
            toLocationID: garage.id,
            parentPlaceID: nil,
            entitlements: pro,
            in: context
        )
        let record = try #require(movedRecord)
        #expect(
            InventoryPlaceMutationPersistence.undoLatest(
                entitlements: pro,
                in: context,
                persist: { throw PersistenceFailure.expected }
            ) == .failed
        )

        let storedPlaces = try context.fetch(FetchDescriptor<InventoryPlace>())
        let storedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        let storedRecord = try #require(
            context.fetch(FetchDescriptor<InventoryPlaceMutationRecord>()).first
        )
        #expect(storedPlaces.allSatisfy { $0.locationID == garage.id })
        #expect(storedItem.locationName == "Garage")
        #expect(storedRecord.id == record.id)
        #expect(storedRecord.undoneAt == nil)
    }

    @Test func hierarchyMutationHistoryPrunesWholeGroupedOperations() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let root = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(locationID: office.id, parentPlaceID: root.id, name: "Drawer")
        context.insert(office)
        context.insert(garage)
        context.insert(root)
        context.insert(child)
        try context.save()
        let firstID = UUID()
        let secondID = UUID()

        _ = try InventoryPlaceMutationPersistence.moveSubtree(
            .init(place: root),
            toLocationID: garage.id,
            parentPlaceID: nil,
            entitlements: pro,
            in: context,
            operationID: firstID,
            occurredAt: Date(timeIntervalSince1970: 1),
            retainedOperationLimit: 1
        )
        _ = try InventoryPlaceMutationPersistence.moveSubtree(
            .init(place: root),
            toLocationID: office.id,
            parentPlaceID: nil,
            entitlements: pro,
            in: context,
            operationID: secondID,
            occurredAt: Date(timeIntervalSince1970: 2),
            retainedOperationLimit: 1
        )

        #expect(
            try context.fetch(FetchDescriptor<InventoryPlaceMutationRecord>()).map(\.id)
                == [secondID]
        )
        #expect(root.locationID == office.id)
        #expect(child.locationID == office.id)
    }

    @Test func staleExpectationAndConcurrentDeletionFailBeforeMutation() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "Cabinet")
        context.insert(location)
        context.insert(place)
        try context.save()
        let expectation = InventoryPlaceMutationExpectation(place: place)

        place.name = "Changed elsewhere"
        place.updatedAt = .now.addingTimeInterval(1)
        try context.save()
        #expect(throws: InventoryPlaceMutationError.staleState) {
            try InventoryPlaceMutationPersistence.rename(
                expectation,
                to: "New name",
                iconID: nil,
                entitlements: .free,
                in: context
            )
        }

        let currentExpectation = InventoryPlaceMutationExpectation(place: place)
        context.delete(place)
        try context.save()
        #expect(throws: InventoryPlaceMutationError.missingPlace) {
            try InventoryPlaceMutationPersistence.rename(
                currentExpectation,
                to: "New name",
                iconID: nil,
                entitlements: .free,
                in: context
            )
        }
    }

    @Test func deletionNeverCascadesAcrossChildrenOrDirectItems() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        let parent = InventoryPlace(locationID: location.id, name: "Cabinet")
        let child = InventoryPlace(locationID: location.id, parentPlaceID: parent.id, name: "Drawer")
        context.insert(location)
        context.insert(parent)
        context.insert(child)
        try context.save()

        #expect(throws: InventoryPlaceMutationError.accessRequired) {
            try InventoryPlaceMutationPersistence.delete(
                .init(place: parent),
                entitlements: .free,
                in: context
            )
        }
        #expect(throws: InventoryPlaceMutationError.containsChildren(1)) {
            try InventoryPlaceMutationPersistence.delete(
                .init(place: parent),
                entitlements: pro,
                in: context
            )
        }

        let item = InventoryItem(
            name: "Cable",
            locationName: location.name,
            containerName: child.name,
            placeID: child.id
        )
        context.insert(item)
        try context.save()
        #expect(throws: InventoryPlaceMutationError.containsItems(1)) {
            try InventoryPlaceMutationPersistence.delete(
                .init(place: child),
                entitlements: pro,
                in: context
            )
        }
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).count == 1)
    }

    @Test func failedSubtreeMoveRollsBackPlacesItemsAndHistory() throws {
        let context = try modelContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let place = InventoryPlace(locationID: office.id, name: "Cabinet")
        let item = InventoryItem(
            name: "Tape",
            locationName: office.name,
            containerName: place.name,
            placeID: place.id
        )
        context.insert(office)
        context.insert(garage)
        context.insert(place)
        context.insert(item)
        try context.save()

        #expect(throws: InventoryPlaceMutationError.persistenceFailed) {
            try InventoryPlaceMutationPersistence.moveSubtree(
                .init(place: place),
                toLocationID: garage.id,
                parentPlaceID: nil,
                entitlements: pro,
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        let storedPlace = try #require(context.fetch(FetchDescriptor<InventoryPlace>()).first)
        let storedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(storedPlace.locationID == office.id)
        #expect(storedItem.locationName == "Office")
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InventoryPlaceMutationRecord>()).isEmpty)
    }

    private var pro: InventoryEntitlements {
        InventoryEntitlements(ownsLifetimePro: true, hasActiveFamilySubscription: false)
    }

    private func modelContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private enum PersistenceFailure: Error {
        case expected
    }
}
