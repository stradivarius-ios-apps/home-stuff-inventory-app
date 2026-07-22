import Foundation

enum InventoryPlaceIconPresentation {
    static func symbolName(placeID: UUID?, isMissingPlace: Bool, places: [InventoryPlace]) -> String {
        guard !isMissingPlace else { return "shippingbox.circle" }
        return PlaceIconCatalog.symbolName(for: places.first(where: { $0.id == placeID })?.iconID)
    }
}

extension InventoryBrowseSummaries {
    struct PreviewItem: Equatable, Identifiable {
        let id: String
        let title: String
    }

    struct PreviewGroup: Equatable, Identifiable {
        enum Kind: Equatable {
            case category
            case place
            case recentItem
        }

        let kind: Kind
        let visibleItems: [PreviewItem]
        let hiddenCount: Int

        var id: String {
            switch kind {
            case .category:
                "category"
            case .place:
                "place"
            case .recentItem:
                "recentItem"
            }
        }
    }

    struct LocationSummary: Equatable, Identifiable {
        let name: String
        let iconID: String?
        let itemCount: Int
        let isMissingLocation: Bool
        let categoryPreview: [String]
        let hiddenCategoryCount: Int
        let placePreview: [String]
        let hiddenPlaceCount: Int
        let previewGroups: [PreviewGroup]

        var id: String {
            isMissingLocation ? "__missing_location__" : name
        }

        init(
            name: String,
            iconID: String? = nil,
            itemCount: Int,
            isMissingLocation: Bool,
            categoryPreview: [String] = [],
            hiddenCategoryCount: Int = 0,
            placePreview: [String] = [],
            hiddenPlaceCount: Int = 0,
            previewGroups: [PreviewGroup]? = nil
        ) {
            self.name = name
            self.iconID = iconID
            self.itemCount = itemCount
            self.isMissingLocation = isMissingLocation
            self.categoryPreview = categoryPreview
            self.hiddenCategoryCount = hiddenCategoryCount
            self.placePreview = placePreview
            self.hiddenPlaceCount = hiddenPlaceCount
            self.previewGroups = previewGroups ?? Self.previewGroups(
                categoryPreview: categoryPreview,
                hiddenCategoryCount: hiddenCategoryCount,
                placePreview: placePreview,
                hiddenPlaceCount: hiddenPlaceCount
            )
        }
    }

    struct PlaceSummary: Equatable, Identifiable {
        struct CategorySummary: Equatable, Identifiable {
            /// The normalized persistence value used for deterministic ordering and icon lookup.
            let storageIdentity: String
            let displayName: String
            let itemCount: Int

            var id: String { storageIdentity }
        }

        let id: String
        /// Stable identity when this summary represents one reusable Place.
        let placeID: UUID?
        let name: String
        let itemCount: Int
        let locationID: String
        let locationName: String
        let isMissingLocation: Bool
        let isMissingPlace: Bool
        let categoryPreview: [String]
        let hiddenCategoryCount: Int
        /// The complete ranked category list for Place-row adaptive presentation.
        let categorySummaries: [CategorySummary]
        let previewGroups: [PreviewGroup]

        init(
            id: String,
            placeID: UUID? = nil,
            name: String,
            itemCount: Int,
            locationID: String,
            locationName: String,
            isMissingLocation: Bool,
            isMissingPlace: Bool,
            categoryPreview: [String] = [],
            hiddenCategoryCount: Int = 0,
            categorySummaries: [CategorySummary] = [],
            previewGroups: [PreviewGroup]? = nil
        ) {
            self.id = id
            self.placeID = placeID
            self.name = name
            self.itemCount = itemCount
            self.locationID = locationID
            self.locationName = locationName
            self.isMissingLocation = isMissingLocation
            self.isMissingPlace = isMissingPlace
            self.categoryPreview = categoryPreview
            self.hiddenCategoryCount = hiddenCategoryCount
            self.categorySummaries = categorySummaries
            self.previewGroups = previewGroups ?? Self.previewGroups(
                categoryPreview: categoryPreview,
                hiddenCategoryCount: hiddenCategoryCount
            )
        }
    }
}
