import Foundation
import SwiftData

/// A bounded, local-only aggregate for one canonical Place. This is deliberately
/// not portable inventory content.
@Model
final class InventoryPlaceOpenRecord {
    @Attribute(.unique)
    var id: UUID
    var placeIdentity: String
    var placeID: UUID?
    var openCount: Int
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        placeIdentity: String,
        placeID: UUID? = nil,
        openCount: Int = 0,
        lastOpenedAt: Date = .distantPast
    ) {
        self.id = id
        self.placeIdentity = placeIdentity
        self.placeID = placeID
        self.openCount = openCount
        self.lastOpenedAt = lastOpenedAt
    }
}
