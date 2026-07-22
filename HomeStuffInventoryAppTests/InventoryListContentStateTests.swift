import Testing
@testable import HomeStuffInventoryApp

struct InventoryListContentStateTests {
    @Test func zeroItemsAlwaysUseInitialState() {
        #expect(InventoryListContentState.make(itemCount: 0, filteredItemCount: 0) == .initial)
        #expect(InventoryListContentState.make(itemCount: 0, filteredItemCount: 5) == .initial)
    }

    @Test func nonemptyInventoryDistinguishesFilteredEmptyAndResults() {
        #expect(InventoryListContentState.make(itemCount: 1, filteredItemCount: 0) == .filteredEmpty)
        #expect(InventoryListContentState.make(itemCount: 1, filteredItemCount: 1) == .results)
    }

    @Test func locationCreateContextDoesNotPersistMissingLocationFallback() {
        let named = InventoryBrowseSummaries.LocationSummary(name: "Garage", itemCount: 0, isMissingLocation: false)
        let missing = InventoryBrowseSummaries.LocationSummary(name: "No Location", itemCount: 1, isMissingLocation: true)

        #expect(InventoryLocationCreateContext.make(for: named) == InventoryItemCreateContext(locationName: "Garage"))
        #expect(InventoryLocationCreateContext.make(for: missing) == .global)
    }
}
