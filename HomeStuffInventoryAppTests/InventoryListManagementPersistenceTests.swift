import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryListManagementPersistenceTests {
    @Test func saveOperationsPersistLocationsCategoriesAndLinkedRenames() throws {
        let context = try modelContext()

        try InventoryListManagementPersistence.save(
            .addLocation(name: " Hall closet ", iconID: "closet"),
            locations: [],
            customCategories: [],
            items: [],
            in: context
        )
        try InventoryListManagementPersistence.save(
            .addCustomCategory(name: " Craft supplies "),
            locations: try context.fetch(FetchDescriptor<StorageLocation>()),
            customCategories: [],
            items: [],
            in: context
        )

        let location = try #require(context.fetch(FetchDescriptor<StorageLocation>()).first)
        let category = try #require(context.fetch(FetchDescriptor<InventoryCustomCategory>()).first)
        let item = InventoryItem(name: "Tape", category: category.name, locationName: location.name)
        context.insert(item)
        try context.save()

        try InventoryListManagementPersistence.save(
            .renameLocation(location, name: " Utility closet ", iconID: "box"),
            locations: [location],
            customCategories: [category],
            items: [item],
            in: context
        )
        try InventoryListManagementPersistence.save(
            .renameCustomCategory(category, name: " Workshop "),
            locations: [location],
            customCategories: [category],
            items: [item],
            in: context
        )

        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(location.name == "Utility closet")
        #expect(location.iconID == "box")
        #expect(category.name == "Workshop")
        #expect(persistedItem.locationName == "Utility closet")
        #expect(persistedItem.category == "Workshop")
    }

    @Test func failedLocationRenameRollsBackLocationAndLinkedItems() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Hall closet", iconID: "closet")
        let item = InventoryItem(name: "Tape", locationName: location.name)
        context.insert(location)
        context.insert(item)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.save(
                .renameLocation(location, name: "Garage", iconID: "garage"),
                locations: [location],
                customCategories: [],
                items: [item],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        let persistedLocation = try #require(context.fetch(FetchDescriptor<StorageLocation>()).first)
        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persistedLocation.name == "Hall closet")
        #expect(persistedLocation.iconID == "closet")
        #expect(persistedItem.locationName == "Hall closet")
    }

    @Test func failedLocationAddRollsBackInsertion() throws {
        let context = try modelContext()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.save(
                .addLocation(name: "Hall closet", iconID: "closet"),
                locations: [],
                customCategories: [],
                items: [],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).isEmpty)
    }

    @Test func failedCategoryRenameRollsBackCategoryAndLinkedItems() throws {
        let context = try modelContext()
        let category = InventoryCustomCategory(name: "Craft supplies")
        let item = InventoryItem(name: "Tape", category: category.name, locationName: "Desk")
        context.insert(category)
        context.insert(item)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.save(
                .renameCustomCategory(category, name: "Workshop"),
                locations: [],
                customCategories: [category],
                items: [item],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        let persistedCategory = try #require(context.fetch(FetchDescriptor<InventoryCustomCategory>()).first)
        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persistedCategory.name == "Craft supplies")
        #expect(persistedItem.category == "Craft supplies")
    }

    @Test func failedCategoryAddRollsBackInsertion() throws {
        let context = try modelContext()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.save(
                .addCustomCategory(name: "Craft supplies"),
                locations: [],
                customCategories: [],
                items: [],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).isEmpty)
    }

    @Test func deleteOperationsPersistLocationAndCategoryRemoval() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Hall closet")
        let category = InventoryCustomCategory(name: "Craft supplies")
        context.insert(location)
        context.insert(category)
        try context.save()

        try InventoryListManagementPersistence.delete(location, items: [], in: context)
        try InventoryListManagementPersistence.delete(category, items: [], in: context)

        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).isEmpty)
    }

    @Test func failedLocationDeleteRollsBackRemoval() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Hall closet")
        context.insert(location)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.delete(
                location,
                items: [],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).map(\.name) == ["Hall closet"])
    }

    @Test func failedCategoryDeleteRollsBackRemoval() throws {
        let context = try modelContext()
        let category = InventoryCustomCategory(name: "Craft supplies")
        context.insert(category)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.delete(
                category,
                items: [],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).map(\.name) == ["Craft supplies"])
    }

    @Test func placeOperationsPersistAndRenameRollsBackPlaceAndItems() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        context.insert(location)
        try context.save()

        try InventoryListManagementPersistence.save(
            .addPlace(name: "Drawer", iconID: "drawer", location: location),
            locations: [location],
            places: [],
            customCategories: [],
            items: [],
            in: context
        )
        let place = try #require(context.fetch(FetchDescriptor<InventoryPlace>()).first)
        let item = InventoryItem(name: "Tape", locationName: "Office", containerName: "Drawer", placeID: place.id)
        context.insert(item)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.save(
                .renamePlace(place, name: "Tool Drawer", iconID: "cabinet", location: location),
                locations: [location],
                places: [place],
                customCategories: [],
                items: [item],
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(place.name == "Drawer")
        #expect(place.iconID == "drawer")
        #expect(item.containerName == "Drawer")
        #expect(item.placeID == place.id)
    }

    @Test func failedPlaceDeleteRollsBackRemoval() throws {
        let context = try modelContext()
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "Drawer")
        context.insert(location)
        context.insert(place)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryListManagementPersistence.delete(place, in: location, items: [], in: context, persist: { throw PersistenceFailure.expected })
        }
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).map(\.id) == [place.id])
    }

    private func modelContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private enum PersistenceFailure: Error, Equatable {
        case expected
    }
}

