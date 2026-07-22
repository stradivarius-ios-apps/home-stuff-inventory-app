import Foundation

enum InventoryLocalization {
    static func string(
        _ key: StaticString,
        defaultValue: String
    ) -> String {
        String(localized: key, defaultValue: String.LocalizationValue(defaultValue), bundle: .main)
    }

    static func formatted(
        _ key: StaticString,
        defaultValue: String,
        _ arguments: CVarArg...
    ) -> String {
        String(format: string(key, defaultValue: defaultValue), locale: .current, arguments: arguments)
    }

    static func itemCount(_ count: Int, bundle: Bundle = .main) -> String {
        itemCount(count, languageIdentifier: preferredLanguageIdentifier(in: bundle), bundle: bundle)
    }

    static func itemCount(
        _ count: Int,
        languageIdentifier: String,
        bundle: Bundle = .main
    ) -> String {
        let key = countWordKey(
            for: .item,
            count: count,
            languageIdentifier: languageIdentifier
        )
        let word = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        return "\(count) \(word)"
    }

    static func placeCount(_ count: Int, bundle: Bundle = .main) -> String {
        placeCount(count, languageIdentifier: preferredLanguageIdentifier(in: bundle), bundle: bundle)
    }

    static func placeCount(_ count: Int, languageIdentifier: String, bundle: Bundle = .main) -> String {
        let key = countWordKey(
            for: .place,
            count: count,
            languageIdentifier: languageIdentifier
        )
        let word = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        return "\(count) \(word)"
    }

    static func tagOverflowLabel(_ count: Int, bundle: Bundle = .main) -> String {
        tagOverflowLabel(count, languageIdentifier: preferredLanguageIdentifier(in: bundle), bundle: bundle)
    }

    static func tagOverflowLabel(_ count: Int, languageIdentifier: String, bundle: Bundle = .main) -> String {
        formattedPlural(.tagOverflow, count: count, languageIdentifier: languageIdentifier, bundle: bundle, count)
    }

    static func categoryOverflowLabel(_ count: Int, bundle: Bundle = .main) -> String {
        categoryOverflowLabel(count, languageIdentifier: preferredLanguageIdentifier(in: bundle), bundle: bundle)
    }

    static func categoryOverflowLabel(_ count: Int, languageIdentifier: String, bundle: Bundle = .main) -> String {
        formattedPlural(.categoryOverflow, count: count, languageIdentifier: languageIdentifier, bundle: bundle, count)
    }

    static func locationContainsPlacesMessage(_ name: String, count: Int, bundle: Bundle = .main) -> String {
        locationContainsPlacesMessage(name, count: count, languageIdentifier: preferredLanguageIdentifier(in: bundle), bundle: bundle)
    }

    static func locationContainsPlacesMessage(
        _ name: String,
        count: Int,
        languageIdentifier: String,
        bundle: Bundle = .main
    ) -> String {
        formattedPlural(.locationContainsPlaces, count: count, languageIdentifier: languageIdentifier, bundle: bundle, name, count)
    }

    static let noLocation = string("inventory.fallback.noLocation", defaultValue: "No location")
    static let noContainer = string("inventory.fallback.noContainer", defaultValue: "No Storage Place")
    static let noNotes = string("inventory.fallback.noNotes", defaultValue: "No notes")
    static let notesPlaceholder = string(
        "inventory.notes.placeholder",
        defaultValue: "Add details: what it’s for, what’s included, or where to find it."
    )

    private static func preferredLanguageIdentifier(in bundle: Bundle) -> String {
        bundle.preferredLocalizations.first ?? Locale.current.language.languageCode?.identifier ?? "en"
    }

    private static func formattedPlural(
        _ message: PluralMessage,
        count: Int,
        languageIdentifier: String,
        bundle: Bundle,
        _ arguments: CVarArg...
    ) -> String {
        let pluralForm = itemCountPluralForm(for: count, languageIdentifier: languageIdentifier)
        let template = bundle.localizedString(
            forKey: message.key(for: pluralForm),
            value: message.defaultValue(for: pluralForm),
            table: "Localizable"
        )
        return String(format: template, locale: Locale(identifier: languageIdentifier), arguments: arguments)
    }

