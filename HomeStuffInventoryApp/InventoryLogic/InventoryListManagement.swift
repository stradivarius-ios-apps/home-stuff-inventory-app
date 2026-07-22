import Foundation

enum InventoryManagedCategoryKind {
    case defaultCategory(InventoryCategory)
    case custom(InventoryCustomCategory)
}

struct InventoryManagedCategory: Identifiable {
    let id: String
    let displayName: String
    let storageValue: String
    let kind: InventoryManagedCategoryKind
    let itemCount: Int

    var isEditable: Bool {
        if case .custom = kind {
            return true
        }

        return false
    }
}

enum InventoryManagedItemsSelection: Hashable, Identifiable {
    case location(id: UUID, name: String, iconID: String?)
    case place(id: UUID, locationID: UUID, locationName: String, name: String, iconID: String?)
    case category(id: String, displayName: String, storageValue: String)

    var id: String {
        switch self {
        case let .location(id, _, _):
            return "location-\(id.uuidString)"
        case let .place(id, _, _, _, _):
            return "place-\(id.uuidString)"
        case let .category(id, _, _):
            return "category-\(id)"
        }
    }

    var title: String {
        switch self {
        case let .location(_, name, _):
            return name
        case let .place(_, _, _, name, _):
            return name
        case let .category(_, displayName, _):
            return displayName
        }
    }

    var emptySystemImage: String {
        switch self {
        case let .location(_, _, iconID):
            return LocationIconCatalog.symbolName(for: iconID)
        case let .place(_, _, _, _, iconID):
            return PlaceIconCatalog.symbolName(for: iconID)
        case .category:
            return "tag"
        }
    }
}

enum InventoryListManagementError: Error, Equatable {
    case emptyName
    case duplicateName(String)
    case defaultCategoryProtected
    case valueInUse(String, Int)
    case locationContainsPlaces(String, Int)
    case placeDoesNotBelongToLocation
}

