import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryPlaceContentsMovementTests {
    @Test func emptyPlaceIsCalmBeforeAccessAndDirectContentsExcludeDescendants() throws {
        let fixture = try makeFixture()
        let free = access(lifetime: false)

        #expect(
            InventoryPlaceContentsMovement.prepare(
                sourcePlaceID: fixture.empty.id,
                items: fixture.items,
                locations: fixture.locations,
                places: fixture.places,
                destination: fixture.destination,
                access: free
            ) == .emptyPlace
        )

        let pro = access(lifetime: true)
        let oneFixture = try makeFixture()
        oneFixture.second.applyMovement(
            InventoryMovementEndpointSnapshot(
                locationID: oneFixture.office.id,
                locationName: oneFixture.office.name,
                placeID: oneFixture.child.id,
                placeName: oneFixture.child.name
            )
        )
        let one = try #require(ready(prepare(oneFixture, access: pro)))
        #expect(one.itemCount == 1)
        #expect(one.movement.selectedItemIDs == [oneFixture.first.id])

        let preflight = try #require(
            ready(
                InventoryPlaceContentsMovement.prepare(
                    sourcePlaceID: fixture.source.id,
                    items: fixture.items,
                    locations: fixture.locations,
                    places: fixture.places,
                    destination: fixture.destination,
                    access: pro
                )
            )
        )
        #expect(preflight.itemCount == 2)
        #expect(Set(preflight.movement.selectedItemIDs) == [fixture.first.id, fixture.second.id])
        #expect(!preflight.movement.selectedItemIDs.contains(fixture.descendantItem.id))

        let sameDestination = try #require(
            InventoryBulkMovementDestinationDirectory.destinations(
                locations: fixture.locations,
                places: fixture.places
            ).first { $0.id == .place(fixture.source.id) }
        )
        let unchanged = try #require(
            ready(
                InventoryPlaceContentsMovement.prepare(
                    sourcePlaceID: fixture.source.id,
                    items: fixture.items,
                    locations: fixture.locations,
                    places: fixture.places,
                    destination: sameDestination,
                    access: pro
                )
            )
        )
        #expect(unchanged.movement.changedItemCount == 0)
        #expect(
            InventoryPlaceContentsMovement.commit(
                unchanged,
                access: pro,
                in: fixture.context
            ) == .unchanged
        )
        #expect(try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func legacyOnlyAndMixedDirectRowsRequireReviewBeforeEmptyOrAccess() throws {
        let legacyOnly = try makeFixture()
        legacyOnly.first.applyMovement(
            InventoryMovementEndpointSnapshot(
                locationID: legacyOnly.office.id,
                locationName: legacyOnly.office.name,
                placeID: legacyOnly.child.id,
                placeName: legacyOnly.child.name
            )
        )
        legacyOnly.second.applyMovement(
            InventoryMovementEndpointSnapshot(
                locationID: legacyOnly.office.id,
                locationName: legacyOnly.office.name,
                placeID: legacyOnly.child.id,
                placeName: legacyOnly.child.name
            )
        )
        let legacyItem = InventoryItem(
            name: "Legacy cable",
            locationName: legacyOnly.office.name,
            containerName: legacyOnly.source.name
        )
        let free = access(lifetime: false)

        #expect(
            InventoryPlaceContentsMovement.prepare(
                sourcePlaceID: legacyOnly.source.id,
                items: legacyOnly.items + [legacyItem],
                locations: legacyOnly.locations,
                places: legacyOnly.places,
                destination: legacyOnly.destination,
                access: free
            ) == .legacyReviewRequired
        )
        #expect(legacyItem.placeID == nil)
        #expect(try legacyOnly.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)

        let mixed = try makeFixture()
        let mixedLegacyItem = InventoryItem(
            name: "Legacy adapter",
            locationName: mixed.office.name,
            containerName: mixed.source.name
        )
        #expect(
            InventoryPlaceContentsMovement.prepare(
                sourcePlaceID: mixed.source.id,
                items: mixed.items + [mixedLegacyItem],
                locations: mixed.locations,
                places: mixed.places,
                destination: mixed.destination,
                access: free
            ) == .legacyReviewRequired
        )
        #expect(mixed.first.placeID == mixed.source.id)
        #expect(mixedLegacyItem.placeID == nil)
        #expect(try mixed.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func legacyRowAddedAfterReviewBlocksCommitWithoutPartialMovement() throws {
        let fixture = try makeFixture()
        let pro = access(lifetime: true)
        let preflight = try #require(ready(prepare(fixture, access: pro)))
        let legacyItem = InventoryItem(
            name: "Late legacy item",
            locationName: fixture.office.name,
            containerName: fixture.source.name
        )
        fixture.context.insert(legacyItem)
        try fixture.context.save()

        #expect(
            InventoryPlaceContentsMovement.commit(
                preflight,
                access: pro,
                in: fixture.context
            ) == .legacyReviewRequired
        )
        #expect(fixture.first.placeID == fixture.source.id)
        #expect(fixture.second.placeID == fixture.source.id)
        #expect(legacyItem.placeID == nil)
        #expect(try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test(arguments: [SourceMutation.add, .remove, .change])
    func commitRejectsEveryDirectMembershipChange(mutation: SourceMutation) throws {
        let fixture = try makeFixture()
        let pro = access(lifetime: true)
        let preflight = try #require(ready(prepare(fixture, access: pro)))

        switch mutation {
        case .add:
            fixture.context.insert(
                InventoryItem(
                    name: "Added",
                    locationName: fixture.office.name,
                    containerName: fixture.source.name,
                    placeID: fixture.source.id
                )
            )
        case .remove:
            fixture.context.delete(fixture.second)
        case .change:
            fixture.second.applyMovement(fixture.destination.endpoint)
        }
        try fixture.context.save()

        #expect(
            InventoryPlaceContentsMovement.commit(
                preflight,
                access: pro,
                in: fixture.context
            ) == .sourceChanged
        )
        #expect(fixture.first.placeID == fixture.source.id)
        #expect(try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test(arguments: [
        DestinationMutation.rename,
        .reparent,
        .delete,
        .corruptHierarchy
    ])
    func commitRejectsEveryDestinationIdentityOrPathChange(
        mutation: DestinationMutation
    ) throws {
        let fixture = try makeFixture()
        let pro = access(lifetime: true)
        let preflight = try #require(ready(prepare(fixture, access: pro)))

        switch mutation {
        case .rename:
            fixture.target.name = "Renamed"
        case .reparent:
            fixture.target.parentPlaceID = fixture.source.id
        case .delete:
            fixture.context.delete(fixture.target)
        case .corruptHierarchy:
            fixture.target.parentPlaceID = fixture.target.id
        }
        try fixture.context.save()

        #expect(
            InventoryPlaceContentsMovement.commit(
                preflight,
                access: pro,
                in: fixture.context
            ) == .invalidDestination
        )
        let persistedItems = try fixture.context.fetch(FetchDescriptor<InventoryItem>())
        #expect(
            persistedItems
                .filter { $0.id == fixture.first.id || $0.id == fixture.second.id }
                .allSatisfy { $0.placeID == fixture.source.id }
        )
        #expect(try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func sourceRenameAndReparentRequireFreshConfirmation() throws {
        for mutation in [SourcePlaceMutation.rename, .reparent] {
            let fixture = try makeFixture()
            let pro = access(lifetime: true)
            let preflight = try #require(ready(prepare(fixture, access: pro)))

            switch mutation {
            case .rename:
                fixture.source.name = "Renamed source"
            case .reparent:
                fixture.source.parentPlaceID = fixture.empty.id
            }
            try fixture.context.save()

            #expect(
                InventoryPlaceContentsMovement.commit(
                    preflight,
                    access: pro,
                    in: fixture.context
                ) == .sourceChanged
            )
        }
    }

    @Test func moveIsAtomicCreatesOneGroupedOperationAndUndoRestoresAllDirectItems() throws {
        let fixture = try makeFixture()
        let pro = access(lifetime: true)
        let preflight = try #require(ready(prepare(fixture, access: pro)))
        let operationID = id("90000000-0000-0000-0000-000000000001")

        #expect(
            InventoryPlaceContentsMovement.commit(
                preflight,
                access: pro,
                in: fixture.context,
                operationID: operationID
            ) == .moved(operationID: operationID, itemCount: 2)
        )
        #expect(fixture.first.placeID == fixture.target.id)
        #expect(fixture.second.placeID == fixture.target.id)
        #expect(fixture.descendantItem.placeID == fixture.child.id)

        let records = try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>())
        #expect(records.count == 2)
        #expect(Set(records.map(\.operationID)) == [operationID])
        #expect(records.allSatisfy { $0.origin == .storagePlaceDirectContents })

        let undo = InventoryMovementHistory.undoLatest(
            records: records,
            items: fixture.items,
            locations: fixture.locations,
            places: fixture.places,
            entitlements: pro.entitlements,
            in: fixture.context
        )
        guard case .undone = undo else {
            Issue.record("Expected grouped undo, got \(undo)")
            return
        }
        #expect(fixture.first.placeID == fixture.source.id)
        #expect(fixture.second.placeID == fixture.source.id)
    }

    @Test func persistenceFailureRollsBackEveryItemAndHistoryRecord() throws {
        let fixture = try makeFixture()
        let pro = access(lifetime: true)
        let preflight = try #require(ready(prepare(fixture, access: pro)))

        #expect(
            InventoryPlaceContentsMovement.commit(
                preflight,
                access: pro,
                in: fixture.context,
                persist: { throw TestFailure() }
            ) == .failed
        )
        let persistedItems = try fixture.context.fetch(FetchDescriptor<InventoryItem>())
        #expect(
            persistedItems
                .filter { $0.id == fixture.first.id || $0.id == fixture.second.id }
                .allSatisfy { $0.placeID == fixture.source.id }
        )
        #expect(try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func entitlementIsRecheckedAndDowngradePreservesCommittedDataAndOrdinaryMovement() throws {
        let fixture = try makeFixture()
        let pro = access(lifetime: true)
        let preflight = try #require(ready(prepare(fixture, access: pro)))
        let free = access(lifetime: false)

        #expect(
            InventoryPlaceContentsMovement.commit(
                preflight,
                access: free,
                in: fixture.context
            ) == .accessRequired
        )
        #expect(fixture.first.placeID == fixture.source.id)

        let moved = InventoryPlaceContentsMovement.commit(
            preflight,
            access: pro,
            in: fixture.context
        )
        guard case .moved = moved else {
            Issue.record("Expected committed move, got \(moved)")
            return
        }

        let recordCount = try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).count
        #expect(recordCount == 2)
        #expect(fixture.first.placeID == fixture.target.id)

        let ordinaryDestination = InventoryMovementEndpointSnapshot(
            locationID: fixture.office.id,
            locationName: fixture.office.name,
            placeID: fixture.empty.id,
            placeName: fixture.empty.name
        )
        let ordinaryRecords = try InventoryMovementHistory.move(
            [
                InventoryMovementRequest(
                    item: fixture.first,
                    expectedSource: InventoryMovementEndpointSnapshot(
                        item: fixture.first,
                        locations: fixture.locations
                    ),
                    destination: ordinaryDestination
                )
            ],
            origin: .singleItem,
            in: fixture.context,
            locations: fixture.locations
        )
        #expect(ordinaryRecords.count == 1)
        #expect(fixture.first.placeID == fixture.empty.id)
        #expect(try fixture.context.fetch(FetchDescriptor<InventoryMovementRecord>()).count == 3)
    }

    private func prepare(
        _ fixture: Fixture,
        access: PremiumAccessState
    ) -> InventoryPlaceContentsMovementPreparationOutcome {
        InventoryPlaceContentsMovement.prepare(
            sourcePlaceID: fixture.source.id,
            items: fixture.items,
            locations: fixture.locations,
            places: fixture.places,
            destination: fixture.destination,
            access: access
        )
    }

    private func ready(
        _ outcome: InventoryPlaceContentsMovementPreparationOutcome
    ) -> InventoryPlaceContentsMovementPreflight? {
        guard case let .ready(preflight) = outcome else { return nil }
        return preflight
    }

    private func makeFixture() throws -> Fixture {
        let context = ModelContext(try InventoryModelContainer.make(inMemory: true))
        let office = StorageLocation(
            id: id("10000000-0000-0000-0000-000000000001"),
            name: "Office"
        )
        let garage = StorageLocation(
            id: id("10000000-0000-0000-0000-000000000002"),
            name: "Garage"
        )
        let source = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000001"),
            locationID: office.id,
            name: "Cabinet"
        )
        let child = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000002"),
            locationID: office.id,
            parentPlaceID: source.id,
            name: "Drawer"
        )
        let empty = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000003"),
            locationID: office.id,
            name: "Empty"
        )
        let target = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000004"),
            locationID: garage.id,
            name: "Shelf"
        )
        let first = InventoryItem(
            id: id("30000000-0000-0000-0000-000000000001"),
            name: "Cable",
            locationName: office.name,
            containerName: source.name,
            placeID: source.id
        )
        let second = InventoryItem(
            id: id("30000000-0000-0000-0000-000000000002"),
            name: "Tape",
            locationName: office.name,
            containerName: source.name,
            placeID: source.id
        )
        let descendantItem = InventoryItem(
            id: id("30000000-0000-0000-0000-000000000003"),
            name: "Adapter",
            locationName: office.name,
            containerName: child.name,
            placeID: child.id
        )
        [office, garage].forEach(context.insert)
        [source, child, empty, target].forEach(context.insert)
        [first, second, descendantItem].forEach(context.insert)
        try context.save()

        let locations = [office, garage]
        let places = [source, child, empty, target]
        let destination = try #require(
            InventoryBulkMovementDestinationDirectory.destinations(
                locations: locations,
                places: places
            ).first { $0.id == .place(target.id) }
        )
        return Fixture(
            context: context,
            office: office,
            source: source,
            child: child,
            empty: empty,
            target: target,
            first: first,
            second: second,
            descendantItem: descendantItem,
            locations: locations,
            places: places,
            items: [first, second, descendantItem],
            destination: destination
        )
    }

    private func access(lifetime: Bool) -> PremiumAccessState {
        PremiumAccessState(
            entitlements: .init(
                ownsLifetimePro: lifetime,
                hasActiveFamilySubscription: false
            )
        )
    }

    private func id(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    enum SourceMutation: CaseIterable {
        case add
        case remove
        case change
    }

    enum DestinationMutation: CaseIterable {
        case rename
        case reparent
        case delete
        case corruptHierarchy
    }

    private enum SourcePlaceMutation {
        case rename
        case reparent
    }

    private struct Fixture {
        let context: ModelContext
        let office: StorageLocation
        let source: InventoryPlace
        let child: InventoryPlace
        let empty: InventoryPlace
        let target: InventoryPlace
        let first: InventoryItem
        let second: InventoryItem
        let descendantItem: InventoryItem
        let locations: [StorageLocation]
        let places: [InventoryPlace]
        let items: [InventoryItem]
        let destination: InventoryBulkMovementDestination
    }

    private struct TestFailure: Error {}
}
