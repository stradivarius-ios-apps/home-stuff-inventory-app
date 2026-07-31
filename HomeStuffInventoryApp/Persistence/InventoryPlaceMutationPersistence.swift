import Foundation
import SwiftData

enum InventoryPlaceMutationError: Error, Equatable {
    case accessRequired
    case emptyName
    case missingPlace
    case missingLocation
    case staleState
    case missingParent
    case crossLocationParent
    case descendantCycle
    case duplicateSiblingName(String)
    case containsChildren(Int)
    case containsItems(Int)
    case persistenceFailed
}

enum InventoryPlaceMutationUndoAvailability: Equatable {
    case available(operationID: UUID)
    case unavailable
    case accessRequired
    case currentStateChanged
    case unsafeRestoration
}

enum InventoryPlaceMutationUndoOutcome: Equatable {
    case undone(operationID: UUID)
    case unavailable
    case accessRequired
    case currentStateChanged
    case unsafeRestoration
    case failed
}

struct InventoryPlaceMutationExpectation: Equatable {
    let id: UUID
    let locationID: UUID
    let parentPlaceID: UUID?
    let name: String
    let iconID: String?
    let updatedAt: Date

    init(place: InventoryPlace) {
        id = place.id
        locationID = place.locationID
        parentPlaceID = place.parentPlaceID
        name = place.name
        iconID = place.iconID
        updatedAt = place.updatedAt
    }

    fileprivate func matches(_ place: InventoryPlace) -> Bool {
        id == place.id
            && locationID == place.locationID
            && parentPlaceID == place.parentPlaceID
            && name == place.name
            && iconID == place.iconID
            && updatedAt == place.updatedAt
    }
}

struct InventoryPlaceSubtreeContentsExpectation: Equatable {
    let descendants: [InventoryPlaceMutationExpectation]
    let affectedItemIDs: [UUID]
}

enum InventoryPlaceMutationPersistence {
    static let defaultRetainedOperationLimit = 50

