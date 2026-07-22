import Testing
@testable import HomeStuffInventoryApp

struct InventoryItemMutationFailureTests {
    @Test func deleteFailureUsesStableLocalizedPresentation() {
        let failure = InventoryItemMutationFailure.deleteItem

        #expect(failure.title == "Item Not Deleted")
        #expect(failure.message == "The item could not be deleted. Please try again.")
    }

    @Test func notesSaveFailureUsesStableLocalizedPresentation() {
        let failure = InventoryItemMutationFailure.saveNotes

        #expect(failure.title == "Item Not Updated")
        #expect(failure.message == "Your changes could not be saved. Please try again.")
    }
}
