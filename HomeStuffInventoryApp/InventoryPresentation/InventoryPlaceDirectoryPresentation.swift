import Foundation

/// Deterministic, location-scoped presentation data for the Settings Place directory.
struct InventoryPlaceDirectorySection: Identifiable {
    let location: StorageLocation
    let places: [InventoryPlace]

    var id: UUID { location.id }

    static func make(locations: [StorageLocation], places: [InventoryPlace]) -> [Self] {
        let placesByLocation = Dictionary(grouping: places, by: \.locationID)

        return locations.compactMap { location in
            let scopedPlaces = (placesByLocation[location.id] ?? []).sorted(by: placeSort)
            guard !scopedPlaces.isEmpty else { return nil }
            return Self(location: location, places: scopedPlaces)
        }
        .sorted(by: locationSort)
    }

    private static func locationSort(_ lhs: Self, _ rhs: Self) -> Bool {
        localizedSort(lhs.location.name, rhs.location.name, lhsID: lhs.location.id, rhsID: rhs.location.id)
    }

    private static func placeSort(_ lhs: InventoryPlace, _ rhs: InventoryPlace) -> Bool {
        localizedSort(lhs.name, rhs.name, lhsID: lhs.id, rhsID: rhs.id)
    }

    private static func localizedSort(_ lhs: String, _ rhs: String, lhsID: UUID, rhsID: UUID) -> Bool {
        let result = lhs.localizedStandardCompare(rhs)
        return result == .orderedSame ? lhsID.uuidString < rhsID.uuidString : result == .orderedAscending
    }
}
