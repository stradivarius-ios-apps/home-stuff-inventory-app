import Foundation

enum InventoryPlaceHierarchyError: Error, Equatable {
    case missingParent(UUID)
    case selfParent
    case crossLocationParent
    case descendantCycle
    case duplicateSiblingName(String)
}

enum InventoryPlacePathStatus: Equatable {
    case complete
    case missingParent(UUID)
    case crossLocationParent(UUID)
    case cycle(UUID)
}

struct InventoryPlacePath: Equatable {
    let placeIDs: [UUID]
    let components: [String]
    let status: InventoryPlacePathStatus

    var displayName: String {
        components.joined(separator: " › ")
    }
}

enum InventoryPlaceHierarchy {
    static func children(
        of parentPlaceID: UUID?,
        locationID: UUID,
        places: [InventoryPlace]
    ) -> [InventoryPlace] {
        places
            .filter { $0.locationID == locationID && $0.parentPlaceID == parentPlaceID }
            .sorted(by: InventoryPlace.deterministicOrder)
    }

    static func descendantIDs(
        of placeID: UUID,
        places: [InventoryPlace]
    ) -> Set<UUID> {
        let childrenByParent = Dictionary(grouping: places.compactMap { place -> (UUID, UUID)? in
            guard let parentID = place.parentPlaceID else { return nil }
            return (parentID, place.id)
        }, by: \.0)
        var result: Set<UUID> = [placeID]
        var pending = [placeID]

        while let current = pending.popLast() {
            for childID in childrenByParent[current, default: []].map(\.1)
                where result.insert(childID).inserted {
                pending.append(childID)
            }
        }

        return result
    }

    static func validatePlacement(
        of place: InventoryPlace,
        under parentPlaceID: UUID?,
        places: [InventoryPlace]
    ) throws {
        let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

        if let parentPlaceID {
            guard parentPlaceID != place.id else {
                throw InventoryPlaceHierarchyError.selfParent
            }
            guard let parent = placesByID[parentPlaceID] else {
                throw InventoryPlaceHierarchyError.missingParent(parentPlaceID)
            }
            guard parent.locationID == place.locationID else {
                throw InventoryPlaceHierarchyError.crossLocationParent
            }

            var visited = Set<UUID>()
            var current: InventoryPlace? = parent
            while let candidate = current {
                guard candidate.id != place.id, visited.insert(candidate.id).inserted else {
                    throw InventoryPlaceHierarchyError.descendantCycle
                }
                current = candidate.parentPlaceID.flatMap { placesByID[$0] }
            }
        }

        let normalizedName = InventoryNormalizedName.place(place.name)
        if places.contains(where: { candidate in
            candidate.id != place.id
                && candidate.locationID == place.locationID
                && candidate.parentPlaceID == parentPlaceID
                && InventoryNormalizedName.place(candidate.name) == normalizedName
        }) {
            throw InventoryPlaceHierarchyError.duplicateSiblingName(normalizedName.displayName)
        }
    }

    static func path(
        for place: InventoryPlace,
        places: [InventoryPlace]
    ) -> InventoryPlacePath {
        let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        var reversedIDs: [UUID] = []
        var reversedComponents: [String] = []
        var visited = Set<UUID>()
        var current = place

        while true {
            guard visited.insert(current.id).inserted else {
                return makePath(
                    reversedIDs: reversedIDs,
                    reversedComponents: reversedComponents,
                    status: .cycle(current.id)
                )
            }

            reversedIDs.append(current.id)
            reversedComponents.append(current.name)

            guard let parentPlaceID = current.parentPlaceID else {
                return makePath(
                    reversedIDs: reversedIDs,
                    reversedComponents: reversedComponents,
                    status: .complete
                )
            }
            guard let parent = placesByID[parentPlaceID] else {
                return makePath(
                    reversedIDs: reversedIDs,
                    reversedComponents: reversedComponents,
                    status: .missingParent(parentPlaceID)
                )
            }
            guard parent.locationID == place.locationID else {
                return makePath(
                    reversedIDs: reversedIDs,
                    reversedComponents: reversedComponents,
                    status: .crossLocationParent(parentPlaceID)
                )
            }
            current = parent
        }
    }

    private static func makePath(
        reversedIDs: [UUID],
        reversedComponents: [String],
        status: InventoryPlacePathStatus
    ) -> InventoryPlacePath {
        InventoryPlacePath(
            placeIDs: reversedIDs.reversed(),
            components: reversedComponents.reversed(),
            status: status
        )
    }
}

/// The persistence identity intentionally uses the same comparison keys as browse grouping.
struct InventoryPlaceIdentity: Hashable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static func make(
        locationName: String,
        placeName: String?,
        vocabulary: InventoryBrowseVocabulary = .default
    ) -> InventoryPlaceIdentity {
        let location = InventoryNormalizedName.location(locationName, vocabulary: vocabulary)
        let place = InventoryNormalizedName.place(placeName, vocabulary: vocabulary)
        // Prefixing the two states makes the reserved missing values non-colliding
        // even if a user types a string resembling an internal comparison key.
        return InventoryPlaceIdentity(
            rawValue: "location:\(component(for: location))|place:\(component(for: place))"
        )
    }

    static func make(for item: InventoryItem) -> InventoryPlaceIdentity {
        make(locationName: item.locationName, placeName: item.containerName)
    }

    private static func component(for name: InventoryNormalizedName) -> String {
        name.isMissing ? "missing" : "named:\(name.comparisonKey)"
    }
}
