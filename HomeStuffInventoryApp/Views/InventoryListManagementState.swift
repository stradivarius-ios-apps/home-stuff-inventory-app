import Foundation

enum InventoryListManagementSheet: Identifiable {
    case addLocation
    case editLocation(StorageLocation)
    case addCategory
    case editCategory(InventoryCustomCategory)

    var id: String {
        switch self {
        case .addLocation:
            return "add-location"
        case let .editLocation(location):
            return "edit-location-\(location.id.uuidString)"
        case .addCategory:
            return "add-category"
        case let .editCategory(category):
            return "edit-category-\(category.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .addLocation:
            return String(localized: "inventory.lists.addLocation", defaultValue: "Add Location", bundle: .main)
        case .editLocation:
            return String(localized: "inventory.lists.editLocation", defaultValue: "Edit Location", bundle: .main)
        case .addCategory:
            return String(localized: "inventory.lists.addCategory", defaultValue: "Add Category", bundle: .main)
        case .editCategory:
            return String(localized: "inventory.lists.renameCategory", defaultValue: "Rename Category", bundle: .main)
        }
    }

    var prompt: String {
        switch self {
        case .addLocation, .editLocation:
            return String(localized: "inventory.selection.location.newPrompt", defaultValue: "New location", bundle: .main)
        case .addCategory, .editCategory:
            return String(localized: "inventory.selection.category.newPrompt", defaultValue: "New category", bundle: .main)
        }
    }

    var initialValue: String {
        switch self {
        case .addLocation, .addCategory:
            return ""
        case let .editLocation(location):
            return location.name
        case let .editCategory(category):
            return category.name
        }
    }

    var initialIconID: String? {
        switch self {
        case let .editLocation(location):
            return LocationIconCatalog.normalizedIconID(location.iconID)
        case .addLocation, .addCategory, .editCategory:
            return nil
        }
    }

    var supportsLocationIcon: Bool {
        switch self {
        case .addLocation, .editLocation:
            return true
        case .addCategory, .editCategory:
            return false
        }
    }
}

enum InventoryListManagementDeleteRequest: Identifiable {
    case location(StorageLocation)
    case category(InventoryCustomCategory)

    var id: String {
        switch self {
        case let .location(location):
            return "location-\(location.id.uuidString)"
        case let .category(category):
            return "category-\(category.id.uuidString)"
        }
    }
}

enum InventoryListManagementDialog: Identifiable {
    case delete(InventoryListManagementDeleteRequest)
    case message(InventoryListManagementAlert)
    case valueInUse(InventoryListManagementAlert, InventoryManagedItemsSelection)

    var id: String {
        switch self {
        case let .delete(request):
            return "delete-\(request.id)"
        case let .message(alert):
            return "message-\(alert.id.uuidString)"
        case let .valueInUse(alert, selection):
            return "value-in-use-\(alert.id.uuidString)-\(selection.id)"
        }
    }
}

struct InventoryListManagementAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func error(_ error: InventoryListManagementError) -> InventoryListManagementAlert {
        switch error {
        case .emptyName:
            return InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.empty.title", defaultValue: "Name Required", bundle: .main),
                message: String(localized: "inventory.lists.error.empty.message", defaultValue: "Enter a name before saving.", bundle: .main)
            )
        case let .duplicateName(name):
            return InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.duplicate.title", defaultValue: "Name Already Exists", bundle: .main),
                message: String(
                    format: String(localized: "inventory.lists.error.duplicate.message", defaultValue: "%@ is already in this list.", bundle: .main),
                    name
                )
            )
        case .defaultCategoryProtected:
            return InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.default.title", defaultValue: "Default Category", bundle: .main),
                message: String(localized: "inventory.lists.error.default.message", defaultValue: "Built-in categories cannot be renamed or deleted.", bundle: .main)
            )
        case let .valueInUse(name, count):
            return InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.used.title", defaultValue: "Value Is In Use", bundle: .main),
                message: String(
                    format: String(localized: "inventory.lists.error.used.message", defaultValue: "%@ is used by %@. Rename it or update those items before deleting it.", bundle: .main),
                    name,
                    InventoryLocalization.itemCount(count)
                )
            )
        case let .locationContainsPlaces(name, count):
            return InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.used.title", defaultValue: "Value Is In Use", bundle: .main),
                message: InventoryLocalization.locationContainsPlacesMessage(name, count: count)
            )
        case .placeDoesNotBelongToLocation:
            return InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.save.title", defaultValue: "List Not Updated", bundle: .main),
                message: String(localized: "inventory.lists.error.placeDoesNotBelongToLocation.message", defaultValue: "This storage place does not belong to the selected location.", bundle: .main)
            )
        }
    }
}

enum InventoryListManagementPersistenceFailure {
    case save
    case deleteValidation
    case delete

    var alert: InventoryListManagementAlert {
        switch self {
        case .save:
            InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.save.title", defaultValue: "List Not Updated", bundle: .main),
                message: String(
                    localized: "inventory.lists.error.save.message",
                    defaultValue: "Your list changes could not be saved. Please try again.",
                    bundle: .main
                )
            )
        case .deleteValidation:
            InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.delete.title", defaultValue: "Value Not Deleted", bundle: .main),
                message: String(
                    localized: "inventory.lists.error.delete.validationMessage",
                    defaultValue: "The value could not be checked before deletion. Please try again.",
                    bundle: .main
                )
            )
        case .delete:
            InventoryListManagementAlert(
                title: String(localized: "inventory.lists.error.delete.title", defaultValue: "Value Not Deleted", bundle: .main),
                message: String(
                    localized: "inventory.lists.error.delete.message",
                    defaultValue: "The value could not be deleted. Please try again.",
                    bundle: .main
                )
            )
        }
    }

    var logOperation: String {
        switch self {
        case .save:
            return "save"
        case .deleteValidation:
            return "delete validation"
        case .delete:
            return "delete"
        }
    }
}

struct InventoryListManagementValueDraft {
    let value: String
    let iconID: String?
}