struct InventoryPlaceDirectoryPresentationTests {
    @Test func groupsPlacesByParentAndSortsNamesWithStableIdentityFallback() {
        let office = StorageLocation(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Office")
        let garage = StorageLocation(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Garage")
        let officeBox = InventoryPlace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, locationID: office.id, name: "Red Box")
        let garageBox = InventoryPlace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, locationID: garage.id, name: "Red Box")
        let officeDrawer = InventoryPlace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, locationID: office.id, name: "Drawer")

        let sections = InventoryPlaceDirectorySection.make(locations: [office, garage], places: [officeBox, garageBox, officeDrawer])

        #expect(sections.map(\.location.name) == ["Garage", "Office"])
        #expect(sections[0].places.map(\.name) == ["Red Box"])
        #expect(sections[1].places.map(\.name) == ["Drawer", "Red Box"])
        #expect(sections[0].places[0].id != sections[1].places[1].id)
    }

    @Test func omitsLocationsWithoutPlaces() {
        let used = StorageLocation(name: "Kitchen")
        let empty = StorageLocation(name: "Attic")
        let place = InventoryPlace(locationID: used.id, name: "Top shelf", iconID: "not-a-place-icon")

        let sections = InventoryPlaceDirectorySection.make(locations: [used, empty], places: [place])

        #expect(sections.count == 1)
        #expect(sections[0].location.id == used.id)
        #expect(sections[0].places[0].iconID == PlaceIconCatalog.defaultIconID)
    }

    @Test func hierarchyDirectoryKeepsEveryTreeParticipantVisibleAndDeterministic() {
        let office = StorageLocation(name: "Office")
        let root = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(
            locationID: office.id,
            parentPlaceID: root.id,
            name: "Drawer"
        )
        let leaf = InventoryPlace(
            locationID: office.id,
            parentPlaceID: child.id,
            name: "Cable box"
        )
        let flat = InventoryPlace(locationID: office.id, name: "Shelf")
        let item = InventoryItem(
            name: "Adapter",
            locationName: office.name,
            containerName: leaf.name,
            placeID: leaf.id
        )

        let sections = InventoryPlaceHierarchyManagement.sections(
            locations: [office],
            places: [leaf, flat, child, root],
            items: [item]
        )
        let rows = sections[0].rows

        #expect(rows.map(\.name) == ["Cabinet", "Drawer", "Cable box", "Shelf"])
        #expect(rows.map(\.depth) == [0, 1, 2, 0])
        #expect(rows.map(\.pathText) == [
            "Cabinet",
            "Cabinet › Drawer",
            "Cabinet › Drawer › Cable box",
            "Shelf"
        ])
        #expect(rows.prefix(3).map(\.participatesInHierarchy) == [true, true, true])
        #expect(rows.last?.participatesInHierarchy == false)
        #expect(rows[0].descendantPlaceCount == 2)
        #expect(rows[0].containedItemCount == 1)
        #expect(rows[2].directItemCount == 1)
    }

    @Test func freeCanEditOnlyTrulyFlatPlacesWhileBothProFactsUnlockTreeParticipants() {
        let flat = InventoryPlaceHierarchyManagement.Row(
            placeID: UUID(),
            locationID: UUID(),
            parentPlaceID: nil,
            name: "Shelf",
            iconID: nil,
            depth: 0,
            pathComponents: ["Shelf"],
            directItemCount: 0,
            descendantPlaceCount: 0,
            containedItemCount: 0,
            participatesInHierarchy: false,
            hasCompletePath: true
        )
        let treeParticipant = InventoryPlaceHierarchyManagement.Row(
            placeID: UUID(),
            locationID: UUID(),
            parentPlaceID: UUID(),
            name: "Drawer",
            iconID: nil,
            depth: 1,
            pathComponents: ["Cabinet", "Drawer"],
            directItemCount: 0,
            descendantPlaceCount: 0,
            containedItemCount: 0,
            participatesInHierarchy: true,
            hasCompletePath: true
        )

        #expect(InventoryPlaceHierarchyManagement.canDirectlyEdit(flat, entitlements: .free))
        #expect(!InventoryPlaceHierarchyManagement.canDirectlyEdit(treeParticipant, entitlements: .free))
        #expect(
            InventoryPlaceHierarchyManagement.canDirectlyEdit(
                treeParticipant,
                entitlements: .init(
                    ownsLifetimePro: true,
                    hasActiveFamilySubscription: false
                )
            )
        )
        #expect(
            InventoryPlaceHierarchyManagement.canDirectlyEdit(
                treeParticipant,
                entitlements: .init(
                    ownsLifetimePro: false,
                    hasActiveFamilySubscription: true
                )
            )
        )
    }

    @Test func hierarchyMovePreflightShowsFullPathsCountsAndExcludesCycles() {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let root = InventoryPlace(locationID: office.id, name: "Cabinet")
        let child = InventoryPlace(
            locationID: office.id,
            parentPlaceID: root.id,
            name: "Drawer"
        )
        let leaf = InventoryPlace(
            locationID: office.id,
            parentPlaceID: child.id,
            name: "Cable box"
        )
        let target = InventoryPlace(locationID: garage.id, name: "Workbench")
        let item = InventoryItem(
            name: "Adapter",
            locationName: office.name,
            containerName: leaf.name,
            placeID: leaf.id
        )
        let places = [root, child, leaf, target]
        let locations = [office, garage]

        let destinations = InventoryPlaceHierarchyManagement.destinations(
            for: root.id,
            locations: locations,
            places: places
        )
        #expect(!destinations.contains { $0.id == .place(root.id) })
        #expect(!destinations.contains { $0.id == .place(child.id) })
        #expect(!destinations.contains { $0.id == .place(leaf.id) })
        #expect(destinations.contains { $0.id == .place(target.id) })

        let outcome = InventoryPlaceHierarchyManagement.prepareMove(
            sourcePlaceID: root.id,
            destinationID: .place(target.id),
            locations: locations,
            places: places,
            items: [item]
        )
        guard case let .ready(preflight) = outcome else {
            Issue.record("Expected a complete hierarchy preflight")
            return
        }
        #expect(preflight.sourcePath == "Office › Cabinet")
        #expect(preflight.destinationPath == "Garage › Workbench")
        #expect(preflight.movedPlaceCount == 3)
        #expect(preflight.descendantPlaceCount == 2)
        #expect(preflight.containedItemCount == 1)
        #expect(preflight.sourceExpectation.id == root.id)

        target.parentPlaceID = nil
        target.name = "Changed workbench"
        #expect(
            !InventoryPlaceHierarchyManagement.isValid(
                preflight,
                locations: locations,
                places: places,
                items: [item]
            )
        )
    }
}
