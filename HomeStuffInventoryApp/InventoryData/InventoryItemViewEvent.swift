import Foundation
import SwiftData

@Model
final class InventoryItemViewEvent {
    @Attribute(.unique)
    var id: UUID
    var itemID: UUID
    var viewedAt: Date

    init(
        id: UUID = UUID(),
        itemID: UUID,
        viewedAt: Date = .now
    ) {
        self.id = id
        self.itemID = itemID
        self.viewedAt = viewedAt
    }
}
