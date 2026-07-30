import Foundation

/// Resolves Item form Place linkage without ever matching a Place globally by name.
enum InventoryItemPlaceLink {
    struct DestinationOption: Identifiable, Equatable {
        let id: UUID
        let name: String
        let iconID: String?
        let pathComponents: [String]

        var pathText: String { pathComponents.joined(separator: " › ") }
        var depth: Int { max(0, pathComponents.count - 1) }
    }

    struct ResolvedValue: Equatable {
        let locationName: String
        let placeName: String?
        let placeID: UUID?
    }

    static func resolve(
        draft: InventoryItemDraft,
        locations: [StorageLocation],
        places: [InventoryPlace]
    ) -> ResolvedValue {
        let locationName = draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyPlace = normalizedOptional(draft.containerName)
        guard let location = locations.first(where: {
            InventoryNormalizedName.location($0.name) == InventoryNormalizedName.location(locationName)
        }) else {
            return .init(locationName: locationName, placeName: legacyPlace, placeID: nil)
        }

        if let selectedID = draft.placeID,
           let selected = places.first(where: { $0.id == selectedID && $0.locationID == location.id }) {
            return .init(locationName: location.name, placeName: selected.name, placeID: selected.id)
        }

        guard draft.allowsLegacyPlaceResolution,
              let legacyPlace,
              let exact = places.first(where: {
                  $0.locationID == location.id
                      && $0.parentPlaceID == nil
                      && InventoryNormalizedName.place($0.name) == InventoryNormalizedName.place(legacyPlace)
              }) else {
            return .init(locationName: location.name, placeName: legacyPlace, placeID: nil)
        }
        return .init(locationName: location.name, placeName: exact.name, placeID: exact.id)
    }

    static func places(in location: StorageLocation?, from places: [InventoryPlace]) -> [InventoryPlace] {
        guard let location else { return [] }
        return places.filter { $0.locationID == location.id }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func destinationOptions(
        in location: StorageLocation?,
        from places: [InventoryPlace]
    ) -> [DestinationOption] {
        self.places(in: location, from: places).map { place in
            let path = InventoryPlaceHierarchy.path(for: place, places: places)
            return DestinationOption(
                id: place.id,
                name: place.name,
                iconID: place.iconID,
                pathComponents: path.components
            )
        }
        .sorted { lhs, rhs in
            let comparison = lhs.pathText.localizedCaseInsensitiveCompare(rhs.pathText)
            guard comparison == .orderedSame else { return comparison == .orderedAscending }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