enum InventoryListManagement {
    static func managedCategories(
        customCategories: [InventoryCustomCategory],
        items: [InventoryItem],
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [InventoryManagedCategory] {
        let defaultRows = InventoryCategory.allCases.map { category in
            InventoryManagedCategory(
                id: "default-\(category.rawValue)",
                displayName: vocabulary.categoryName(for: category),
                storageValue: category.rawValue,
                kind: .defaultCategory(category),
                itemCount: usageCount(forCategoryValue: category.rawValue, in: items)
            )
        }

        let customRows = customCategories
            .map { category -> InventoryManagedCategory in
                let name = normalizedName(category.name)

                return InventoryManagedCategory(
                    id: "custom-\(category.id.uuidString)",
                    displayName: name,
                    storageValue: name,
                    kind: .custom(category),
                    itemCount: usageCount(forCategoryValue: name, in: items)
                )
            }
            .sorted { (lhs: InventoryManagedCategory, rhs: InventoryManagedCategory) in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        return defaultRows + customRows
    }

    static func addLocation(
        named name: String,
        iconID: String? = nil,
        to locations: [StorageLocation]
    ) throws -> StorageLocation {
        let normalizedName = try validatedLocationName(name, locations: locations)
        return StorageLocation(name: normalizedName, iconID: LocationIconCatalog.normalizedIconID(iconID))
    }

    static func renameLocation(
        _ location: StorageLocation,
        to name: String,
        iconID: String? = nil,
        locations: [StorageLocation],
        items: [InventoryItem],
        updatedAt timestamp: Date = .now
    ) throws {
        let normalizedName = try validatedLocationName(name, locations: locations, excluding: location)
        let normalizedIconID = LocationIconCatalog.normalizedIconID(iconID)
        let previousName = location.name

        guard previousName != normalizedName || location.iconID != normalizedIconID else {
            location.name = normalizedName
            location.iconID = normalizedIconID
            return
        }

        location.name = normalizedName
        location.iconID = normalizedIconID
        location.updatedAt = timestamp

        for item in items where InventoryNormalizedName.location(item.locationName) == InventoryNormalizedName.location(previousName) {
            item.locationName = normalizedName
            item.updatedAt = timestamp
        }
    }

    static func deleteLocation(
        _ location: StorageLocation,
        items: [InventoryItem],
        places: [InventoryPlace] = []
    ) throws {
        let placeCount = places.filter { $0.locationID == location.id }.count
        guard placeCount == 0 else {
            throw InventoryListManagementError.locationContainsPlaces(normalizedName(location.name), placeCount)
        }
        let usedCount = usageCount(forLocationName: location.name, in: items)

        guard usedCount == 0 else {
            throw InventoryListManagementError.valueInUse(normalizedName(location.name), usedCount)
        }
    }

    static func addPlace(
        named name: String,
        iconID: String? = nil,
        in location: StorageLocation,
        places: [InventoryPlace]
    ) throws -> InventoryPlace {
        let normalizedName = try validatedPlaceName(name, in: location, places: places)
        return InventoryPlace(locationID: location.id, name: normalizedName, iconID: iconID)
    }

    static func renamePlace(
        _ place: InventoryPlace,
        in location: StorageLocation,
        to name: String,
        iconID: String? = nil,
        places: [InventoryPlace],
        items: [InventoryItem],
        updatedAt timestamp: Date = .now
    ) throws {
        guard place.locationID == location.id else {
            throw InventoryListManagementError.placeDoesNotBelongToLocation
        }

        let normalizedName = try validatedPlaceName(name, in: location, places: places, excluding: place)
        let normalizedIconID = PlaceIconCatalog.normalizedIconID(iconID)
        let previousName = place.name

        guard previousName != normalizedName || place.iconID != normalizedIconID else {
            place.name = normalizedName
            place.iconID = normalizedIconID
            return
        }

        let changesName = previousName != normalizedName
        place.name = normalizedName
        place.iconID = normalizedIconID
        place.updatedAt = timestamp

        guard changesName else { return }

        for item in items where itemUses(place, in: location, item: item, compatibilityName: previousName) {
            item.containerName = normalizedName
            item.placeID = place.id
            item.updatedAt = timestamp
        }
    }

    static func deletePlace(
        _ place: InventoryPlace,
        in location: StorageLocation,
        items: [InventoryItem]
    ) throws {
        guard place.locationID == location.id else {
            throw InventoryListManagementError.placeDoesNotBelongToLocation
        }

        let usedCount = usageCount(for: place, in: location, items: items)
        guard usedCount == 0 else {
            throw InventoryListManagementError.valueInUse(normalizedName(place.name), usedCount)
        }
    }

    static func addCustomCategory(
        named name: String,
        to customCategories: [InventoryCustomCategory]
    ) throws -> InventoryCustomCategory {
        let normalizedName = try validatedCategoryName(name, customCategories: customCategories)
        return InventoryCustomCategory(name: normalizedName)
    }

    static func renameCustomCategory(
        _ category: InventoryCustomCategory,
        to name: String,
        customCategories: [InventoryCustomCategory],
        items: [InventoryItem],
        updatedAt timestamp: Date = .now
    ) throws {
        let normalizedName = try validatedCategoryName(
            name,
            customCategories: customCategories,
            excluding: category
        )
        let previousName = category.name

        guard previousName != normalizedName else {
            category.name = normalizedName
            return
        }

        category.name = normalizedName
        category.updatedAt = timestamp

        for item in items where categoryValuesMatch(item.category, previousName) {
            item.category = normalizedName
            item.updatedAt = timestamp
        }
    }

    static func deleteCustomCategory(
        _ category: InventoryCustomCategory,
        items: [InventoryItem]
    ) throws {
        let usedCount = usageCount(forCategoryValue: category.name, in: items)

        guard usedCount == 0 else {
            throw InventoryListManagementError.valueInUse(normalizedName(category.name), usedCount)
        }
    }

    static func assertDefaultCategoryCanBeEdited() throws {
        throw InventoryListManagementError.defaultCategoryProtected
    }

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func usageCount(forLocationName name: String, in items: [InventoryItem]) -> Int {
        let normalizedName = InventoryNormalizedName.location(name)

        guard !normalizedName.isMissing else {
            return 0
        }

        return items.filter { InventoryNormalizedName.location($0.locationName) == normalizedName }.count
    }

    static func usageCount(forCategoryValue value: String, in items: [InventoryItem]) -> Int {
        items.filter { categoryValuesMatch($0.category, value) }.count
    }

    static func items(in items: [InventoryItem], matching selection: InventoryManagedItemsSelection) -> [InventoryItem] {
        switch selection {
        case let .location(_, name, _):
            return items.filter { InventoryNormalizedName.location($0.locationName) == InventoryNormalizedName.location(name) }
        case let .place(id, _, locationName, name, _):
            return items.filter { item in
                item.placeID == id || (
                    item.placeID == nil
                        && InventoryNormalizedName.location(item.locationName) == InventoryNormalizedName.location(locationName)
                        && InventoryNormalizedName.place(item.containerName) == InventoryNormalizedName.place(name)
                )
            }
        case let .category(_, _, storageValue):
            return items.filter { categoryValuesMatch($0.category, storageValue) }
        }
    }

    static func selection(for location: StorageLocation) -> InventoryManagedItemsSelection {
        .location(id: location.id, name: location.name, iconID: location.iconID)
    }

    static func selection(for place: InventoryPlace, in location: StorageLocation) throws -> InventoryManagedItemsSelection {
        guard place.locationID == location.id else {
            throw InventoryListManagementError.placeDoesNotBelongToLocation
        }
        return .place(
            id: place.id,
            locationID: location.id,
            locationName: location.name,
            name: place.name,
            iconID: PlaceIconCatalog.normalizedIconID(place.iconID)
        )
    }

    static func usageCount(for place: InventoryPlace, in location: StorageLocation, items: [InventoryItem]) -> Int {
        guard let selection = try? selection(for: place, in: location) else { return 0 }
        return Self.items(in: items, matching: selection).count
    }

    static func selection(for category: InventoryManagedCategory) -> InventoryManagedItemsSelection {
        .category(id: category.id, displayName: category.displayName, storageValue: category.storageValue)
    }

    static func selection(for category: InventoryCustomCategory) -> InventoryManagedItemsSelection {
        .category(
            id: "custom-\(category.id.uuidString)",
            displayName: normalizedName(category.name),
            storageValue: normalizedName(category.name)
        )
    }

    private static func validatedLocationName(
        _ name: String,
        locations: [StorageLocation],
        excluding excludedLocation: StorageLocation? = nil
    ) throws -> String {
        let normalizedName = normalizedName(name)

        guard !normalizedName.isEmpty else {
            throw InventoryListManagementError.emptyName
        }

        if locations.contains(where: { location in
            location.id != excludedLocation?.id
                && InventoryNormalizedName.location(location.name) == InventoryNormalizedName.location(normalizedName)
        }) {
            throw InventoryListManagementError.duplicateName(normalizedName)
        }

        return normalizedName
    }

    private static func validatedCategoryName(
        _ name: String,
        customCategories: [InventoryCustomCategory],
        excluding excludedCategory: InventoryCustomCategory? = nil
    ) throws -> String {
        let normalizedName = normalizedName(name)

        guard !normalizedName.isEmpty else {
            throw InventoryListManagementError.emptyName
        }

        if InventoryCategory.resolveBuiltInCategory(from: normalizedName) != nil {
            throw InventoryListManagementError.duplicateName(normalizedName)
        }

        if customCategories.contains(where: { category in
            category.id != excludedCategory?.id && categoryValuesMatch(category.name, normalizedName)
        }) {
            throw InventoryListManagementError.duplicateName(normalizedName)
        }

        return normalizedName
    }

    private static func validatedPlaceName(
        _ name: String,
        in location: StorageLocation,
        places: [InventoryPlace],
        excluding excludedPlace: InventoryPlace? = nil
    ) throws -> String {
        let normalizedName = normalizedName(name)
        guard !normalizedName.isEmpty else {
            throw InventoryListManagementError.emptyName
        }
        if places.contains(where: { place in
            place.locationID == location.id
                && place.id != excludedPlace?.id
                && InventoryNormalizedName.place(place.name) == InventoryNormalizedName.place(normalizedName)
        }) {
            throw InventoryListManagementError.duplicateName(normalizedName)
        }
        return normalizedName
    }

    private static func itemUses(
        _ place: InventoryPlace,
        in location: StorageLocation,
        item: InventoryItem,
        compatibilityName: String
    ) -> Bool {
        if item.placeID == place.id { return true }
        guard item.placeID == nil else { return false }
        return InventoryNormalizedName.location(item.locationName) == InventoryNormalizedName.location(location.name)
            && InventoryNormalizedName.place(item.containerName) == InventoryNormalizedName.place(compatibilityName)
    }

    static func categoryValuesMatch(_ lhs: String, _ rhs: String) -> Bool {
        if let lhsCategory = InventoryCategory.resolveBuiltInCategory(from: lhs),
           let rhsCategory = InventoryCategory.resolveBuiltInCategory(from: rhs) {
            return lhsCategory == rhsCategory
        }

        return normalizedName(lhs).localizedCaseInsensitiveCompare(normalizedName(rhs)) == .orderedSame
    }
}
