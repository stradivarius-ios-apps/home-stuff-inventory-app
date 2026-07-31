import Foundation
import SwiftData

struct InventoryPlaceMutationPlaceSnapshot: Codable, Equatable, Sendable {
    let id: UUID
    let locationID: UUID
    let parentPlaceID: UUID?
    let name: String
    let iconID: String?
    let updatedAt: Date

    init(place: InventoryPlace) {
        id = place.id
        locationID = place.locationID
        parentPlaceID = place.parentPlaceID
        name = place.name
        iconID = place.iconID
        updatedAt = place.updatedAt
    }
}

struct InventoryPlaceMutationItemSnapshot: Codable, Equatable, Sendable {
    let id: UUID
    let locationName: String
    let containerName: String?
    let placeID: UUID?
    let updatedAt: Date

    init(item: InventoryItem) {
        id = item.id
        locationName = item.locationName
        containerName = item.containerName
        placeID = item.placeID
        updatedAt = item.updatedAt
    }
}

struct InventoryPlaceMutationSnapshot: Codable, Equatable, Sendable {
    let rootPlaceID: UUID
    let places: [InventoryPlaceMutationPlaceSnapshot]
    let items: [InventoryPlaceMutationItemSnapshot]

    init(rootPlaceID: UUID, places: [InventoryPlace], items: [InventoryItem]) {
        self.rootPlaceID = rootPlaceID
        self.places = places
            .map(InventoryPlaceMutationPlaceSnapshot.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        self.items = items
            .map(InventoryPlaceMutationItemSnapshot.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

@Model
final class InventoryPlaceMutationRecord {
    @Attribute(.unique)
    var id: UUID
    var occurredAt: Date
    var beforeSnapshotData: Data
    var afterSnapshotData: Data
    var undoneAt: Date?

    init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        before: InventoryPlaceMutationSnapshot,
        after: InventoryPlaceMutationSnapshot,
        undoneAt: Date? = nil
    ) throws {
        self.id = id
        self.occurredAt = occurredAt
        self.beforeSnapshotData = try Self.encoder.encode(before)
        self.afterSnapshotData = try Self.encoder.encode(after)
        self.undoneAt = undoneAt
    }

    var beforeSnapshot: InventoryPlaceMutationSnapshot? {
        try? Self.decoder.decode(
            InventoryPlaceMutationSnapshot.self,
            from: beforeSnapshotData
        )
    }

    var afterSnapshot: InventoryPlaceMutationSnapshot? {
        try? Self.decoder.decode(
            InventoryPlaceMutationSnapshot.self,
            from: afterSnapshotData
        )
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        JSONDecoder()
    }
}
