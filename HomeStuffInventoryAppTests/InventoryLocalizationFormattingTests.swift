import Testing
@testable import HomeStuffInventoryApp

struct InventoryLocalizationFormattingTests {
    @Test func itemCountUsesEnglishSingularAndPluralForms() {
        let bundle = localizationTestLanguageBundle("en") ?? .main
        #expect(InventoryLocalization.itemCount(0, languageIdentifier: "en", bundle: bundle) == "0 items")
        #expect(InventoryLocalization.itemCount(1, languageIdentifier: "en", bundle: bundle) == "1 item")
        #expect(InventoryLocalization.itemCount(2, languageIdentifier: "en", bundle: bundle) == "2 items")
        #expect(InventoryLocalization.itemCount(5, languageIdentifier: "en", bundle: bundle) == "5 items")
    }

    @Test func itemCountUsesUkrainianPluralForms() throws {
        let bundle = try #require(localizationTestLanguageBundle("uk"))
        #expect(InventoryLocalization.itemCount(0, languageIdentifier: "uk", bundle: bundle) == "0 речей")
        #expect(InventoryLocalization.itemCount(1, languageIdentifier: "uk", bundle: bundle) == "1 річ")
        #expect(InventoryLocalization.itemCount(2, languageIdentifier: "uk", bundle: bundle) == "2 речі")
        #expect(InventoryLocalization.itemCount(5, languageIdentifier: "uk", bundle: bundle) == "5 речей")
        #expect(InventoryLocalization.itemCount(21, languageIdentifier: "uk", bundle: bundle) == "21 річ")
        #expect(InventoryLocalization.itemCount(22, languageIdentifier: "uk", bundle: bundle) == "22 речі")
        #expect(InventoryLocalization.itemCount(25, languageIdentifier: "uk", bundle: bundle) == "25 речей")
    }

    @Test func placeCountUsesEnglishAndUkrainianPluralForms() throws {
        let englishBundle = localizationTestLanguageBundle("en") ?? .main
        let ukrainianBundle = try #require(localizationTestLanguageBundle("uk"))

        #expect(InventoryLocalization.placeCount(0, languageIdentifier: "en", bundle: englishBundle) == "0 storage places")
        #expect(InventoryLocalization.placeCount(1, languageIdentifier: "en", bundle: englishBundle) == "1 storage place")
        #expect(InventoryLocalization.placeCount(2, languageIdentifier: "en", bundle: englishBundle) == "2 storage places")
        #expect(InventoryLocalization.placeCount(5, languageIdentifier: "en", bundle: englishBundle) == "5 storage places")
        #expect(InventoryLocalization.placeCount(1, languageIdentifier: "uk", bundle: ukrainianBundle) == "1 місце зберігання")
        #expect(InventoryLocalization.placeCount(2, languageIdentifier: "uk", bundle: ukrainianBundle) == "2 місця зберігання")
        #expect(InventoryLocalization.placeCount(5, languageIdentifier: "uk", bundle: ukrainianBundle) == "5 місць зберігання")
        #expect(InventoryLocalization.placeCount(22, languageIdentifier: "uk", bundle: ukrainianBundle) == "22 місця зберігання")
    }

    @Test func tagAndCategoryOverflowLabelsUseEnglishAndUkrainianPluralForms() throws {
        let englishBundle = localizationTestLanguageBundle("en") ?? .main
        let ukrainianBundle = try #require(localizationTestLanguageBundle("uk"))

        #expect(InventoryLocalization.tagOverflowLabel(1, languageIdentifier: "en", bundle: englishBundle) == "Show 1 more tag")
        #expect(InventoryLocalization.tagOverflowLabel(2, languageIdentifier: "en", bundle: englishBundle) == "Show 2 more tags")
        #expect(InventoryLocalization.tagOverflowLabel(5, languageIdentifier: "en", bundle: englishBundle) == "Show 5 more tags")
        #expect(InventoryLocalization.tagOverflowLabel(1, languageIdentifier: "uk", bundle: ukrainianBundle) == "Показати ще 1 тег")
        #expect(InventoryLocalization.tagOverflowLabel(2, languageIdentifier: "uk", bundle: ukrainianBundle) == "Показати ще 2 теги")
        #expect(InventoryLocalization.tagOverflowLabel(5, languageIdentifier: "uk", bundle: ukrainianBundle) == "Показати ще 5 тегів")

        #expect(InventoryLocalization.categoryOverflowLabel(1, languageIdentifier: "en", bundle: englishBundle) == "1 more category")
        #expect(InventoryLocalization.categoryOverflowLabel(2, languageIdentifier: "en", bundle: englishBundle) == "2 more categories")
        #expect(InventoryLocalization.categoryOverflowLabel(5, languageIdentifier: "en", bundle: englishBundle) == "5 more categories")
        #expect(InventoryLocalization.categoryOverflowLabel(1, languageIdentifier: "uk", bundle: ukrainianBundle) == "ще 1 категорія")
        #expect(InventoryLocalization.categoryOverflowLabel(2, languageIdentifier: "uk", bundle: ukrainianBundle) == "ще 2 категорії")
        #expect(InventoryLocalization.categoryOverflowLabel(5, languageIdentifier: "uk", bundle: ukrainianBundle) == "ще 5 категорій")
    }

    @Test func locationContainsPlacesMessageAgreesWithPluralFormInBothClauses() throws {
        let englishBundle = localizationTestLanguageBundle("en") ?? .main
        let ukrainianBundle = try #require(localizationTestLanguageBundle("uk"))

        #expect(InventoryLocalization.locationContainsPlacesMessage("Hall", count: 1, languageIdentifier: "en", bundle: englishBundle) == "Hall contains 1 storage place. Remove that storage place before deleting this location.")
        #expect(InventoryLocalization.locationContainsPlacesMessage("Hall", count: 2, languageIdentifier: "en", bundle: englishBundle) == "Hall contains 2 storage places. Remove those storage places before deleting this location.")
        #expect(InventoryLocalization.locationContainsPlacesMessage("Hall", count: 5, languageIdentifier: "en", bundle: englishBundle) == "Hall contains 5 storage places. Remove those storage places before deleting this location.")
        #expect(InventoryLocalization.locationContainsPlacesMessage("Hall", count: 1, languageIdentifier: "uk", bundle: ukrainianBundle) == "«Hall» містить 1 місце зберігання. Видаліть це місце зберігання перед видаленням локації.")
        #expect(InventoryLocalization.locationContainsPlacesMessage("Hall", count: 2, languageIdentifier: "uk", bundle: ukrainianBundle) == "«Hall» містить 2 місця зберігання. Видаліть ці місця зберігання перед видаленням локації.")
        #expect(InventoryLocalization.locationContainsPlacesMessage("Hall", count: 5, languageIdentifier: "uk", bundle: ukrainianBundle) == "«Hall» містить 5 місць зберігання. Видаліть ці місця зберігання перед видаленням локації.")
    }
}
