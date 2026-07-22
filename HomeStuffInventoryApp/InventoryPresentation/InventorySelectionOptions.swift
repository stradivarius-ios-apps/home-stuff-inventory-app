import Foundation
import SwiftData

struct InventorySelectionOption: Equatable, Identifiable {
    let displayName: String
    let storageValue: String

    var id: String {
        storageValue
    }
}

enum InventorySelectionOptions {
    static func categories(
        from items: [InventoryItem],
        customCategories: [InventoryCustomCategory] = []
    ) -> [InventorySelectionOption] {
        let defaultOptions = InventoryCategory.allCases.map {
            InventorySelectionOption(displayName: $0.displayName, storageValue: $0.rawValue)
        }
        let customOptions = customCategories.map {
            InventorySelectionOption(displayName: $0.name, storageValue: $0.name)
        }
        let itemOptions = items.map {
            InventorySelectionOption(
                displayName: InventoryCategory.displayName(forStoredValue: $0.category),
                storageValue: InventoryCategory.storageValue(from: $0.category)
            )
        }

        return sortedUniqueOptions(defaultOptions + customOptions + itemOptions)
    }

    static func locations(from items: [InventoryItem], storageLocations: [StorageLocation] = []) -> [InventorySelectionOption] {
        let itemOptions = items.map {
            InventorySelectionOption(displayName: $0.locationName, storageValue: $0.locationName)
        }
        let storageLocationOptions = storageLocations.map {
            InventorySelectionOption(displayName: $0.name, storageValue: $0.name)
        }

        return sortedUniqueOptions(itemOptions + storageLocationOptions)
    }

    static func resolvedCategoryValue(
        _ value: String,
        from items: [InventoryItem],
        customCategories: [InventoryCustomCategory] = []
    ) -> String? {
        resolvedValue(value, in: categories(from: items, customCategories: customCategories), fallbackMapsDefaultCategory: true)
    }

    static func resolvedLocationName(
        _ value: String,
        from items: [InventoryItem],
        storageLocations: [StorageLocation] = []
    ) -> String? {
        resolvedValue(value, in: locations(from: items, storageLocations: storageLocations), fallbackMapsDefaultCategory: false)
    }

    private static func resolvedValue(
        _ value: String,
        in options: [InventorySelectionOption],
        fallbackMapsDefaultCategory: Bool
    ) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            return nil
        }

        if fallbackMapsDefaultCategory, let category = InventoryCategory.resolveBuiltInCategory(from: trimmedValue) {
            return category.rawValue
        }

        if let option = options.first(where: { option in
            option.displayName.localizedCaseInsensitiveCompare(trimmedValue) == .orderedSame
                || option.storageValue.localizedCaseInsensitiveCompare(trimmedValue) == .orderedSame
        }) {
            return option.storageValue
        }

        return trimmedValue
    }

    private static func sortedUniqueOptions(_ options: [InventorySelectionOption]) -> [InventorySelectionOption] {
        var seenKeys = Set<String>()

        return options
            .compactMap { option -> InventorySelectionOption? in
                let displayName = option.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let storageValue = option.storageValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let comparisonKey = displayName.lowercased()

                guard !displayName.isEmpty, !storageValue.isEmpty, seenKeys.insert(comparisonKey).inserted else {
                    return nil
                }

                return InventorySelectionOption(displayName: displayName, storageValue: storageValue)
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }
}

extension Array where Element == InventorySelectionOption {
    func containsEquivalent(to value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            return false
        }

        return contains { option in
            option.displayName.localizedCaseInsensitiveCompare(trimmedValue) == .orderedSame
                || option.storageValue.localizedCaseInsensitiveCompare(trimmedValue) == .orderedSame
        }
    }
}
