import Foundation
import Testing
import SwiftData
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryItemFormPersistenceTests {
    @Test func createsAndPersistsValidDraftThroughInjectedBoundary() {
        var draft = InventoryItemDraft()
        draft.name = "Cable"
        var insertedItem: InventoryItem?

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: nil,
            insert: { insertedItem = $0 },
            persist: { },
            rollback: { Issue.record("Rollback should not run for a successful save.") }
        )

        #expect(outcome == .saved)
        #expect(insertedItem?.name == "Cable")
    }

    @Test func saveFailureRollsBackForEditsAndReturnsStableOutcome() {
        var draft = InventoryItemDraft()
        draft.name = "Updated cable"
        let item = InventoryItem(name: "Cable", locationName: "Desk")
        var didRollback = false

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: item,
            insert: { _ in Issue.record("Edit flow must not insert a new item.") },
            persist: { throw PersistenceFailure.expected },
            rollback: { didRollback = true }
        )

        #expect(outcome == .saveFailed)
        #expect(didRollback)
    }

    @Test func invalidDraftDoesNotInsertOrPersist() {
        var draft = InventoryItemDraft()
        draft.name = " \n "
        var didInsert = false
        var didPersist = false

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: nil,
            insert: { _ in didInsert = true },
            persist: { didPersist = true },
            rollback: { Issue.record("Invalid drafts must not roll back a transaction.") }
        )

        #expect(outcome == .invalidDraft)
        #expect(!didInsert)
        #expect(!didPersist)
    }

    @Test func failedEditRestoresPersistedItemInModelContext() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let item = InventoryItem(
            name: "Cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Desk",
            containerName: "Top drawer",
            quantity: 2,
            condition: InventoryCondition.good.rawValue,
            notes: "Original"
        )
        let originalPlaceID = UUID()
        item.placeID = originalPlaceID
        context.insert(item)
        try context.save()

        var draft = InventoryItemDraft(item: item)
        draft.name = "Updated cable"
        draft.locationName = "Garage"
        draft.containerName = "Shelf"
        draft.quantity = 9
        draft.notes = "Updated"

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: item,
            insert: { _ in Issue.record("Edit flow must not insert a new item.") },
            persist: { throw PersistenceFailure.expected },
            rollback: context.rollback
        )

        #expect(outcome == .saveFailed)
        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persistedItem.name == "Cable")
        #expect(persistedItem.locationName == "Desk")
        #expect(persistedItem.containerName == "Top drawer")
        #expect(persistedItem.quantity == 2)
        #expect(persistedItem.notes == "Original")
        #expect(persistedItem.placeID == originalPlaceID)
    }

    @Test func failedCreateIsRemovedFromModelContext() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        var draft = InventoryItemDraft()
        draft.name = "New cable"
        draft.locationName = "Desk"

        let outcome = InventoryItemFormPersistence.save(
            draft: draft,
            item: nil,
            insert: context.insert,
            persist: { throw PersistenceFailure.expected },
            rollback: context.rollback
        )

        #expect(outcome == .saveFailed)
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).isEmpty)
    }

    @Test func successfulCreateAndEditPersistThroughModelContext() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        var createDraft = InventoryItemDraft()
        createDraft.name = "Cable"
        createDraft.locationName = "Desk"

        #expect(
            InventoryItemFormPersistence.save(
                draft: createDraft,
                item: nil,
                insert: context.insert,
                persist: context.save,
                rollback: context.rollback
            ) == .saved
        )

        let item = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        var editDraft = InventoryItemDraft(item: item)
        editDraft.name = "Updated cable"

        #expect(
            InventoryItemFormPersistence.save(
                draft: editDraft,
                item: item,
                insert: { _ in Issue.record("Edit flow must not insert a new item.") },
                persist: context.save,
                rollback: context.rollback
            ) == .saved
        )
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).first?.name == "Updated cable")
    }

    @Test func saveLinksOnlyTheExactPlaceInsideSelectedLocation() throws {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let officeBox = InventoryPlace(locationID: office.id, name: "Red Box", iconID: "archive")
        let garageBox = InventoryPlace(locationID: garage.id, name: "Red Box", iconID: "drawer")
        var draft = InventoryItemDraft()
        draft.name = "Cable"
        draft.locationName = "Office"
        draft.containerName = " red box "
        var inserted: InventoryItem?

        let result = InventoryItemFormPersistence.save(
            draft: draft,
            item: nil,
            locations: [office, garage],
            places: [officeBox, garageBox],
            insert: { inserted = $0 },
            persist: { },
            rollback: { Issue.record("Unexpected rollback") }
        )

        #expect(result == .saved)
        #expect(inserted?.placeID == officeBox.id)
        #expect(inserted?.containerName == "Red Box")
    }

    @Test func changedLocationDoesNotAutoLinkSameLegacyPlaceText() {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let officeBox = InventoryPlace(locationID: office.id, name: "Red Box")
        let garageBox = InventoryPlace(locationID: garage.id, name: "Red Box")
        var draft = InventoryItemDraft()
        draft.name = "Cable"
        draft.locationName = "Garage"
        draft.containerName = "Red Box"
        draft.placeID = officeBox.id
        draft.allowsLegacyPlaceResolution = false
        var inserted: InventoryItem?

        _ = InventoryItemFormPersistence.save(
            draft: draft,
            item: nil,
            locations: [office, garage],
            places: [officeBox, garageBox],
            insert: { inserted = $0 },
            persist: { },
            rollback: { Issue.record("Unexpected rollback") }
        )

        #expect(inserted?.placeID == nil)
        #expect(inserted?.containerName == "Red Box")
    }

    @Test func staleSelectedPlaceFromAnotherLocationCannotBeSavedAcrossLocations() {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let officePlace = InventoryPlace(locationID: office.id, name: "Red Box")
        var draft = InventoryItemDraft()
        draft.name = "Cable"
        draft.locationName = "Garage"
        draft.containerName = "Red Box"
        draft.placeID = officePlace.id
        draft.allowsLegacyPlaceResolution = false
        var inserted: InventoryItem?

        _ = InventoryItemFormPersistence.save(draft: draft, item: nil, locations: [office, garage], places: [officePlace], insert: { inserted = $0 }, persist: { }, rollback: { Issue.record("Unexpected rollback") })

        #expect(inserted?.placeID == nil)
        #expect(inserted?.locationName == "Garage")
    }

    @Test func saveLinksAnOtherwiseUnchangedLegacyItem() {
        let office = StorageLocation(name: "Office")
        let box = InventoryPlace(locationID: office.id, name: "Red Box")
        let item = InventoryItem(name: "Cable", locationName: "Office", containerName: "Red Box")
        var draft = InventoryItemDraft(item: item)
        draft.placeID = box.id

        let result = InventoryItemFormPersistence.save(
            draft: draft,
            item: item,
            locations: [office],
            places: [box],
            insert: { _ in Issue.record("Edit flow must not insert") },
            persist: { },
            rollback: { Issue.record("Unexpected rollback") }
        )

        #expect(result == .saved)
        #expect(item.placeID == box.id)
    }

    @Test func roomSweepSavesConsecutiveDuplicateNamesAsOrdinaryItems() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "Top drawer")
        context.insert(location)
        context.insert(place)
        try context.save()
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        var workflow = InventoryRoomSweepWorkflow(
            createContext: .init(
                locationName: location.name,
                placeName: place.name,
                placeID: place.id
            )
        )

        for _ in 0..<2 {
            workflow.draft.name = "USB-C cable"
            #expect(
                InventoryRoomSweepPersistence.save(
                    draft: workflow.draft,
                    access: access,
                    locations: [location],
                    places: [place],
                    in: context
                ) == .saved
            )
            workflow.didSaveItem()
        }

        let savedItems = try context.fetch(FetchDescriptor<InventoryItem>())
        #expect(savedItems.count == 2)
        #expect(savedItems.allSatisfy { $0.name == "USB-C cable" })
        #expect(savedItems.allSatisfy { $0.locationName == location.name })
        #expect(savedItems.allSatisfy { $0.placeID == place.id })
        #expect(workflow.savedCount == 2)
        #expect(workflow.draft.name.isEmpty)
    }

    @Test func roomSweepCancellationLeavesSavedItemsAndNeverPersistsTheCurrentDraft() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        var workflow = InventoryRoomSweepWorkflow(createContext: .init(locationName: "Office"))
        workflow.draft.name = "Saved cable"

        #expect(
            InventoryRoomSweepPersistence.save(
                draft: workflow.draft,
                access: access,
                locations: [],
                places: [],
                in: context
            ) == .saved
        )
        workflow.didSaveItem()
        workflow.draft.name = "Unsaved tape"

        let savedItems = try context.fetch(FetchDescriptor<InventoryItem>())
        #expect(savedItems.map(\.name) == ["Saved cable"])
    }

    @Test func roomSweepFailureRollsBackTheCurrentItemAndKeepsEarlierSaves() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        var firstDraft = InventoryItemDraft(createContext: .init(locationName: "Office"))
        firstDraft.name = "Saved cable"
        #expect(
            InventoryRoomSweepPersistence.save(
                draft: firstDraft,
                access: access,
                locations: [],
                places: [],
                in: context
            ) == .saved
        )
        var failingDraft = InventoryItemDraft(createContext: .init(locationName: "Office"))
        failingDraft.name = "Failed tape"

        #expect(
            InventoryRoomSweepPersistence.save(
                draft: failingDraft,
                access: access,
                locations: [],
                places: [],
                in: context,
                persist: { throw PersistenceFailure.expected }
            ) == .saveFailed
        )

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).map(\.name) == ["Saved cable"])
    }

    @Test func roomSweepChecksCurrentEntitlementBeforeEveryMutationAndDowngradeKeepsItemsVisible() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        var draft = InventoryItemDraft(createContext: .init(locationName: "Office"))
        draft.name = "Cable"
        #expect(
            InventoryRoomSweepPersistence.save(
                draft: draft,
                access: access,
                locations: [],
                places: [],
                in: context
            ) == .saved
        )

        access.apply(.verified(.free))
        var blockedDraft = InventoryItemDraft(createContext: .init(locationName: "Office"))
        blockedDraft.name = "Tape"
        #expect(
            InventoryRoomSweepPersistence.save(
                draft: blockedDraft,
                access: access,
                locations: [],
                places: [],
                in: context
            ) == .accessRequired
        )

        let ordinaryItems = try context.fetch(FetchDescriptor<InventoryItem>())
        #expect(ordinaryItems.map(\.name) == ["Cable"])
        #expect(ordinaryItems.allSatisfy { _ in
            InventoryFreeAccessPolicy().availability(
                of: .viewItem,
                entitlementState: .free
            ) == .available
        })
    }

    @Test func roomSweepCreationDoesNotFabricateRelocationHistory() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let access = PremiumAccessState(
            entitlements: .init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        )
        var draft = InventoryItemDraft(createContext: .init(locationName: "Office"))
        draft.name = "Cable"

        #expect(
            InventoryRoomSweepPersistence.save(
                draft: draft,
                access: access,
                locations: [],
                places: [],
                in: context
            ) == .saved
        )

        #expect(try context.fetch(FetchDescriptor<InventoryMovementRecord>()).isEmpty)
    }

    private enum PersistenceFailure: Error {
        case expected
    }
}
