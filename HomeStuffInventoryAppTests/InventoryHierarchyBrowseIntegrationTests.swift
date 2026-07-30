import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryHierarchyBrowseIntegrationTests {
    private let locationID = UUID(uuidString: "7CF804EE-41E2-451D-A09E-A1CD4178EA50")!
    private let rootID = UUID(uuidString: "56A52D46-4A42-4407-B729-A0D10C33EC29")!
    private let childID = UUID(uuidString: "68446326-4502-4B1F-83B0-D984EF5F1D91")!
    private let leafID = UUID(uuidString: "C969CF74-548C-4926-823A-B869CC3D221D")!

    @Test func locationListsOnlyTopLevelPlacesAndPlaceCountsSeparateDirectFromRecursive() {
        let location = StorageLocation(id: locationID, name: "Office")
        let places = hierarchyPlaces()
        let direct = InventoryItem(
            name: "Direct cable",
            locationName: location.name,
            containerName: "Cabinet",
            placeID: rootID
        )
        let nested = InventoryItem(
            name: "Nested adapter",
            locationName: location.name,
            containerName: "Tray",
            placeID: leafID
        )
        let locationSummary = InventoryBrowseSummaries.locationSummaries(
            from: [direct, nested],
            storageLocations: [location]
        )[0]

        let roots = InventoryBrowseSummaries.placeSummaries(
            in: [direct, nested],
            matching: locationSummary,
            places: places
        )
        let children = InventoryBrowseSummaries.placeSummaries(
            in: [direct, nested],
            matching: locationSummary,
            places: places,
            parentPlaceID: rootID
        )

        #expect(roots.map(\.placeID) == [rootID])
        #expect(roots[0].directItemCount == 1)
        #expect(roots[0].recursiveItemCount == 2)
        #expect(roots[0].childPlaceCount == 1)
        #expect(children.map(\.placeID) == [childID])
        #expect(children[0].directItemCount == 0)
        #expect(children[0].recursiveItemCount == 1)
    }

    @Test func zeroOneAndManyChildrenRemainDeterministic() {
        let root = InventoryPlace(id: rootID, locationID: locationID, name: "Cabinet")
        let alpha = InventoryPlace(locationID: locationID, parentPlaceID: rootID, name: "Alpha")
        let beta = InventoryPlace(locationID: locationID, parentPlaceID: rootID, name: "Beta")

        #expect(InventoryPlaceHierarchy.children(of: rootID, locationID: locationID, places: [root]).isEmpty)
        #expect(InventoryPlaceHierarchy.children(of: rootID, locationID: locationID, places: [alpha, root]).map(\.name) == ["Alpha"])
        #expect(InventoryPlaceHierarchy.children(of: rootID, locationID: locationID, places: [beta, root, alpha]).map(\.name) == ["Alpha", "Beta"])
    }

    @Test func searchMatchesParentAndLeafWhileItemNameRanksStronger() {
        let places = hierarchyPlaces()
        let ancestorMatch = InventoryItem(
            name: "USB adapter",
            locationName: "Office",
            containerName: "Tray",
            placeID: leafID
        )
        let directNameMatch = InventoryItem(
            name: "Cabinet manual",
            locationName: "Office",
            containerName: "Desk",
            placeID: nil
        )

        let parentResults = InventorySearch.matchingResults(
            in: [ancestorMatch, directNameMatch],
            query: "cabinet",
            places: places
        )
        let leafResults = InventorySearch.matchingItems(
            in: [ancestorMatch],
            query: "tray",
            places: places
        )

        #expect(parentResults.map(\.id) == [directNameMatch.id, ancestorMatch.id])
        #expect(leafResults.map(\.id) == [ancestorMatch.id])
    }

    @Test func destinationOptionsExposeFullLongPathsAndNestedSelectionStaysFree() {
        let location = StorageLocation(id: locationID, name: "Домашній офіс із довгою назвою")
        let places = hierarchyPlaces(
            rootName: "Висока шафа для техніки",
            childName: "Середня полиця із запасними кабелями",
            leafName: "Прозорий лоток для адаптерів"
        )
        let options = InventoryItemPlaceLink.destinationOptions(in: location, from: places)
        let leaf = options.first { $0.id == leafID }
        let policy = InventoryFreeAccessPolicy()

        #expect(
            leaf?.pathText
                == "Висока шафа для техніки › Середня полиця із запасними кабелями › Прозорий лоток для адаптерів"
        )
        #expect(leaf?.depth == 2)
        #expect(policy.availability(of: .relocateSingleItem, entitlementState: .free) == .available)
        #expect(policy.availability(of: .relocateSingleItem, entitlementState: nil) == .available)
    }

    @Test func contextualCreateAndItemDetailPreserveStableNestedDestinationAndFullPath() {
        let places = hierarchyPlaces()
        let draft = InventoryItemDraft(
            createContext: InventoryItemCreateContext(
                locationName: "Office",
                placeName: "Tray",
                placeID: leafID
            )
        )
        let item = InventoryItem(
            name: "Adapter",
            locationName: "Office",
            containerName: "Tray",
            placeID: leafID
        )
        let detail = InventoryItemDetailViewModel(item: item, places: places)

        #expect(draft.placeID == leafID)
        #expect(draft.containerName == "Tray")
        #expect(detail.containerName == "Cabinet › Shelf › Tray")
    }

    @Test func legacyTextResolutionCannotJumpIntoAnAmbiguousNestedPlace() {
        let location = StorageLocation(id: locationID, name: "Office")
        let topLevelTray = InventoryPlace(locationID: locationID, name: "Tray")
        let places = hierarchyPlaces() + [topLevelTray]
        var draft = InventoryItemDraft(
            createContext: InventoryItemCreateContext(locationName: "Office", placeName: "Tray")
        )
        draft.allowsLegacyPlaceResolution = true

        let resolved = InventoryItemPlaceLink.resolve(
            draft: draft,
            locations: [location],
            places: places
        )

        #expect(resolved.placeID == topLevelTray.id)
    }

    private func hierarchyPlaces(
        rootName: String = "Cabinet",
        childName: String = "Shelf",
        leafName: String = "Tray"
    ) -> [InventoryPlace] {
        [
            InventoryPlace(id: leafID, locationID: locationID, parentPlaceID: childID, name: leafName),
            InventoryPlace(id: rootID, locationID: locationID, name: rootName),
            InventoryPlace(id: childID, locationID: locationID, parentPlaceID: rootID, name: childName)
        ]
    }
}
