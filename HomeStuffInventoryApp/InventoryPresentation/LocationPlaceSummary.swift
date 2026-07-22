import Foundation

struct PlaceCategoryRowPresentation: Equatable {
    let visibleCategories: [InventoryBrowseSummaries.PlaceSummary.CategorySummary]
    let hiddenCategoryCount: Int

    init(
        categories: [InventoryBrowseSummaries.PlaceSummary.CategorySummary],
        visibleCount: Int
    ) {
        let limit = min(max(0, visibleCount), categories.count)
        visibleCategories = Array(categories.prefix(limit))
        hiddenCategoryCount = max(0, categories.count - limit)
    }

    var overflowText: String? {
        guard hiddenCategoryCount > 0 else { return nil }
        return InventoryLocalization.formatted(
            "locations.categoryPreview.overflow",
            defaultValue: "+%d",
            hiddenCategoryCount
        )
    }

    var accessibilityOverflowText: String? {
        guard hiddenCategoryCount > 0 else { return nil }
        return InventoryLocalization.categoryOverflowLabel(hiddenCategoryCount)
    }
}

struct PlaceCategoryEntryPresentation: Equatable, Identifiable {
    let category: InventoryBrowseSummaries.PlaceSummary.CategorySummary
    let symbolName: String

    var id: String { category.id }
    var displayName: String { category.displayName }

    init(category: InventoryBrowseSummaries.PlaceSummary.CategorySummary) {
        self.category = category

        guard let builtInCategory = InventoryCategory(storedValue: category.storageIdentity),
              builtInCategory != .miscellaneous,
              let iconID = ItemIconCatalog.defaultIconID(forCategory: builtInCategory.rawValue)
        else {
            symbolName = "tag"
            return
        }

        symbolName = ItemIconCatalog.symbolName(for: iconID)
    }
}

struct LocationPlaceSummary: Equatable {
    let placeCount: Int
    let placeCountText: String
    let visibleText: String
    let overflowText: String?
    let text: String?

    init(places: [String], hiddenPlaceCount: Int = 0, visibleCount: Int = 2) {
        let cleanPlaces = places
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        placeCount = cleanPlaces.count + max(0, hiddenPlaceCount)
        placeCountText = InventoryLocalization.placeCount(placeCount)

        guard !cleanPlaces.isEmpty else {
            visibleText = ""
            overflowText = nil
            text = placeCountText
            return
        }

        let visiblePlaces = cleanPlaces.prefix(max(1, visibleCount))
        let remainingCount = cleanPlaces.count - visiblePlaces.count + max(0, hiddenPlaceCount)
        visibleText = visiblePlaces.joined(separator: ", ")

        if remainingCount > 0 {
            overflowText = InventoryLocalization.formatted(
                "locations.categoryPreview.overflow",
                defaultValue: "+%d",
                remainingCount
            )
            text = "\(placeCountText) · \(visibleText) \(overflowText ?? "")"
        } else {
            overflowText = nil
            text = "\(placeCountText) · \(visibleText)"
        }
    }
}

struct LocationCategorySummary: Equatable {
    let visibleText: String
    let overflowText: String?
    let text: String?

    init(
        categories: [String],
        hiddenCategoryCount: Int = 0,
        visibleCount: Int = 3,
        maxVisibleCharacters: Int = 32
    ) {
        let cleanCategories = categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanCategories.isEmpty else {
            visibleText = ""
            overflowText = nil
            text = nil
            return
        }

        let visibleLimit = max(1, visibleCount)
        let characterLimit = max(1, maxVisibleCharacters)
        var visibleCategories: [String] = []
        var hiddenByLengthCount = 0

        for category in cleanCategories {
            guard visibleCategories.count < visibleLimit else {
                hiddenByLengthCount += 1
                continue
            }

            guard !visibleCategories.isEmpty else {
                visibleCategories.append(category)
                continue
            }

            let candidateText = (visibleCategories + [category]).joined(separator: " · ")

            guard candidateText.count <= characterLimit else {
                hiddenByLengthCount = cleanCategories.count - visibleCategories.count
                break
            }

            visibleCategories.append(category)
        }

        let remainingCount = hiddenByLengthCount + max(0, hiddenCategoryCount)
        visibleText = visibleCategories.joined(separator: " · ")

        if remainingCount > 0 {
            overflowText = InventoryLocalization.formatted(
                "locations.categoryPreview.overflow",
                defaultValue: "+%d",
                remainingCount
            )
            text = "\(visibleText) \(overflowText ?? "")"
        } else {
            overflowText = nil
            text = visibleText
        }
    }
}

