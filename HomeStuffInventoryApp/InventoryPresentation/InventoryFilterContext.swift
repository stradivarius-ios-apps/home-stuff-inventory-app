import Foundation

struct InventoryFilterContext: Equatable {
    enum ClearAction: Equatable {
        case search
        case filters
        case searchAndFilters
    }

    let resultCount: Int
    let searchText: String?
    let category: String?
    let locationName: String?
    let place: InventorySearch.PlaceFilter?

    init(
        resultCount: Int,
        searchText: String,
        category: String?,
        locationName: String?,
        place: InventorySearch.PlaceFilter? = nil
    ) {
        self.resultCount = resultCount
        self.searchText = Self.normalizedValue(searchText)
        self.category = Self.normalizedValue(category)
        self.locationName = Self.normalizedValue(locationName)
        self.place = place
    }

    var isActive: Bool {
        searchText != nil || category != nil || locationName != nil || place != nil
    }

    var clearAction: ClearAction? {
        switch (searchText != nil, category != nil || locationName != nil || place != nil) {
        case (true, true):
            .searchAndFilters
        case (true, false):
            .search
        case (false, true):
            .filters
        case (false, false):
            nil
        }
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalizedValue.isEmpty
        else {
            return nil
        }

        return normalizedValue
    }
}
