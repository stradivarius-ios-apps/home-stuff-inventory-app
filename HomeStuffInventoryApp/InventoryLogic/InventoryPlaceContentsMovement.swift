import Foundation
import SwiftData

struct InventoryPlaceContentsMovementPreflight: Equatable {
    let source: InventoryBulkMovementDestination
    let movement: InventoryBulkMovementPreflight

    var itemCount: Int {
        movement.selectedItemCount
    }
}

enum InventoryPlaceContentsMovementPreparationOutcome: Equatable {
    case ready(InventoryPlaceContentsMovementPreflight)
    case emptyPlace
    case legacyReviewRequired
    case accessRequired
    case invalidSource
    case invalidDestination
}

enum InventoryPlaceContentsMovementCommitOutcome: Equatable {
    case moved(operationID: UUID, itemCount: Int)
    case unchanged
    case legacyReviewRequired
    case accessRequired
    case sourceChanged
    case invalidDestination
    case cancelled
    case failed
}

enum InventoryPlaceContentsMovement {
    @MainActor
    static func prepare(
        sourcePlaceID: UUID,
        items: [InventoryItem],
        locations: [StorageLocation],
        places: [InventoryPlace],
        destination: InventoryBulkMovementDestination,
        access: PremiumAccessProviding
    ) -> InventoryPlaceContentsMovementPreparationOutcome {
        let directory = InventoryBulkMovementDestinationDirectory.destinations(
            locations: locations,
            places: places
        )
        guard let source = directory.first(where: { $0.id == .place(sourcePlaceID) }) else {
            return .invalidSource
        }
        guard let sourcePlace = places.first(where: { $0.id == sourcePlaceID }),
              let sourceLocation = locations.first(where: { $0.id == sourcePlace.locationID })
        else {
            return .invalidSource
        }
        guard !hasLegacyDirectItems(
            in: items,
            sourcePlace: sourcePlace,
            sourceLocation: sourceLocation
        ) else {
            return .legacyReviewRequired
        }

        let directItemIDs = Set(
            items.lazy
                .filter { $0.placeID == sourcePlaceID }
                .map(\.id)
        )
        // Empty content is ordinary inventory state and is reported before premium access.
        guard !directItemIDs.isEmpty else {
            return .emptyPlace
        }

        switch InventoryBulkMovement.prepare(
            selectedItemIDs: directItemIDs,
            items: items,
            locations: locations,
            places: places,
            destination: destination,
            access: access,
            requiredFeature: .movePlaceContents
        ) {
        case let .ready(movement):
            return .ready(
                InventoryPlaceContentsMovementPreflight(
                    source: source,
                    movement: movement
                )
            )
        case .accessRequired:
            return .accessRequired
        case .invalidDestination:
            return .invalidDestination
        case .emptySelection, .staleSelection:
            return .invalidSource
        }
    }

    @MainActor
    static func commit(
        _ preflight: InventoryPlaceContentsMovementPreflight,
        access: PremiumAccessProviding,
        in modelContext: ModelContext,
        operationID: UUID = UUID(),
        occurredAt: Date = .now,
        isCancelled: () -> Bool = { false },
        persist: (() throws -> Void)? = nil
    ) -> InventoryPlaceContentsMovementCommitOutcome {
        guard access.availability(of: .movePlaceContents) == .available else {
            return .accessRequired
        }
        guard !isCancelled() else {
            return .cancelled
        }

        do {
            let items = try modelContext.fetch(FetchDescriptor<InventoryItem>())
            let locations = try modelContext.fetch(FetchDescriptor<StorageLocation>())
            let places = try modelContext.fetch(FetchDescriptor<InventoryPlace>())
            let directory = InventoryBulkMovementDestinationDirectory.destinations(
                locations: locations,
                places: places
            )

            guard directory.first(where: { $0.id == preflight.source.id }) == preflight.source else {
                return .sourceChanged
            }

            guard case let .place(sourcePlaceID) = preflight.source.id else {
                return .sourceChanged
            }
            guard let sourcePlace = places.first(where: { $0.id == sourcePlaceID }),
                  let sourceLocation = locations.first(where: { $0.id == sourcePlace.locationID })
            else {
                return .sourceChanged
            }
            guard !hasLegacyDirectItems(
                in: items,
                sourcePlace: sourcePlace,
                sourceLocation: sourceLocation
            ) else {
                return .legacyReviewRequired
            }
            let currentDirectItemIDs = Set(
                items.lazy
                    .filter { $0.placeID == sourcePlaceID }
                    .map(\.id)
            )
            guard currentDirectItemIDs == Set(preflight.movement.selectedItemIDs) else {
                return .sourceChanged
            }

            switch InventoryBulkMovement.commit(
                preflight.movement,
                access: access,
                in: modelContext,
                requiredFeature: .movePlaceContents,
                origin: .storagePlaceDirectContents,
                operationID: operationID,
                occurredAt: occurredAt,
                isCancelled: isCancelled,
                persist: persist
            ) {
            case let .moved(operationID, itemCount):
                return .moved(operationID: operationID, itemCount: itemCount)
            case .unchanged:
                return .unchanged
            case .accessRequired:
                return .accessRequired
            case .staleSelection:
                return .sourceChanged
            case .invalidDestination:
                return .invalidDestination
            case .cancelled:
                return .cancelled
            case .failed:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    static func hasLegacyDirectItems(
        in items: [InventoryItem],
        sourcePlace: InventoryPlace,
        sourceLocation: StorageLocation
    ) -> Bool {
        items.contains {
            InventoryBrowseSummaries.isLegacyDirectItem(
                $0,
                locationName: sourceLocation.name,
                placeName: sourcePlace.name,
                parentPlaceID: sourcePlace.parentPlaceID,
                vocabulary: .localized
            )
        }
    }
}
