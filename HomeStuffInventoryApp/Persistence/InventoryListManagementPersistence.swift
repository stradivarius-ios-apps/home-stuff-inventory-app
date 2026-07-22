import SwiftData

enum InventoryListManagementPersistenceOperation {
    case addLocation(name: String, iconID: String?)
    case renameLocation(StorageLocation, name: String, iconID: String?)
    case addPlace(name: String, iconID: String?, location: StorageLocation)
    case renamePlace(InventoryPlace, name: String, iconID: String?, location: StorageLocation)
    case addCustomCategory(name: String)
    case renameCustomCategory(InventoryCustomCategory, name: String)
}

enum InventoryListManagementPersistence {
    static func save(
        _ operation: InventoryListManagementPersistenceOperation,
        locations: [StorageLocation],
        places: [InventoryPlace] = [],
        customCategories: [InventoryCustomCategory],
        items: [InventoryItem],
        in modelContext: ModelContext,
        persist: (() throws -> Void)? = nil
    ) throws {
        do {
            switch operation {
            case let .addLocation(name, iconID):
                modelContext.insert(
                    try InventoryListManagement.addLocation(
                        named: name,
                        iconID: iconID,
                        to: locations
                    )
                )
            case let .renameLocation(location, name, iconID):
                try InventoryListManagement.renameLocation(
                    location,
                    to: name,
                    iconID: iconID,
                    locations: locations,
                    items: items
                )
            case let .addPlace(name, iconID, location):
                modelContext.insert(
                    try InventoryListManagement.addPlace(
                        named: name,
                        iconID: iconID,
                        in: location,
                        places: places
                    )
                )
            case let .renamePlace(place, name, iconID, location):
                let originalPlace = (place.name, place.iconID, place.updatedAt)
                let originalItems = Dictionary(uniqueKeysWithValues: items.map { ($0.id, ($0.containerName, $0.placeID, $0.updatedAt)) })
                do {
                    try InventoryListManagement.renamePlace(
                        place,
                        in: location,
                        to: name,
                        iconID: iconID,
                        places: places,
                        items: items
                    )
                    try (persist ?? modelContext.save)()
                    return
                } catch {
                    modelContext.rollback()
                    place.name = originalPlace.0
                    place.iconID = originalPlace.1
                    place.updatedAt = originalPlace.2
                    for item in items {
                        guard let original = originalItems[item.id] else { continue }
                        item.containerName = original.0
                        item.placeID = original.1
                        item.updatedAt = original.2
                    }
                    throw error
                }
            case let .addCustomCategory(name):
                modelContext.insert(
                    try InventoryListManagement.addCustomCategory(
                        named: name,
                        to: customCategories
                    )
                )
            case let .renameCustomCategory(category, name):
                try InventoryListManagement.renameCustomCategory(
                    category,
                    to: name,
                    customCategories: customCategories,
                    items: items
                )
            }

            try (persist ?? modelContext.save)()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func delete(
        _ location: StorageLocation,
        items: [InventoryItem],
        places: [InventoryPlace] = [],
        in modelContext: ModelContext,
        persist: (() throws -> Void)? = nil
    ) throws {
        try performDelete(
            validate: { try InventoryListManagement.deleteLocation(location, items: items, places: places) },
            delete: { modelContext.delete(location) },
            modelContext: modelContext,
            persist: persist
        )
    }

    static func delete(
        _ place: InventoryPlace,
        in location: StorageLocation,
        items: [InventoryItem],
        in modelContext: ModelContext,
        persist: (() throws -> Void)? = nil
    ) throws {
        try performDelete(
            validate: { try InventoryListManagement.deletePlace(place, in: location, items: items) },
            delete: { modelContext.delete(place) },
            modelContext: modelContext,
            persist: persist
        )
    }

    static func delete(
        _ category: InventoryCustomCategory,
        items: [InventoryItem],
        in modelContext: ModelContext,
        persist: (() throws -> Void)? = nil
    ) throws {
        try performDelete(
            validate: { try InventoryListManagement.deleteCustomCategory(category, items: items) },
            delete: { modelContext.delete(category) },
            modelContext: modelContext,
            persist: persist
        )
    }

    private static func performDelete(
        validate: () throws -> Void,
        delete: () -> Void,
        modelContext: ModelContext,
        persist: (() throws -> Void)?
    ) throws {
        do {
            try validate()
            delete()
            try (persist ?? modelContext.save)()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
