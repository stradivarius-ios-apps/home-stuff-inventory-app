import Foundation

enum InventoryBrowseSummaries {
    static let placeDetailRecentItemsMinimumItemCount = 5

    static func locationSummaries(
        from items: [InventoryItem],
        storageLocations: [StorageLocation] = [],
        recentViewEvents: [InventoryItemViewEvent] = [],
        placeOpenRecords: [InventoryPlaceOpenRecord] = [],
        now: Date = .now,
        rollingWindow: TimeInterval = InventoryRecentItemViews.defaultRollingWindow,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [LocationSummary] {
        let groupedItems = Dictionary(grouping: items) { normalizedLocationName(for: $0, vocabulary: vocabulary) }
        let reusableLocations = reusableLocationsByName(storageLocations)
        let namedLocationNames = Set(groupedItems.keys.filter { !$0.isMissing })
            .union(reusableLocations.values.map { normalizedLocationName($0.name, vocabulary: vocabulary) })

        let namedSummaries: [LocationSummary] = namedLocationNames
            .map { location in
                let items = groupedItems[location] ?? []
                let reusableLocation = reusableLocations[location.comparisonKey]
                let categoryPreview = commonCategories(from: items, vocabulary: vocabulary)
                let placePreview = commonContainerNames(
                    from: items,
                    placeOpenRecords: placeOpenRecords,
                    vocabulary: vocabulary
                )
                let recentPreview = recentItems(
                    from: items,
                    events: recentViewEvents,
                    now: now,
                    rollingWindow: rollingWindow
                )

                return LocationSummary(
                    name: reusableLocation?.name ?? location.displayName,
                    iconID: reusableLocation.flatMap { LocationIconCatalog.normalizedIconID($0.iconID) },
                    itemCount: items.count,
                    isMissingLocation: false,
                    categoryPreview: categoryPreview.visibleNames,
                    hiddenCategoryCount: categoryPreview.hiddenCount,
                    placePreview: placePreview.visibleNames,
                    hiddenPlaceCount: placePreview.hiddenCount,
                    previewGroups: previewGroups(
                        categoryPreview: categoryPreview,
                        placePreview: placePreview,
                        recentItemPreview: recentPreview
                    )
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        guard let missingLocationItems = groupedItems[.missingLocation(vocabulary: vocabulary)] else {
            return namedSummaries
        }

        let missingPlacePreview = commonContainerNames(
            from: missingLocationItems,
            placeOpenRecords: placeOpenRecords,
            vocabulary: vocabulary
        )
        let missingCategoryPreview = commonCategories(from: missingLocationItems, vocabulary: vocabulary)
        let missingRecentPreview = recentItems(
            from: missingLocationItems,
            events: recentViewEvents,
            now: now,
            rollingWindow: rollingWindow
        )

        return namedSummaries + [
            LocationSummary(
                name: vocabulary.missingLocationName,
                itemCount: missingLocationItems.count,
                isMissingLocation: true,
                categoryPreview: missingCategoryPreview.visibleNames,
                hiddenCategoryCount: missingCategoryPreview.hiddenCount,
                placePreview: missingPlacePreview.visibleNames,
                hiddenPlaceCount: missingPlacePreview.hiddenCount,
                previewGroups: previewGroups(
                    categoryPreview: missingCategoryPreview,
                    placePreview: missingPlacePreview,
                    recentItemPreview: missingRecentPreview
                )
            )
        ]
    }

    static func hasLocationsRootContent(
        items: [InventoryItem],
        storageLocations: [StorageLocation]
    ) -> Bool {
        !items.isEmpty || storageLocations.contains {
            !InventoryNormalizedName.location($0.name).isMissing
        }
    }

    static func items(
        in items: [InventoryItem],
        matching location: LocationSummary,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [InventoryItem] {
        items.filter { item in
            normalizedLocationName(for: item, vocabulary: vocabulary).matches(name: location.name, isMissing: location.isMissingLocation)
        }
    }

    static func placeSummaries(
        in items: [InventoryItem],
        matching location: LocationSummary,
        recentViewEvents: [InventoryItemViewEvent] = [],
        now: Date = .now,
        rollingWindow: TimeInterval = InventoryRecentItemViews.defaultRollingWindow,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [PlaceSummary] {
        let locationItems = self.items(in: items, matching: location, vocabulary: vocabulary)
        let groupedItems = Dictionary(grouping: locationItems) { normalizedPlaceName(for: $0, vocabulary: vocabulary) }

        let namedSummaries: [PlaceSummary] = groupedItems
            .filter { !$0.key.isMissing }
            .map { entry in
                placeSummary(
                    for: entry.key,
                    location: location,
                    items: entry.value,
                    recentViewEvents: recentViewEvents,
                    now: now,
                    rollingWindow: rollingWindow,
                    vocabulary: vocabulary
                )
            }
            .sorted(by: sortedPlaceSummaries)

        guard let missingPlaceItems = groupedItems[.missingPlace(vocabulary: vocabulary)] else {
            return namedSummaries
        }

        return namedSummaries + [
            placeSummary(
                for: .missingPlace(vocabulary: vocabulary),
                location: location,
                items: missingPlaceItems,
                recentViewEvents: recentViewEvents,
                now: now,
                rollingWindow: rollingWindow,
                vocabulary: vocabulary
            )
        ]
    }

    static func placeDetailSummary(
        in items: [InventoryItem],
        matching place: PlaceSummary,
        recentViewEvents: [InventoryItemViewEvent] = [],
        now: Date = .now,
        rollingWindow: TimeInterval = InventoryRecentItemViews.defaultRollingWindow,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> PlaceSummary {
        let placeItems = self.items(in: items, matching: place, vocabulary: vocabulary)
        let normalizedPlace = place.isMissingPlace
            ? InventoryNormalizedName.missingPlace(vocabulary: vocabulary)
            : normalizedPlaceName(place.name, vocabulary: vocabulary)
        let categoryPreview = commonCategories(from: placeItems, vocabulary: vocabulary)
        let categorySummaries = placeCategorySummaries(from: placeItems, vocabulary: vocabulary)
        let recentPreview = recentItems(
            from: placeItems,
            events: recentViewEvents,
            now: now,
            rollingWindow: rollingWindow
        )

        return PlaceSummary(
            id: place.id,
            placeID: place.placeID,
            name: normalizedPlace.displayName,
            itemCount: placeItems.count,
            locationID: place.locationID,
            locationName: place.locationName,
            isMissingLocation: place.isMissingLocation,
            isMissingPlace: place.isMissingPlace,
            categoryPreview: categoryPreview.visibleNames,
            hiddenCategoryCount: categoryPreview.hiddenCount,
            categorySummaries: categorySummaries,
            previewGroups: placePreviewGroups(
                categoryPreview: categoryPreview,
                recentItemPreview: placeItems.count >= placeDetailRecentItemsMinimumItemCount
                    ? recentPreview
                    : LabelPreview(visibleItems: [], hiddenCount: 0)
            )
        )
    }

    static func items(
        in items: [InventoryItem],
        matching place: PlaceSummary,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [InventoryItem] {
        items.filter { item in
            if let placeID = place.placeID {
                // Legacy Items remain visible with their linked Place while the form offers
                // an explicit migration choice; never include another linked Place by text.
                if item.placeID == placeID { return true }
                guard item.placeID == nil else { return false }
            }
            return normalizedLocationName(for: item, vocabulary: vocabulary).matches(name: place.locationName, isMissing: place.isMissingLocation)
                && normalizedPlaceName(for: item, vocabulary: vocabulary).matches(name: place.name, isMissing: place.isMissingPlace)
        }
    }

    private static func normalizedLocationName(
        for item: InventoryItem,
        vocabulary: InventoryBrowseVocabulary
    ) -> InventoryNormalizedName {
        normalizedLocationName(item.locationName, vocabulary: vocabulary)
    }

    private static func normalizedLocationName(
        _ value: String,
        vocabulary: InventoryBrowseVocabulary
    ) -> InventoryNormalizedName {
        InventoryNormalizedName.location(value, vocabulary: vocabulary)
    }

    private static func normalizedPlaceName(
        for item: InventoryItem,
        vocabulary: InventoryBrowseVocabulary
    ) -> InventoryNormalizedName {
        normalizedPlaceName(item.containerName, vocabulary: vocabulary)
    }

    private static func normalizedPlaceName(
        _ value: String?,
        vocabulary: InventoryBrowseVocabulary
    ) -> InventoryNormalizedName {
        InventoryNormalizedName.place(value, vocabulary: vocabulary)
    }

    private static func reusableLocationsByName(_ locations: [StorageLocation]) -> [String: StorageLocation] {
        locations
            .sorted(by: sortedReusableLocations)
            .reduce(into: [:]) { result, location in
            let normalizedName = normalizedLocationName(location.name, vocabulary: .default)

            guard !normalizedName.isMissing else {
                return
            }

            result[normalizedName.comparisonKey] = result[normalizedName.comparisonKey] ?? location
        }
    }

    private static func sortedReusableLocations(_ lhs: StorageLocation, _ rhs: StorageLocation) -> Bool {
        let localizedComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)

        if localizedComparison != .orderedSame {
            return localizedComparison == .orderedAscending
        }

        return lhs.name < rhs.name
    }

    private static func sortedPlaceSummaries(_ lhs: PlaceSummary, _ rhs: PlaceSummary) -> Bool {
        if lhs.itemCount == rhs.itemCount {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return lhs.itemCount > rhs.itemCount
    }

    private static func placeSummary(
        for place: InventoryNormalizedName,
        location: LocationSummary,
        items: [InventoryItem],
        recentViewEvents: [InventoryItemViewEvent],
        now: Date,
        rollingWindow: TimeInterval,
        vocabulary: InventoryBrowseVocabulary
    ) -> PlaceSummary {
        let categoryPreview = commonCategories(from: items, vocabulary: vocabulary)
        let categorySummaries = placeCategorySummaries(from: items, vocabulary: vocabulary)
        let recentPreview = recentItems(
            from: items,
            events: recentViewEvents,
            now: now,
            rollingWindow: rollingWindow
        )

        return PlaceSummary(
            id: placeSummaryID(locationID: location.id, place: place),
            placeID: stablePlaceID(in: items),
            name: place.displayName,
            itemCount: items.count,
            locationID: location.id,
            locationName: location.name,
            isMissingLocation: location.isMissingLocation,
            isMissingPlace: place.isMissing,
            categoryPreview: categoryPreview.visibleNames,
            hiddenCategoryCount: categoryPreview.hiddenCount,
            categorySummaries: categorySummaries,
            previewGroups: placePreviewGroups(
                categoryPreview: categoryPreview,
                recentItemPreview: recentPreview
            )
        )
    }

    private static func placeSummaryID(locationID: String, place: InventoryNormalizedName) -> String {
        "\(locationID)::\(place.comparisonKey)"
    }

    private static func stablePlaceID(in items: [InventoryItem]) -> UUID? {
        let ids = Set(items.compactMap(\.placeID))
        return ids.count == 1 ? ids.first : nil
    }
}
