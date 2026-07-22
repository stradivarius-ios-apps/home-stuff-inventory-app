import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

struct InventorySelectionOptionsTests {
    @Test func valueCreationStateRejectsBlankTrimmedValue() {
        var state = InventoryValueCreationState(value: "  \n ")

        #expect(state.trimmedValue.isEmpty)
        #expect(!state.canSubmit)
        #expect(state.beginSubmit() == nil)
    }

    @Test func valueCreationStateFailurePreservesInputAndAllowsRetry() {
        var state = InventoryValueCreationState(value: "  Hall closet  ")

        #expect(state.beginSubmit() == "Hall closet")
        state.apply(.failure("Try again."))

        #expect(state.value == "  Hall closet  ")
        #expect(state.errorMessage == "Try again.")
        #expect(state.canSubmit)
        #expect(state.beginSubmit() == "Hall closet")
        state.apply(.success("Hall closet"))
        #expect(state.errorMessage == nil)
    }

    @Test func valueCreationStateBlocksDuplicateSubmitWhileSubmitting() {
        var state = InventoryValueCreationState(value: "Garage")

        #expect(state.beginSubmit() == "Garage")
        #expect(state.isSubmitting)
        #expect(!state.canSubmit)
        #expect(state.beginSubmit() == nil)
    }

