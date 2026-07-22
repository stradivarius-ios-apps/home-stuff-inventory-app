import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryRecentItemViewsTests {
    @Test func rankingPrioritizesLatestRecentViewOverViewCount() {
        let now = Date(timeIntervalSince1970: 10_000)
        let batteries = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Batteries")
        let tape = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Tape")
        let charger = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Charger")

        let rankedItems = InventoryRecentItemViews.topItems(
            from: [batteries, tape, charger],
            events: [
                event(for: batteries, viewedAt: now.addingTimeInterval(-10)),
                event(for: tape, viewedAt: now.addingTimeInterval(-30)),
                event(for: tape, viewedAt: now.addingTimeInterval(-20)),
                event(for: tape, viewedAt: now.addingTimeInterval(-10)),
                event(for: charger, viewedAt: now.addingTimeInterval(-15)),
                event(for: charger, viewedAt: now.addingTimeInterval(-5))
            ],
            now: now,
            rollingWindow: 100,
            limit: 3
        )

        #expect(rankedItems.map(\.id) == [charger.id, tape.id, batteries.id])
    }

    @Test func rankingBreaksEqualLatestViewTimesByViewCountThenItemName() {
        let now = Date(timeIntervalSince1970: 10_000)
        let cable = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, name: "Cable")
        let adapter = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, name: "Adapter")
        let wrench = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, name: "Wrench")

        let rankedItems = InventoryRecentItemViews.topItems(
            from: [cable, adapter, wrench],
            events: [
                event(for: cable, viewedAt: now.addingTimeInterval(-20)),
                event(for: cable, viewedAt: now.addingTimeInterval(-30)),
                event(for: adapter, viewedAt: now.addingTimeInterval(-20)),
                event(for: wrench, viewedAt: now.addingTimeInterval(-5))
            ],
            now: now,
            rollingWindow: 100,
            limit: 3
        )

        #expect(rankedItems.map(\.id) == [wrench.id, cable.id, adapter.id])
    }

    @Test func rankingBreaksEqualLatestTimeAndCountByLocalizedItemNameThenUUID() {
        let now = Date(timeIntervalSince1970: 10_000)
        let omega = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000019")!, name: "Omega")
        let alphaLaterUUID = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!, name: "alpha")
        let alphaEarlierUUID = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, name: "Alpha")

        let rankedItems = InventoryRecentItemViews.topItems(
            from: [omega, alphaLaterUUID, alphaEarlierUUID],
            events: [
                event(for: omega, viewedAt: now.addingTimeInterval(-10)),
                event(for: alphaLaterUUID, viewedAt: now.addingTimeInterval(-10)),
                event(for: alphaEarlierUUID, viewedAt: now.addingTimeInterval(-10))
            ],
            now: now,
            rollingWindow: 100,
            limit: 3
        )

        #expect(rankedItems.map(\.id) == [alphaEarlierUUID.id, alphaLaterUUID.id, omega.id])
    }

    @Test func rankingIgnoresEventsOutsideRollingWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let oldFavorite = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, name: "Old favorite")
        let recentItem = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, name: "Recent item")

        let rankedItems = InventoryRecentItemViews.topItems(
            from: [oldFavorite, recentItem],
            events: [
                event(for: oldFavorite, viewedAt: now.addingTimeInterval(-200)),
                event(for: oldFavorite, viewedAt: now.addingTimeInterval(-190)),
                event(for: oldFavorite, viewedAt: now.addingTimeInterval(-180)),
                event(for: recentItem, viewedAt: now.addingTimeInterval(-10))
            ],
            now: now,
            rollingWindow: 100,
            limit: 3
        )

        #expect(rankedItems.map(\.id) == [recentItem.id])
    }

    @Test func rankingIgnoresEventsForMissingItems() {
        let now = Date(timeIntervalSince1970: 10_000)
        let visibleItem = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!, name: "Visible item")
        let deletedItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!

        let rankedItems = InventoryRecentItemViews.topItems(
            from: [visibleItem],
            events: [
                InventoryItemViewEvent(itemID: deletedItemID, viewedAt: now.addingTimeInterval(-10)),
                InventoryItemViewEvent(itemID: deletedItemID, viewedAt: now.addingTimeInterval(-9)),
                InventoryItemViewEvent(itemID: deletedItemID, viewedAt: now.addingTimeInterval(-8)),
                event(for: visibleItem, viewedAt: now.addingTimeInterval(-20))
            ],
            now: now,
            rollingWindow: 100,
            limit: 3
        )

        #expect(rankedItems.map(\.id) == [visibleItem.id])
    }

    @Test func rankingIgnoresFutureAndOutOfScopeEvents() {
        let now = Date(timeIntervalSince1970: 10_000)
        let scopedItem = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000033")!, name: "Scoped item")
        let outOfScopeItem = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000034")!, name: "Out of scope item")

        let rankedItems = InventoryRecentItemViews.topItems(
            from: [scopedItem],
            events: [
                event(for: scopedItem, viewedAt: now.addingTimeInterval(1)),
                event(for: outOfScopeItem, viewedAt: now),
                event(for: scopedItem, viewedAt: now.addingTimeInterval(-10))
            ],
            now: now,
            rollingWindow: 100,
            limit: 3
        )

        #expect(rankedItems.map(\.id) == [scopedItem.id])
    }

    @Test func rankingReturnsNoItemsForNonPositiveRollingWindow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let batteries = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!, name: "Batteries")

        #expect(
            InventoryRecentItemViews.topItems(
                from: [batteries],
                events: [event(for: batteries, viewedAt: now)],
                now: now,
                rollingWindow: 0,
                limit: 3
            )
            .isEmpty
        )

        #expect(
            InventoryRecentItemViews.topItems(
                from: [batteries],
                events: [event(for: batteries, viewedAt: now.addingTimeInterval(-1))],
                now: now,
                rollingWindow: -1,
                limit: 3
            )
            .isEmpty
        )
    }

    @Test func rankingReturnsNoItemsForNonPositiveLimit() {
        let now = Date(timeIntervalSince1970: 10_000)
        let batteries = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!, name: "Batteries")

        #expect(
            InventoryRecentItemViews.topItems(
                from: [batteries],
                events: [event(for: batteries, viewedAt: now)],
                now: now,
                rollingWindow: 100,
                limit: 0
            )
            .isEmpty
        )
    }

    @Test func recordViewPersistsCurrentEventAndPrunesOldEvents() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 10_000)
        let item = item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!, name: "Flashlight")
        let oldEvent = event(for: item, viewedAt: now.addingTimeInterval(-200))

        context.insert(item)
        context.insert(oldEvent)
        try context.save()

        try InventoryRecentItemViews.recordView(
            of: item,
            in: context,
            viewedAt: now,
            rollingWindow: 100
        )

        let events = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())

        #expect(events.count == 1)
        #expect(events.first?.itemID == item.id)
        #expect(events.first?.viewedAt == now)
    }

    @Test func maintenanceRemovesOnlyOrphanAndExpiredEvents() throws {
        let context = try modelContext()
        let now = Date(timeIntervalSince1970: 10_000)
        let item = item(id: UUID(), name: "Flashlight")
        let validAtCutoff = event(for: item, viewedAt: now.addingTimeInterval(-100))
        let validRecent = event(for: item, viewedAt: now.addingTimeInterval(-1))
        let validFuture = event(for: item, viewedAt: now.addingTimeInterval(1))
        let expired = event(for: item, viewedAt: now.addingTimeInterval(-101))
        let orphan = InventoryItemViewEvent(itemID: UUID(), viewedAt: now)
        context.insert(item)
        [validAtCutoff, validRecent, validFuture, expired, orphan].forEach(context.insert)
        try context.save()

        try InventoryRecentItemViews.repairPersistedEvents(in: context, now: now, rollingWindow: 100)

        #expect(Set(try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).map(\.id)) == Set([
            validAtCutoff.id,
            validRecent.id,
            validFuture.id
        ]))
    }

    @Test func maintenanceIsIdempotentWhenNoEventsNeedRepair() throws {
        let context = try modelContext()
        let now = Date(timeIntervalSince1970: 10_000)
        let item = item(id: UUID(), name: "Flashlight")
        let validEvent = event(for: item, viewedAt: now)
        context.insert(item)
        context.insert(validEvent)
        try context.save()

        try InventoryRecentItemViews.repairPersistedEvents(in: context, now: now, rollingWindow: 100)
        try InventoryRecentItemViews.repairPersistedEvents(in: context, now: now, rollingWindow: 100)

        #expect(try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).map(\.id) == [validEvent.id])
    }

    private func modelContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private func item(id: UUID, name: String) -> InventoryItem {
        InventoryItem(id: id, name: name, locationName: "Hall closet")
    }

    private func event(for item: InventoryItem, viewedAt: Date) -> InventoryItemViewEvent {
        InventoryItemViewEvent(itemID: item.id, viewedAt: viewedAt)
    }
}
