import Foundation

struct InventoryEmptyStateViewModel: Equatable {
    let title: String
    let message: String
    let primaryActionTitle: String

    static let initial = InventoryEmptyStateViewModel(
        title: InventoryLocalization.string("inventory.empty.title", defaultValue: "Nothing stored yet"),
        message: InventoryLocalization.string(
            "inventory.empty.message",
            defaultValue: "Add household items with their location and exact storage place so you can find them later."
        ),
        primaryActionTitle: InventoryLocalization.string("inventory.action.addItem", defaultValue: "Add Item")
    )
}

enum InventoryListContentState: Equatable {
    case initial
    case filteredEmpty
    case results

    static func make(itemCount: Int, filteredItemCount: Int) -> Self {
        itemCount == 0 ? .initial : (filteredItemCount == 0 ? .filteredEmpty : .results)
    }
}

enum InventoryLocationCreateContext {
    static func make(for location: InventoryBrowseSummaries.LocationSummary) -> InventoryItemCreateContext {
        InventoryItemCreateContext(locationName: location.isMissingLocation ? "" : location.name)
    }
}