struct InventoryPreviewGroupPresentation: Equatable, Identifiable {
    struct Chip: Equatable, Identifiable {
        let id: String
        let title: String
        let isOverflow: Bool
    }

    let id: String
    let kind: InventoryBrowseSummaries.PreviewGroup.Kind
    let label: String
    let systemImage: String
    let visibleChips: [Chip]
    let overflowChip: Chip?
    let visibleValueText: String
    let accessibilityText: String

    var chips: [Chip] {
        visibleChips + [overflowChip].compactMap { $0 }
    }

    var compactSummaryText: String {
        [visibleValueText, overflowChip?.title]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    init?(_ group: InventoryBrowseSummaries.PreviewGroup) {
        let visibleLimit = group.kind.visibleLimit
        let cleanItems = group.visibleItems.compactMap { item -> Chip? in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                return nil
            }

            return Chip(id: item.id, title: title, isOverflow: false)
        }

        let visibleChips = Array(cleanItems.prefix(visibleLimit))
        guard !visibleChips.isEmpty else {
            return nil
        }

        let hiddenCount = max(0, cleanItems.count - visibleChips.count) + max(0, group.hiddenCount)
        let overflowText = hiddenCount > 0
            ? InventoryLocalization.formatted("locations.categoryPreview.overflow", defaultValue: "+%d", hiddenCount)
            : nil
        let visibleText = visibleChips.map(\.title).joined(separator: ", ")

        id = group.id
        self.kind = group.kind
        label = InventoryLocalization.string(group.kind.labelKey, defaultValue: group.kind.labelDefaultValue)
        systemImage = group.kind.systemImage
        self.visibleChips = visibleChips
        overflowChip = overflowText.map {
            Chip(id: "\(group.id).overflow", title: $0, isOverflow: true)
        }
        visibleValueText = visibleText

        if hiddenCount > 0 {
            accessibilityText = InventoryLocalization.formatted(
                group.kind.accessibilityTextWithHiddenCountKey,
                defaultValue: group.kind.accessibilityTextWithHiddenCountDefaultValue,
                visibleText,
                hiddenCount
            )
        } else {
            accessibilityText = InventoryLocalization.formatted(
                group.kind.accessibilityTextKey,
                defaultValue: group.kind.accessibilityTextDefaultValue,
                visibleText
            )
        }
    }
}

extension InventoryBrowseSummaries.PreviewGroup.Kind {
    var visibleLimit: Int {
        switch self {
        case .category, .place:
            return 2
        case .recentItem:
            return 3
        }
    }

    var labelKey: StaticString {
        switch self {
        case .category:
            return "locations.previewGroup.categories.label"
        case .place:
            return "locations.previewGroup.places.label"
        case .recentItem:
            return "locations.previewGroup.recentItems.label"
        }
    }

    var labelDefaultValue: String {
        switch self {
        case .category:
            return "Categories"
        case .place:
            return "Storage Places"
        case .recentItem:
            return "Recent"
        }
    }

    var systemImage: String {
        switch self {
        case .category:
            return "tag"
        case .place:
            return "shippingbox"
        case .recentItem:
            return "clock"
        }
    }

    var accessibilityTextKey: StaticString {
        switch self {
        case .category:
            return "locations.previewGroup.categories.accessibilityText"
        case .place:
            return "locations.previewGroup.places.accessibilityText"
        case .recentItem:
            return "locations.previewGroup.recentItems.accessibilityText"
        }
    }

    var accessibilityTextDefaultValue: String {
        switch self {
        case .category:
            return "categories: %@"
        case .place:
            return "storage places: %@"
        case .recentItem:
            return "recently viewed items: %@"
        }
    }

    var accessibilityTextWithHiddenCountKey: StaticString {
        switch self {
        case .category:
            return "locations.previewGroup.categories.accessibilityTextWithHiddenCount"
        case .place:
            return "locations.previewGroup.places.accessibilityTextWithHiddenCount"
        case .recentItem:
            return "locations.previewGroup.recentItems.accessibilityTextWithHiddenCount"
        }
    }

    var accessibilityTextWithHiddenCountDefaultValue: String {
        switch self {
        case .category:
            return "categories: %@, %d more"
        case .place:
            return "storage places: %@, %d more"
        case .recentItem:
            return "recently viewed items: %@, %d more"
        }
    }
}