    @Test func categoryOptionsIncludeDefaultsAndCustomCategories() {
        let items = [
            InventoryItem(name: "HDMI adapter", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office"),
            InventoryItem(name: "Vintage bulb", category: "Lighting", locationName: "Closet")
        ]
        let customCategories = [
            InventoryCustomCategory(name: "Craft Supplies")
        ]

        let options = InventorySelectionOptions.categories(from: items, customCategories: customCategories)

        #expect(options.contains(InventorySelectionOption(
            displayName: InventoryCategory.tools.displayName,
            storageValue: InventoryCategory.tools.rawValue
        )))
        #expect(options.contains(InventorySelectionOption(displayName: "Craft Supplies", storageValue: "Craft Supplies")))
        #expect(options.contains(InventorySelectionOption(displayName: "Lighting", storageValue: "Lighting")))
    }

    @Test func categoryCreationReusesExistingOptionIgnoringCaseAndWhitespace() {
        let items = [
            InventoryItem(name: "Vintage bulb", category: "Lighting", locationName: "Closet")
        ]
        let customCategories = [
            InventoryCustomCategory(name: "Craft Supplies")
        ]

        #expect(InventorySelectionOptions.resolvedCategoryValue("  lighting  ", from: items, customCategories: customCategories) == "Lighting")
        #expect(InventorySelectionOptions.resolvedCategoryValue("  craft supplies  ", from: items, customCategories: customCategories) == "Craft Supplies")
        #expect(InventorySelectionOptions.resolvedCategoryValue("  Tools  ", from: items, customCategories: customCategories) == InventoryCategory.tools.rawValue)
    }

    @Test func newCategoryCreationTrimsWhitespaceAndRejectsEmptyValues() {
        #expect(InventorySelectionOptions.resolvedCategoryValue("  Craft Supplies  ", from: []) == "Craft Supplies")
        #expect(InventorySelectionOptions.resolvedCategoryValue("  \n  ", from: []) == nil)
    }

    @Test func locationOptionsCombineItemsAndStorageLocationsWithoutCaseDuplicates() {
        let items = [
            InventoryItem(name: "Adapter", locationName: "Office"),
            InventoryItem(name: "Tape", locationName: "  ")
        ]
        let storageLocations = [
            StorageLocation(name: "office"),
            StorageLocation(name: "Garage")
        ]

        let options = InventorySelectionOptions.locations(from: items, storageLocations: storageLocations)

        #expect(options == [
            InventorySelectionOption(displayName: "Garage", storageValue: "Garage"),
            InventorySelectionOption(displayName: "Office", storageValue: "Office")
        ])
    }

    @Test func locationCreationReusesExistingOptionIgnoringCaseAndWhitespace() {
        let items = [
            InventoryItem(name: "Adapter", locationName: "Office")
        ]
        let storageLocations = [
            StorageLocation(name: "Garage")
        ]

        #expect(
            InventorySelectionOptions.resolvedLocationName(
                "  office  ",
                from: items,
                storageLocations: storageLocations
            ) == "Office"
        )
        #expect(
            InventorySelectionOptions.resolvedLocationName(
                " GARAGE ",
                from: items,
                storageLocations: storageLocations
            ) == "Garage"
        )
    }

    @Test func newLocationCreationTrimsWhitespaceAndRejectsEmptyValues() {
        #expect(InventorySelectionOptions.resolvedLocationName("  Hall closet  ", from: []) == "Hall closet")
        #expect(InventorySelectionOptions.resolvedLocationName("  \n  ", from: []) == nil)
    }

    @MainActor
    @Test func creatingCategoryPersistsImmediatelyAndSelectsTrimmedValueBeforeItemSave() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        let selectedValue = try InventorySelectionValueStore.persistedCategoryValue(
            "  Craft Supplies  ",
            items: [],
            customCategories: [],
            modelContext: context
        )

        let categories = try context.fetch(FetchDescriptor<InventoryCustomCategory>())
        let options = InventorySelectionOptions.categories(from: [], customCategories: categories)
        let items = try context.fetch(FetchDescriptor<InventoryItem>())

        #expect(selectedValue == "Craft Supplies")
        #expect(options.contains(InventorySelectionOption(displayName: "Craft Supplies", storageValue: "Craft Supplies")))
        #expect(items.isEmpty)
    }

    @MainActor
    @Test func creatingLocationPersistsImmediatelyAndSelectsTrimmedValueBeforeItemSave() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        let selectedValue = try InventorySelectionValueStore.persistedLocationName(
            "  Hall closet  ",
            items: [],
            storageLocations: [],
            modelContext: context
        )

        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let options = InventorySelectionOptions.locations(from: [], storageLocations: locations)
        let items = try context.fetch(FetchDescriptor<InventoryItem>())

        #expect(selectedValue == "Hall closet")
        #expect(options == [InventorySelectionOption(displayName: "Hall closet", storageValue: "Hall closet")])
        #expect(items.isEmpty)
    }

    @MainActor
    @Test func createdReusableValuesRemainWhenItemDraftIsCanceled() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        _ = try InventorySelectionValueStore.persistedCategoryValue(
            "Craft Supplies",
            items: [],
            customCategories: [],
            modelContext: context
        )
        _ = try InventorySelectionValueStore.persistedLocationName(
            "Hall closet",
            items: [],
            storageLocations: [],
            modelContext: context
        )

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).map(\.name) == ["Craft Supplies"])
        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).map(\.name) == ["Hall closet"])
    }

    @MainActor
    @Test func persistingReusableValuesPreventsCaseAndWhitespaceDuplicates() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let category = InventoryCustomCategory(name: "Craft Supplies")
        let location = StorageLocation(name: "Hall closet")
        context.insert(category)
        context.insert(location)
        try context.save()

        let selectedCategory = try InventorySelectionValueStore.persistedCategoryValue(
            "  craft supplies  ",
            items: [],
            customCategories: [category],
            modelContext: context
        )
        let selectedLocation = try InventorySelectionValueStore.persistedLocationName(
            "  HALL CLOSET  ",
            items: [],
            storageLocations: [location],
            modelContext: context
        )

        #expect(selectedCategory == "Craft Supplies")
        #expect(selectedLocation == "Hall closet")
        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).map(\.name) == ["Craft Supplies"])
        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).map(\.name) == ["Hall closet"])
    }

    @MainActor
    @Test func categoryPersistenceFailureRollsBackNewValue() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        #expect(throws: TestPersistenceError.failed) {
            try InventorySelectionValueStore.persistedCategoryValue(
                "Craft Supplies",
                items: [],
                customCategories: [],
                modelContext: context,
                save: { throw TestPersistenceError.failed }
            )
        }

        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).isEmpty)
    }

    @MainActor
    @Test func locationPersistenceFailureRollsBackNewValue() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        #expect(throws: TestPersistenceError.failed) {
            try InventorySelectionValueStore.persistedLocationName(
                "Hall closet",
                items: [],
                storageLocations: [],
                modelContext: context,
                save: { throw TestPersistenceError.failed }
            )
        }

        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).isEmpty)
    }
}

private enum TestPersistenceError: Error, Equatable {
    case failed
}
