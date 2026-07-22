import Foundation

/// Presentation-owned text is supplied at the logic boundary so matching and grouping
/// remain independent of the active bundle and locale.
struct InventoryBrowseVocabulary: Equatable {
    let missingLocationName: String
    let missingPlaceName: String
    private let categoryNames: [InventoryCategory: String]

    init(
        missingLocationName: String,
        missingPlaceName: String,
        categoryNames: [InventoryCategory: String] = [:]
    ) {
        self.missingLocationName = missingLocationName
        self.missingPlaceName = missingPlaceName
        self.categoryNames = categoryNames
    }

    func categoryName(for category: InventoryCategory) -> String {
        categoryNames[category] ?? category.rawValue
    }

    func categoryName(forStoredValue value: String) -> String {
        InventoryCategory(storedValue: value).map(categoryName)
            ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Stable fallback values for non-UI callers such as imports and pure-logic tests.
    static let `default` = InventoryBrowseVocabulary(
        missingLocationName: "No location",
        missingPlaceName: "No Place"
    )
}

struct InventoryNormalizedName: Hashable {
    let displayName: String
    let comparisonKey: String
    let isMissing: Bool

    private let missingComparisonKey: String

    static func location(
        _ value: String,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> InventoryNormalizedName {
        normalized(
            value,
            missingDisplayName: vocabulary.missingLocationName,
            missingComparisonKey: "__missing_location__"
        )
    }

    static func place(
        _ value: String?,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> InventoryNormalizedName {
        normalized(
            value,
            missingDisplayName: vocabulary.missingPlaceName,
            missingComparisonKey: "__missing_place__"
        )
    }

    static func missingLocation(
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> InventoryNormalizedName {
        location("", vocabulary: vocabulary)
    }

    static func missingPlace(
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> InventoryNormalizedName {
        place(nil, vocabulary: vocabulary)
    }

    func hash(into hasher: inout Hasher) {
        if isMissing {
            hasher.combine("missing")
            hasher.combine(missingComparisonKey)
        } else {
            hasher.combine("named")
            hasher.combine(comparisonKey)
        }
    }

    static func == (lhs: InventoryNormalizedName, rhs: InventoryNormalizedName) -> Bool {
        switch (lhs.isMissing, rhs.isMissing) {
        case (true, true):
            return lhs.missingComparisonKey == rhs.missingComparisonKey
        case (false, false):
            return lhs.comparisonKey == rhs.comparisonKey
        default:
            return false
        }
    }

    func matches(name: String, isMissing: Bool) -> Bool {
        if self.isMissing {
            return isMissing
        }

        return !isMissing && comparisonKey == Self.comparisonKey(for: name)
    }

    private static func normalized(
        _ value: String?,
        missingDisplayName: String,
        missingComparisonKey: String
    ) -> InventoryNormalizedName {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedValue.isEmpty else {
            return InventoryNormalizedName(
                displayName: missingDisplayName,
                comparisonKey: missingComparisonKey,
                isMissing: true,
                missingComparisonKey: missingComparisonKey
            )
        }

        return InventoryNormalizedName(
            displayName: trimmedValue,
            comparisonKey: comparisonKey(for: trimmedValue),
            isMissing: false,
            missingComparisonKey: missingComparisonKey
        )
    }

    private static func comparisonKey(for value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
