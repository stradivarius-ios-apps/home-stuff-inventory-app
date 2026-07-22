import Testing
@testable import HomeStuffInventoryApp

struct LocationPlaceSummaryTests {
    private func category(
        _ identity: String,
        _ name: String = "Category",
        count: Int = 1
    ) -> InventoryBrowseSummaries.PlaceSummary.CategorySummary {
        .init(storageIdentity: identity, displayName: name, itemCount: count)
    }

    @Test func emptyPlacesProduceNoSummary() {
        #expect(LocationPlaceSummary(places: []).text == "0 storage places")
        #expect(LocationPlaceSummary(places: [" ", "\n"]).text == "0 storage places")
    }

    @Test func onePlaceUsesPlaceName() {
        let summary = LocationPlaceSummary(places: ["Dresser"])

        #expect(summary.placeCount == 1)
        #expect(summary.placeCountText == "1 storage place")
        #expect(summary.visibleText == "Dresser")
        #expect(summary.overflowText == nil)
        #expect(summary.text == "1 storage place · Dresser")
    }

    @Test func twoPlacesUseCommaSeparatedNames() {
        let summary = LocationPlaceSummary(places: ["Dresser", "Desk tray"])

        #expect(summary.visibleText == "Dresser, Desk tray")
        #expect(summary.overflowText == nil)
        #expect(summary.text == "2 storage places · Dresser, Desk tray")
    }

    @Test func moreThanTwoPlacesUseOverflowCount() {
        let summary = LocationPlaceSummary(places: ["Dresser", "Desk tray", "Parts box", "Top shelf"])

        #expect(summary.visibleText == "Dresser, Desk tray")
        #expect(summary.overflowText == "+2")
        #expect(summary.text == "4 storage places · Dresser, Desk tray +2")
    }

    @Test func hiddenPlacesContributeToOverflowCount() {
        let summary = LocationPlaceSummary(places: ["Dresser", "Desk tray", "Parts box"], hiddenPlaceCount: 2)

        #expect(summary.visibleText == "Dresser, Desk tray")
        #expect(summary.overflowText == "+3")
        #expect(summary.text == "5 storage places · Dresser, Desk tray +3")
    }

    @Test func unicodePlaceNamesRemainBoundedAndUnchanged() {
        let summary = LocationPlaceSummary(
            places: ["Шухляда 🧰", "Полиця №2", "Контейнер"],
            hiddenPlaceCount: 1
        )

        #expect(summary.visibleText == "Шухляда 🧰, Полиця №2")
        #expect(summary.text == "4 storage places · Шухляда 🧰, Полиця №2 +2")
    }

    @Test func emptyCategoriesProduceNoSummary() {
        #expect(LocationCategorySummary(categories: []).text == nil)
        #expect(LocationCategorySummary(categories: [" ", "\n"]).text == nil)
    }

    @Test func categoriesUseCompactSeparator() {
        let summary = LocationCategorySummary(categories: ["Electronics", "Documents", "Tools"])

        #expect(summary.visibleText == "Electronics · Documents · Tools")
        #expect(summary.overflowText == nil)
        #expect(summary.text == "Electronics · Documents · Tools")
    }

    @Test func longThirdCategoryUsesOverflowInsteadOfPartialTruncation() {
        let summary = LocationCategorySummary(
            categories: ["Spare Parts", "Tools", "Cables & Adapters"],
            maxVisibleCharacters: 22
        )

        #expect(summary.visibleText == "Spare Parts · Tools")
        #expect(summary.overflowText == "+1")
        #expect(summary.text == "Spare Parts · Tools +1")
    }

    @Test func hiddenCategoriesCombineWithCategoriesHiddenByCharacterLimit() {
        let summary = LocationCategorySummary(
            categories: ["Spare Parts", "Tools", "Cables & Adapters"],
            hiddenCategoryCount: 2,
            maxVisibleCharacters: 22
        )

        #expect(summary.visibleText == "Spare Parts · Tools")
        #expect(summary.overflowText == "+3")
        #expect(summary.text == "Spare Parts · Tools +3")
    }

    @Test func shortCategoryNamesStillShowWhenTheyFitCharacterLimit() {
        let summary = LocationCategorySummary(
            categories: ["Tools", "Tape", "Pens"],
            maxVisibleCharacters: 30
        )

        #expect(summary.visibleText == "Tools · Tape · Pens")
        #expect(summary.overflowText == nil)
        #expect(summary.text == "Tools · Tape · Pens")
    }

