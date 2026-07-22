import Foundation
import SwiftData

enum InventoryPlaceReconcilerError: Error, Equatable {
    case saveFailed
}

/// Reconciles the additive Place catalog from legacy Item text without changing that text.
enum InventoryPlaceReconciler {
    typealias SaveOperation = @MainActor (ModelContext) throws -> Void

    @MainActor
    static func reconcile(
        in context: ModelContext,
        save: SaveOperation = { try $0.save() }
    ) throws {
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())

        let originalItemPlaceIDs = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.placeID) })
        var insertedLocations: [StorageLocation] = []
        var insertedPlaces: [InventoryPlace] = []
        var deletedPlaces: [InventoryPlace] = []

        do {
            var locationsByName = Dictionary(grouping: locations, by: { InventoryNormalizedName.location($0.name) })
                .mapValues { $0.sorted { $0.id.uuidString < $1.id.uuidString } }

            let legacyLocationNames = Dictionary(grouping: items.compactMap { item -> (InventoryNormalizedName, String)? in
                let normalized = InventoryNormalizedName.location(item.locationName)
                return normalized.isMissing ? nil : (normalized, normalized.displayName)
            }, by: { $0.0 })

            for (normalized, values) in legacyLocationNames where locationsByName[normalized] == nil {
                let location = StorageLocation(name: preferredSpelling(values.map(\.1)))
                context.insert(location)
                insertedLocations.append(location)
                locationsByName[normalized] = [location]
            }

            var placesByScope = Dictionary(grouping: places, by: scope(for:))
                .mapValues { $0.sorted { $0.id.uuidString < $1.id.uuidString } }
            for groupedPlaces in placesByScope.values where groupedPlaces.count > 1 {
                guard let keeper = groupedPlaces.first else { continue }
                for duplicate in groupedPlaces.dropFirst() {
                    for item in items where item.placeID == duplicate.id {
                        item.placeID = keeper.id
                    }
                    context.delete(duplicate)
                    deletedPlaces.append(duplicate)
                }
            }
            placesByScope = placesByScope.mapValues { Array($0.prefix(1)) }

            for item in items {
                let locationName = InventoryNormalizedName.location(item.locationName)
                let placeName = InventoryNormalizedName.place(item.containerName)
                guard !locationName.isMissing, !placeName.isMissing,
                      let location = locationsByName[locationName]?.first
                else {
                    item.placeID = nil
                    continue
                }

                let key = PlaceScope(locationID: location.id, name: placeName)
                let place: InventoryPlace
                if let existing = placesByScope[key]?.first {
                    place = existing
                } else {
                    place = InventoryPlace(locationID: location.id, name: placeName.displayName, iconID: PlaceIconCatalog.defaultIconID)
                    context.insert(place)
                    insertedPlaces.append(place)
                    placesByScope[key] = [place]
                }
                item.placeID = place.id
            }

            let changed = !insertedLocations.isEmpty || !insertedPlaces.isEmpty || !deletedPlaces.isEmpty
                || items.contains { $0.placeID != originalItemPlaceIDs[$0.id] }
            if changed { try save(context) }
        } catch {
            for item in items { item.placeID = originalItemPlaceIDs[item.id] ?? nil }
            insertedPlaces.forEach(context.delete)
            insertedLocations.forEach(context.delete)
            context.rollback()
            throw InventoryPlaceReconcilerError.saveFailed
        }
    }

    private struct PlaceScope: Hashable {
        let locationID: UUID
        let name: InventoryNormalizedName
    }

    private static func scope(for place: InventoryPlace) -> PlaceScope {
        PlaceScope(locationID: place.locationID, name: InventoryNormalizedName.place(place.name))
    }

    private static func preferredSpelling(_ spellings: [String]) -> String {
        Dictionary(grouping: spellings, by: { $0 })
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                let comparison = lhs.key.localizedCaseInsensitiveCompare(rhs.key)
                return comparison == .orderedSame ? lhs.key < rhs.key : comparison == .orderedAscending
            }
            .first!.key
    }
}
