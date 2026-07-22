import Foundation

/// The persistence identity intentionally uses the same comparison keys as browse grouping.
struct InventoryPlaceIdentity: Hashable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static func make(
        locationName: String,
        placeName: String?,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> InventoryPlaceIdentity {
        let location = InventoryNormalizedName.location(locationName, vocabulary: vocabulary)
        let place = InventoryNormalizedName.place(placeName, vocabulary: vocabulary)
        // Prefixing the two states makes the reserved missing values non-colliding
        // even if a user types a string resembling an internal comparison key.
        return InventoryPlaceIdentity(
            rawValue: "location:\(component(for: location))|place:\(component(for: place))"
        )
    }

    static func make(for item: InventoryItem) -> InventoryPlaceIdentity {
        make(locationName: item.locationName, placeName: item.containerName)
    }

    private static func component(for name: InventoryNormalizedName) -> String {
        name.isMissing ? "missing" : "named:\(name.comparisonKey)"
    }
}
