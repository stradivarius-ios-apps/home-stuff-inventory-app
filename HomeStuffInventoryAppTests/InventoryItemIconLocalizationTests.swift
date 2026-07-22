import Testing

struct InventoryItemIconLocalizationTests {
    @Test func ukrainianItemIconStringsResolveFromCatalog() {
        #expect(localizationTestValue("itemIcons.picker.title") == "Іконка речі")
        #expect(localizationTestValue("itemIcons.default.title") == "Типова")
        #expect(localizationTestValue("itemIcons.category.toolsAndRepair") == "Інструменти й ремонт")
        #expect(localizationTestValue("itemIcons.category.cablesAndElectronics") == "Кабелі й електроніка")
        #expect(localizationTestValue("itemIcons.option.cable") == "Кабель")
        #expect(localizationTestValue("itemIcons.option.firstAid") == "Аптечка")
        #expect(localizationTestValue("itemIcons.selected.accessibilityLabel") == "Іконка речі: %@")
    }
}