    private static func countWordKey(
        for vocabulary: CountVocabulary,
        count: Int,
        languageIdentifier: String
    ) -> String {
        vocabulary.key(for: itemCountPluralForm(for: count, languageIdentifier: languageIdentifier))
    }

    private enum CountVocabulary {
        case item
        case place

        func key(for pluralForm: ItemCountPluralForm) -> String {
            switch (self, pluralForm) {
            case (.item, .one):
                return "inventory.itemCount.word.one"
            case (.item, .few):
                return "inventory.itemCount.word.few"
            case (.item, .many):
                return "inventory.itemCount.word.many"
            case (.item, .other):
                return "inventory.itemCount.word.other"
            case (.place, .one):
                return "locations.placeCount.word.one"
            case (.place, .few):
                return "locations.placeCount.word.few"
            case (.place, .many):
                return "locations.placeCount.word.many"
            case (.place, .other):
                return "locations.placeCount.word.other"
            }
        }
    }

    private enum PluralMessage {
        case tagOverflow
        case categoryOverflow
        case locationContainsPlaces

        func key(for pluralForm: ItemCountPluralForm) -> String {
            switch (self, pluralForm) {
            case (.tagOverflow, .one): return "inventory.tags.showMore.accessibilityLabel.one"
            case (.tagOverflow, .few): return "inventory.tags.showMore.accessibilityLabel.few"
            case (.tagOverflow, .many): return "inventory.tags.showMore.accessibilityLabel.many"
            case (.tagOverflow, .other): return "inventory.tags.showMore.accessibilityLabel.other"
            case (.categoryOverflow, .one): return "locations.places.row.hiddenCategories.one"
            case (.categoryOverflow, .few): return "locations.places.row.hiddenCategories.few"
            case (.categoryOverflow, .many): return "locations.places.row.hiddenCategories.many"
            case (.categoryOverflow, .other): return "locations.places.row.hiddenCategories.other"
            case (.locationContainsPlaces, .one): return "inventory.lists.error.locationContainsPlaces.message.one"
            case (.locationContainsPlaces, .few): return "inventory.lists.error.locationContainsPlaces.message.few"
            case (.locationContainsPlaces, .many): return "inventory.lists.error.locationContainsPlaces.message.many"
            case (.locationContainsPlaces, .other): return "inventory.lists.error.locationContainsPlaces.message.other"
            }
        }

        func defaultValue(for pluralForm: ItemCountPluralForm) -> String {
            switch (self, pluralForm) {
            case (.tagOverflow, .one): return "Show %d more tag"
            case (.tagOverflow, .few), (.tagOverflow, .many), (.tagOverflow, .other): return "Show %d more tags"
            case (.categoryOverflow, .one): return "%d more category"
            case (.categoryOverflow, .few), (.categoryOverflow, .many), (.categoryOverflow, .other): return "%d more categories"
            case (.locationContainsPlaces, .one): return "%@ contains %d storage place. Remove that storage place before deleting this location."
            case (.locationContainsPlaces, .few), (.locationContainsPlaces, .many), (.locationContainsPlaces, .other): return "%@ contains %d storage places. Remove those storage places before deleting this location."
            }
        }
    }

    private static func itemCountPluralForm(for count: Int, languageIdentifier: String) -> ItemCountPluralForm {
        guard languageIdentifier.hasPrefix("uk") else {
            return count == 1 ? .one : .other
        }

        let absoluteCount = abs(count)
        let mod10 = absoluteCount % 10
        let mod100 = absoluteCount % 100

        if mod10 == 1 && mod100 != 11 {
            return .one
        }

        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return .few
        }

        return .many
    }
}

extension InventoryBrowseVocabulary {
    static var localized: InventoryBrowseVocabulary {
        InventoryBrowseVocabulary(
            missingLocationName: InventoryLocalization.noLocation,
            missingPlaceName: InventoryLocalization.noContainer,
            categoryNames: Dictionary(
                uniqueKeysWithValues: InventoryCategory.allCases.map { ($0, $0.displayName) }
            )
        )
    }
}

private enum ItemCountPluralForm {
    case one
    case few
    case many
    case other
}
