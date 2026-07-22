import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryListManagementTests {
    @Test func savePersistenceFailureUsesStablePresentation() {
        let alert = InventoryListManagementPersistenceFailure.save.alert

        #expect(alert.title == "List Not Updated")
        #expect(alert.message == "Your list changes could not be saved. Please try again.")
    }

    @Test func deleteValidationFailureUsesStablePresentation() {
        let alert = InventoryListManagementPersistenceFailure.deleteValidation.alert

        #expect(alert.title == "Value Not Deleted")
        #expect(alert.message == "The value could not be checked before deletion. Please try again.")
    }

    @Test func deletePersistenceFailureUsesStablePresentation() {
        let alert = InventoryListManagementPersistenceFailure.delete.alert

        #expect(alert.title == "Value Not Deleted")
        #expect(alert.message == "The value could not be deleted. Please try again.")
    }

    @Test func locationIconCatalogResolvesEverySupportedLookupPath() throws {
        for category in LocationIconCategory.allCases {
            #expect(category.id == category.rawValue)
            #expect(category.titleKey == "locationIcons.category.\(category.rawValue)")
            #expect(LocationIconCatalog.options(in: category).allSatisfy { $0.category == category })
        }

        let kitchen = try #require(LocationIconCatalog.option(for: "kitchen"))

        #expect(kitchen.symbolName == "fork.knife")
        #expect(LocationIconCatalog.option(for: nil) == nil)
        #expect(LocationIconCatalog.option(for: "unsupported") == nil)
        #expect(LocationIconCatalog.symbolName(for: "kitchen") == "fork.knife")
        #expect(LocationIconCatalog.symbolName(for: nil) == LocationIconCatalog.fallbackSymbolName)
        #expect(LocationIconCatalog.normalizedIconID("kitchen") == "kitchen")
        #expect(LocationIconCatalog.normalizedIconID(nil) == nil)
        #expect(LocationIconCatalog.normalizedIconID("unsupported") == nil)
    }

    @Test func addingLocationTrimsWhitespace() throws {
        let location = try InventoryListManagement.addLocation(named: "  Hall closet  ", to: [])

        #expect(location.name == "Hall closet")
    }

    @Test func addingLocationStoresSupportedIcon() throws {
        let location = try InventoryListManagement.addLocation(named: "Kitchen", iconID: "kitchen", to: [])

        #expect(location.name == "Kitchen")
        #expect(location.iconID == "kitchen")
    }

    @Test func addingLocationIgnoresUnsupportedIcon() throws {
        let location = try InventoryListManagement.addLocation(named: "Kitchen", iconID: "not-a-symbol", to: [])

        #expect(location.iconID == nil)
    }

    @Test func addingLocationRejectsCaseAndWhitespaceDuplicates() throws {
        let existing = StorageLocation(name: "Hall closet")

        #expect(throws: InventoryListManagementError.duplicateName("hall closet")) {
            _ = try InventoryListManagement.addLocation(named: "  hall closet  ", to: [existing])
        }
    }

    @Test func renamingLocationUpdatesMatchingItems() throws {
        let location = StorageLocation(name: "Hall closet", createdAt: Date(timeIntervalSince1970: 100))
        let matchingItem = InventoryItem(name: "Tape", locationName: "  hall closet\n")
        let otherItem = InventoryItem(name: "Cable", locationName: "Office")
        let timestamp = Date(timeIntervalSince1970: 300)

        try InventoryListManagement.renameLocation(
            location,
            to: "  Utility closet  ",
            locations: [location],
            items: [matchingItem, otherItem],
            updatedAt: timestamp
        )

        #expect(location.name == "Utility closet")
        #expect(location.updatedAt == timestamp)
        #expect(matchingItem.locationName == "Utility closet")
        #expect(matchingItem.updatedAt == timestamp)
        #expect(otherItem.locationName == "Office")
    }

    @Test func editingLocationCanChangeOnlyIcon() throws {
        let location = StorageLocation(
            name: "Hall closet",
            iconID: "box",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let timestamp = Date(timeIntervalSince1970: 300)

        try InventoryListManagement.renameLocation(
            location,
            to: "Hall closet",
            iconID: "closet",
            locations: [location],
            items: [],
            updatedAt: timestamp
        )

        #expect(location.name == "Hall closet")
        #expect(location.iconID == "closet")
        #expect(location.updatedAt == timestamp)
    }

    @Test func deletingUsedLocationIsBlocked() throws {
        let location = StorageLocation(name: "Hall closet")
        let item = InventoryItem(name: "Tape", locationName: " hall closet ")

        #expect(throws: InventoryListManagementError.valueInUse("Hall closet", 1)) {
            try InventoryListManagement.deleteLocation(location, items: [item])
        }
    }

    @Test func deletingLocationReportsAllMatchingItems() throws {
        let location = StorageLocation(name: "Hall closet")
        let items = [
            InventoryItem(name: "Tape", locationName: " hall closet "),
            InventoryItem(name: "Cable", locationName: "HALL CLOSET"),
            InventoryItem(name: "Adapter", locationName: "Office")
        ]

        #expect(throws: InventoryListManagementError.valueInUse("Hall closet", 2)) {
            try InventoryListManagement.deleteLocation(location, items: items)
        }
    }

    @Test func deletingUnusedLocationIsAllowed() throws {
        let location = StorageLocation(name: "Hall closet")

        try InventoryListManagement.deleteLocation(location, items: [])
    }

    @Test func addingSamePlaceNameInDifferentLocationsIsAllowed() throws {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let officePlace = try InventoryListManagement.addPlace(named: "  Red Box ", in: office, places: [])
        let garagePlace = try InventoryListManagement.addPlace(named: "red box", in: garage, places: [officePlace])

        #expect(officePlace.name == "Red Box")
        #expect(garagePlace.name == "red box")
        #expect(officePlace.locationID != garagePlace.locationID)
    }

    @Test func addingAndRenamingPlaceRejectsNormalizedDuplicateInOneLocation() throws {
        let location = StorageLocation(name: "Office")
        let existing = InventoryPlace(locationID: location.id, name: "Desk Drawer")
        let renamed = InventoryPlace(locationID: location.id, name: "Cable Box")

        #expect(throws: InventoryListManagementError.duplicateName("desk drawer")) {
            _ = try InventoryListManagement.addPlace(named: " desk drawer ", in: location, places: [existing])
        }
        #expect(throws: InventoryListManagementError.duplicateName("DESK DRAWER")) {
            try InventoryListManagement.renamePlace(
                renamed,
                in: location,
                to: " DESK DRAWER ",
                places: [existing, renamed],
                items: []
            )
        }
    }

    @Test func renamingPlaceUpdatesOnlyExactScopedItems() throws {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let place = InventoryPlace(locationID: office.id, name: "Red Box")
        let linked = InventoryItem(name: "Tape", locationName: "Office", containerName: "Old text", placeID: place.id)
        let legacy = InventoryItem(name: "Cable", locationName: " office ", containerName: " red box ")
        let otherLocation = InventoryItem(name: "Screw", locationName: "Garage", containerName: "Red Box")
        let stale = InventoryItem(name: "Label", locationName: "Office", containerName: "Red Box", placeID: UUID())
        let timestamp = Date(timeIntervalSince1970: 100)

        try InventoryListManagement.renamePlace(
            place,
            in: office,
            to: "Blue Box",
            places: [place],
            items: [linked, legacy, otherLocation, stale],
            updatedAt: timestamp
        )

        #expect(place.name == "Blue Box")
        #expect(linked.containerName == "Blue Box")
        #expect(linked.placeID == place.id)
        #expect(legacy.containerName == "Blue Box")
        #expect(legacy.placeID == place.id)
        #expect(otherLocation.containerName == "Red Box")
        #expect(stale.containerName == "Red Box")
    }

    @Test func placeIconOnlyEditAndNoOpPreserveItemTextAndTimestamp() throws {
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "Drawer", iconID: "drawer", updatedAt: .distantPast)
        let item = InventoryItem(name: "Tape", locationName: "Office", containerName: "Drawer", placeID: place.id)
        let timestamp = Date(timeIntervalSince1970: 100)

        try InventoryListManagement.renamePlace(place, in: location, to: "Drawer", iconID: "invalid", places: [place], items: [item], updatedAt: timestamp)
        #expect(place.iconID == PlaceIconCatalog.defaultIconID)
        #expect(place.updatedAt == timestamp)
        #expect(item.containerName == "Drawer")
        #expect(item.updatedAt != timestamp)

        try InventoryListManagement.renamePlace(place, in: location, to: "Drawer", iconID: PlaceIconCatalog.defaultIconID, places: [place], items: [item], updatedAt: Date(timeIntervalSince1970: 200))
        #expect(place.updatedAt == timestamp)
    }

    @Test func placeUsageAndSelectionAreScopedAndKeepPlaceIcon() throws {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let officePlace = InventoryPlace(locationID: office.id, name: "Red Box", iconID: "archive")
        let garagePlace = InventoryPlace(locationID: garage.id, name: "Red Box")
        let officeItem = InventoryItem(name: "Tape", locationName: "Office", containerName: "Red Box", placeID: officePlace.id)
        let garageItem = InventoryItem(name: "Screw", locationName: "Garage", containerName: "Red Box", placeID: garagePlace.id)

        let selection = try InventoryListManagement.selection(for: officePlace, in: office)
        #expect(InventoryListManagement.usageCount(for: officePlace, in: office, items: [officeItem, garageItem]) == 1)
        #expect(InventoryListManagement.items(in: [officeItem, garageItem], matching: selection).map(\.id) == [officeItem.id])
        #expect(selection.emptySystemImage == "archivebox")
    }

    @Test func deletingUsedPlaceIsBlockedButUnusedPlaceIsAllowed() throws {
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "Drawer")
        let item = InventoryItem(name: "Tape", locationName: "Office", containerName: "Drawer", placeID: place.id)

        #expect(throws: InventoryListManagementError.valueInUse("Drawer", 1)) {
            try InventoryListManagement.deletePlace(place, in: location, items: [item])
        }
        try InventoryListManagement.deletePlace(place, in: location, items: [])
    }

    @Test func locationRenameKeepsPlaceIdentityAndLocationDeleteRequiresPlaceRemoval() throws {
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "Drawer", iconID: "drawer")
        let history = InventoryPlaceOpenRecord(placeIdentity: "legacy", placeID: place.id)
        let item = InventoryItem(name: "Tape", locationName: "Office")

        try InventoryListManagement.renameLocation(location, to: "Study", locations: [location], items: [item])
        #expect(place.locationID == location.id)
        #expect(place.iconID == "drawer")
        #expect(history.placeID == place.id)
        #expect(throws: InventoryListManagementError.locationContainsPlaces("Study", 1)) {
            try InventoryListManagement.deleteLocation(location, items: [], places: [place])
        }
    }

    @Test func managedLocationSelectionMatchesCaseAndWhitespaceVariants() {
        let location = StorageLocation(name: "Hall closet", iconID: "closet")
        let matching = InventoryItem(name: "Tape", locationName: " hall CLOSET ")
        let other = InventoryItem(name: "Cable", locationName: "Office")
        let selection = InventoryListManagement.selection(for: location)

        #expect(selection.id == "location-\(location.id.uuidString)")
        #expect(InventoryListManagement.items(in: [matching, other], matching: selection).map(\.id) == [matching.id])
    }

    @Test func managedCategoriesIncludeReadOnlyDefaultsAndCustomCategories() {
        let customCategory = InventoryCustomCategory(name: "Craft Supplies")
        let item = InventoryItem(name: "Glue", category: "Craft Supplies", locationName: "Desk")

        let categories = InventoryListManagement.managedCategories(
            customCategories: [customCategory],
            items: [item]
        )

        #expect(categories.contains(where: {
            $0.displayName == InventoryCategory.tools.rawValue && !$0.isEditable
        }))
        #expect(categories.contains(where: {
            $0.displayName == "Craft Supplies" && $0.isEditable && $0.itemCount == 1
        }))
    }

    @Test func managedCategoriesKeepCustomNamesAsUserDefinedStrings() {
        let customCategory = InventoryCustomCategory(name: "Craft Supplies")

        let categories = InventoryListManagement.managedCategories(
            customCategories: [customCategory],
            items: []
        )

        #expect(categories.contains(where: {
            $0.displayName == "Craft Supplies" && $0.storageValue == "Craft Supplies"
        }))
    }

    @Test func managedCategoriesUseInjectedDefaultNamesAndStableStorageValues() {
        let item = InventoryItem(name: "Hammer", category: InventoryCategory.tools.rawValue, locationName: "Garage")
        let vocabulary = InventoryBrowseVocabulary(
            missingLocationName: "Missing location",
            missingPlaceName: "Missing place",
            categoryNames: [.tools: "Workshop tools"]
        )

        let category = InventoryListManagement.managedCategories(
            customCategories: [],
            items: [item],
            vocabulary: vocabulary
        ).first { $0.storageValue == InventoryCategory.tools.rawValue }

        #expect(category?.displayName == "Workshop tools")
        #expect(category?.storageValue == InventoryCategory.tools.rawValue)
        #expect(category?.itemCount == 1)
    }

    @Test func addingCustomCategoryRejectsDefaultCategoryDuplicates() throws {
        #expect(throws: InventoryListManagementError.duplicateName("Tools")) {
            _ = try InventoryListManagement.addCustomCategory(named: "Tools", to: [])
        }
    }

    @Test func addingAndRenamingCustomCategoriesRejectAllBuiltInAliases() throws {
        let ukrainianTools = ukrainianCategoryName(for: .tools)
        for alias in [InventoryCategory.tools.rawValue, "Tools", ukrainianTools] {
            #expect(throws: InventoryListManagementError.duplicateName(alias)) {
                _ = try InventoryListManagement.addCustomCategory(named: alias, to: [])
            }
        }

        let customCategory = InventoryCustomCategory(name: "Craft Supplies")
        #expect(throws: InventoryListManagementError.duplicateName(ukrainianTools)) {
            try InventoryListManagement.renameCustomCategory(
                customCategory,
                to: ukrainianTools,
                customCategories: [customCategory],
                items: []
            )
        }
    }

    @Test func addingCustomCategoryRejectsCustomDuplicates() throws {
        let category = InventoryCustomCategory(name: "Craft Supplies")

        #expect(throws: InventoryListManagementError.duplicateName("craft supplies")) {
            _ = try InventoryListManagement.addCustomCategory(named: " craft supplies ", to: [category])
        }
    }

    @Test func renamingCustomCategoryUpdatesMatchingItems() throws {
        let category = InventoryCustomCategory(name: "Craft Supplies", createdAt: Date(timeIntervalSince1970: 100))
        let matchingItem = InventoryItem(name: "Glue", category: "craft supplies", locationName: "Desk")
        let otherItem = InventoryItem(name: "Cable", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office")
        let timestamp = Date(timeIntervalSince1970: 300)

        try InventoryListManagement.renameCustomCategory(
            category,
            to: "  School Supplies  ",
            customCategories: [category],
            items: [matchingItem, otherItem],
            updatedAt: timestamp
        )

        #expect(category.name == "School Supplies")
        #expect(category.updatedAt == timestamp)
        #expect(matchingItem.category == "School Supplies")
        #expect(matchingItem.updatedAt == timestamp)
        #expect(otherItem.category == InventoryCategory.cablesAndAdapters.rawValue)
    }

    @Test func deletingUsedCustomCategoryIsBlocked() throws {
        let category = InventoryCustomCategory(name: "Craft Supplies")
        let item = InventoryItem(name: "Glue", category: "craft supplies", locationName: "Desk")

        #expect(throws: InventoryListManagementError.valueInUse("Craft Supplies", 1)) {
            try InventoryListManagement.deleteCustomCategory(category, items: [item])
        }
    }

    @Test func deletingCustomCategoryReportsAllMatchingItems() throws {
        let category = InventoryCustomCategory(name: "Craft Supplies")
        let items = [
            InventoryItem(name: "Glue", category: "craft supplies", locationName: "Desk"),
            InventoryItem(name: "Paper", category: " Craft Supplies ", locationName: "Desk"),
            InventoryItem(name: "Cable", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office")
        ]

        #expect(throws: InventoryListManagementError.valueInUse("Craft Supplies", 2)) {
            try InventoryListManagement.deleteCustomCategory(category, items: items)
        }
    }

    @Test func deletingUnusedCustomCategoryIsAllowed() throws {
        let category = InventoryCustomCategory(name: "Craft Supplies")

        try InventoryListManagement.deleteCustomCategory(category, items: [])
    }

    @Test func managedCategorySelectionMatchesBuiltInStoredAndDisplayValues() {
        let managedCategory = InventoryListManagement.managedCategories(customCategories: [], items: [])
            .first { $0.id == "default-tools" }!
        let storedValue = InventoryItem(name: "Hammer", category: "tools", locationName: "Garage")
        let displayValue = InventoryItem(name: "Pliers", category: " Tools ", locationName: "Garage")
        let other = InventoryItem(name: "Cable", category: "cablesAndAdapters", locationName: "Desk")
        let selection = InventoryListManagement.selection(for: managedCategory)

        #expect(InventoryListManagement.items(in: [storedValue, displayValue, other], matching: selection).map(\.id) == [storedValue.id, displayValue.id])
    }

    @Test func managedCustomCategorySelectionMatchesCaseAndWhitespaceVariants() {
        let category = InventoryCustomCategory(name: "Craft Supplies")
        let matching = InventoryItem(name: "Glue", category: " craft supplies ", locationName: "Desk")
        let other = InventoryItem(name: "Paper", category: "Documents", locationName: "Desk")
        let selection = InventoryListManagement.selection(for: category)

        #expect(InventoryListManagement.items(in: [matching, other], matching: selection).map(\.id) == [matching.id])
    }

    @Test func managedSelectionsRetainStableIdentityAndRecomputeLiveItems() {
        let location = StorageLocation(name: "Hall closet")
        let item = InventoryItem(name: "Tape", locationName: "Hall closet")
        let selection = InventoryListManagement.selection(for: location)

        #expect(InventoryListManagement.usageCount(forLocationName: location.name, in: [item]) == 1)
        #expect(InventoryListManagement.items(in: [item], matching: selection).count == 1)

        item.locationName = "Office"

        #expect(InventoryListManagement.items(in: [item], matching: selection).isEmpty)
    }

    @Test func defaultCategoryProtectionIsExplicit() throws {
        #expect(throws: InventoryListManagementError.defaultCategoryProtected) {
            try InventoryListManagement.assertDefaultCategoryCanBeEdited()
        }
    }
}
