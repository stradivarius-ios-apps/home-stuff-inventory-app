import Foundation
import SwiftData

enum InventoryPlaceReconcilerError: Error, Equatable {
    case saveFailed
}

struct InventoryPlaceRepairReport: Equatable {
    var missingParentsRemoved = 0
    var crossLocationParentsRemoved = 0
    var selfParentsRemoved = 0
    var cyclesBroken = 0
    var siblingCollisionsReparented = 0

    var madeChanges: Bool {
        missingParentsRemoved > 0
            || crossLocationParentsRemoved > 0
            || selfParentsRemoved > 0
            || cyclesBroken > 0
            || siblingCollisionsReparented > 0
    }
}

/// Reconciles the additive Place catalog from legacy Item text without changing that text.
enum InventoryPlaceReconciler {
    typealias SaveOperation = @MainActor (ModelContext) throws -> Void

    @discardableResult
    @MainActor
    static func reconcile(
        in context: ModelContext,
        save: SaveOperation = { try $0.save() }
    ) throws -> InventoryPlaceRepairReport {
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())

        let originalItemPlaceIDs = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.placeID) })
        let originalParentPlaceIDs = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.parentPlaceID) })
        var insertedLocations: [StorageLocation] = []
        var insertedPlaces: [InventoryPlace] = []

        do {
            let repairReport = repairHierarchy(places)
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
            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

            for item in items {
                let locationName = InventoryNormalizedName.location(item.locationName)
                let placeName = InventoryNormalizedName.place(item.containerName)
                guard !locationName.isMissing, !placeName.isMissing,
                      let location = locationsByName[locationName]?.first
                else {
                    item.placeID = nil
                    continue
                }

                if let linkedPlaceID = item.placeID,
                   let linkedPlace = placesByID[linkedPlaceID],
                   linkedPlace.locationID == location.id {
                    continue
                }

                let key = PlaceScope(locationID: location.id, parentPlaceID: nil, name: placeName)
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

            let changed = repairReport.madeChanges || !insertedLocations.isEmpty || !insertedPlaces.isEmpty
                || items.contains { $0.placeID != originalItemPlaceIDs[$0.id] }
            if changed { try save(context) }
            return repairReport
        } catch {
            for item in items { item.placeID = originalItemPlaceIDs[item.id] ?? nil }
            for place in places { place.parentPlaceID = originalParentPlaceIDs[place.id] ?? nil }
            insertedPlaces.forEach(context.delete)
            insertedLocations.forEach(context.delete)
            context.rollback()
            throw InventoryPlaceReconcilerError.saveFailed
        }
    }

    private struct PlaceScope: Hashable {
        let locationID: UUID
        let parentPlaceID: UUID?
        let name: InventoryNormalizedName
    }

    private static func scope(for place: InventoryPlace) -> PlaceScope {
        PlaceScope(
            locationID: place.locationID,
            parentPlaceID: place.parentPlaceID,
            name: InventoryNormalizedName.place(place.name)
        )
    }

    private static func repairHierarchy(_ places: [InventoryPlace]) -> InventoryPlaceRepairReport {
        var report = InventoryPlaceRepairReport()
        let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let orderedPlaces = places.sorted { $0.id.uuidString < $1.id.uuidString }

        for place in orderedPlaces {
            guard let parentPlaceID = place.parentPlaceID else { continue }
            if parentPlaceID == place.id {
                place.parentPlaceID = nil
                report.selfParentsRemoved += 1
            } else if let parent = placesByID[parentPlaceID] {
                if parent.locationID != place.locationID {
                    place.parentPlaceID = nil
                    report.crossLocationParentsRemoved += 1
                }
            } else {
                place.parentPlaceID = nil
                report.missingParentsRemoved += 1
            }
        }

        var completelyVisited = Set<UUID>()
        for place in orderedPlaces where !completelyVisited.contains(place.id) {
            var chain: [InventoryPlace] = []
            var positionByID: [UUID: Int] = [:]
            var current: InventoryPlace? = place

            while let candidate = current, !completelyVisited.contains(candidate.id) {
                if let cycleStart = positionByID[candidate.id] {
                    let cycle = chain[cycleStart...]
                    let breaker = cycle.min { $0.id.uuidString < $1.id.uuidString }!
                    breaker.parentPlaceID = nil
                    report.cyclesBroken += 1
                    break
                }

                positionByID[candidate.id] = chain.count
                chain.append(candidate)
                current = candidate.parentPlaceID.flatMap { placesByID[$0] }
            }

            completelyVisited.formUnion(chain.map(\.id))
        }

        // Turn each deterministic collision group into a chain. This preserves every
        // stable ID and user-authored name instead of deleting or renaming a Place.
        while true {
            let collision = Dictionary(grouping: orderedPlaces, by: scope(for:))
                .values
                .filter { $0.count > 1 }
                .map { $0.sorted { $0.id.uuidString < $1.id.uuidString } }
                .sorted { lhs, rhs in
                    let left = lhs[0]
                    let right = rhs[0]
                    if left.locationID != right.locationID {
                        return left.locationID.uuidString < right.locationID.uuidString
                    }
                    let leftParent = left.parentPlaceID?.uuidString ?? ""
                    let rightParent = right.parentPlaceID?.uuidString ?? ""
                    if leftParent != rightParent {
                        return leftParent < rightParent
                    }
                    let nameComparison = left.name.localizedCaseInsensitiveCompare(right.name)
                    return nameComparison == .orderedSame
                        ? left.id.uuidString < right.id.uuidString
                        : nameComparison == .orderedAscending
                }
                .first

            guard let collision else { break }
            var parent = collision[0]
            for duplicate in collision.dropFirst() {
                duplicate.parentPlaceID = parent.id
                parent = duplicate
                report.siblingCollisionsReparented += 1
            }
        }

        return report
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
