import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventorySearchTests {
    private let items = [
        InventoryItem(
            name: "USB-C to HDMI adapter",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Office",
            containerName: "Desk drawer",
            tags: ["display", "adapter"],
            notes: "Connects the laptop to the living room TV."
        ),
        InventoryItem(
            name: "CR2032 batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen",
            containerName: "Utility drawer",
            tags: ["coin cell", "remote"],
            notes: "Spare cells for the scale."
        ),
        InventoryItem(
            name: "Thermal paste",
            category: InventoryCategory.spareParts.rawValue,
            locationName: "Office",
            containerName: "PC parts box",
            tags: ["cpu", "repair"],
            notes: "Half-used tube from desktop maintenance."
        ),
        InventoryItem(
            name: "Passport photos",
            category: InventoryCategory.documents.rawValue,
            locationName: "Hallway drawer",
            containerName: nil,
            tags: ["documents"],
            notes: "Small envelope with ID photos."
        ),
        InventoryItem(
            name: "Loose hex key",
            category: InventoryCategory.tools.rawValue,
            locationName: " ",
            containerName: "Small tray",
            tags: ["tools"],
            notes: "Needs a storage spot."
        )
    ]

    @Test func emptyQueryReturnsAllItems() {
        let expectedNames = ["CR2032 batteries", "Loose hex key", "Passport photos", "Thermal paste", "USB-C to HDMI adapter"]
        #expect(InventorySearch.matchingItems(in: items, query: "").map(\.name) == expectedNames)
        #expect(InventorySearch.matchingItems(in: items, query: " \n ").map(\.name) == expectedNames)
    }

    @Test func searchMatchesNamePartiallyAndCaseInsensitively() {
        let matches = InventorySearch.matchingItems(in: items, query: "adapter")

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter"])
    }

    @Test func searchMatchesCategory() {
        let matches = InventorySearch.matchingItems(in: items, query: "parts")

        #expect(matches.map(\.name) == ["Thermal paste"])
    }

    @Test func searchMatchesLocation() {
        let matches = InventorySearch.matchingItems(in: items, query: "office")

        #expect(matches.map(\.name) == ["Thermal paste", "USB-C to HDMI adapter"])
    }

    @Test func searchMatchesMissingLocationDisplayText() {
        let matches = InventorySearch.matchingItems(in: items, query: "No Location")

        #expect(matches.map(\.name) == ["Loose hex key"])
    }

    @Test func searchMatchesContainer() {
        let matches = InventorySearch.matchingItems(in: items, query: "utility")

        #expect(matches.map(\.name) == ["CR2032 batteries"])
    }

    @Test func searchMatchesMissingContainerDisplayText() {
        let matches = InventorySearch.matchingItems(in: items, query: "No Storage Place", vocabulary: .localized)

        #expect(matches.map(\.name) == ["Passport photos"])
    }

    @Test func searchMatchesTags() {
        let matches = InventorySearch.matchingItems(in: items, query: "CPU")

        #expect(matches.map(\.name) == ["Thermal paste"])
    }

    @Test func searchMatchesNotes() {
        let matches = InventorySearch.matchingItems(in: items, query: "living room")

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter"])
    }

    @Test func unmatchedQueryReturnsNoItems() {
        #expect(InventorySearch.matchingItems(in: items, query: "garden hose").isEmpty)
    }

    @Test func queryNormalizationHandlesCaseDiacriticsWhitespaceAndSeparators() {
        let normalized = InventorySearchNormalization.normalize("  CÁFE--USB_C / HDMI\\port  ")

        #expect(normalized.fullText == "cafe usb c hdmi port")
        #expect(normalized.tokens == ["cafe", "usb", "c", "hdmi", "port"])
    }

    @Test func tokensCanMatchAcrossNameLocationPlaceTagNotesAndCategory() {
        let item = InventoryItem(
            name: "Travel adapter",
            category: InventoryCategory.electronics.rawValue,
            locationName: "Office",
            containerName: "Desk drawer",
            tags: ["HDMI cable"],
            notes: "Use in the living room."
        )

        #expect(InventorySearch.matchingItems(in: [item], query: "office adapter").map(\.id) == [item.id])
        #expect(InventorySearch.matchingItems(in: [item], query: "desk hdmi").map(\.id) == [item.id])
        #expect(InventorySearch.matchingItems(in: [item], query: "living electronics").map(\.id) == [item.id])
    }

    @Test func allTokensAreRequiredAndUSBCMatchesHyphenatedText() {
        let item = InventoryItem(name: "USB-C adapter", locationName: "Office")

        #expect(InventorySearch.matchingItems(in: [item], query: "usb c").map(\.id) == [item.id])
        #expect(InventorySearch.matchingItems(in: [item], query: "usb missing").isEmpty)
    }

    @Test func exactNameBonusOutranksPrefixAndContainsMatches() {
        let exact = InventoryItem(name: "Adapter", locationName: "Office")
        let prefix = InventoryItem(name: "Adapter cable", locationName: "Office")
        let contains = InventoryItem(name: "USB adapter", locationName: "Office")

        #expect(InventorySearch.matchingItems(in: [contains, prefix, exact], query: "adapter").map(\.id) == [exact.id, prefix.id, contains.id])
    }

    @Test func rankingUsesFieldWeightsAndDeterministicNameAndUUIDTieBreakers() {
        let name = InventoryItem(name: "HDMI adapter", locationName: "Kitchen")
        let place = InventoryItem(name: "Zeta", locationName: "Kitchen", containerName: "HDMI drawer")
        let location = InventoryItem(name: "Omega", locationName: "HDMI closet")
        let category = InventoryItem(name: "Alpha", category: "HDMI gear", locationName: "Kitchen")
        let tag = InventoryItem(name: "Beta", locationName: "Kitchen", tags: ["HDMI"])
        let notes = InventoryItem(name: "Gamma", locationName: "Kitchen", notes: "HDMI cable")
        let firstTie = InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Tie", locationName: "Kitchen", tags: ["HDMI"])
        let secondTie = InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Tie", locationName: "Kitchen", tags: ["HDMI"])

        let matchingItems = InventorySearch.matchingItems(
            in: [notes, tag, category, location, place, name, secondTie, firstTie],
            query: "hdmi"
        )
        let orderedIDs = matchingItems.map(\.id)
        let expectedIDs = [name.id, place.id, location.id, category.id, tag.id, firstTie.id, secondTie.id, notes.id]
        #expect(orderedIDs == expectedIDs)
    }

    @Test func filtersRestrictRankedResultsAndEmptyQueryIsAlphabetical() {
        let alpha = InventoryItem(name: "Alpha adapter", category: InventoryCategory.tools.rawValue, locationName: "Office")
        let beta = InventoryItem(name: "Beta adapter", category: InventoryCategory.tools.rawValue, locationName: "Garage")
        let zeta = InventoryItem(name: "Zeta adapter", category: InventoryCategory.electronics.rawValue, locationName: "Office")

        #expect(InventorySearch.matchingItems(in: [zeta, beta, alpha], query: "").map(\.name) == ["Alpha adapter", "Beta adapter", "Zeta adapter"])
        #expect(
            InventorySearch.matchingItems(
                in: [zeta, beta, alpha],
                query: "adapter",
                filters: .init(category: InventoryCategory.tools.displayName, locationName: "Office")
            ).map(\.id) == [alpha.id]
        )
    }

    @Test func missingFallbacksRemainSearchableAndMatchContextsExplainHiddenFields() {
        let missing = InventoryItem(name: "Cable", locationName: "", containerName: nil)
        let tagOnly = InventoryItem(name: "Cable", locationName: "Office", tags: ["HDMI", "display"])
        let notesOnly = InventoryItem(name: "Cable", locationName: "Office", notes: "Stored with a projector")

        #expect(InventorySearch.matchingItems(in: [missing], query: "no location").map(\.id) == [missing.id])
        #expect(InventorySearch.matchingItems(in: [missing], query: "no place").map(\.id) == [missing.id])
        #expect(InventorySearch.matchingResults(in: [tagOnly], query: "hdmi").first?.matchContext == .init(matchedTag: "HDMI", matchedInNotes: false))
        #expect(InventorySearch.matchingResults(in: [notesOnly], query: "projector").first?.matchContext == .init(matchedTag: nil, matchedInNotes: true))
        #expect(InventorySearch.matchingResults(in: [tagOnly], query: "cable").first?.matchContext == nil)
    }

    @Test func categoryFilterReturnsMatchingItems() {
        let filters = InventorySearch.Filters(category: InventoryCategory.cablesAndAdapters.displayName)
        let matches = InventorySearch.matchingItems(in: items, query: "", filters: filters)

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter"])
    }

    @Test func categoryFilterTrimsWhitespaceAndIgnoresCase() {
        let filters = InventorySearch.Filters(category: "  \(InventoryCategory.cablesAndAdapters.displayName.uppercased())  ")
        let matches = InventorySearch.matchingItems(in: items, query: "", filters: filters)

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter"])
    }

    @Test func categorySearchAndFilterHandleLegacyDisplayValues() {
        let legacyItem = InventoryItem(
            name: "Legacy wrench",
            locationName: "Toolbox"
        )
        legacyItem.category = "Tools"
        let legacyItems = items + [legacyItem]

        let searchedItems = InventorySearch.matchingItems(in: legacyItems, query: "tools")
        let filteredItems = InventorySearch.matchingItems(
            in: legacyItems,
            query: "",
            filters: InventorySearch.Filters(category: "Tools")
        )

        #expect(searchedItems.map(\.name) == ["Legacy wrench", "Loose hex key"])
        #expect(filteredItems.map(\.name) == ["Legacy wrench", "Loose hex key"])
    }

    @Test func categorySearchAndFilterHandleCustomCategoryValues() {
        let customItem = InventoryItem(
            name: "Embroidery hoop",
            category: "Craft Supplies",
            locationName: "Closet"
        )
        let customItems = items + [customItem]

        let searchedItems = InventorySearch.matchingItems(in: customItems, query: "craft")
        let filteredItems = InventorySearch.matchingItems(
            in: customItems,
            query: "",
            filters: InventorySearch.Filters(category: "  craft supplies  ")
        )

        #expect(searchedItems.map(\.name) == ["Embroidery hoop"])
        #expect(filteredItems.map(\.name) == ["Embroidery hoop"])
    }

    @Test func locationFilterReturnsMatchingItems() {
        let filters = InventorySearch.Filters(locationName: "Office")
        let matches = InventorySearch.matchingItems(in: items, query: "", filters: filters)

        #expect(matches.map(\.name) == ["Thermal paste", "USB-C to HDMI adapter"])
    }

    @Test func locationFilterTrimsWhitespaceAndIgnoresCase() {
        let filters = InventorySearch.Filters(locationName: "  office  ")
        let matches = InventorySearch.matchingItems(in: items, query: "", filters: filters)

        #expect(matches.map(\.name) == ["Thermal paste", "USB-C to HDMI adapter"])
    }

    @Test func filtersCanMatchMissingLocationDisplayText() {
        let filters = InventorySearch.Filters(locationName: "No location")
        let matches = InventorySearch.matchingItems(in: items, query: "", filters: filters)

        #expect(matches.map(\.name) == ["Loose hex key"])
    }

    @Test func searchAndFiltersCombinePredictably() {
        let filters = InventorySearch.Filters(
            category: InventoryCategory.spareParts.displayName,
            locationName: "Office"
        )
        let matches = InventorySearch.matchingItems(in: items, query: "repair", filters: filters)

        #expect(matches.map(\.name) == ["Thermal paste"])
    }

    @Test func trimmedSearchAndNormalizedFiltersCombinePredictably() {
        let filters = InventorySearch.Filters(
            category: "  \(InventoryCategory.spareParts.displayName.lowercased())  ",
            locationName: "  OFFICE  "
        )
        let matches = InventorySearch.matchingItems(in: items, query: "  CPU  ", filters: filters)

        #expect(matches.map(\.name) == ["Thermal paste"])
    }

    @Test func mismatchedSearchAndFiltersReturnsNoItems() {
        let filters = InventorySearch.Filters(
            category: InventoryCategory.batteries.displayName,
            locationName: "Kitchen"
        )

        #expect(InventorySearch.matchingItems(in: items, query: "adapter", filters: filters).isEmpty)
    }

    @Test func emptyFiltersDoNotRestrictSearchResults() {
        let filters = InventorySearch.Filters(category: " \n ", locationName: nil)
        let matches = InventorySearch.matchingItems(in: items, query: "office", filters: filters)

        #expect(!filters.hasActiveFilters)
        #expect(matches.map(\.name) == ["Thermal paste", "USB-C to HDMI adapter"])
    }

    @Test func placeFiltersComposeWithLocationCategoryAndSearch() {
        let filters = InventorySearch.Filters(
            category: InventoryCategory.cablesAndAdapters.displayName,
            locationName: "Office",
            place: .named("  DESK DRAWER  ")
        )

        #expect(InventorySearch.matchingItems(in: items, query: "adapter", filters: filters).map(\.name) == ["USB-C to HDMI adapter"])
    }

    @Test func placeFilterMatchesGloballyAndMissingPlaceUsesNormalizedVocabulary() {
        let deskDrawer = InventoryItem(name: "Spare adapter", locationName: "Kitchen", containerName: " desk drawer ")
        let globalMatches = InventorySearch.matchingItems(
            in: items + [deskDrawer],
            query: "",
            filters: .init(place: .named("Desk drawer"))
        )
        let missingMatches = InventorySearch.matchingItems(
            in: items,
            query: "",
            filters: .init(place: .missing)
        )

        #expect(globalMatches.map(\.name) == ["Spare adapter", "USB-C to HDMI adapter"])
        #expect(missingMatches.map(\.name) == ["Passport photos"])
    }

    @Test func availablePlacesScopeDeduplicatesSortsAndReconcilesSelection() {
        let scopedItems = [
            InventoryItem(name: "A", locationName: "Office", containerName: " desk drawer "),
            InventoryItem(name: "B", locationName: "Office", containerName: "Desk Drawer"),
            InventoryItem(name: "C", locationName: "Office", containerName: nil),
            InventoryItem(name: "D", locationName: "Kitchen", containerName: "Pantry")
        ]
        let options = InventorySearch.availablePlaces(from: scopedItems, locationName: "office")

        #expect(options == [.named("desk drawer"), .missing])
        #expect(InventorySearch.reconciledPlaceSelection(.named("Pantry"), availablePlaces: options) == nil)
        #expect(InventorySearch.reconciledPlaceSelection(.named("DESK DRAWER"), availablePlaces: options) == .named("desk drawer"))
        #expect(InventorySearch.reconciledPlaceSelection(.missing, availablePlaces: options) == .missing)
    }

    @Test func availableFilterOptionsAreSortedAndUnique() {
        #expect(
            InventorySearch.availableCategories(from: items) == [
                InventoryCategory.batteries.rawValue,
                InventoryCategory.cablesAndAdapters.rawValue,
                InventoryCategory.documents.rawValue,
                InventoryCategory.electronics.rawValue,
                InventoryCategory.householdSupplies.rawValue,
                InventoryCategory.miscellaneous.rawValue,
                InventoryCategory.outdoorAndTravel.rawValue,
                InventoryCategory.spareParts.rawValue,
                InventoryCategory.tools.rawValue
            ]
        )
        #expect(
            InventorySearch.availableLocations(from: items) == [
                "Hallway drawer",
                "Kitchen",
                "No location",
                "Office"
            ]
        )
    }

    @Test func injectedCategoryVocabularyDrivesOptionsAndSearchWithoutChangingStorage() {
        let vocabulary = InventoryBrowseVocabulary(
            missingLocationName: "Missing location",
            missingPlaceName: "Missing place",
            categoryNames: [.spareParts: "Replacement components"]
        )

        #expect(
            InventorySearch.availableCategories(from: items, vocabulary: vocabulary)
                .contains("Replacement components")
        )
        #expect(
            InventorySearch.matchingItems(
                in: items,
                query: "replacement",
                vocabulary: vocabulary
            ).map(\.name) == ["Thermal paste"]
        )
        #expect(items.first { $0.name == "Thermal paste" }?.category == InventoryCategory.spareParts.rawValue)
    }
}
