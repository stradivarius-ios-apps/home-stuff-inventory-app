import Foundation

extension InventoryBrowseSummaries {
    static func commonContainerNames(
        from items: [InventoryItem],
        placeOpenRecords: [InventoryPlaceOpenRecord] = [],
        limit: Int = 3,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> LabelPreview {
        let popularityByIdentity = placePopularityByIdentity(placeOpenRecords)
        let places = Dictionary(grouping: items) {
            InventoryNormalizedName.place($0.containerName, vocabulary: vocabulary)
        }
        let rankedPlaces = places
            .filter { !$0.key.isMissing }
            .map { place, placeItems in
                PlacePreview(
                    name: place.displayName,
                    itemCount: placeItems.count,
                    identity: InventoryPlaceIdentity.make(for: placeItems[0]).rawValue,
                    popularity: popularityByIdentity[InventoryPlaceIdentity.make(for: placeItems[0]).rawValue]
                )
            }
            .sorted(by: sortedPlacePreviews)

        return LabelPreview(
            visibleItems: rankedPlaces.prefix(limit).map { place in
                PreviewItem(id: place.name, title: place.name)
            },
            hiddenCount: max(0, rankedPlaces.count - limit)
        )
    }

    static func commonCategories(
        from items: [InventoryItem],
        limit: Int = 3,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> LabelPreview {
        topLabels(from: items, limit: limit) { item in
            vocabulary.categoryName(forStoredValue: item.category)
        }
    }

    /// Keeps Place-card data independent from the limited Location-card category preview.
    static func placeCategorySummaries(
        from items: [InventoryItem],
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [PlaceSummary.CategorySummary] {
        Dictionary(grouping: items, by: categoryStorageIdentity(for:))
            .filter { !$0.key.isEmpty }
            .map { storageIdentity, categoryItems in
                PlaceSummary.CategorySummary(
                    storageIdentity: storageIdentity,
                    displayName: vocabulary.categoryName(forStoredValue: storageIdentity),
                    itemCount: categoryItems.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.itemCount != rhs.itemCount {
                    return lhs.itemCount > rhs.itemCount
                }

                let nameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                return lhs.storageIdentity < rhs.storageIdentity
            }
    }

    static func recentItems(
        from items: [InventoryItem],
        events: [InventoryItemViewEvent],
        now: Date,
        rollingWindow: TimeInterval,
        limit: Int = 3
    ) -> LabelPreview {
        let rankedItems = InventoryRecentItemViews.topItems(
            from: items,
            events: events,
            now: now,
            rollingWindow: rollingWindow,
            limit: .max
        )

        return LabelPreview(
            visibleItems: rankedItems.prefix(limit).map { item in
                PreviewItem(id: item.id.uuidString, title: item.name)
            },
            hiddenCount: max(0, rankedItems.count - limit)
        )
    }

    private static func topLabels(
        from items: [InventoryItem],
        limit: Int,
        label: (InventoryItem) -> String
    ) -> LabelPreview {
        let groupedLabels = Dictionary(grouping: items, by: label)

        let sortedLabels = groupedLabels
            .filter { !$0.key.isEmpty }
            .sorted { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }

                return lhs.value.count > rhs.value.count
            }
            .map(\.key)

        return LabelPreview(
            visibleItems: sortedLabels.prefix(limit).map { label in
                PreviewItem(id: label, title: label)
            },
            hiddenCount: max(0, sortedLabels.count - limit)
        )
    }

    private static func categoryStorageIdentity(for item: InventoryItem) -> String {
        InventoryCategory.storageValue(from: item.category)
    }

    private static func placePopularityByIdentity(
        _ records: [InventoryPlaceOpenRecord]
    ) -> [String: PlacePopularity] {
        Dictionary(grouping: records.filter { $0.openCount > 0 }, by: \.placeIdentity)
            .mapValues { records in
                PlacePopularity(
                    openCount: records.reduce(0) { InventoryPlaceOpenPersistence.saturatedAdd($0, $1.openCount) },
                    lastOpenedAt: records.map(\.lastOpenedAt).max() ?? .distantPast
                )
            }
    }

    private static func sortedPlacePreviews(_ lhs: PlacePreview, _ rhs: PlacePreview) -> Bool {
        let lhsOpenCount = lhs.popularity?.openCount ?? 0
        let rhsOpenCount = rhs.popularity?.openCount ?? 0
        if lhsOpenCount != rhsOpenCount { return lhsOpenCount > rhsOpenCount }

        let lhsLastOpenedAt = lhs.popularity?.lastOpenedAt ?? .distantPast
        let rhsLastOpenedAt = rhs.popularity?.lastOpenedAt ?? .distantPast
        if lhsLastOpenedAt != rhsLastOpenedAt { return lhsLastOpenedAt > rhsLastOpenedAt }

        if lhs.itemCount != rhs.itemCount { return lhs.itemCount > rhs.itemCount }

        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameComparison != .orderedSame { return nameComparison == .orderedAscending }

        return lhs.identity < rhs.identity
    }

    static func previewGroups(
        categoryPreview: LabelPreview,
        placePreview: LabelPreview,
        recentItemPreview: LabelPreview
    ) -> [PreviewGroup] {
        [
            previewGroup(kind: .category, preview: categoryPreview),
            previewGroup(kind: .place, preview: placePreview),
            previewGroup(kind: .recentItem, preview: recentItemPreview)
        ].compactMap { $0 }
    }

    static func placePreviewGroups(
        categoryPreview: LabelPreview,
        recentItemPreview: LabelPreview
    ) -> [PreviewGroup] {
        [
            previewGroup(kind: .category, preview: categoryPreview),
            previewGroup(kind: .recentItem, preview: recentItemPreview)
        ].compactMap { $0 }
    }

    private static func previewGroup(kind: PreviewGroup.Kind, preview: LabelPreview) -> PreviewGroup? {
        guard !preview.visibleItems.isEmpty else {
            return nil
        }

        return PreviewGroup(kind: kind, visibleItems: preview.visibleItems, hiddenCount: preview.hiddenCount)
    }
}

private extension InventoryBrowseSummaries {
    struct PlacePreview {
        let name: String
        let itemCount: Int
        let identity: String
        let popularity: PlacePopularity?
    }

    struct PlacePopularity {
        let openCount: Int
        let lastOpenedAt: Date
    }
}

struct LabelPreview {
    let visibleItems: [InventoryBrowseSummaries.PreviewItem]
    let hiddenCount: Int

    var visibleNames: [String] {
        visibleItems.map(\.title)
    }
}

extension InventoryBrowseSummaries.LocationSummary {
    static func previewGroups(
        categoryPreview: [String],
        hiddenCategoryCount: Int,
        placePreview: [String],
        hiddenPlaceCount: Int
    ) -> [InventoryBrowseSummaries.PreviewGroup] {
        [
            InventoryBrowseSummaries.previewGroup(
                kind: .category,
                preview: LabelPreview(
                    visibleItems: categoryPreview.map { .init(id: $0, title: $0) },
                    hiddenCount: hiddenCategoryCount
                )
            ),
            InventoryBrowseSummaries.previewGroup(
                kind: .place,
                preview: LabelPreview(
                    visibleItems: placePreview.map { .init(id: $0, title: $0) },
                    hiddenCount: hiddenPlaceCount
                )
            )
        ].compactMap { $0 }
    }
}

extension InventoryBrowseSummaries.PlaceSummary {
    static func previewGroups(
        categoryPreview: [String],
        hiddenCategoryCount: Int
    ) -> [InventoryBrowseSummaries.PreviewGroup] {
        [
            InventoryBrowseSummaries.previewGroup(
                kind: .category,
                preview: LabelPreview(
                    visibleItems: categoryPreview.map { .init(id: $0, title: $0) },
                    hiddenCount: hiddenCategoryCount
                )
            )
        ].compactMap { $0 }
    }
}
