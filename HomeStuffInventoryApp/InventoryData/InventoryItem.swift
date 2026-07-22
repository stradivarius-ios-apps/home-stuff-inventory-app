import Foundation
import SwiftData

@Model
final class InventoryItem {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var category: String
    var locationName: String
    var containerName: String?
    var placeID: UUID?
    var iconID: String?
    var quantity: Int
    var condition: String
    var tags: [String]
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String = InventoryCategory.miscellaneous.rawValue,
        locationName: String,
        containerName: String? = nil,
        placeID: UUID? = nil,
        iconID: String? = nil,
        quantity: Int = 1,
        condition: String = InventoryCondition.unknown.rawValue,
        tags: [String] = [],
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = InventoryCategory.storageValue(from: category)
        self.locationName = locationName
        self.containerName = containerName
        self.placeID = placeID
        self.iconID = ItemIconCatalog.normalizedIconID(iconID)
        self.quantity = Self.validQuantity(from: quantity)
        self.condition = InventoryCondition.storageValue(from: condition)
        self.tags = InventoryTagNormalization.normalizedTags(from: tags)
        self.notes = Self.normalizedNotes(from: notes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var hasRequiredName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func applyUserEdit(
        name: String,
        category: String,
        locationName: String,
        containerName: String?,
        placeID: UUID? = nil,
        updatesPlaceID: Bool = false,
        iconID: String?,
        quantity: Int,
        condition: String,
        tags: [String],
        notes: String,
        updatedAt timestamp: Date = .now
    ) {
        let normalizedContainerName = containerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextContainerName = normalizedContainerName?.isEmpty == true ? nil : normalizedContainerName
        let nextIconID = ItemIconCatalog.normalizedIconID(iconID)
        let nextCategory = InventoryCategory.storageValue(from: category)
        let nextQuantity = Self.validQuantity(from: quantity)
        let nextCondition = InventoryCondition.storageValue(from: condition)
        let nextTags = InventoryTagNormalization.normalizedTags(from: tags)
        let compatibilityPlaceChanged = self.locationName != locationName || self.containerName != nextContainerName
        let nextPlaceID = updatesPlaceID ? placeID : (compatibilityPlaceChanged ? nil : self.placeID)
        let changesPlaceText = self.locationName != locationName || self.containerName != nextContainerName || self.placeID != nextPlaceID

        guard self.name != name
            || self.category != nextCategory
            || self.locationName != locationName
            || self.containerName != nextContainerName
            || self.placeID != nextPlaceID
            || self.iconID != nextIconID
            || self.quantity != nextQuantity
            || self.condition != nextCondition
            || self.tags != nextTags
            || self.notes != Self.normalizedNotes(from: notes)
        else {
            return
        }

        self.name = name
        self.category = nextCategory
        self.locationName = locationName
        self.containerName = nextContainerName
        if changesPlaceText {
            self.placeID = nextPlaceID
        }
        self.iconID = nextIconID
        self.quantity = nextQuantity
        self.condition = nextCondition
        self.tags = nextTags
        self.notes = Self.normalizedNotes(from: notes)
        self.updatedAt = timestamp
    }

    func applyNotesEdit(_ notes: String, updatedAt timestamp: Date = .now) {
        let nextNotes = Self.normalizedNotes(from: notes)

        guard self.notes != nextNotes else {
            return
        }

        self.notes = nextNotes
        self.updatedAt = timestamp
    }

    static func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func normalizedNotes(from notes: String) -> String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validQuantity(from quantity: Int) -> Int {
        max(1, quantity)
    }

}

enum InventoryTagNormalization {
    static func normalizedTags(from tags: [String]) -> [String] {
        var comparisonKeys = Set<String>()

        return tags.compactMap { tag in
            let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else {
                return nil
            }

            let comparisonKey = comparisonKey(for: trimmedTag)
            guard comparisonKeys.insert(comparisonKey).inserted else {
                return nil
            }

            return trimmedTag
        }
    }

    static func comparisonKey(for tag: String) -> String {
        tag.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        .lowercased()
    }
}

enum InventoryCategory: String, CaseIterable, Identifiable {
    case tools = "tools"
    case cablesAndAdapters = "cablesAndAdapters"
    case electronics = "electronics"
    case spareParts = "spareParts"
    case batteries = "batteries"
    case documents = "documents"
    case householdSupplies = "householdSupplies"
    case outdoorAndTravel = "outdoorAndTravel"
    case miscellaneous = "miscellaneous"

    var id: String { rawValue }

    init?(storedValue: String) {
        guard let category = Self.resolveBuiltInCategory(from: storedValue) else {
            return nil
        }
        self = category
    }

    /// Resolves persisted identifiers and every shipped localized category name without relying on the current app locale.
    static func resolveBuiltInCategory(from value: String) -> InventoryCategory? {
        let comparisonValue = aliasComparisonValue(value)

        guard !comparisonValue.isEmpty else {
            return nil
        }

        return allCases.first { category in
            category.builtInAliases.contains { aliasComparisonValue($0) == comparisonValue }
        }
    }

    static func storageValue(from value: String) -> String {
        Self(storedValue: value)?.rawValue ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var builtInAliases: [String] {
        switch self {
        case .tools: [rawValue, "Tools", "Інструменти"]
        case .cablesAndAdapters: [rawValue, "Cables & Adapters", "Кабелі й адаптери"]
        case .electronics: [rawValue, "Electronics", "Електроніка"]
        case .spareParts: [rawValue, "Spare Parts", "Запчастини"]
        case .batteries: [rawValue, "Batteries", "Батарейки"]
        case .documents: [rawValue, "Documents", "Документи"]
        case .householdSupplies: [rawValue, "Household Supplies", "Побутові речі"]
        case .outdoorAndTravel: [rawValue, "Outdoor & Travel", "Для вулиці й подорожей"]
        case .miscellaneous: [rawValue, "Miscellaneous", "Різне"]
        }
    }

    private static func aliasComparisonValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
    }
}

enum InventoryCondition: String, CaseIterable, Identifiable {
    case new = "new"
    case good = "good"
    case worn = "worn"
    case needsRepair = "needsRepair"
    case unknown = "unknown"

    var id: String { rawValue }

    private var builtInAliases: [String] {
        switch self {
        case .new: [rawValue, "New", "Новий"]
        case .good: [rawValue, "Good", "Гарний"]
        case .worn: [rawValue, "Worn", "Зношений"]
        case .needsRepair: [rawValue, "Needs Repair", "Потребує ремонту"]
        case .unknown: [rawValue, "Unknown", "Невідомий"]
        }
    }

    init?(storedValue: String) {
        let trimmedValue = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let condition = Self(rawValue: trimmedValue) {
            self = condition
            return
        }

        guard let condition = Self.allCases.first(where: { condition in
            condition.builtInAliases.contains {
                $0.localizedCaseInsensitiveCompare(trimmedValue) == .orderedSame
            }
        }) else {
            return nil
        }

        self = condition
    }

    static func storageValue(from value: String) -> String {
        Self(storedValue: value)?.rawValue ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
