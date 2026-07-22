import SwiftData

enum InventorySelectionValueStore {
    static func persistedCategoryValue(
        _ value: String,
        items: [InventoryItem],
        customCategories: [InventoryCustomCategory],
        modelContext: ModelContext,
        save: (() throws -> Void)? = nil
    ) throws -> String? {
        let options = InventorySelectionOptions.categories(from: items, customCategories: customCategories)
        guard let resolvedValue = InventorySelectionOptions.resolvedCategoryValue(value, from: items, customCategories: customCategories) else {
            return nil
        }
        guard !options.containsEquivalent(to: resolvedValue) else {
            return resolvedValue
        }

        let category = InventoryCustomCategory(name: resolvedValue)
        modelContext.insert(category)
        do {
            try (save ?? modelContext.save)()
        } catch {
            modelContext.rollback()
            throw error
        }
        return category.name
    }

    static func persistedLocationName(
        _ value: String,
        items: [InventoryItem],
        storageLocations: [StorageLocation],
        modelContext: ModelContext,
        save: (() throws -> Void)? = nil
    ) throws -> String? {
        let options = InventorySelectionOptions.locations(from: items, storageLocations: storageLocations)
        guard let resolvedValue = InventorySelectionOptions.resolvedLocationName(value, from: items, storageLocations: storageLocations) else {
            return nil
        }
        guard !options.containsEquivalent(to: resolvedValue) else {
            return resolvedValue
        }

        let location = StorageLocation(name: resolvedValue)
        modelContext.insert(location)
        do {
            try (save ?? modelContext.save)()
        } catch {
            modelContext.rollback()
            throw error
        }
        return location.name
    }
}
