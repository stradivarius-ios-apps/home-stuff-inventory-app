import Foundation
import SwiftData

/// A reusable Place inside one persisted StorageLocation.
@Model
final class InventoryPlace {
    @Attribute(.unique)
    var id: UUID
    var locationID: UUID
    var parentPlaceID: UUID?
    var name: String
    var iconID: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        locationID: UUID,
        parentPlaceID: UUID? = nil,
        name: String,
        iconID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.locationID = locationID
        self.parentPlaceID = parentPlaceID
        self.name = InventoryNormalizedName.place(name).displayName
        self.iconID = PlaceIconCatalog.normalizedIconID(iconID)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

extension InventoryPlace {
    static func deterministicOrder(_ lhs: InventoryPlace, _ rhs: InventoryPlace) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard comparison == .orderedSame else { return comparison == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
