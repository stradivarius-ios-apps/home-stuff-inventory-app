import Foundation

enum InventorySearch {
    typealias LocationSummary = InventoryBrowseSummaries.LocationSummary
    typealias PlaceSummary = InventoryBrowseSummaries.PlaceSummary

    struct Result: Identifiable {
        let item: InventoryItem
        let score: Int
        let matchContext: MatchContext?

        var id: UUID { item.id }
    }

    struct MatchContext: Equatable {
        let matchedTag: String?
        let matchedInNotes: Bool

        var isEmpty: Bool {
            matchedTag == nil && !matchedInNotes
        }
    }

    struct Filters: Equatable {
        var category: String? = nil
        var locationName: String? = nil
        var place: PlaceFilter? = nil

        var hasActiveFilters: Bool {
            normalizedCategory != nil || normalizedLocationName != nil || place != nil
        }

        fileprivate var normalizedCategory: String? {
            Self.normalizedFilterValue(category)
        }

        fileprivate var normalizedLocationName: String? {
            Self.normalizedFilterValue(locationName)
        }

        private static func normalizedFilterValue(_ value: String?) -> String? {
            guard let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !normalizedValue.isEmpty
            else {
                return nil
            }

            return normalizedValue
        }
    }

    enum PlaceFilter: Hashable {
        case named(String)
        case missing

        func displayName(vocabulary: InventoryBrowseVocabulary) -> String {
            switch self {
            case let .named(name): name
            case .missing: vocabulary.missingPlaceName
            }
        }
    }

