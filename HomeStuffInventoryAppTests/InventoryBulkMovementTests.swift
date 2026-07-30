import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBulkMovementTests {
    @Test func selectionRequiresAccessAndKeepsHiddenFilteredItemsDeterministically() {
        let first = id("10000000-0000-0000-0000-000000000001")
        let second = id("10000000-0000-0000-0000-000000000002")
        let third = id("10000000-0000-0000-0000-000000000003")
        var state = InventoryBulkSelectionState()

        #expect(
            state.begin(visibleItemIDs: [first], availability: .unavailable)
                == .accessRequired
        )
        #expect(!state.isActive)
        #expect(state.selectedItemIDs.isEmpty)

        #expect(
            state.begin(visibleItemIDs: [second, first], availability: .available)
                == .started
        )
        state.replaceSelection(with: [first], visibleItemIDs: [first, second])
        state.replaceSelection(with: [second], visibleItemIDs: [second, third])
        #expect(state.selectedItemIDs == [first, second])
        state.selectAll(visibleItemIDs: [third])
        #expect(state.selectedItemIDs == [first, second, third])

        state.reconcile(availableItemIDs: [second, third])
        #expect(state.selectedItemIDs == [second, third])
        state.cancel()
        #expect(!state.isActive)
        #expect(state.selectedItemIDs.isEmpty)
    }

    @Test func hierarchicalDestinationDirectoryUsesStableIDsAndFullPaths() {
        let kitchen = StorageLocation(
            id: id("10000000-0000-0000-0000-000000000001"),
            name: "Kitchen"
        )
        let cabinet = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000001"),
            locationID: kitchen.id,
            name: "Cabinet"
        )
        let drawer = InventoryPlace(
            id: id("20000000-0000-0000-0000-000000000002"),
            locationID: kitchen.id,
            parentPlaceID: cabinet.id,
            name: "Drawer"
        )

        let destinations = InventoryBulkMovementDestinationDirectory.destinations(
            locations: [kitchen],
            places: [drawer, cabinet]
        )

        #expect(destinations.map(\.id) == [
            .location(kitchen.id),
            .place(cabinet.id),
            .place(drawer.id)
        ])
        #expect(destinations.map(\.displayPath) == [
            "Kitchen",
            "Kitchen › Cabinet",
            "Kitchen › Cabinet › Drawer"
        ])
    }

    @Test func prepareHandlesEmptyOneManyMixedOriginsAndSameDestination() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let first = InventoryItem(name: "Cable", locationName: office.name)
        let second = InventoryItem(name: "Tape", locationName: garage.name)
        [office, garage].forEach(context.insert)
        [first, second].forEach(context.insert)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = InventoryBulkMovementDestination(
            id: .location(garage.id),
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil,
            displayPath: garage.name
        )

        #expect(
            InventoryBulkMovement.prepare(
                selectedItemIDs: [],
                items: [first, second],
                locations: [office, garage],
                places: [],
                destination: destination,
                access: access
            ) == .emptySelection
        )

        let one = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [second.id],
                    items: [first, second],
                    locations: [office, garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )
        #expect(one.selectedItemCount == 1)
        #expect(one.changedItemCount == 0)

        let many = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [second.id, first.id],
                    items: [first, second],
                    locations: [office, garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )
        #expect(many.selectedItemIDs == [first.id, second.id].sorted { $0.uuidString < $1.uuidString })
        #expect(many.sourceSummaries.count == 2)
        #expect(many.changedItemCount == 1)
    }

    @Test func commitMovesAtomicallyAndGroupedUndoRestoresMixedOrigins() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let kitchen = StorageLocation(name: "Kitchen")
        let garage = StorageLocation(name: "Garage")
        let first = InventoryItem(
            id: id("20000000-0000-0000-0000-000000000001"),
            name: "Cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: office.name,
            iconID: "cable",
            quantity: 3,
            condition: InventoryCondition.good.rawValue,
            tags: ["HDMI"],
            notes: "Keep adapter",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let second = InventoryItem(name: "Tape", locationName: kitchen.name)
        [office, kitchen, garage].forEach(context.insert)
        [first, second].forEach(context.insert)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = InventoryBulkMovementDestination(
            id: .location(garage.id),
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil,
            displayPath: garage.name
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [first.id, second.id],
                    items: [first, second],
                    locations: [office, kitchen, garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )
        let operationID = id("30000000-0000-0000-0000-000000000001")

        #expect(
            InventoryBulkMovement.commit(
                preflight,
                access: access,
                in: context,
                operationID: operationID
            ) == .moved(operationID: operationID, itemCount: 2)
        )
        #expect(first.locationName == "Garage")
        #expect(second.locationName == "Garage")
        #expect(first.id == id("20000000-0000-0000-0000-000000000001"))
        #expect(first.name == "Cable")
        #expect(first.category == InventoryCategory.cablesAndAdapters.rawValue)
        #expect(first.iconID == "cable")
        #expect(first.quantity == 3)
        #expect(first.condition == InventoryCondition.good.rawValue)
        #expect(first.tags == ["HDMI"])
        #expect(first.notes == "Keep adapter")
        #expect(first.createdAt == Date(timeIntervalSince1970: 10))
        let records = try context.fetch(FetchDescriptor<InventoryMovementRecord>())
        #expect(records.count == 2)
        #expect(Set(records.map(\.operationID)) == [operationID])
        #expect(records.allSatisfy { $0.origin == .selectedItems })

        #expect(
            InventoryMovementHistory.undoLatest(
                records: records,
                items: [first, second],
                locations: [office, kitchen, garage],
                places: [],
                entitlements: access.entitlements,
                in: context
            ) == .undone(operationID: operationID)
        )
        #expect(first.locationName == "Office")
        #expect(second.locationName == "Kitchen")
    }

    @Test func cancellationFailureAndEntitlementLossNeverPartiallyMove() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let first = InventoryItem(name: "Cable", locationName: office.name)
        let second = InventoryItem(name: "Tape", locationName: office.name)
        [office, garage].forEach(context.insert)
        [first, second].forEach(context.insert)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = InventoryBulkMovementDestination(
            id: .location(garage.id),
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil,
            displayPath: garage.name
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [first.id, second.id],
                    items: [first, second],
                    locations: [office, garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )

        #expect(
            InventoryBulkMovement.commit(
                preflight,
                access: access,
                in: context,
                isCancelled: { true }
            ) == .cancelled
        )
        #expect(first.locationName == "Office")
        #expect(second.locationName == "Office")

        #expect(
            InventoryBulkMovement.commit(
                preflight,
                access: access,
                in: context,
                persist: { throw TestFailure() }
            ) == .failed
        )
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).allSatisfy { $0.locationName == "Office" })
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)

        access.apply(.verified(.free))
        #expect(
            InventoryBulkMovement.commit(
                preflight,
                access: access,
                in: context
            ) == .accessRequired
        )
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).allSatisfy { $0.locationName == "Office" })
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func sameDestinationCreatesNoHistoryAndDowngradePreservesExistingHistory() throws {
        let context = try makeContext()
        let garage = StorageLocation(name: "Garage")
        let item = InventoryItem(name: "Cable", locationName: garage.name)
        context.insert(garage)
        context.insert(item)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = InventoryBulkMovementDestination(
            id: .location(garage.id),
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil,
            displayPath: garage.name
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [item.id],
                    items: [item],
                    locations: [garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )

        #expect(
            InventoryBulkMovement.commit(preflight, access: access, in: context)
                == .unchanged
        )
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)

        let source = InventoryMovementEndpointSnapshot(item: item, locations: [garage])
        let storedRecord = InventoryMovementRecord(
            operationID: UUID(),
            itemID: item.id,
            origin: .selectedItems,
            source: source,
            destination: source
        )
        context.insert(storedRecord)
        try context.save()
        access.apply(.verified(.free))

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).map(\.id) == [item.id])
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).map(\.id) == [storedRecord.id])
    }

    @Test func sourceChangeAfterReviewRequiresFreshPreflightWithoutMutation() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let kitchen = StorageLocation(name: "Kitchen")
        let garage = StorageLocation(name: "Garage")
        let item = InventoryItem(name: "Cable", locationName: office.name)
        [office, kitchen, garage].forEach(context.insert)
        context.insert(item)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = InventoryBulkMovementDestination(
            id: .location(garage.id),
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil,
            displayPath: garage.name
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [item.id],
                    items: [item],
                    locations: [office, kitchen, garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )
        item.applyMovement(
            .init(
                locationID: kitchen.id,
                locationName: kitchen.name,
                placeID: nil,
                placeName: nil
            )
        )
        try context.save()

        #expect(
            InventoryBulkMovement.commit(preflight, access: access, in: context)
                == .staleSelection
        )
        #expect(item.locationName == "Kitchen")
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func swappingReviewedItemSourcesCannotBypassPerItemPreflight() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let kitchen = StorageLocation(name: "Kitchen")
        let garage = StorageLocation(name: "Garage")
        let first = InventoryItem(name: "Cable", locationName: office.name)
        let second = InventoryItem(name: "Tape", locationName: kitchen.name)
        [office, kitchen, garage].forEach(context.insert)
        [first, second].forEach(context.insert)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = InventoryBulkMovementDestination(
            id: .location(garage.id),
            locationID: garage.id,
            locationName: garage.name,
            placeID: nil,
            placeName: nil,
            displayPath: garage.name
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [first.id, second.id],
                    items: [first, second],
                    locations: [office, kitchen, garage],
                    places: [],
                    destination: destination,
                    access: access
                )
            )
        )
        first.applyMovement(
            .init(
                locationID: kitchen.id,
                locationName: kitchen.name,
                placeID: nil,
                placeName: nil
            )
        )
        second.applyMovement(
            .init(
                locationID: office.id,
                locationName: office.name,
                placeID: nil,
                placeName: nil
            )
        )
        try context.save()

        #expect(
            InventoryBulkMovement.commit(preflight, access: access, in: context)
                == .staleSelection
        )
        #expect(first.locationName == "Kitchen")
        #expect(second.locationName == "Office")
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func destinationReparentAfterPreflightIsRejectedWithoutMutation() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let cabinet = InventoryPlace(locationID: garage.id, name: "Cabinet")
        let shelf = InventoryPlace(locationID: garage.id, name: "Shelf")
        let drawer = InventoryPlace(
            locationID: garage.id,
            parentPlaceID: cabinet.id,
            name: "Drawer"
        )
        let item = InventoryItem(name: "Cable", locationName: office.name)
        [office, garage].forEach(context.insert)
        [cabinet, shelf, drawer].forEach(context.insert)
        context.insert(item)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = try #require(
            InventoryBulkMovementDestinationDirectory.destinations(
                locations: [office, garage],
                places: [cabinet, shelf, drawer]
            )
            .first { $0.id == .place(drawer.id) }
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [item.id],
                    items: [item],
                    locations: [office, garage],
                    places: [cabinet, shelf, drawer],
                    destination: destination,
                    access: access
                )
            )
        )
        drawer.parentPlaceID = shelf.id
        try context.save()

        #expect(
            InventoryBulkMovement.commit(preflight, access: access, in: context)
                == .invalidDestination
        )
        #expect(item.locationName == "Office")
        #expect(item.placeID == nil)
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func destinationDeletionAfterPreflightIsRejectedWithoutMutation() throws {
        let context = try makeContext()
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let drawer = InventoryPlace(locationID: garage.id, name: "Drawer")
        let item = InventoryItem(name: "Cable", locationName: office.name)
        [office, garage].forEach(context.insert)
        context.insert(drawer)
        context.insert(item)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        let destination = try #require(
            InventoryBulkMovementDestinationDirectory.destinations(
                locations: [office, garage],
                places: [drawer]
            )
            .first { $0.id == .place(drawer.id) }
        )
        let preflight = try #require(
            readyPreflight(
                InventoryBulkMovement.prepare(
                    selectedItemIDs: [item.id],
                    items: [item],
                    locations: [office, garage],
                    places: [drawer],
                    destination: destination,
                    access: access
                )
            )
        )
        context.delete(drawer)
        try context.save()

        #expect(
            InventoryBulkMovement.commit(preflight, access: access, in: context)
                == .invalidDestination
        )
        #expect(item.locationName == "Office")
        #expect(item.placeID == nil)
        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    @Test func incompleteDestinationPathIsExcludedAndCannotPrepare() throws {
        let location = StorageLocation(name: "Garage")
        let missingParentID = id("20000000-0000-0000-0000-000000000099")
        let orphan = InventoryPlace(
            locationID: location.id,
            parentPlaceID: missingParentID,
            name: "Drawer"
        )
        let item = InventoryItem(name: "Cable", locationName: "Office")
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )

        let destinations = InventoryBulkMovementDestinationDirectory.destinations(
            locations: [location],
            places: [orphan]
        )
        #expect(destinations.map(\.id) == [.location(location.id)])

        let invalidDestination = InventoryBulkMovementDestination(
            id: .place(orphan.id),
            locationID: location.id,
            locationName: location.name,
            placeID: orphan.id,
            placeName: orphan.name,
            displayPath: "Garage › Drawer",
            placePathIDs: [orphan.id],
            placePathComponents: [orphan.name]
        )
        #expect(
            InventoryBulkMovement.prepare(
                selectedItemIDs: [item.id],
                items: [item],
                locations: [location],
                places: [orphan],
                destination: invalidDestination,
                access: access
            ) == .invalidDestination
        )
    }

    private func readyPreflight(
        _ outcome: InventoryBulkMovementPreparationOutcome
    ) -> InventoryBulkMovementPreflight? {
        guard case let .ready(preflight) = outcome else { return nil }
        return preflight
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private func id(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }

    private struct TestFailure: Error {}
}
