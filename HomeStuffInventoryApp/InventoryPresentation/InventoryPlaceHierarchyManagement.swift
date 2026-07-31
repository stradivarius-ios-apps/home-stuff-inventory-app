import Foundation

enum InventoryPlaceHierarchyManagement {
    struct DirectorySection: Identifiable {
        let location: StorageLocation
        let rows: [Row]

        var id: UUID { location.id }
    }

    struct Row: Identifiable, Equatable {
        let placeID: UUID
        let locationID: UUID
        let parentPlaceID: UUID?
        let name: String
        let iconID: String?
        let depth: Int
        let pathComponents: [String]
        let directItemCount: Int
        let descendantPlaceCount: Int
        let containedItemCount: Int
        let participatesInHierarchy: Bool
        let hasCompletePath: Bool

        var id: UUID { placeID }

        var pathText: String {
            pathComponents.joined(separator: " › ")
        }
    }

    struct Destination: Identifiable, Equatable, Hashable {
        enum ID: Hashable {
            case location(UUID)
            case place(UUID)
        }

        let id: ID
        let locationID: UUID
        let parentPlaceID: UUID?
        let displayPath: String
    }

    struct MovePreflight: Equatable {
        let sourceExpectation: InventoryPlaceMutationExpectation
        let destination: Destination
        let sourcePath: String
        let destinationPath: String
        let descendantPlaceCount: Int
        let containedItemCount: Int

        var movedPlaceCount: Int {
            descendantPlaceCount + 1
        }
    }

    enum MovePreparationOutcome: Equatable {
        case ready(MovePreflight)
        case missingSource
        case incompleteSourcePath
        case invalidDestination
        case unchanged
    }

