import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryItemTests {
    @Test func builtInCategoryResolverAcceptsEveryRawEnglishAndUkrainianAlias() {
        for category in InventoryCategory.allCases {
            #expect(InventoryCategory.resolveBuiltInCategory(from: category.rawValue) == category)
            #expect(InventoryCategory.resolveBuiltInCategory(from: englishCategoryName(for: category)) == category)
            #expect(InventoryCategory.resolveBuiltInCategory(from: ukrainianCategoryName(for: category)) == category)
        }
    }

    @Test func builtInConditionResolverAcceptsEveryRawEnglishAndUkrainianAlias() {
        for condition in InventoryCondition.allCases {
            #expect(InventoryCondition(storedValue: condition.rawValue) == condition)
            #expect(InventoryCondition(storedValue: englishConditionName(for: condition)) == condition)
            #expect(InventoryCondition(storedValue: ukrainianConditionName(for: condition)) == condition)
        }
    }

    @Test func builtInCategoryResolverIgnoresCaseWhitespaceAndDiacriticsWithoutRelaxingPunctuation() {
        #expect(InventoryCategory.resolveBuiltInCategory(from: "  TOOLS\n") == .tools)
        #expect(InventoryCategory.resolveBuiltInCategory(from: "  Cables & Adapters  ") == .cablesAndAdapters)
        #expect(InventoryCategory.resolveBuiltInCategory(from: "Cables and Adapters") == nil)
        #expect(InventoryCategory.resolveBuiltInCategory(from: "Tools for Garden") == nil)
        #expect(InventoryCategory.storageValue(from: "  Custom Category  ") == "Custom Category")
    }

    @Test func categoryAndConditionStoreStableIdentifiersSeparateFromDisplayNames() {
        #expect(InventoryCategory.cablesAndAdapters.rawValue == "cablesAndAdapters")
        #expect(InventoryCategory.cablesAndAdapters.displayName == "Cables & Adapters")
        #expect(InventoryCategory.cablesAndAdapters.rawValue != InventoryCategory.cablesAndAdapters.displayName)
        #expect(InventoryCondition.needsRepair.rawValue == "needsRepair")
        #expect(InventoryCondition.needsRepair.displayName == "Needs Repair")
        #expect(InventoryCondition.needsRepair.rawValue != InventoryCondition.needsRepair.displayName)
    }

    @Test func legacyDisplayValuesNormalizeToStableIdentifiers() {
        let item = InventoryItem(
            name: "Old cable",
            category: "Cables & Adapters",
            locationName: "Desk",
            condition: "Good"
        )

        #expect(item.category == InventoryCategory.cablesAndAdapters.rawValue)
        #expect(item.condition == InventoryCondition.good.rawValue)

        item.applyUserEdit(
            name: "Old cable",
            category: "Tools",
            locationName: "Desk",
            containerName: nil,
            iconID: nil,
            quantity: 1,
            condition: "Needs Repair",
            tags: [],
            notes: ""
        )

        #expect(item.category == InventoryCategory.tools.rawValue)
        #expect(item.condition == InventoryCondition.needsRepair.rawValue)
    }

    @Test func defaultsNormalizeForNewItems() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = InventoryItem(
            name: "USB-C Adapter",
            locationName: "Desk drawer",
            quantity: 0,
            tags: [" adapters ", "", "usb-c"],
            createdAt: createdAt
        )

        #expect(item.category == InventoryCategory.miscellaneous.rawValue)
        #expect(item.iconID == nil)
        #expect(item.quantity == 1)
        #expect(item.condition == InventoryCondition.unknown.rawValue)
        #expect(item.tags == ["adapters", "usb-c"])
        #expect(item.notes.isEmpty)
        #expect(item.createdAt == createdAt)
        #expect(item.updatedAt == createdAt)
    }

    @Test func tagNormalizationTrimsRemovesEmptyValuesAndPreservesFirstOccurrences() {
        let item = InventoryItem(
            name: "Travel adapter",
            locationName: "Desk",
            tags: [" USB-C ", "", "usb-c", "Travel", "travel", " tools ", "tools"]
        )

        #expect(item.tags == ["USB-C", "Travel", "tools"])
    }

    @Test func tagNormalizationTreatsDiacriticVariantsAsDuplicates() {
        let item = InventoryItem(
            name: "Coffee grinder",
            locationName: "Kitchen",
            tags: ["café", "CAFE"]
        )

        #expect(item.tags == ["café"])
    }

    @Test func tagNormalizationPreservesPunctuationAndInternalWhitespaceDifferences() {
        let item = InventoryItem(
            name: "Cable organizer",
            locationName: "Desk",
            tags: ["usb-c", "usb c", "tool box", "tool  box"]
        )

        #expect(item.tags == ["usb-c", "usb c", "tool box", "tool  box"])
    }

    @Test func requiredNameValidationTrimsWhitespace() {
        #expect(InventoryItem.isValidName("Hammer"))
        #expect(!InventoryItem.isValidName("  \n  "))

        let item = InventoryItem(name: "  \n  ", locationName: "Toolbox")
        #expect(!item.hasRequiredName)
    }

    @Test func itemIconStoresOnlyKnownStableIdentifiers() {
        let item = InventoryItem(
            name: "Cable",
            locationName: "Desk",
            iconID: "cable"
        )

        #expect(item.iconID == "cable")
        #expect(ItemIconCatalog.symbolName(for: item.iconID) == "cable.connector")

        item.applyUserEdit(
            name: "Cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Desk",
            containerName: nil,
            iconID: "not-a-real-icon",
            quantity: 1,
            condition: InventoryCondition.unknown.rawValue,
            tags: [],
            notes: ""
        )

        #expect(item.iconID == nil)
        #expect(ItemIconCatalog.symbolName(for: item.iconID) == ItemIconCatalog.fallbackSymbolName)
    }

    @Test func applyingUserEditRefreshesUpdatedAtWhenEditableFieldsChange() {
        let item = InventoryItem(
            name: "Old cable",
            locationName: "Closet",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let originalUpdatedAt = item.updatedAt
        let editTimestamp = Date(timeIntervalSince1970: 200)

        item.applyUserEdit(
            name: "HDMI cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Living room cabinet",
            containerName: " Box A ",
            iconID: "cable",
            quantity: 3,
            condition: InventoryCondition.good.rawValue,
            tags: [" video ", ""],
            notes: "For the TV",
            updatedAt: editTimestamp
        )

        #expect(item.name == "HDMI cable")
        #expect(item.category == InventoryCategory.cablesAndAdapters.rawValue)
        #expect(item.locationName == "Living room cabinet")
        #expect(item.containerName == "Box A")
        #expect(item.iconID == "cable")
        #expect(item.quantity == 3)
        #expect(item.condition == InventoryCondition.good.rawValue)
        #expect(item.tags == ["video"])
        #expect(item.notes == "For the TV")
        #expect(item.updatedAt == editTimestamp)
        #expect(item.updatedAt != originalUpdatedAt)
    }

    @Test func applyingSameUserEditDoesNotRefreshUpdatedAt() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = InventoryItem(
            name: "Batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen drawer",
            containerName: "Small bin",
            iconID: nil,
            quantity: 4,
            condition: InventoryCondition.new.rawValue,
            tags: ["AA"],
            notes: "Remote spares",
            createdAt: createdAt
        )

        item.applyUserEdit(
            name: "Batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen drawer",
            containerName: "Small bin",
            iconID: nil,
            quantity: 4,
            condition: InventoryCondition.new.rawValue,
            tags: ["AA"],
            notes: "Remote spares",
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        #expect(item.updatedAt == createdAt)
    }

    @Test func applyingNotesEditRefreshesUpdatedAtWhenNotesChange() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let editTimestamp = Date(timeIntervalSince1970: 200)
        let item = InventoryItem(
            name: "Batteries",
            locationName: "Kitchen drawer",
            notes: "Remote spares",
            createdAt: createdAt
        )

        item.applyNotesEdit("Remote and flashlight spares", updatedAt: editTimestamp)

        #expect(item.notes == "Remote and flashlight spares")
        #expect(item.updatedAt == editTimestamp)
        #expect(item.createdAt == createdAt)
    }

    @Test func applyingSameNotesEditDoesNothing() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = InventoryItem(
            name: "Batteries",
            locationName: "Kitchen drawer",
            notes: "Remote spares",
            createdAt: createdAt
        )

        item.applyNotesEdit("Remote spares")

        #expect(item.notes == "Remote spares")
        #expect(item.updatedAt == createdAt)
    }

    @Test func applyingNormalizedNotesEditDoesNotRefreshUpdatedAt() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = InventoryItem(
            name: "Batteries",
            locationName: "Kitchen drawer",
            notes: "Remote spares",
            createdAt: createdAt
        )

        item.applyNotesEdit(" \n Remote spares \n ")

        #expect(item.notes == "Remote spares")
        #expect(item.updatedAt == createdAt)
    }

    @Test func clearingNotesRefreshesUpdatedAtWithoutChangingUnrelatedFields() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let editTimestamp = Date(timeIntervalSince1970: 200)
        let item = InventoryItem(
            name: "Batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen drawer",
            containerName: "Small bin",
            iconID: "battery.100percent",
            quantity: 4,
            condition: InventoryCondition.new.rawValue,
            tags: ["AA"],
            notes: "Remote spares",
            createdAt: createdAt
        )

        item.applyNotesEdit("  \n ", updatedAt: editTimestamp)

        #expect(item.notes.isEmpty)
        #expect(item.updatedAt == editTimestamp)
        #expect(item.createdAt == createdAt)
        #expect(item.name == "Batteries")
        #expect(item.category == InventoryCategory.batteries.rawValue)
        #expect(item.locationName == "Kitchen drawer")
        #expect(item.containerName == "Small bin")
        #expect(item.quantity == 4)
        #expect(item.condition == InventoryCondition.new.rawValue)
        #expect(item.tags == ["AA"])
    }

    @Test func applyingNormalizedEquivalentEditDoesNotRefreshUpdatedAt() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = InventoryItem(
            name: "Batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen drawer",
            containerName: nil,
            quantity: 1,
            condition: InventoryCondition.new.rawValue,
            tags: ["AA"],
            notes: "Remote spares",
            createdAt: createdAt
        )

        item.applyUserEdit(
            name: "Batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen drawer",
            containerName: "  ",
            iconID: nil,
            quantity: 0,
            condition: InventoryCondition.new.rawValue,
            tags: [" AA ", ""],
            notes: "Remote spares",
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        #expect(item.containerName == nil)
        #expect(item.quantity == 1)
        #expect(item.tags == ["AA"])
        #expect(item.updatedAt == createdAt)
    }

    @Test func duplicateTagInputDoesNotRefreshUpdatedAtWhenLogicalTagSetIsUnchanged() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let item = InventoryItem(
            name: "Batteries",
            locationName: "Kitchen drawer",
            tags: ["USB-C"],
            createdAt: createdAt
        )

        item.applyUserEdit(
            name: "Batteries",
            category: InventoryCategory.miscellaneous.rawValue,
            locationName: "Kitchen drawer",
            containerName: nil,
            iconID: nil,
            quantity: 1,
            condition: InventoryCondition.unknown.rawValue,
            tags: [" USB-C ", "usb-c"],
            notes: "",
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        #expect(item.tags == ["USB-C"])
        #expect(item.updatedAt == createdAt)
    }

    @Test func applyingUserEditPersistsNormalizedDeduplicatedTags() {
        let item = InventoryItem(name: "Adapter", locationName: "Desk")

        item.applyUserEdit(
            name: "Adapter",
            category: InventoryCategory.miscellaneous.rawValue,
            locationName: "Desk",
            containerName: nil,
            iconID: nil,
            quantity: 1,
            condition: InventoryCondition.unknown.rawValue,
            tags: [" USB-C ", "usb-c", "café", "CAFE"],
            notes: ""
        )

        #expect(item.tags == ["USB-C", "café"])
    }

    @Test func legacyDuplicateTagsUseUniquePositionalPresentationIDs() {
        let card = InventoryDetailTagsCard(tags: ["tools", "tools", "USB-C"])

        #expect(card.presentationTags.map(\.value) == ["tools", "tools", "USB-C"])
        #expect(card.presentationTags.map(\.id) == [0, 1, 2])
        #expect(Set(card.presentationTags.map(\.id)).count == card.presentationTags.count)
    }

    @Test func applyingUserEditKeepsQuantityAtOneOrHigher() {
        let item = InventoryItem(
            name: "Spare bulb",
            locationName: "Utility shelf",
            quantity: 4,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let editTimestamp = Date(timeIntervalSince1970: 200)

        item.applyUserEdit(
            name: "Spare bulb",
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: "Utility shelf",
            containerName: nil,
            iconID: nil,
            quantity: -2,
            condition: InventoryCondition.new.rawValue,
            tags: [],
            notes: "",
            updatedAt: editTimestamp
        )

        #expect(item.quantity == 1)
        #expect(item.updatedAt == editTimestamp)
    }

    @Test func swiftDataSupportsItemCreateReadUpdateAndDelete() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let itemID = UUID()

        let item = InventoryItem(
            id: itemID,
            name: "Precision screwdriver set",
            category: InventoryCategory.tools.rawValue,
            locationName: "Toolbox",
            quantity: 1
        )
        context.insert(item)
        try context.save()

        var descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.id == itemID
            }
        )
        var fetchedItems = try context.fetch(descriptor)
        #expect(fetchedItems.count == 1)
        #expect(fetchedItems.first?.name == "Precision screwdriver set")

        let updateTimestamp = Date(timeIntervalSince1970: 500)
        fetchedItems[0].applyUserEdit(
            name: "Precision screwdriver set",
            category: InventoryCategory.tools.rawValue,
            locationName: "Hallway drawer",
            containerName: nil,
            iconID: "toolkit",
            quantity: 2,
            condition: InventoryCondition.good.rawValue,
            tags: ["tool"],
            notes: "Small bits included",
            updatedAt: updateTimestamp
        )
        try context.save()

        fetchedItems = try context.fetch(descriptor)
        #expect(fetchedItems.first?.locationName == "Hallway drawer")
        #expect(fetchedItems.first?.iconID == "toolkit")
        #expect(fetchedItems.first?.quantity == 2)
        #expect(fetchedItems.first?.tags == ["tool"])
        #expect(fetchedItems.first?.updatedAt == updateTimestamp)

        context.delete(fetchedItems[0])
        try context.save()

        descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate<InventoryItem> { item in
                item.id == itemID
            }
        )
        #expect(try context.fetch(descriptor).isEmpty)
    }
}

func englishCategoryName(for category: InventoryCategory) -> String {
    localizedCategoryName(for: category, languageCode: "en")
}

func ukrainianCategoryName(for category: InventoryCategory) -> String {
    localizedCategoryName(for: category, languageCode: "uk")
}

func localizedCategoryName(for category: InventoryCategory, languageCode: String) -> String {
    let key = "inventory.category.\(category.rawValue)"
    let bundle = Bundle(path: Bundle.main.path(forResource: languageCode, ofType: "lproj")!)!
    return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
}

func englishConditionName(for condition: InventoryCondition) -> String {
    localizedConditionName(for: condition, languageCode: "en")
}

func ukrainianConditionName(for condition: InventoryCondition) -> String {
    localizedConditionName(for: condition, languageCode: "uk")
}

func localizedConditionName(for condition: InventoryCondition, languageCode: String) -> String {
    let key = "inventory.condition.\(condition.rawValue)"
    let bundle = Bundle(path: Bundle.main.path(forResource: languageCode, ofType: "lproj")!)!
    return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
}
