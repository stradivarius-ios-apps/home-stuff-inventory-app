import Foundation
import Observation
import os
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

@MainActor
struct InventoryPlacePathIndexTests {
    @Test func indexPreservesPathsAndBrokenHierarchyStatuses() {
        let locationID = UUID()
        let root = InventoryPlace(locationID: locationID, name: "Cabinet")
        let child = InventoryPlace(locationID: locationID, parentPlaceID: root.id, name: "Box")
        let missingID = UUID()
        let orphan = InventoryPlace(locationID: locationID, parentPlaceID: missingID, name: "Orphan")
        let crossLocation = InventoryPlace(locationID: UUID(), parentPlaceID: root.id, name: "Other")
        let cycle = InventoryPlace(locationID: locationID, name: "Cycle")
        cycle.parentPlaceID = cycle.id
        let index = InventoryPlacePathIndex(places: [root, child, orphan, crossLocation, cycle])

        #expect(index[child.id]?.components == ["Cabinet", "Box"])
        #expect(index[child.id]?.placeIDs == [root.id, child.id])
        #expect(index[child.id]?.status == .complete)
        #expect(index[orphan.id]?.status == .missingParent(missingID))
        #expect(index[crossLocation.id]?.status == .crossLocationParent(root.id))
        #expect(index[cycle.id]?.status == .cycle(cycle.id))
        #expect(index[nil] == nil)
        #expect(index[UUID()] == nil)
    }

    @Test func rebuildingPathsAndSearchReflectsRenameMoveDeletionAndRestoredModels() {
        let locationID = UUID()
        let first = InventoryPlace(locationID: locationID, name: "Cabinet")
        let second = InventoryPlace(locationID: locationID, name: "Shelf")
        let leaf = InventoryPlace(locationID: locationID, parentPlaceID: first.id, name: "Box")
        let item = InventoryItem(name: "Cable", locationName: "Office", containerName: "Box", placeID: leaf.id)
        var places = [first, second, leaf]
        let originalPath = InventoryPlacePathIndex(places: places)[leaf.id]
        first.name = "Closet"
        #expect(InventoryPlacePathIndex(places: places)[leaf.id]?.displayName == "Closet › Box")
        #expect(originalPath?.displayName == "Cabinet › Box")
        #expect(InventorySearch.matchingResults(in: [item], query: "closet", places: places).map(\.id) == [item.id])

        leaf.parentPlaceID = second.id
        #expect(InventoryPlacePathIndex(places: places)[leaf.id]?.displayName == "Shelf › Box")
        #expect(InventorySearch.matchingResults(in: [item], query: "closet", places: places).isEmpty)
        #expect(InventorySearch.matchingResults(in: [item], query: "shelf", places: places).map(\.id) == [item.id])
        places.removeAll { $0.id == leaf.id }
        #expect(InventoryPlacePathIndex(places: places)[item.placeID] == nil)
        #expect(InventorySearch.matchingResults(in: [item], query: "shelf", places: places).isEmpty)
        #expect(InventorySearch.matchingResults(in: [item], query: "box", places: places).map(\.id) == [item.id])

        let restoredRoot = InventoryPlace(id: second.id, locationID: locationID, name: "Restored shelf")
        let restoredLeaf = InventoryPlace(id: leaf.id, locationID: locationID, parentPlaceID: second.id, name: "Restored box")
        let restored = InventoryPlacePathIndex(places: [restoredRoot, restoredLeaf])
        #expect(restored[item.placeID]?.displayName == "Restored shelf › Restored box")
        #expect(InventorySearch.matchingResults(in: [item], query: "restored", placePaths: restored).map(\.id) == [item.id])
        item.name = "Adapter"
        item.placeID = second.id
        #expect(restored[item.placeID]?.displayName == "Restored shelf")
        #expect(InventorySearch.matchingResults(in: [item], query: "cable", placePaths: restored).isEmpty)
        #expect(InventorySearch.matchingResults(in: [item], query: "adapter", placePaths: restored).map(\.id) == [item.id])
    }

    @Test func deepHierarchyIndexDoesNotMaterializeUnusedPaths() {
        let locationID = UUID()
        var places: [InventoryPlace] = []
        for offset in 0..<5_000 {
            places.append(InventoryPlace(
                locationID: locationID, parentPlaceID: places.last?.id, name: "Level \(offset)"
            ))
        }
        let invalidated = OSAllocatedUnfairLock(initialState: false)
        let index = withObservationTracking {
            InventoryPlacePathIndex(places: places)
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        #expect(index[places.first?.id]?.components == ["Level 0"])
        #expect(index[places.last?.id]?.components.count == 5_000)
        places[2_500].name = "Renamed unused ancestor"
        #expect(!invalidated.withLock { $0 })
    }

    @Test(arguments: [0, 1, 2])
    func searchDoesNotReadPathsWithoutCandidatesOrQuery(scenario: Int) {
        let locationID = UUID()
        let root = InventoryPlace(locationID: locationID, name: "Cabinet")
        let leaf = InventoryPlace(locationID: locationID, parentPlaceID: root.id, name: "Box")
        let item = InventoryItem(name: "Cable", locationName: "Office", containerName: "Box", placeID: leaf.id)
        let invalidated = OSAllocatedUnfairLock(initialState: false)
        let results = withObservationTracking {
            InventorySearch.matchingResults(
                in: scenario == 2 ? [] : [item], query: scenario == 0 ? "" : "cabinet",
                filters: scenario == 1 ? .init(locationName: "Kitchen") : .init(),
                places: [root, leaf]
            )
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        #expect(results.count == (scenario == 0 ? 1 : 0))
        root.name = "Closet"
        #expect(!invalidated.withLock { $0 })
    }

    @Test(arguments: [0, 1, 2])
    func indexReadsRegisterHierarchyObservation(change: Int) {
        let locationID = UUID()
        let root = InventoryPlace(locationID: locationID, name: "Cabinet")
        let leaf = InventoryPlace(locationID: locationID, parentPlaceID: root.id, name: "Box")
        let invalidated = OSAllocatedUnfairLock(initialState: false)
        _ = withObservationTracking {
            InventoryPlacePathIndex(places: [root, leaf])[leaf.id]
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        switch change {
        case 0: root.name = "Closet"
        case 1: leaf.parentPlaceID = nil
        default: root.locationID = UUID()
        }
        #expect(invalidated.withLock { $0 })
    }
}
