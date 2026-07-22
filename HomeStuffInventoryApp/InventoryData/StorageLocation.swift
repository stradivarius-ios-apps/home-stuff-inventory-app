import Foundation
import SwiftData

@Model
final class StorageLocation {
    var id: UUID
    var name: String
    var iconID: String?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconID: String? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconID = LocationIconCatalog.normalizedIconID(iconID)
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
