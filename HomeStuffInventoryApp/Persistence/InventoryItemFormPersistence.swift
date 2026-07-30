import Foundation
import SwiftData

enum InventoryItemFormPersistenceOutcome: Equatable {
    case saved
    case invalidDraft
    case saveFailed
}

enum InventoryItemFormPersistence {
    @MainActor
    static func save(
        draft: InventoryItemDraft,
        item: InventoryItem?,
        locations: [StorageLocation] = [],
        places: [InventoryPlace] = [],
        in modelContext: ModelContext,
        occurredAt: Date = .now,
        operationID: UUID = UUID(),
        recordID: UUID = UUID(),
        retainedOperationLimit: Int = InventoryMovementHistory.defaultRetainedOperationLimit,
        persist: (() throws -> Void)? = nil
    ) -> InventoryItemFormPersistenceOutcome {
        let source = item.map {
            InventoryMovementEndpointSnapshot(item: $0, locations: locations)
        }
        let place = InventoryItemPlaceLink.resolve(draft: draft, locations: locations, places: places)
        var linkedDraft = draft
        linkedDraft.locationName = place.locationName
        linkedDraft.containerName = place.placeName ?? ""
        linkedDraft.placeID = place.placeID

        if let item {
            linkedDraft.apply(to: item, placeID: place.placeID, updatedAt: occurredAt)
        } else if let item = linkedDraft.makeInventoryItem(createdAt: occurredAt, placeID: place.placeID) {
            modelContext.insert(item)
        } else {
            return .invalidDraft
        }

        do {
            if let item, let source {
                let destination = InventoryMovementEndpointSnapshot(item: item, locations: locations)
                if isSemanticMovement(from: source, to: destination) {
                    modelContext.insert(
                        InventoryMovementRecord(
                            id: recordID,
                            operationID: operationID,
                            itemID: item.id,
                            occurredAt: occurredAt,
                            origin: .singleItem,
                            source: source,
                            destination: destination
                        )
                    )
                    try InventoryMovementHistory.prune(
                        records: try modelContext.fetch(FetchDescriptor<InventoryMovementRecord>()),
                        keepingLatestOperations: retainedOperationLimit,
                        delete: modelContext.delete
                    )
                }
            }
            try (persist ?? modelContext.save)()
            return .saved
        } catch {
            modelContext.rollback()
            return .saveFailed
        }
    }

    static func save(
        draft: InventoryItemDraft,
        item: InventoryItem?,
        locations: [StorageLocation] = [],
        places: [InventoryPlace] = [],
        insert: (InventoryItem) -> Void,
        persist: () throws -> Void,
        rollback: () -> Void
    ) -> InventoryItemFormPersistenceOutcome {
        let place = InventoryItemPlaceLink.resolve(draft: draft, locations: locations, places: places)
        var linkedDraft = draft
        linkedDraft.locationName = place.locationName
        linkedDraft.containerName = place.placeName ?? ""
        linkedDraft.placeID = place.placeID
        if let item {
            linkedDraft.apply(to: item, placeID: place.placeID)
        } else if let item = linkedDraft.makeInventoryItem(placeID: place.placeID) {
            insert(item)
        } else {
            return .invalidDraft
        }

        do {
            try persist()
            return .saved
        } catch {
            rollback()
            return .saveFailed
        }
    }

    private static func isSemanticMovement(
        from source: InventoryMovementEndpointSnapshot,
        to destination: InventoryMovementEndpointSnapshot
    ) -> Bool {
        let sourceLocation = InventoryNormalizedName.location(source.locationName)
        let destinationLocation = InventoryNormalizedName.location(destination.locationName)
        let sourcePlace = InventoryNormalizedName.place(source.placeName ?? "")
        let destinationPlace = InventoryNormalizedName.place(destination.placeName ?? "")

        if sourceLocation != destinationLocation || sourcePlace != destinationPlace {
            return true
        }
        if let sourcePlaceID = source.placeID, let destinationPlaceID = destination.placeID {
            return sourcePlaceID != destinationPlaceID
        }
        return false
    }
}
