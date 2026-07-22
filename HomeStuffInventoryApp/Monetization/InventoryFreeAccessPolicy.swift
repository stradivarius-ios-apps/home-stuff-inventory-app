enum InventoryEntitlementState: CaseIterable, Hashable, Sendable {
    case free
    case lifetimePro
    case activeFamilySubscription
    case lifetimeProWithActiveFamilySubscription
    case expiredFamilySubscription
    case lifetimeProWithExpiredFamilySubscription
}

enum InventoryFreeCapability: String, CaseIterable, Hashable, Sendable {
    case unlimitedItems
    case createItem
    case viewItem
    case editItem
    case deleteItem
    case manageLocations
    case managePlaces
    case relocateSingleItem
    case searchSupportedFields
    case filterByCategory
    case filterByLocation
    case filterByPlace
    case browseLocationPlaceItem
    case editNotes
    case editTags
    case editQuantity
    case editCondition
    case manageReusableValues
    case guideMissingLocation
    case guideMissingPlace
    case viewExistingRecords
    case exportInventory
    case backUpInventory
    case restoreInventory
}

enum InventoryCapabilityAvailability: Equatable, Sendable {
    case available
    case unavailable
}

struct InventoryFreeAccessPolicy: Sendable {
    func availability(
        of capability: InventoryFreeCapability,
        entitlementState: InventoryEntitlementState?
    ) -> InventoryCapabilityAvailability {
        .available
    }
}
