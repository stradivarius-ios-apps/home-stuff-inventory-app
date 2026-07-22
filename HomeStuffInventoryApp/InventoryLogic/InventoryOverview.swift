import Foundation

struct InventoryOverview: Equatable {
    let itemCount: Int
    let locationCount: Int

    var isEmpty: Bool {
        itemCount == 0 && locationCount == 0
    }
}

enum InventoryOverviewFactory {
    static func make(items: [InventoryItem], locations: [StorageLocation]) -> InventoryOverview {
        InventoryOverview(itemCount: items.count, locationCount: locations.count)
    }
}
