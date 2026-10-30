import Foundation

enum InventoryPlaceDetailPresentation {
    static func usesSimpleLeafLayout(
        selectedPlace: InventoryBrowseSummaries.PlaceSummary,
        detailPlace: InventoryBrowseSummaries.PlaceSummary,
        places: [InventoryPlace],
        locations: [StorageLocation],
        childPlaces: [InventoryBrowseSummaries.PlaceSummary]
    ) -> Bool {
        guard !selectedPlace.isMissingPlace,
              !selectedPlace.isMissingLocation,
              let placeID = selectedPlace.placeID,
              let model = places.first(where: { $0.id == placeID }),
              let location = locations.first(where: { $0.id == model.locationID }),
              InventoryNormalizedName.location(location.name).matches(
                name: selectedPlace.locationName,
                isMissing: selectedPlace.isMissingLocation
              ),
              !InventoryNormalizedName.location(location.name).isMissing,
              model.parentPlaceID == nil,
              detailPlace.childPlaceCount == 0,
              childPlaces.isEmpty,
              detailPlace.recursiveItemCount == detailPlace.directItemCount
        else {
            return false
        }

        // Summary paths can default to a single name even for unresolved models.
        let path = InventoryPlaceHierarchy.path(for: model, places: places)
        return path.status == .complete && path.components.count == 1
    }
}
