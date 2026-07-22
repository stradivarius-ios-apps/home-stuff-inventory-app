import Foundation

enum InventoryItemMutationFailure: Equatable {
    case deleteItem
    case saveNotes

    var title: String {
        switch self {
        case .deleteItem:
            InventoryLocalization.string(
                "inventory.alert.deleteError.title",
                defaultValue: "Item Not Deleted"
            )
        case .saveNotes:
            InventoryLocalization.string(
                "inventory.alert.saveError.editTitle",
                defaultValue: "Item Not Updated"
            )
        }
    }

    var message: String {
        switch self {
        case .deleteItem:
            InventoryLocalization.string(
                "inventory.alert.deleteError.message",
                defaultValue: "The item could not be deleted. Please try again."
            )
        case .saveNotes:
            InventoryLocalization.string(
                "inventory.alert.saveError.message",
                defaultValue: "Your changes could not be saved. Please try again."
            )
        }
    }
}
