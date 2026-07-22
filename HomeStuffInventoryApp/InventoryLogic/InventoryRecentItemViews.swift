import Foundation
import SwiftData

enum InventoryRecentItemViews {
    static let defaultRollingWindow: TimeInterval = 60 * 24 * 60 * 60

    @MainActor
    @discardableResult
    static func recordView(
        of item: InventoryItem,
        in modelContainer: ModelContainer,
        viewedAt: Date = .now,
        rollingWindow: TimeInterval = defaultRollingWindow
    ) throws -> InventoryItemViewEvent {
        try recordView(
            itemID: item.id,
            in: ModelContext(modelContainer),
            viewedAt: viewedAt,
            rollingWindow: rollingWindow
        )
    }

    @MainActor
    @discardableResult
    static func recordView(
        of item: InventoryItem,
        in modelContext: ModelContext,
        viewedAt: Date = .now,
        rollingWindow: TimeInterval = defaultRollingWindow
    ) throws -> InventoryItemViewEvent {
        try recordView(
            itemID: item.id,
            in: modelContext,
            viewedAt: viewedAt,
            rollingWindow: rollingWindow
        )
    }

    @MainActor
    @discardableResult
    private static func recordView(
        itemID: UUID,
        in modelContext: ModelContext,
        viewedAt: Date,
        rollingWindow: TimeInterval
    ) throws -> InventoryItemViewEvent {
        try deleteEvents(olderThan: cutoff(for: viewedAt, rollingWindow: rollingWindow), in: modelContext)

        let event = InventoryItemViewEvent(itemID: itemID, viewedAt: viewedAt)
        modelContext.insert(event)
        try modelContext.save()

        return event
    }

    @MainActor
    static func pruneOldEvents(
        in modelContext: ModelContext,
        now: Date = .now,
        rollingWindow: TimeInterval = defaultRollingWindow
    ) throws {
        let didDelete = try deleteEvents(
            olderThan: cutoff(for: now, rollingWindow: rollingWindow),
            in: modelContext
        )
        if didDelete {
            try modelContext.save()
        }
    }

    static func repairPersistedEvents(
        in modelContext: ModelContext,
        now: Date = .now,
        rollingWindow: TimeInterval = defaultRollingWindow
    ) throws {
        let cutoff = cutoff(for: now, rollingWindow: rollingWindow)
        let itemIDs = Set(try modelContext.fetch(FetchDescriptor<InventoryItem>()).map(\.id))
        let events = try modelContext.fetch(FetchDescriptor<InventoryItemViewEvent>())
        let eventsToDelete = events.filter { event in
            event.viewedAt < cutoff || !itemIDs.contains(event.itemID)
        }

        for event in eventsToDelete {
            modelContext.delete(event)
        }
        if !eventsToDelete.isEmpty {
            try modelContext.save()
        }
    }

    static func topItems(
        from items: [InventoryItem],
        events: [InventoryItemViewEvent],
        now: Date = .now,
        rollingWindow: TimeInterval = defaultRollingWindow,
        limit: Int = 3
    ) -> [InventoryItem] {
        guard limit > 0, rollingWindow > 0 else {
            return []
        }

        let scopedItemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let cutoff = cutoff(for: now, rollingWindow: rollingWindow)

        let statsByItemID = events.reduce(into: [UUID: ViewStats]()) { statsByItemID, event in
            guard scopedItemsByID[event.itemID] != nil,
                  event.viewedAt >= cutoff,
                  event.viewedAt <= now
            else {
                return
            }

            statsByItemID[event.itemID, default: ViewStats()].record(event.viewedAt)
        }

        return items
            .filter { statsByItemID[$0.id] != nil }
            .sorted { lhs, rhs in
                guard let lhsStats = statsByItemID[lhs.id],
                      let rhsStats = statsByItemID[rhs.id]
                else {
                    return lhs.id.uuidString < rhs.id.uuidString
                }

                if lhsStats.latestViewedAt != rhsStats.latestViewedAt {
                    return lhsStats.latestViewedAt > rhsStats.latestViewedAt
                }

                if lhsStats.viewCount != rhsStats.viewCount {
                    return lhsStats.viewCount > rhsStats.viewCount
                }

                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(limit)
            .map { $0 }
    }

    static func topItemIDs(
        from items: [InventoryItem],
        events: [InventoryItemViewEvent],
        now: Date = .now,
        rollingWindow: TimeInterval = defaultRollingWindow,
        limit: Int = 3
    ) -> [UUID] {
        topItems(
            from: items,
            events: events,
            now: now,
            rollingWindow: rollingWindow,
            limit: limit
        )
        .map(\.id)
    }

    private static func cutoff(for date: Date, rollingWindow: TimeInterval) -> Date {
        guard rollingWindow > 0 else {
            return date
        }

        return date.addingTimeInterval(-rollingWindow)
    }

    @MainActor
    private static func deleteEvents(olderThan cutoff: Date, in modelContext: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<InventoryItemViewEvent>(
            predicate: #Predicate<InventoryItemViewEvent> { event in
                event.viewedAt < cutoff
            }
        )

        let events = try modelContext.fetch(descriptor)
        for event in events {
            modelContext.delete(event)
        }
        return !events.isEmpty
    }
}

private struct ViewStats {
    var viewCount = 0
    var latestViewedAt = Date.distantPast

    mutating func record(_ viewedAt: Date) {
        viewCount += 1
        latestViewedAt = max(latestViewedAt, viewedAt)
    }
}
