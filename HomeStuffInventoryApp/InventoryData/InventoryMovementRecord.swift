import Foundation
import SwiftData

enum InventoryMovementOrigin: Equatable, Sendable {
    case singleItem
    case selectedItems
    case storagePlaceDirectContents
    case roomSweep
    case hierarchySubtree
    case undo
    case unknown(String)

    init(rawValue: String) {
        self = switch rawValue {
        case "singleItem": .singleItem
        case "selectedItems": .selectedItems
        case "storagePlaceDirectContents": .storagePlaceDirectContents
        case "roomSweep": .roomSweep
        case "hierarchySubtree": .hierarchySubtree
        case "undo": .undo
        default: .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .singleItem: "singleItem"
        case .selectedItems: "selectedItems"
        case .storagePlaceDirectContents: "storagePlaceDirectContents"
        case .roomSweep: "roomSweep"
        case .hierarchySubtree: "hierarchySubtree"
        case .undo: "undo"
        case let .unknown(rawValue): rawValue
        }
    }
}

struct InventoryMovementEndpointSnapshot: Equatable, Sendable {
    let locationID: UUID?
    let locationName: String
    let placeID: UUID?
    let placeName: String?

    init(
        locationID: UUID?,
        locationName: String,
        placeID: UUID?,
        placeName: String?
    ) {
        self.locationID = locationID
        self.locationName = locationName
        self.placeID = placeID
        self.placeName = placeName
    }

    init(item: InventoryItem, locations: [StorageLocation]) {
        let normalizedLocation = InventoryNormalizedName.location(item.locationName)
        let matchingLocations = locations.filter {
            InventoryNormalizedName.location($0.name) == normalizedLocation
        }

        self.init(
            locationID: matchingLocations.count == 1 ? matchingLocations[0].id : nil,
            locationName: item.locationName,
            placeID: item.placeID,
            placeName: item.containerName
        )
    }
}

@Model
final class InventoryMovementRecord {
    @Attribute(.unique)
    var id: UUID
    var operationID: UUID
    var itemID: UUID
    var occurredAt: Date
    var originStorageValue: String
    var reversedOperationID: UUID?

    var sourceLocationID: UUID?
    var sourceLocationName: String
    var sourcePlaceID: UUID?
    var sourcePlaceName: String?

    var destinationLocationID: UUID?
    var destinationLocationName: String
    var destinationPlaceID: UUID?
    var destinationPlaceName: String?

    init(
        id: UUID = UUID(),
        operationID: UUID,
        itemID: UUID,
        occurredAt: Date = .now,
        origin: InventoryMovementOrigin,
        reversedOperationID: UUID? = nil,
        source: InventoryMovementEndpointSnapshot,
        destination: InventoryMovementEndpointSnapshot
    ) {
        self.id = id
        self.operationID = operationID
        self.itemID = itemID
        self.occurredAt = occurredAt
        self.originStorageValue = origin.rawValue
        self.reversedOperationID = reversedOperationID
        self.sourceLocationID = source.locationID
        self.sourceLocationName = source.locationName
        self.sourcePlaceID = source.placeID
        self.sourcePlaceName = source.placeName
        self.destinationLocationID = destination.locationID
        self.destinationLocationName = destination.locationName
        self.destinationPlaceID = destination.placeID
        self.destinationPlaceName = destination.placeName
    }

    var origin: InventoryMovementOrigin {
        InventoryMovementOrigin(rawValue: originStorageValue)
    }

    var source: InventoryMovementEndpointSnapshot {
        InventoryMovementEndpointSnapshot(
            locationID: sourceLocationID,
            locationName: sourceLocationName,
            placeID: sourcePlaceID,
            placeName: sourcePlaceName
        )
    }

    var destination: InventoryMovementEndpointSnapshot {
        InventoryMovementEndpointSnapshot(
            locationID: destinationLocationID,
            locationName: destinationLocationName,
            placeID: destinationPlaceID,
            placeName: destinationPlaceName
        )
    }
}
