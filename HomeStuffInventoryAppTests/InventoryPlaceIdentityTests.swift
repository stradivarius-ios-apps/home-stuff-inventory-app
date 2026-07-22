import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryPlaceIdentityTests {
    @Test func identityUsesBrowseComparisonRulesWithoutRemovingDiacritics() {
        let first = InventoryPlaceIdentity.make(locationName: "  Hall ", placeName: " Shelf A ")
        let same = InventoryPlaceIdentity.make(locationName: "hall", placeName: "shelf a")
        let differentLocation = InventoryPlaceIdentity.make(locationName: "Kitchen", placeName: "Shelf A")
        let accented = InventoryPlaceIdentity.make(locationName: "Hall", placeName: "Šelf A")

        #expect(first == same)
        #expect(first != differentLocation)
        #expect(first != accented)
    }

    @Test func missingComponentsHaveReservedNonCollidingIdentityComponents() {
        let missing = InventoryPlaceIdentity.make(locationName: "", placeName: nil)
        let userText = InventoryPlaceIdentity.make(
            locationName: "__missing_location__",
            placeName: "__missing_place__"
        )

        #expect(missing != userText)
        #expect(missing.rawValue.contains("location:missing"))
        #expect(missing.rawValue.contains("place:missing"))
    }
}
