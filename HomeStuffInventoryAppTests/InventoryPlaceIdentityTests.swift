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

    @Test func recursivePathPreservesStoredComponentsAndStableIDs() {
        let locationID = UUID()
        let parent = InventoryPlace(locationID: locationID, name: " Cabinet ")
        let child = InventoryPlace(locationID: locationID, parentPlaceID: parent.id, name: "Drawer")
        let grandchild = InventoryPlace(locationID: locationID, parentPlaceID: child.id, name: "Cable Box")

        let path = InventoryPlaceHierarchy.path(for: grandchild, places: [grandchild, parent, child])

        #expect(path.placeIDs == [parent.id, child.id, grandchild.id])
        #expect(path.components == ["Cabinet", "Drawer", "Cable Box"])
        #expect(path.displayName == "Cabinet › Drawer › Cable Box")
        #expect(path.status == .complete)
    }

    @Test func sameNormalizedNameIsAllowedUnderDifferentParentsButRejectedForSiblings() throws {
        let locationID = UUID()
        let firstParent = InventoryPlace(locationID: locationID, name: "First")
        let secondParent = InventoryPlace(locationID: locationID, name: "Second")
        let existing = InventoryPlace(locationID: locationID, parentPlaceID: firstParent.id, name: " Box ")
        let otherBranch = InventoryPlace(locationID: locationID, parentPlaceID: secondParent.id, name: "box")
        let duplicateSibling = InventoryPlace(locationID: locationID, parentPlaceID: firstParent.id, name: "BOX")
        let places = [firstParent, secondParent, existing, otherBranch, duplicateSibling]

        try InventoryPlaceHierarchy.validatePlacement(
            of: otherBranch,
            under: secondParent.id,
            places: places
        )
        #expect(throws: InventoryPlaceHierarchyError.duplicateSiblingName("BOX")) {
            try InventoryPlaceHierarchy.validatePlacement(
                of: duplicateSibling,
                under: firstParent.id,
                places: places
            )
        }
    }

    @Test func invalidParentPlacementsAreRejected() {
        let firstLocationID = UUID()
        let secondLocationID = UUID()
        let parent = InventoryPlace(locationID: firstLocationID, name: "Parent")
        let child = InventoryPlace(locationID: firstLocationID, parentPlaceID: parent.id, name: "Child")
        let otherLocation = InventoryPlace(locationID: secondLocationID, name: "Other")
        let places = [parent, child, otherLocation]
        let missingID = UUID()

        #expect(throws: InventoryPlaceHierarchyError.selfParent) {
            try InventoryPlaceHierarchy.validatePlacement(of: parent, under: parent.id, places: places)
        }
        #expect(throws: InventoryPlaceHierarchyError.descendantCycle) {
            try InventoryPlaceHierarchy.validatePlacement(of: parent, under: child.id, places: places)
        }
        #expect(throws: InventoryPlaceHierarchyError.crossLocationParent) {
            try InventoryPlaceHierarchy.validatePlacement(of: child, under: otherLocation.id, places: places)
        }
        #expect(throws: InventoryPlaceHierarchyError.missingParent(missingID)) {
            try InventoryPlaceHierarchy.validatePlacement(of: child, under: missingID, places: places)
        }
    }

    @Test func corruptPathsTerminateWithDeterministicStatus() {
        let locationID = UUID()
        let missingID = UUID()
        let missingParent = InventoryPlace(locationID: locationID, parentPlaceID: missingID, name: "Missing")
        let foreignParent = InventoryPlace(locationID: UUID(), name: "Foreign")
        let crossLocation = InventoryPlace(locationID: locationID, parentPlaceID: foreignParent.id, name: "Cross")
        let first = InventoryPlace(locationID: locationID, name: "First")
        let second = InventoryPlace(locationID: locationID, parentPlaceID: first.id, name: "Second")
        first.parentPlaceID = second.id
        let places = [missingParent, foreignParent, crossLocation, first, second]

        let missingPath = InventoryPlaceHierarchy.path(for: missingParent, places: places)
        let crossLocationPath = InventoryPlaceHierarchy.path(for: crossLocation, places: places)
        let cyclePath = InventoryPlaceHierarchy.path(for: first, places: places)

        #expect(missingPath.components == ["Missing"])
        #expect(missingPath.status == .missingParent(missingID))
        #expect(crossLocationPath.components == ["Cross"])
        #expect(crossLocationPath.status == .crossLocationParent(foreignParent.id))
        #expect(cyclePath.status == .cycle(first.id))
        #expect(InventoryPlaceHierarchy.path(for: first, places: places) == cyclePath)
    }

    @Test func practicalDeepPathTerminatesWithoutDepthCap() {
        let locationID = UUID()
        var places: [InventoryPlace] = []
        var parentPlaceID: UUID?

        for index in 0..<5_000 {
            let place = InventoryPlace(
                locationID: locationID,
                parentPlaceID: parentPlaceID,
                name: "Level \(index)"
            )
            places.append(place)
            parentPlaceID = place.id
        }

        let path = InventoryPlaceHierarchy.path(for: places.last!, places: places)

        #expect(path.components.count == 5_000)
        #expect(path.components.first == "Level 0")
        #expect(path.components.last == "Level 4999")
        #expect(path.status == .complete)
    }
}
