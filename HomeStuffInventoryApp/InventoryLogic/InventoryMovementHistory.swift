import Foundation
import SwiftData

enum InventoryMovementFailure: Error, Equatable {
    case cancelled
    case emptyOperation
    case duplicateItem
    case staleSource
    case unsafeRestoration
    case persistenceFailed
}

enum InventoryMovementUndoAvailability: Equatable {
    case available(operationID: UUID)
    case unavailable
    case accessRequired
    case currentStateChanged
    case unsafeRestoration
}

enum InventoryMovementUndoOutcome: Equatable {
    case undone(operationID: UUID)
    case accessRequired
    case unavailable
    case currentStateChanged
    case unsafeRestoration
    case failed
}

struct InventoryMovementRequest {
    let item: InventoryItem
    let expectedSource: InventoryMovementEndpointSnapshot
    let destination: InventoryMovementEndpointSnapshot
}

enum InventoryMovementHistory {
    static let defaultRetainedOperationLimit = 50

    @MainActor
    static func move(
        _ requests: [InventoryMovementRequest],
        origin: InventoryMovementOrigin,
        in modelContext: ModelContext,
        locations: [StorageLocation],
        operationID: UUID = UUID(),
        occurredAt: Date = .now,
        recordID: (Int) -> UUID = { _ in UUID() },
        retainedOperationLimit: Int = defaultRetainedOperationLimit,
        isCancelled: () -> Bool = { false },
        persist: (() throws -> Void)? = nil
    ) throws -> [InventoryMovementRecord] {
        guard !requests.isEmpty else {
            throw InventoryMovementFailure.emptyOperation
        }
        guard Set(requests.map(\.item.id)).count == requests.count else {
            throw InventoryMovementFailure.duplicateItem
        }
        guard !isCancelled() else {
            throw InventoryMovementFailure.cancelled
        }
        guard requests.allSatisfy({
            InventoryMovementEndpointSnapshot(item: $0.item, locations: locations) == $0.expectedSource
        }) else {
            throw InventoryMovementFailure.staleSource
        }

        let changedRequests = requests.filter { $0.expectedSource != $0.destination }
        guard !changedRequests.isEmpty else {
            return []
        }

        do {
            let records = changedRequests.enumerated().map { index, request in
                request.item.applyMovement(request.destination, updatedAt: occurredAt)
                let record = InventoryMovementRecord(
                    id: recordID(index),
                    operationID: operationID,
                    itemID: request.item.id,
                    occurredAt: occurredAt,
                    origin: origin,
                    source: request.expectedSource,
                    destination: request.destination
                )
                modelContext.insert(record)
                return record
            }
            try prune(
                records: try modelContext.fetch(FetchDescriptor<InventoryMovementRecord>()),
                keepingLatestOperations: retainedOperationLimit,
                delete: modelContext.delete
            )
            guard !isCancelled() else {
                modelContext.rollback()
                throw InventoryMovementFailure.cancelled
            }
            try (persist ?? modelContext.save)()
            return records
        } catch let failure as InventoryMovementFailure {
            throw failure
        } catch {
            modelContext.rollback()
            throw InventoryMovementFailure.persistenceFailed
        }
    }

    static func undoAvailability(
        records: [InventoryMovementRecord],
        items: [InventoryItem],
        locations: [StorageLocation],
        places: [InventoryPlace],
        entitlements: InventoryEntitlements,
        policy: PremiumAccessPolicy = PremiumAccessPolicy()
    ) -> InventoryMovementUndoAvailability {
        guard let operation = latestOperation(in: records),
              operation.records.allSatisfy({ $0.origin != .undo })
        else {
            return .unavailable
        }

        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard operation.records.allSatisfy({ record in
            guard let item = itemsByID[record.itemID] else { return false }
            return InventoryMovementEndpointSnapshot(item: item, locations: locations) == record.destination
        }) else {
            return .currentStateChanged
        }
        guard operation.records.allSatisfy({
            isRestorable($0.source, locations: locations, places: places)
        }) else {
            return .unsafeRestoration
        }
        guard policy.availability(of: .extendedMovementUndo, entitlements: entitlements) == .available else {
            return .accessRequired
        }

        return .available(operationID: operation.id)
    }

