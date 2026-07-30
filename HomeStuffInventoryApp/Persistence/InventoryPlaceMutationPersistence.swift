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

enum InventoryPlaceMutationPersistence {
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
            if place.parentPlaceID != nil {
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
        operationID: UUID = UUID(),
        occurredAt: Date = .now,
        retainedOperationLimit: Int = InventoryMovementHistory.defaultRetainedOperationLimit,
        persist: (() throws -> Void)? = nil
    ) throws -> [InventoryMovementRecord] {
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
                return []
            }

            let movingItems = state.items.filter { item in
                item.placeID.map(subtreeIDs.contains) == true
                    || legacyItem(item, directlyUses: root, locationsByID: state.locationsByID)
            }
            let requests = movingItems.map { item in
                InventoryMovementRequest(
                    item: item,
                    expectedSource: InventoryMovementEndpointSnapshot(
                        item: item,
                        locations: Array(state.locationsByID.values)
                    ),
                    destination: InventoryMovementEndpointSnapshot(
                        locationID: destinationLocation.id,
                        locationName: destinationLocation.name,
                        placeID: item.placeID ?? root.id,
                        placeName: state.placesByID[item.placeID ?? root.id]?.name ?? root.name
                    )
                )
            }

            let records: [InventoryMovementRecord]
            if requests.isEmpty || root.locationID == destinationLocationID {
                records = []
            } else {
                records = try InventoryMovementHistory.move(
                    requests,
                    origin: .hierarchySubtree,
                    in: modelContext,
                    locations: Array(state.locationsByID.values),
                    operationID: operationID,
                    occurredAt: occurredAt,
                    retainedOperationLimit: retainedOperationLimit,
                    persist: {}
                )
            }

            root.parentPlaceID = destinationParentPlaceID
            for place in subtree {
                place.locationID = destinationLocationID
                place.updatedAt = occurredAt
            }
            try (persist ?? modelContext.save)()
            return records
        } catch let error as InventoryPlaceMutationError {
            modelContext.rollback()
            throw error
        } catch let error as InventoryMovementFailure {
            modelContext.rollback()
            switch error {
            case .staleSource:
                throw InventoryPlaceMutationError.staleState
            default:
                throw InventoryPlaceMutationError.persistenceFailed
            }
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
            if place.parentPlaceID != nil {
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
}
