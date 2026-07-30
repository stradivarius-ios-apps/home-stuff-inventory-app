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
        let item = InventoryItem(
            name: "Cable",
            locationName: location.name,
            containerName: child.name,
            placeID: child.id
        )
        context.insert(location)
        context.insert(parent)
        context.insert(child)
        context.insert(item)
        try context.save()

        try InventoryPlaceMutationPersistence.rename(
            .init(place: parent),
            to: "Tall Cabinet",
            iconID: "cabinet",
            entitlements: .free,
            in: context
        )
        #expect(parent.name == "Tall Cabinet")

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

        let records = try InventoryPlaceMutationPersistence.moveSubtree(
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
        #expect(records.count == 2)
        #expect(Set(records.map(\.operationID)) == [operationID])
        #expect(records.allSatisfy { $0.origin == .hierarchySubtree })
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

        let records = try InventoryPlaceMutationPersistence.moveSubtree(
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
        #expect(records.isEmpty)
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

        #expect(throws: InventoryPlaceMutationError.containsChildren(1)) {
            try InventoryPlaceMutationPersistence.delete(
                .init(place: parent),
                entitlements: .free,
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
