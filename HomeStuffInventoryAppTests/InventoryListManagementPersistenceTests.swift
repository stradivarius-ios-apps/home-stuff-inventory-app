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
}
