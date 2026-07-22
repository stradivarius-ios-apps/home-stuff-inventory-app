import Foundation

enum InventoryItemFormPersistenceOutcome: Equatable {
    case saved
    case invalidDraft
    case saveFailed
}

enum InventoryItemFormPersistence {
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
}
