import Foundation
import SwiftData

enum InventoryPlaceOpenPersistenceError: Error, Equatable {
    case saveFailed
}

enum InventoryPlaceOpenPersistence {
    typealias SaveOperation = @MainActor (ModelContext) throws -> Void

    @MainActor
    @discardableResult
    static func recordOpen(
        for identity: InventoryPlaceIdentity,
        placeID: UUID? = nil,
        in context: ModelContext,
        now: Date = .now,
        save: SaveOperation = { try $0.save() }
    ) throws -> InventoryPlaceOpenRecord {
        let records = try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>())
        let matching = records.filter { record in
            if let placeID { return record.placeID == placeID || (record.placeID == nil && record.placeIdentity == identity.rawValue) }
            return record.placeIdentity == identity.rawValue
        }
        let record: InventoryPlaceOpenRecord
        let original: (Int, Date)?

        if let existing = matching.sorted(by: { $0.id.uuidString < $1.id.uuidString }).first {
            record = existing
            original = (existing.openCount, existing.lastOpenedAt)
            existing.openCount = saturatedIncrement(existing.openCount)
            existing.lastOpenedAt = now
            if existing.placeID == nil { existing.placeID = placeID }
            if placeID != nil { existing.placeIdentity = identity.rawValue }
        } else {
            record = InventoryPlaceOpenRecord(placeIdentity: identity.rawValue, placeID: placeID, openCount: 1, lastOpenedAt: now)
            original = nil
            context.insert(record)
        }

        do {
            try save(context)
            return record
        } catch {
            if let original {
                record.openCount = original.0
                record.lastOpenedAt = original.1
            } else {
                context.delete(record)
            }
            context.rollback()
            throw InventoryPlaceOpenPersistenceError.saveFailed
        }
    }

    @MainActor
    static func repairPersistedRecords(in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>())
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let validLegacyIdentities = Set(items.map(InventoryPlaceIdentity.make(for:)).map(\.rawValue))
        let locationsByID = Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) })
        let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        let placesByLegacyIdentity = Dictionary(uniqueKeysWithValues: places.compactMap { place -> (String, InventoryPlace)? in
            guard let location = locationsByID[place.locationID] else { return nil }
            return (InventoryPlaceIdentity.make(locationName: location.name, placeName: place.name).rawValue, place)
        })
        var associatedLegacyRecord = false
        let grouped = Dictionary(grouping: records.compactMap { record -> (String, InventoryPlaceOpenRecord)? in
            if let placeID = record.placeID, placesByID[placeID] != nil { return ("place:\(placeID.uuidString)", record) }
            if let place = placesByLegacyIdentity[record.placeIdentity] {
                associatedLegacyRecord = associatedLegacyRecord || record.placeID != place.id
                record.placeID = place.id
                return ("place:\(place.id.uuidString)", record)
            }
            return validLegacyIdentities.contains(record.placeIdentity) ? ("legacy:\(record.placeIdentity)", record) : nil
        }, by: \.0)
        var changed = associatedLegacyRecord

        let retained = Set(grouped.values.flatMap { $0.map(\.1.id) })
        for record in records where !retained.contains(record.id) {
            context.delete(record)
            changed = true
        }
        for entries in grouped.values {
            let group = entries.map(\.1)
            let ordered = group.sorted { $0.id.uuidString < $1.id.uuidString }
            guard let keeper = ordered.first else { continue }
            let count = group.reduce(0) { saturatedAdd($0, max(0, $1.openCount)) }
            let newest = group.map(\.lastOpenedAt).max() ?? keeper.lastOpenedAt
            if keeper.openCount != count || keeper.lastOpenedAt != newest {
                keeper.openCount = count
                keeper.lastOpenedAt = newest
                changed = true
            }
            for duplicate in ordered.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        if changed { try context.save() }
    }

    static func saturatedIncrement(_ value: Int) -> Int { saturatedAdd(max(0, value), 1) }

    static func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
        guard lhs > 0 else { return max(0, rhs) }
        guard rhs > 0 else { return lhs }
        return lhs > Int.max - rhs ? Int.max : lhs + rhs
    }
}

@MainActor
final class InventoryPlaceOpenRegistration {
    private var hasRegistered = false

    func registerIfNeeded(
        identity: InventoryPlaceIdentity,
        placeID: UUID? = nil,
        in context: ModelContext,
        now: Date = .now,
        save: InventoryPlaceOpenPersistence.SaveOperation = { try $0.save() }
    ) throws {
        guard !hasRegistered else { return }
        try InventoryPlaceOpenPersistence.recordOpen(for: identity, placeID: placeID, in: context, now: now, save: save)
        hasRegistered = true
    }
}