    @MainActor
    static func createChild(
        named name: String,
        iconID: String? = nil,
        under parentExpectation: InventoryPlaceMutationExpectation,
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext,
        createdAt: Date = .now,
        persist: (() throws -> Void)? = nil
    ) throws -> InventoryPlace {
        try requireHierarchyAccess(entitlements)
        let normalizedName = try validatedName(name)

        do {
            let state = try authoritativeState(in: modelContext)
            guard let parent = state.placesByID[parentExpectation.id] else {
                throw InventoryPlaceMutationError.missingPlace
            }
            guard parentExpectation.matches(parent) else {
                throw InventoryPlaceMutationError.staleState
            }
            guard state.locationsByID[parent.locationID] != nil else {
                throw InventoryPlaceMutationError.missingLocation
            }
            try validateCompleteAncestry(
                of: parent,
                locationID: parent.locationID,
                placesByID: state.placesByID
            )
            try requireUniqueSiblingName(
                normalizedName,
                locationID: parent.locationID,
                parentPlaceID: parent.id,
                excluding: nil,
                places: state.places
            )

            let child = InventoryPlace(
                locationID: parent.locationID,
                parentPlaceID: parent.id,
                name: normalizedName,
                iconID: iconID,
                createdAt: createdAt
            )
            modelContext.insert(child)
            try (persist ?? modelContext.save)()
            return child
        } catch let error as InventoryPlaceMutationError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw InventoryPlaceMutationError.persistenceFailed
        }
    }

    @MainActor
    static func rename(
        _ expectation: InventoryPlaceMutationExpectation,
        to name: String,
        iconID: String?,
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext,
        updatedAt: Date = .now,
        persist: (() throws -> Void)? = nil
    ) throws {
        let normalizedName = try validatedName(name)

        do {
            let state = try authoritativeState(in: modelContext)
            guard let place = state.placesByID[expectation.id] else {
                throw InventoryPlaceMutationError.missingPlace
            }
            guard expectation.matches(place) else {
                throw InventoryPlaceMutationError.staleState
            }
            if participatesInHierarchy(place, places: state.places) {
                try requireHierarchyAccess(entitlements)
            }
            try requireUniqueSiblingName(
                normalizedName,
                locationID: place.locationID,
                parentPlaceID: place.parentPlaceID,
                excluding: place.id,
                places: state.places
            )

            let normalizedIconID = PlaceIconCatalog.normalizedIconID(iconID)
            guard place.name != normalizedName || place.iconID != normalizedIconID else {
                return
            }
            let previousName = place.name
            place.name = normalizedName
            place.iconID = normalizedIconID
            place.updatedAt = updatedAt

            for item in directItems(
                in: place,
                previousName: previousName,
                locationsByID: state.locationsByID,
                items: state.items
            ) {
                item.containerName = normalizedName
                item.placeID = place.id
                item.updatedAt = updatedAt
            }
            try (persist ?? modelContext.save)()
        } catch let error as InventoryPlaceMutationError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw InventoryPlaceMutationError.persistenceFailed
        }
    }

    @MainActor
    static func moveSubtree(
        _ expectation: InventoryPlaceMutationExpectation,
        toLocationID destinationLocationID: UUID,
        parentPlaceID destinationParentPlaceID: UUID?,
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext,
        contentsExpectation: InventoryPlaceSubtreeContentsExpectation? = nil,
        operationID: UUID = UUID(),
        occurredAt: Date = .now,
        retainedOperationLimit: Int = defaultRetainedOperationLimit,
        persist: (() throws -> Void)? = nil
    ) throws -> InventoryPlaceMutationRecord? {
        try requireHierarchyAccess(entitlements)

        do {
            let state = try authoritativeState(in: modelContext)
            guard let root = state.placesByID[expectation.id] else {
                throw InventoryPlaceMutationError.missingPlace
            }
            guard expectation.matches(root) else {
                throw InventoryPlaceMutationError.staleState
            }
            guard let destinationLocation = state.locationsByID[destinationLocationID] else {
                throw InventoryPlaceMutationError.missingLocation
            }

            let subtree = subtreeRooted(at: root.id, places: state.places)
            let subtreeIDs = Set(subtree.map(\.id))
            if let contentsExpectation {
                let currentDescendants = subtree
                    .filter { $0.id != root.id }
                    .map(InventoryPlaceMutationExpectation.init)
                    .sorted { $0.id.uuidString < $1.id.uuidString }
                guard currentDescendants == contentsExpectation.descendants else {
                    throw InventoryPlaceMutationError.staleState
                }
            }
            for place in subtree {
                try validateCompleteAncestry(
                    of: place,
                    locationID: root.locationID,
                    placesByID: state.placesByID
                )
            }
            if let destinationParentPlaceID {
                guard let parent = state.placesByID[destinationParentPlaceID] else {
                    throw InventoryPlaceMutationError.missingParent
                }
                guard parent.locationID == destinationLocationID else {
                    throw InventoryPlaceMutationError.crossLocationParent
                }
                guard !subtreeIDs.contains(parent.id) else {
                    throw InventoryPlaceMutationError.descendantCycle
                }
                try validateCompleteAncestry(
                    of: parent,
                    locationID: destinationLocationID,
                    placesByID: state.placesByID
                )
            }
            try requireUniqueSiblingName(
                root.name,
                locationID: destinationLocationID,
                parentPlaceID: destinationParentPlaceID,
                excluding: root.id,
                places: state.places
            )

            guard root.locationID != destinationLocationID
                    || root.parentPlaceID != destinationParentPlaceID
            else {
                return nil
            }

            let movingItems = state.items.filter { item in
                item.placeID.map(subtreeIDs.contains) == true
                    || legacyItem(item, directlyUses: root, locationsByID: state.locationsByID)
            }
            if let contentsExpectation {
                let currentAffectedItemIDs = movingItems
                    .map(\.id)
                    .sorted { $0.uuidString < $1.uuidString }
                guard currentAffectedItemIDs == contentsExpectation.affectedItemIDs else {
                    throw InventoryPlaceMutationError.staleState
                }
            }
            let before = InventoryPlaceMutationSnapshot(
                rootPlaceID: root.id,
                places: subtree,
                items: movingItems
            )
            for item in movingItems {
                let placeID = item.placeID ?? root.id
                item.applyMovement(
                    InventoryMovementEndpointSnapshot(
                        locationID: destinationLocation.id,
                        locationName: destinationLocation.name,
                        placeID: placeID,
                        placeName: state.placesByID[placeID]?.name ?? root.name
                    ),
                    updatedAt: occurredAt
                )
            }

            root.parentPlaceID = destinationParentPlaceID
            for place in subtree {
                place.locationID = destinationLocationID
                place.updatedAt = occurredAt
            }
            let after = InventoryPlaceMutationSnapshot(
                rootPlaceID: root.id,
                places: subtree,
                items: movingItems
            )
            let record = try InventoryPlaceMutationRecord(
                id: operationID,
                occurredAt: occurredAt,
                before: before,
                after: after
            )
            modelContext.insert(record)
            try prune(
                records: try modelContext.fetch(FetchDescriptor<InventoryPlaceMutationRecord>()),
                keepingLatestOperations: retainedOperationLimit,
                delete: modelContext.delete
            )
            try (persist ?? modelContext.save)()
            return record
        } catch let error as InventoryPlaceMutationError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw InventoryPlaceMutationError.persistenceFailed
        }
    }

    @MainActor
    static func delete(
        _ expectation: InventoryPlaceMutationExpectation,
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext,
        persist: (() throws -> Void)? = nil
    ) throws {
        do {
            let state = try authoritativeState(in: modelContext)
            guard let place = state.placesByID[expectation.id] else {
                throw InventoryPlaceMutationError.missingPlace
            }
            guard expectation.matches(place) else {
                throw InventoryPlaceMutationError.staleState
            }
            if participatesInHierarchy(place, places: state.places) {
                try requireHierarchyAccess(entitlements)
            }

            let childCount = state.places.filter { $0.parentPlaceID == place.id }.count
            guard childCount == 0 else {
                throw InventoryPlaceMutationError.containsChildren(childCount)
            }
            let itemCount = directItems(
                in: place,
                previousName: place.name,
                locationsByID: state.locationsByID,
                items: state.items
            ).count
            guard itemCount == 0 else {
                throw InventoryPlaceMutationError.containsItems(itemCount)
            }

            modelContext.delete(place)
            try (persist ?? modelContext.save)()
        } catch let error as InventoryPlaceMutationError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw InventoryPlaceMutationError.persistenceFailed
        }
    }

    @MainActor
    static func undoLatestAvailability(
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext
    ) -> InventoryPlaceMutationUndoAvailability {
        do {
            guard let record = try latestActiveRecord(in: modelContext) else {
                return .unavailable
            }
            guard let after = record.afterSnapshot,
                  let before = record.beforeSnapshot
            else {
                return .unsafeRestoration
            }
            let state = try authoritativeState(in: modelContext)
            guard snapshotMatchesAuthoritativeState(after, state: state) else {
                return .currentStateChanged
            }
            guard restorationIsSafe(before, state: state) else {
                return .unsafeRestoration
            }
            guard PremiumAccessPolicy().availability(
                of: .extendedMovementUndo,
                entitlements: entitlements
            ) == .available else {
                return .accessRequired
            }
            return .available(operationID: record.id)
        } catch {
            return .unsafeRestoration
        }
    }

    @MainActor
    static func undoLatest(
        entitlements: InventoryEntitlements,
        in modelContext: ModelContext,
        occurredAt: Date = .now,
        persist: (() throws -> Void)? = nil
    ) -> InventoryPlaceMutationUndoOutcome {
        let availability = undoLatestAvailability(
            entitlements: entitlements,
            in: modelContext
        )
        guard case let .available(operationID) = availability else {
            return undoOutcome(for: availability)
        }

        do {
            guard let record = try latestActiveRecord(in: modelContext),
                  record.id == operationID,
                  let before = record.beforeSnapshot,
                  let after = record.afterSnapshot
            else {
                return .currentStateChanged
            }
            let state = try authoritativeState(in: modelContext)
            guard snapshotMatchesAuthoritativeState(after, state: state) else {
                return .currentStateChanged
            }
            guard restorationIsSafe(before, state: state) else {
                return .unsafeRestoration
            }

            for snapshot in before.places {
                guard let place = state.placesByID[snapshot.id] else {
                    modelContext.rollback()
                    return .currentStateChanged
                }
                place.locationID = snapshot.locationID
                place.parentPlaceID = snapshot.parentPlaceID
                place.name = snapshot.name
                place.iconID = snapshot.iconID
                place.updatedAt = snapshot.updatedAt
            }
            let itemsByID = Dictionary(
                state.items.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            for snapshot in before.items {
                guard let item = itemsByID[snapshot.id] else {
                    modelContext.rollback()
                    return .currentStateChanged
                }
                item.locationName = snapshot.locationName
                item.containerName = snapshot.containerName
                item.placeID = snapshot.placeID
                item.updatedAt = snapshot.updatedAt
            }
            record.undoneAt = occurredAt
            try (persist ?? modelContext.save)()
            return .undone(operationID: operationID)
        } catch {
            modelContext.rollback()
            return .failed
        }
    }

    private struct State {
        let locationsByID: [UUID: StorageLocation]
        let places: [InventoryPlace]
        let placesByID: [UUID: InventoryPlace]
        let items: [InventoryItem]
    }

    @MainActor
    private static func authoritativeState(in modelContext: ModelContext) throws -> State {
        let locations = try modelContext.fetch(FetchDescriptor<StorageLocation>())
        let places = try modelContext.fetch(FetchDescriptor<InventoryPlace>())
        return State(
            locationsByID: Dictionary(locations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            places: places,
            placesByID: Dictionary(places.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            items: try modelContext.fetch(FetchDescriptor<InventoryItem>())
        )
    }

    private static func requireHierarchyAccess(_ entitlements: InventoryEntitlements) throws {
        guard PremiumAccessPolicy().availability(
            of: .storageHierarchyEditing,
            entitlements: entitlements
        ) == .available else {
            throw InventoryPlaceMutationError.accessRequired
        }
    }

    private static func validatedName(_ name: String) throws -> String {
        let normalized = InventoryNormalizedName.place(name)
        guard !normalized.isMissing else {
            throw InventoryPlaceMutationError.emptyName
        }
        return normalized.displayName
    }

    private static func requireUniqueSiblingName(
        _ name: String,
        locationID: UUID,
        parentPlaceID: UUID?,
        excluding excludedID: UUID?,
        places: [InventoryPlace]
    ) throws {
        let normalized = InventoryNormalizedName.place(name)
        if places.contains(where: {
            $0.id != excludedID
                && $0.locationID == locationID
                && $0.parentPlaceID == parentPlaceID
                && InventoryNormalizedName.place($0.name) == normalized
        }) {
            throw InventoryPlaceMutationError.duplicateSiblingName(normalized.displayName)
        }
    }

    private static func participatesInHierarchy(
        _ place: InventoryPlace,
        places: [InventoryPlace]
    ) -> Bool {
        place.parentPlaceID != nil || places.contains { $0.parentPlaceID == place.id }
    }

    private static func validateCompleteAncestry(
        of place: InventoryPlace,
        locationID: UUID,
        placesByID: [UUID: InventoryPlace]
    ) throws {
        var current = place
        var visited = Set<UUID>()
        while true {
            guard visited.insert(current.id).inserted else {
                throw InventoryPlaceMutationError.descendantCycle
            }
            guard current.locationID == locationID else {
                throw InventoryPlaceMutationError.crossLocationParent
            }
            guard let parentID = current.parentPlaceID else {
                return
            }
            guard let parent = placesByID[parentID] else {
                throw InventoryPlaceMutationError.missingParent
            }
            current = parent
        }
    }

    private static func subtreeRooted(
        at rootID: UUID,
        places: [InventoryPlace]
    ) -> [InventoryPlace] {
        let children = Dictionary(grouping: places, by: \.parentPlaceID)
        var result: [InventoryPlace] = []
        var pending = [rootID]
        var visited = Set<UUID>()
        while let id = pending.popLast(), visited.insert(id).inserted {
            guard let place = places.first(where: { $0.id == id }) else { continue }
            result.append(place)
            pending.append(contentsOf: (children[id] ?? []).map(\.id))
        }
        return result
    }

    private static func directItems(
        in place: InventoryPlace,
        previousName: String,
        locationsByID: [UUID: StorageLocation],
        items: [InventoryItem]
    ) -> [InventoryItem] {
        items.filter { item in
            item.placeID == place.id
                || (
                    item.placeID == nil
                        && place.parentPlaceID == nil
                        && InventoryNormalizedName.place(item.containerName)
                            == InventoryNormalizedName.place(previousName)
                        && locationsByID[place.locationID].map { location in
                            InventoryNormalizedName.location(location.name)
                                == InventoryNormalizedName.location(item.locationName)
                        } == true
                )
        }
    }

    private static func legacyItem(
        _ item: InventoryItem,
        directlyUses place: InventoryPlace,
        locationsByID: [UUID: StorageLocation]
    ) -> Bool {
        item.placeID == nil
            && place.parentPlaceID == nil
            && InventoryNormalizedName.place(item.containerName)
                == InventoryNormalizedName.place(place.name)
            && locationsByID[place.locationID].map { location in
                InventoryNormalizedName.location(location.name)
                    == InventoryNormalizedName.location(item.locationName)
            } == true
    }

    @MainActor
    private static func latestActiveRecord(
        in modelContext: ModelContext
    ) throws -> InventoryPlaceMutationRecord? {
        try modelContext.fetch(FetchDescriptor<InventoryPlaceMutationRecord>())
            .filter { $0.undoneAt == nil }
            .sorted {
                if $0.occurredAt != $1.occurredAt {
                    return $0.occurredAt > $1.occurredAt
                }
                return $0.id.uuidString > $1.id.uuidString
            }
            .first
    }

    private static func snapshotMatchesAuthoritativeState(
        _ snapshot: InventoryPlaceMutationSnapshot,
        state: State
    ) -> Bool {
        guard state.placesByID[snapshot.rootPlaceID] != nil else {
            return false
        }
        let expectedPlaceIDs = Set(snapshot.places.map(\.id))
        let currentSubtreeIDs = Set(
            subtreeRooted(at: snapshot.rootPlaceID, places: state.places).map(\.id)
        )
        guard snapshot.places.allSatisfy({ state.locationsByID[$0.locationID] != nil }),
              currentSubtreeIDs == expectedPlaceIDs,
              snapshot.places.allSatisfy({ placeSnapshot in
                  state.placesByID[placeSnapshot.id].map {
                      placeSnapshot == InventoryPlaceMutationPlaceSnapshot(place: $0)
                  } == true
              })
        else {
            return false
        }

        for place in snapshot.places {
            guard let parentID = place.parentPlaceID,
                  !expectedPlaceIDs.contains(parentID)
            else {
                continue
            }
            guard let parent = state.placesByID[parentID],
                  parent.locationID == place.locationID,
                  (try? validateCompleteAncestry(
                      of: parent,
                      locationID: place.locationID,
                      placesByID: state.placesByID
                  )) != nil
            else {
                return false
            }
        }

        let root = state.placesByID[snapshot.rootPlaceID]!
        let currentItems = state.items.filter { item in
            item.placeID.map(expectedPlaceIDs.contains) == true
                || legacyItem(item, directlyUses: root, locationsByID: state.locationsByID)
        }
        let expectedItemIDs = Set(snapshot.items.map(\.id))
        guard Set(currentItems.map(\.id)) == expectedItemIDs else {
            return false
        }
        let itemsByID = Dictionary(
            currentItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return snapshot.items.allSatisfy { itemSnapshot in
            itemsByID[itemSnapshot.id].map {
                itemSnapshot == InventoryPlaceMutationItemSnapshot(item: $0)
            } == true
        }
    }

    private static func restorationIsSafe(
        _ snapshot: InventoryPlaceMutationSnapshot,
        state: State
    ) -> Bool {
        let snapshotPlacesByID = Dictionary(
            snapshot.places.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard snapshot.places.allSatisfy({
            state.locationsByID[$0.locationID] != nil
                && state.placesByID[$0.id] != nil
        }) else {
            return false
        }

        for place in snapshot.places {
            guard let parentID = place.parentPlaceID else { continue }
            if let parent = snapshotPlacesByID[parentID] {
                guard parent.locationID == place.locationID else {
                    return false
                }
            } else {
                guard let parent = state.placesByID[parentID],
                      parent.locationID == place.locationID,
                      (try? validateCompleteAncestry(
                          of: parent,
                          locationID: place.locationID,
                          placesByID: state.placesByID
                      )) != nil
                else {
                    return false
                }
            }
        }

        guard let root = snapshotPlacesByID[snapshot.rootPlaceID] else {
            return false
        }
        let rootName = InventoryNormalizedName.place(root.name)
        guard !state.places.contains(where: {
            $0.id != root.id
                && $0.locationID == root.locationID
                && $0.parentPlaceID == root.parentPlaceID
                && InventoryNormalizedName.place($0.name) == rootName
        }) else {
            return false
        }
        let snapshotPlaceIDs = Set(snapshot.places.map(\.id))
        return snapshot.items.allSatisfy { item in
            if let placeID = item.placeID {
                return snapshotPlaceIDs.contains(placeID)
            }
            guard root.parentPlaceID == nil,
                  let location = state.locationsByID[root.locationID]
            else {
                return false
            }
            return InventoryNormalizedName.place(item.containerName)
                    == InventoryNormalizedName.place(root.name)
                && InventoryNormalizedName.location(item.locationName)
                    == InventoryNormalizedName.location(location.name)
        }
    }

    private static func prune(
        records: [InventoryPlaceMutationRecord],
        keepingLatestOperations limit: Int,
        delete: (InventoryPlaceMutationRecord) -> Void
    ) throws {
        let retainedIDs = Set(
            records.sorted {
                if $0.occurredAt != $1.occurredAt {
                    return $0.occurredAt > $1.occurredAt
                }
                return $0.id.uuidString > $1.id.uuidString
            }
            .prefix(max(0, limit))
            .map(\.id)
        )
        records.filter { !retainedIDs.contains($0.id) }.forEach(delete)
    }

    private static func undoOutcome(
        for availability: InventoryPlaceMutationUndoAvailability
    ) -> InventoryPlaceMutationUndoOutcome {
        switch availability {
        case .available:
            .unavailable
        case .unavailable:
            .unavailable
        case .accessRequired:
            .accessRequired
        case .currentStateChanged:
            .currentStateChanged
        case .unsafeRestoration:
            .unsafeRestoration
        }
    }
}
