import Foundation

struct InventoryItemDetailViewModel: Equatable {
    let name: String
    let iconID: String?
    let iconSymbolName: String
    let iconDisplayName: String
    let locationName: String
    let containerName: String
    let category: String
    let quantityText: String
    let quantityBadgeText: String
    let condition: String
    let tags: [String]
    let tagsText: String?
    let notesText: String
    let createdAt: Date
    let updatedAt: Date
    let hasLocation: Bool
    let hasContainer: Bool
    let hasNotes: Bool

    init(item: InventoryItem, places: [InventoryPlace] = []) {
        name = item.name
        iconID = ItemIconCatalog.normalizedIconID(item.iconID)
        iconSymbolName = ItemIconCatalog.symbolName(for: item.iconID)
        iconDisplayName = ItemIconCatalog.displayName(for: item.iconID)
        locationName = Self.displayText(item.locationName, fallback: InventoryLocalization.noLocation)
        if let placeID = item.placeID,
           let place = places.first(where: { $0.id == placeID }) {
            containerName = InventoryPlaceHierarchy.path(for: place, places: places).displayName
        } else {
            containerName = Self.displayText(item.containerName, fallback: InventoryLocalization.noContainer)
        }
        category = InventoryCategory.displayName(forStoredValue: item.category)
        quantityText = item.quantity.formatted()
        quantityBadgeText = InventoryLocalization.itemCount(item.quantity)
        condition = InventoryCondition.displayName(forStoredValue: item.condition)
        tags = item.tags
        tagsText = item.tags.isEmpty ? nil : item.tags.joined(separator: ", ")
        notesText = Self.displayText(item.notes, fallback: InventoryLocalization.noNotes)
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        hasLocation = Self.hasDisplayableText(item.locationName)
        hasContainer = Self.hasDisplayableText(item.containerName)
        hasNotes = Self.hasDisplayableText(item.notes)
    }

    func createdText(formatter: DateFormatter = .inventoryLastUpdated) -> String {
        formatter.string(from: createdAt)
    }

    func lastUpdatedText(formatter: DateFormatter = .inventoryLastUpdated) -> String {
        formatter.string(from: updatedAt)
    }

    private static func displayText(_ value: String?, fallback: String) -> String {
        guard let value else {
            return fallback
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? fallback : trimmedValue
    }

    private static func hasDisplayableText(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct InventoryDetailTagsPresentation: Equatable {
    static let collapsedLimit = 3

    let tags: [String]
    let isExpanded: Bool

    var visibleTags: [String] {
        isExpanded ? tags : Array(tags.prefix(Self.collapsedLimit))
    }

    var overflowCount: Int {
        max(0, tags.count - Self.collapsedLimit)
    }

    var canExpand: Bool {
        !isExpanded && overflowCount > 0
    }

    var canCollapse: Bool {
        isExpanded && overflowCount > 0
    }
}

extension DateFormatter {
    static let inventoryLastUpdated: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

extension InventoryCategory {
    var displayName: String {
        InventoryVocabulary.categoryDisplayName(for: self)
    }

    static func displayName(forStoredValue value: String) -> String {
        Self(storedValue: value).map(InventoryVocabulary.categoryDisplayName)
            ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension InventoryCondition {
    var displayName: String {
        InventoryVocabulary.conditionDisplayName(for: self)
    }

    static func displayName(forStoredValue value: String) -> String {
        Self(storedValue: value).map(InventoryVocabulary.conditionDisplayName)
            ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ItemIconCatalog {
    static func displayName(for id: String?) -> String {
        guard let option = option(for: id) else {
            return InventoryLocalization.string("itemIcons.option.box", defaultValue: "Box")
        }

        return Bundle.main.localizedString(forKey: option.nameKey, value: option.id, table: "Localizable")
    }
}

private enum InventoryVocabulary {
    static func categoryDisplayName(for category: InventoryCategory) -> String {
        switch category {
        case .tools: InventoryLocalization.string("inventory.category.tools", defaultValue: "Tools")
        case .cablesAndAdapters: InventoryLocalization.string("inventory.category.cablesAndAdapters", defaultValue: "Cables & Adapters")
        case .electronics: InventoryLocalization.string("inventory.category.electronics", defaultValue: "Electronics")
        case .spareParts: InventoryLocalization.string("inventory.category.spareParts", defaultValue: "Spare Parts")
        case .batteries: InventoryLocalization.string("inventory.category.batteries", defaultValue: "Batteries")
        case .documents: InventoryLocalization.string("inventory.category.documents", defaultValue: "Documents")
        case .householdSupplies: InventoryLocalization.string("inventory.category.householdSupplies", defaultValue: "Household Supplies")
        case .outdoorAndTravel: InventoryLocalization.string("inventory.category.outdoorAndTravel", defaultValue: "Outdoor & Travel")
        case .miscellaneous: InventoryLocalization.string("inventory.category.miscellaneous", defaultValue: "Miscellaneous")
        }
    }

    static func conditionDisplayName(for condition: InventoryCondition) -> String {
        switch condition {
        case .new: InventoryLocalization.string("inventory.condition.new", defaultValue: "New")
        case .good: InventoryLocalization.string("inventory.condition.good", defaultValue: "Good")
        case .worn: InventoryLocalization.string("inventory.condition.worn", defaultValue: "Worn")
        case .needsRepair: InventoryLocalization.string("inventory.condition.needsRepair", defaultValue: "Needs Repair")
        case .unknown: InventoryLocalization.string("inventory.condition.unknown", defaultValue: "Unknown")
        }
    }
}