    @MainActor
    static func undoLatest(
        records _: [InventoryMovementRecord],
        items _: [InventoryItem],
        locations _: [StorageLocation],
        places _: [InventoryPlace],
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext,
        operationID: UUID = UUID(),
        occurredAt: Date = .now,
        recordID: (Int) -> UUID = { _ in UUID() },
        retainedOperationLimit: Int = defaultRetainedOperationLimit,
        policy: PremiumAccessPolicy = PremiumAccessPolicy(),
        persist: (() throws -> Void)? = nil
    ) -> InventoryMovementUndoOutcome {
        let authoritativeState: UndoState
        do {
            authoritativeState = try undoState(in: modelContext)
        } catch {
            return .failed
        }
        let availability = undoAvailability(
            records: authoritativeState.records,
            items: authoritativeState.items,
            locations: authoritativeState.locations,
            places: authoritativeState.places,
            entitlements: entitlements,
            policy: policy
        )
        guard case let .available(targetOperationID) = availability,
              let target = latestOperation(in: authoritativeState.records),
              target.id == targetOperationID
        else {
            return switch availability {
            case .accessRequired: .accessRequired
            case .currentStateChanged: .currentStateChanged
            case .unsafeRestoration: .unsafeRestoration
            case .available, .unavailable: .unavailable
            }
        }

        do {
            let commitState = try undoState(in: modelContext)
            let commitAvailability = undoAvailability(
                records: commitState.records,
                items: commitState.items,
                locations: commitState.locations,
                places: commitState.places,
                entitlements: entitlements,
                policy: policy
            )
            guard case let .available(commitTargetOperationID) = commitAvailability,
                  commitTargetOperationID == targetOperationID,
                  let commitTarget = latestOperation(in: commitState.records),
                  commitTarget.id == targetOperationID
            else {
                return switch commitAvailability {
                case .accessRequired: .accessRequired
                case .currentStateChanged: .currentStateChanged
                case .unsafeRestoration: .unsafeRestoration
                case .available, .unavailable: .unavailable
                }
            }

            let itemsByID = Dictionary(
                commitState.items.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            for (index, record) in commitTarget.records.enumerated() {
                guard let item = itemsByID[record.itemID] else {
                    modelContext.rollback()
                    return .currentStateChanged
                }
                item.applyMovement(record.source, updatedAt: occurredAt)
                modelContext.insert(
                    InventoryMovementRecord(
                        id: recordID(index),
                        operationID: operationID,
                        itemID: item.id,
                        occurredAt: occurredAt,
                        origin: .undo,
                        reversedOperationID: targetOperationID,
                        source: record.destination,
                        destination: record.source
                    )
                )
            }
            try prune(
                records: try modelContext.fetch(FetchDescriptor<InventoryMovementRecord>()),
                keepingLatestOperations: retainedOperationLimit,
                delete: modelContext.delete
            )
            try (persist ?? modelContext.save)()
            return .undone(operationID: targetOperationID)
        } catch {
            modelContext.rollback()
            return .failed
        }
    }

    @MainActor
    private static func undoState(in modelContext: ModelContext) throws -> UndoState {
        UndoState(
            records: try modelContext.fetch(FetchDescriptor<InventoryMovementRecord>()),
            items: try modelContext.fetch(FetchDescriptor<InventoryItem>()),
            locations: try modelContext.fetch(FetchDescriptor<StorageLocation>()),
            places: try modelContext.fetch(FetchDescriptor<InventoryPlace>())
        )
    }

    static func records(
        for itemID: UUID,
        from records: [InventoryMovementRecord]
    ) -> [InventoryMovementRecord] {
        records
            .filter { $0.itemID == itemID }
            .sorted(by: recordSort)
    }

    static func prune(
        records: [InventoryMovementRecord],
        keepingLatestOperations limit: Int,
        delete: (InventoryMovementRecord) -> Void
    ) throws {
        let operations = Dictionary(grouping: records, by: \.operationID)
            .map { operationID, records in
                (
                    id: operationID,
                    occurredAt: records.map(\.occurredAt).max() ?? .distantPast
                )
            }
            .sorted {
                if $0.occurredAt != $1.occurredAt {
                    return $0.occurredAt > $1.occurredAt
                }
                return $0.id.uuidString > $1.id.uuidString
            }
        let retainedIDs = Set(operations.prefix(max(0, limit)).map(\.id))
        records.filter { !retainedIDs.contains($0.operationID) }.forEach(delete)
    }

    private static func latestOperation(
        in records: [InventoryMovementRecord]
    ) -> (id: UUID, records: [InventoryMovementRecord])? {
        let grouped = Dictionary(grouping: records, by: \.operationID)
        return grouped
            .map { operationID, records in
                (id: operationID, records: records.sorted(by: recordSort))
            }
            .sorted {
                let lhsDate = $0.records.map(\.occurredAt).max() ?? .distantPast
                let rhsDate = $1.records.map(\.occurredAt).max() ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return $0.id.uuidString > $1.id.uuidString
            }
            .first
    }

    private struct UndoState {
        let records: [InventoryMovementRecord]
        let items: [InventoryItem]
        let locations: [StorageLocation]
        let places: [InventoryPlace]
    }

    private static func isRestorable(
        _ snapshot: InventoryMovementEndpointSnapshot,
        locations: [StorageLocation],
        places: [InventoryPlace]
    ) -> Bool {
        if let locationID = snapshot.locationID {
            guard locations.contains(where: {
                $0.id == locationID
                    && InventoryNormalizedName.location($0.name)
                    == InventoryNormalizedName.location(snapshot.locationName)
            }) else {
                return false
            }
        }
        if let placeID = snapshot.placeID {
            guard let place = places.first(where: { $0.id == placeID }),
                  place.locationID == snapshot.locationID,
                  InventoryNormalizedName.place(place.name)
                    == InventoryNormalizedName.place(snapshot.placeName ?? "")
            else {
                return false
            }
        }
        return true
    }

    private static func recordSort(
        _ lhs: InventoryMovementRecord,
        _ rhs: InventoryMovementRecord
    ) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt > rhs.occurredAt
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}