    static func sections(
        locations: [StorageLocation],
        places: [InventoryPlace],
        items: [InventoryItem]
    ) -> [DirectorySection] {
        let locationsByID = Dictionary(
            locations.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let childrenByParent = Dictionary(grouping: places, by: \.parentPlaceID)
        let placesByLocation = Dictionary(grouping: places, by: \.locationID)

        return locations.compactMap { location in
            let scopedPlaces = placesByLocation[location.id] ?? []
            let scopedIDs = Set(scopedPlaces.map(\.id))
            let roots = scopedPlaces.filter { place in
                guard let parentID = place.parentPlaceID else { return true }
                return !scopedIDs.contains(parentID)
            }
            var visited = Set<UUID>()
            var rows: [Row] = []

            func append(_ place: InventoryPlace, depth: Int) {
                guard visited.insert(place.id).inserted else { return }
                rows.append(
                    row(
                        for: place,
                        depth: depth,
                        places: places,
                        items: items,
                        locationsByID: locationsByID
                    )
                )
                for child in (childrenByParent[place.id] ?? []).sorted(by: placeSort) {
                    append(child, depth: depth + 1)
                }
            }

            for root in roots.sorted(by: placeSort) {
                append(root, depth: 0)
            }
            for unresolved in scopedPlaces.sorted(by: placeSort) where !visited.contains(unresolved.id) {
                append(unresolved, depth: 0)
            }

            guard !rows.isEmpty else { return nil }
            return DirectorySection(location: location, rows: rows)
        }
        .sorted { localizedSort($0.location.name, $1.location.name, lhsID: $0.id, rhsID: $1.id) }
    }

    static func canDirectlyEdit(
        _ row: Row,
        entitlements: InventoryEntitlements
    ) -> Bool {
        !row.participatesInHierarchy || entitlements.hasLocalProFeatures
    }

    static func destinations(
        for sourcePlaceID: UUID,
        locations: [StorageLocation],
        places: [InventoryPlace]
    ) -> [Destination] {
        guard let source = places.first(where: { $0.id == sourcePlaceID }) else {
            return []
        }
        let sourceSubtreeIDs = InventoryPlaceHierarchy.descendantIDs(
            of: source.id,
            places: places
        )

        return InventoryBulkMovementDestinationDirectory.destinations(
            locations: locations,
            places: places
        ).compactMap { destination in
            if let destinationPlaceID = destination.placeID {
                guard !sourceSubtreeIDs.contains(destinationPlaceID) else {
                    return nil
                }
            }
            return Destination(
                id: destination.placeID.map(Destination.ID.place)
                    ?? .location(destination.locationID),
                locationID: destination.locationID,
                parentPlaceID: destination.placeID,
                displayPath: destination.displayPath
            )
        }
    }

    static func prepareMove(
        sourcePlaceID: UUID,
        destinationID: Destination.ID,
        locations: [StorageLocation],
        places: [InventoryPlace],
        items: [InventoryItem]
    ) -> MovePreparationOutcome {
        guard let source = places.first(where: { $0.id == sourcePlaceID }) else {
            return .missingSource
        }
        let sourcePath = InventoryPlaceHierarchy.path(for: source, places: places)
        guard sourcePath.status == .complete,
              let sourceLocation = locations.first(where: { $0.id == source.locationID })
        else {
            return .incompleteSourcePath
        }
        guard let destination = destinations(
            for: sourcePlaceID,
            locations: locations,
            places: places
        ).first(where: { $0.id == destinationID }) else {
            return .invalidDestination
        }
        guard source.locationID != destination.locationID
                || source.parentPlaceID != destination.parentPlaceID
        else {
            return .unchanged
        }

        let subtreeIDs = InventoryPlaceHierarchy.descendantIDs(
            of: source.id,
            places: places
        )
        let descendantIDs = subtreeIDs.subtracting([source.id])
        let containedItemCount = items.filter { item in
            if let placeID = item.placeID {
                return subtreeIDs.contains(placeID)
            }
            return source.parentPlaceID == nil
                && InventoryNormalizedName.location(item.locationName)
                    == InventoryNormalizedName.location(sourceLocation.name)
                && InventoryNormalizedName.place(item.containerName)
                    == InventoryNormalizedName.place(source.name)
        }.count

        return .ready(
            MovePreflight(
                sourceExpectation: InventoryPlaceMutationExpectation(place: source),
                destination: destination,
                sourcePath: ([sourceLocation.name] + sourcePath.components)
                    .joined(separator: " › "),
                destinationPath: destination.displayPath,
                descendantPlaceCount: descendantIDs.count,
                containedItemCount: containedItemCount
            )
        )
    }

    static func isValid(
        _ preflight: MovePreflight,
        locations: [StorageLocation],
        places: [InventoryPlace],
        items: [InventoryItem]
    ) -> Bool {
        prepareMove(
            sourcePlaceID: preflight.sourceExpectation.id,
            destinationID: preflight.destination.id,
            locations: locations,
            places: places,
            items: items
        ) == .ready(preflight)
    }

    private static func row(
        for place: InventoryPlace,
        depth: Int,
        places: [InventoryPlace],
        items: [InventoryItem],
        locationsByID: [UUID: StorageLocation]
    ) -> Row {
        let path = InventoryPlaceHierarchy.path(for: place, places: places)
        let subtreeIDs = InventoryPlaceHierarchy.descendantIDs(of: place.id, places: places)
        let descendantIDs = subtreeIDs.subtracting([place.id])
        let directItemCount = items.filter { $0.placeID == place.id }.count
        let stableContainedCount = items.filter {
            $0.placeID.map(subtreeIDs.contains) == true
        }.count
        let legacyDirectCount: Int
        if place.parentPlaceID == nil, let location = locationsByID[place.locationID] {
            legacyDirectCount = items.filter {
                $0.placeID == nil
                    && InventoryNormalizedName.location($0.locationName)
                        == InventoryNormalizedName.location(location.name)
                    && InventoryNormalizedName.place($0.containerName)
                        == InventoryNormalizedName.place(place.name)
            }.count
        } else {
            legacyDirectCount = 0
        }

        return Row(
            placeID: place.id,
            locationID: place.locationID,
            parentPlaceID: place.parentPlaceID,
            name: place.name,
            iconID: place.iconID,
            depth: depth,
            pathComponents: path.components,
            directItemCount: directItemCount + legacyDirectCount,
            descendantPlaceCount: descendantIDs.count,
            containedItemCount: stableContainedCount + legacyDirectCount,
            participatesInHierarchy: place.parentPlaceID != nil
                || places.contains { $0.parentPlaceID == place.id },
            hasCompletePath: path.status == .complete
        )
    }

    private static func placeSort(_ lhs: InventoryPlace, _ rhs: InventoryPlace) -> Bool {
        localizedSort(lhs.name, rhs.name, lhsID: lhs.id, rhsID: rhs.id)
    }

    private static func localizedSort(
        _ lhs: String,
        _ rhs: String,
        lhsID: UUID,
        rhsID: UUID
    ) -> Bool {
        let result = lhs.localizedStandardCompare(rhs)
        return result == .orderedSame
            ? lhsID.uuidString < rhsID.uuidString
            : result == .orderedAscending
    }
}