    static func matchingItems(
        in items: [InventoryItem],
        query: String,
        filters: Filters = Filters(),
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [InventoryItem] {
        matchingResults(in: items, query: query, filters: filters, vocabulary: vocabulary).map(\.item)
    }

    static func matchingResults(
        in items: [InventoryItem],
        query: String,
        filters: Filters = Filters(),
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [Result] {
        let normalizedQuery = InventorySearchNormalization.normalize(query)
        let filteredItems = items.filter {
            matchesCategory($0, category: filters.normalizedCategory)
                && matchesLocation($0, locationName: filters.normalizedLocationName, vocabulary: vocabulary)
                && matchesPlace($0, place: filters.place, vocabulary: vocabulary)
        }

        guard !normalizedQuery.tokens.isEmpty else {
            return filteredItems
                .sorted(by: alphabeticalItemOrder)
                .map { Result(item: $0, score: 0, matchContext: nil) }
        }

        return filteredItems.compactMap { item in
            result(for: item, normalizedQuery: normalizedQuery, vocabulary: vocabulary)
        }
        .sorted(by: rankedItemOrder)
    }

    static func availableCategories(
        from items: [InventoryItem],
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [String] {
        sortedUniqueValues(
            InventoryCategory.allCases.map(vocabulary.categoryName)
                + items.map { displayCategory(for: $0, vocabulary: vocabulary) }
        )
    }

    static func availableLocations(
        from items: [InventoryItem],
        storageLocations: [StorageLocation] = [],
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [String] {
        let optionNames = items.map(\.locationName) + storageLocations.map(\.name)
        let hasMissingLocation = items.contains { normalizedLocationName(for: $0, vocabulary: vocabulary).isMissingLocation }

        guard hasMissingLocation else {
            return sortedUniqueValues(optionNames)
        }

        return sortedUniqueValues(optionNames + [vocabulary.missingLocationName])
    }

    static func availablePlaces(
        from items: [InventoryItem],
        locationName: String? = nil,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [PlaceFilter] {
        let location = Filters(locationName: locationName).normalizedLocationName
        let scopedItems = items.filter {
            matchesLocation($0, locationName: location, vocabulary: vocabulary)
        }
        var namedPlaces: [String: String] = [:]
        var includesMissingPlace = false

        for item in scopedItems {
            let normalizedName = InventoryNormalizedName.place(item.containerName, vocabulary: vocabulary)
            if normalizedName.isMissing {
                includesMissingPlace = true
            } else if namedPlaces[normalizedName.comparisonKey] == nil {
                namedPlaces[normalizedName.comparisonKey] = normalizedName.displayName
            }
        }

        var options = namedPlaces.values
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map(PlaceFilter.named)
        if includesMissingPlace {
            options.append(.missing)
        }
        return options.sorted {
            $0.displayName(vocabulary: vocabulary)
                .localizedCaseInsensitiveCompare($1.displayName(vocabulary: vocabulary)) == .orderedAscending
        }
    }

    static func reconciledPlaceSelection(
        _ selection: PlaceFilter?,
        availablePlaces: [PlaceFilter]
    ) -> PlaceFilter? {
        guard let selection else { return nil }
        switch selection {
        case .missing:
            return availablePlaces.contains(.missing) ? .missing : nil
        case let .named(name):
            return availablePlaces.first {
                guard case let .named(candidate) = $0 else { return false }
                return InventoryNormalizedName.place(candidate) == InventoryNormalizedName.place(name)
            }
        }
    }

    static func locationSummaries(
        from items: [InventoryItem],
        storageLocations: [StorageLocation] = [],
        recentViewEvents: [InventoryItemViewEvent] = [],
        now: Date = .now,
        rollingWindow: TimeInterval = InventoryRecentItemViews.defaultRollingWindow,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [LocationSummary] {
        InventoryBrowseSummaries.locationSummaries(
            from: items,
            storageLocations: storageLocations,
            recentViewEvents: recentViewEvents,
            now: now,
            rollingWindow: rollingWindow,
            vocabulary: vocabulary
        )
    }

    static func items(
        in items: [InventoryItem],
        matching location: LocationSummary,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [InventoryItem] {
        InventoryBrowseSummaries.items(in: items, matching: location, vocabulary: vocabulary)
    }

    static func placeSummaries(
        in items: [InventoryItem],
        matching location: LocationSummary,
        recentViewEvents: [InventoryItemViewEvent] = [],
        now: Date = .now,
        rollingWindow: TimeInterval = InventoryRecentItemViews.defaultRollingWindow,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [PlaceSummary] {
        InventoryBrowseSummaries.placeSummaries(
            in: items,
            matching: location,
            recentViewEvents: recentViewEvents,
            now: now,
            rollingWindow: rollingWindow,
            vocabulary: vocabulary
        )
    }

    static func placeDetailSummary(
        in items: [InventoryItem],
        matching place: PlaceSummary,
        recentViewEvents: [InventoryItemViewEvent] = [],
        now: Date = .now,
        rollingWindow: TimeInterval = InventoryRecentItemViews.defaultRollingWindow,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> PlaceSummary {
        InventoryBrowseSummaries.placeDetailSummary(
            in: items,
            matching: place,
            recentViewEvents: recentViewEvents,
            now: now,
            rollingWindow: rollingWindow,
            vocabulary: vocabulary
        )
    }

    static func items(
        in items: [InventoryItem],
        matching place: PlaceSummary,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> [InventoryItem] {
        InventoryBrowseSummaries.items(in: items, matching: place, vocabulary: vocabulary)
    }

    private static func matchesCategory(_ item: InventoryItem, category: String?) -> Bool {
        guard let category else {
            return true
        }

        if let selectedCategory = InventoryCategory.resolveBuiltInCategory(from: category) {
            return InventoryCategory.resolveBuiltInCategory(from: item.category) == selectedCategory
        }

        return item.category.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(category) == .orderedSame
    }

    private static func matchesLocation(
        _ item: InventoryItem,
        locationName: String?,
        vocabulary: InventoryBrowseVocabulary
    ) -> Bool {
        guard let locationName else {
            return true
        }

        return searchableLocationName(for: item, vocabulary: vocabulary)
            .localizedCaseInsensitiveCompare(locationName) == .orderedSame
    }

    private static func matchesPlace(
        _ item: InventoryItem,
        place: PlaceFilter?,
        vocabulary: InventoryBrowseVocabulary
    ) -> Bool {
        guard let place else { return true }
        let itemPlace = InventoryNormalizedName.place(item.containerName, vocabulary: vocabulary)
        switch place {
        case .missing:
            return itemPlace.isMissing
        case let .named(name):
            return itemPlace.matches(name: name, isMissing: false)
        }
    }

    fileprivate static func displayCategory(
        for item: InventoryItem,
        vocabulary: InventoryBrowseVocabulary
    ) -> String {
        vocabulary.categoryName(forStoredValue: item.category)
    }

    fileprivate static func searchableLocationName(
        for item: InventoryItem,
        vocabulary: InventoryBrowseVocabulary
    ) -> String {
        normalizedLocationName(for: item, vocabulary: vocabulary).displayName
    }

    fileprivate static func searchableContainerName(
        for item: InventoryItem,
        vocabulary: InventoryBrowseVocabulary
    ) -> String {
        guard let containerName = item.containerName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !containerName.isEmpty
        else {
            return vocabulary.missingPlaceName
        }

        return containerName
    }

    private static func result(
        for item: InventoryItem,
        normalizedQuery: InventorySearchNormalization.Query,
        vocabulary: InventoryBrowseVocabulary
    ) -> Result? {
        let fields = SearchableFields(item: item, vocabulary: vocabulary)
        var score = 0
        var matchedTag: String?
        var matchedInNotes = false

        for token in normalizedQuery.tokens {
            let matchingFields = fields.matchingFields(for: token)
            guard let strongestField = matchingFields.max(by: { $0.weight < $1.weight }) else {
                return nil
            }

            score += strongestField.weight

            let hasVisibleMatch = matchingFields.contains { $0.isVisibleInRow }
            if !hasVisibleMatch {
                if matchedTag == nil, let tag = matchingFields.first(where: { $0.field == .tag })?.originalValue {
                    matchedTag = tag
                }
                if matchingFields.contains(where: { $0.field == .notes }) {
                    matchedInNotes = true
                }
            }
        }

        if fields.name.value == normalizedQuery.fullText {
            score += 1000
        } else if fields.name.value.hasPrefix(normalizedQuery.fullText) {
            score += 600
        } else if fields.name.value.contains(normalizedQuery.fullText) {
            score += 300
        }

        let context = MatchContext(matchedTag: matchedTag, matchedInNotes: matchedInNotes)
        return Result(item: item, score: score, matchContext: context.isEmpty ? nil : context)
    }

    private static func rankedItemOrder(_ lhs: Result, _ rhs: Result) -> Bool {
        guard lhs.score == rhs.score else { return lhs.score > rhs.score }
        return alphabeticalItemOrder(lhs.item, rhs.item)
    }

    private static func alphabeticalItemOrder(_ lhs: InventoryItem, _ rhs: InventoryItem) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard comparison == .orderedSame else { return comparison == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func sortedUniqueValues(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private static func normalizedLocationName(
        for item: InventoryItem,
        vocabulary: InventoryBrowseVocabulary
    ) -> SearchLocationName {
        normalizedLocationName(item.locationName, vocabulary: vocabulary)
    }

    private static func normalizedLocationName(
        _ value: String,
        vocabulary: InventoryBrowseVocabulary
    ) -> SearchLocationName {
        SearchLocationName(InventoryNormalizedName.location(value, vocabulary: vocabulary))
    }
}

private enum SearchField: Int {
    case name, place, location, category, tag, notes

    var weight: Int {
        switch self {
        case .name: 100
        case .place: 70
        case .location: 60
        case .category: 50
        case .tag: 45
        case .notes: 20
        }
    }

    var isVisibleInRow: Bool {
        switch self {
        case .name, .place, .location, .category: true
        case .tag, .notes: false
        }
    }
}

private struct NormalizedSearchField {
    let field: SearchField
    let value: String
    let originalValue: String?

    var weight: Int { field.weight }
    var isVisibleInRow: Bool { field.isVisibleInRow }
}

private struct SearchableFields {
    let name: NormalizedSearchField
    let fields: [NormalizedSearchField]

    init(item: InventoryItem, vocabulary: InventoryBrowseVocabulary) {
        name = NormalizedSearchField(field: .name, value: InventorySearchNormalization.normalize(item.name).fullText, originalValue: nil)
        fields = [
            name,
            NormalizedSearchField(field: .place, value: InventorySearchNormalization.normalize(InventorySearch.searchableContainerName(for: item, vocabulary: vocabulary)).fullText, originalValue: nil),
            NormalizedSearchField(field: .location, value: InventorySearchNormalization.normalize(InventorySearch.searchableLocationName(for: item, vocabulary: vocabulary)).fullText, originalValue: nil),
            NormalizedSearchField(field: .category, value: InventorySearchNormalization.normalize(InventorySearch.displayCategory(for: item, vocabulary: vocabulary)).fullText, originalValue: nil),
            NormalizedSearchField(field: .notes, value: InventorySearchNormalization.normalize(item.notes).fullText, originalValue: nil)
        ] + item.tags.map {
            NormalizedSearchField(field: .tag, value: InventorySearchNormalization.normalize($0).fullText, originalValue: $0)
        }
    }

    func matchingFields(for token: String) -> [NormalizedSearchField] {
        fields.filter { $0.value.contains(token) }
    }
}

enum InventorySearchNormalization {
    struct Query: Equatable {
        let fullText: String
        let tokens: [String]
    }

    static func normalize(_ value: String) -> Query {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = trimmed
            .localizedLowercase
            .folding(options: .diacriticInsensitive, locale: .current)
        let separatorNormalized = folded.replacingOccurrences(
            of: "[-_/\\\\]",
            with: " ",
            options: .regularExpression
        )
        let fullText = separatorNormalized
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return Query(fullText: fullText, tokens: fullText.split(separator: " ").map(String.init))
    }
}

private struct SearchLocationName {
    private let normalizedName: InventoryNormalizedName

    init(_ normalizedName: InventoryNormalizedName) {
        self.normalizedName = normalizedName
    }

    var displayName: String {
        normalizedName.displayName
    }

    var isMissingLocation: Bool {
        normalizedName.isMissing
    }
}
