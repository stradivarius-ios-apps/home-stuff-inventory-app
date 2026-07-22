import Testing
@testable import HomeStuffInventoryApp

struct InventoryFilterContextTests {
    @Test func inactiveContextIgnoresBlankSearchAndFilters() {
        let context = InventoryFilterContext(
            resultCount: 5,
            searchText: " \n ",
            category: nil,
            locationName: " "
        )

        #expect(!context.isActive)
        #expect(context.searchText == nil)
        #expect(context.category == nil)
        #expect(context.locationName == nil)
        #expect(context.place == nil)
        #expect(context.clearAction == nil)
    }

    @Test func activeContextTrimsVisibleValuesAndKeepsResultCount() {
        let context = InventoryFilterContext(
            resultCount: 12,
            searchText: "  usb  ",
            category: "  Cables & Adapters  ",
            locationName: "  Hallway cabinet  ",
            place: .named("  Drawer  ")
        )

        #expect(context.isActive)
        #expect(context.resultCount == 12)
        #expect(context.searchText == "usb")
        #expect(context.category == "Cables & Adapters")
        #expect(context.locationName == "Hallway cabinet")
        #expect(context.place == .named("  Drawer  "))
        #expect(context.clearAction == .searchAndFilters)
    }

    @Test(arguments: [
        ("usb", nil, nil, InventoryFilterContext.ClearAction.search),
        ("", "Tools", nil, InventoryFilterContext.ClearAction.filters),
        ("", nil, "Office", InventoryFilterContext.ClearAction.filters)
    ])
    func clearActionReflectsActiveSearchAndFilters(
        searchText: String,
        category: String?,
        locationName: String?,
        expectedAction: InventoryFilterContext.ClearAction
    ) {
        let context = InventoryFilterContext(
            resultCount: 1,
            searchText: searchText,
            category: category,
            locationName: locationName
        )

        #expect(context.clearAction == expectedAction)
    }

    @Test func placeParticipatesInActiveContextAndClearAction() {
        let context = InventoryFilterContext(
            resultCount: 0,
            searchText: "usb",
            category: nil,
            locationName: nil,
            place: .missing
        )

        #expect(context.isActive)
        #expect(context.place == .missing)
        #expect(context.clearAction == .searchAndFilters)
    }
}