    @Test func hiddenCategoriesContributeToLocalizedOverflowCount() {
        let summary = LocationCategorySummary(
            categories: ["Electronics", "Documents", "Tools"],
            hiddenCategoryCount: 2
        )

        #expect(summary.visibleText == "Electronics · Documents · Tools")
        #expect(summary.overflowText == "+2")
        #expect(summary.text == "Electronics · Documents · Tools +2")
    }

    @Test func placeCategoryRowPresentationComputesExactOverflowForEveryAdaptiveVariant() {
        let categories = [
            category("tools", "Tools"),
            category("documents", "Documents"),
            category("batteries", "Batteries"),
            category("custom", "Custom")
        ]

        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: 3).hiddenCategoryCount == 1)
        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: 2).hiddenCategoryCount == 2)
        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: 1).hiddenCategoryCount == 3)
        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: 0).hiddenCategoryCount == 4)
    }

    @Test func placeCategoryRowPresentationAvoidsZeroOrNegativeOverflowAndHandlesEmptyPlaces() {
        let categories = [category("tools", "Tools")]

        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: 3).overflowText == nil)
        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: -1).overflowText == "+1")
        #expect(PlaceCategoryRowPresentation(categories: [], visibleCount: 0).hiddenCategoryCount == 0)
        #expect(PlaceCategoryRowPresentation(categories: [], visibleCount: 0).overflowText == nil)
        #expect(PlaceCategoryRowPresentation(categories: [], visibleCount: 0).accessibilityOverflowText == nil)
        #expect(PlaceCategoryRowPresentation(categories: categories, visibleCount: 0).accessibilityOverflowText == "1 more category")
    }

    @Test func placeCategoryEntryPresentationUsesBuiltInIconsAndTagFallbacks() {
        #expect(PlaceCategoryEntryPresentation(category: category("tools", "Tools")).symbolName == "wrench.and.screwdriver")
        #expect(PlaceCategoryEntryPresentation(category: category("miscellaneous", "Miscellaneous")).symbolName == "tag")
        #expect(PlaceCategoryEntryPresentation(category: category("Craft Supplies", "Craft Supplies")).symbolName == "tag")
        #expect(PlaceCategoryEntryPresentation(category: category("unresolved", "Unresolved")).symbolName == "tag")
    }

    @Test func previewGroupPresentationPreservesPreviewItemIDsForDuplicateTitles() throws {
        let group = InventoryBrowseSummaries.PreviewGroup(
            kind: .recentItem,
            visibleItems: [
                .init(id: "first-manual", title: "Manual"),
                .init(id: "second-manual", title: "Manual")
            ],
            hiddenCount: 0
        )

        let presentation = try #require(InventoryPreviewGroupPresentation(group))

        #expect(presentation.visibleChips.map(\.id) == ["first-manual", "second-manual"])
        #expect(presentation.visibleChips.map(\.title) == ["Manual", "Manual"])
    }

    @Test func previewGroupPresentationUsesSameVisibleValuesForAccessibilityAndOverflow() throws {
        let group = InventoryBrowseSummaries.PreviewGroup(
            kind: .place,
            visibleItems: [
                .init(id: "dresser", title: "Dresser"),
                .init(id: "tray", title: "Desk tray"),
                .init(id: "shelf", title: "Top shelf")
            ],
            hiddenCount: 1
        )

        let presentation = try #require(InventoryPreviewGroupPresentation(group))

        #expect(presentation.visibleChips.map(\.title) == ["Dresser", "Desk tray"])
        #expect(presentation.visibleValueText == "Dresser, Desk tray")
        #expect(presentation.overflowChip?.title == "+2")
        #expect(presentation.accessibilityText == "storage places: Dresser, Desk tray, 2 more")
        #expect(presentation.chips.map(\.title) == ["Dresser", "Desk tray", "+2"])
        #expect(presentation.compactSummaryText == "Dresser, Desk tray +2")
    }

    @Test func recentPreviewGroupAccessibilityTextIncludesOverflowCount() throws {
        let group = InventoryBrowseSummaries.PreviewGroup(
            kind: .recentItem,
            visibleItems: [
                .init(id: "adapter", title: "USB-C adapter"),
                .init(id: "cable", title: "Charging cable"),
                .init(id: "battery", title: "Spare battery"),
                .init(id: "manual", title: "Device manual")
            ],
            hiddenCount: 2
        )

        let presentation = try #require(InventoryPreviewGroupPresentation(group))

        #expect(presentation.visibleChips.map(\.title) == ["USB-C adapter", "Charging cable", "Spare battery"])
        #expect(presentation.overflowChip?.title == "+3")
        #expect(
            presentation.accessibilityText
                == "recently viewed items: USB-C adapter, Charging cable, Spare battery, 3 more"
        )
    }
}
