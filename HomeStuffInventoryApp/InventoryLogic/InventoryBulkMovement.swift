import Foundation
import SwiftData

enum InventoryBulkSelectionStartOutcome: Equatable {
    case started
    case accessRequired
    case noItems
}

struct InventoryBulkSelectionState: Equatable {
    private(set) var isActive = false
    private(set) var selectedItemIDs: Set<UUID> = []

    var selectedCount: Int {
        selectedItemIDs.count
    }

    mutating func begin(
        visibleItemIDs: [UUID],
        availability: InventoryCapabilityAvailability
    ) -> InventoryBulkSelectionStartOutcome {
        guard availability == .available else {
            cancel()
            return .accessRequired
        }
        guard !visibleItemIDs.isEmpty else {
            cancel()
            return .noItems
        }

        isActive = true
        selectedItemIDs = []
        return .started
    }

    mutating func replaceSelection(with itemIDs: Set<UUID>, visibleItemIDs: [UUID]) {
        guard isActive else { return }
        let visibleIDs = Set(visibleItemIDs)
        let hiddenSelection = selectedItemIDs.subtracting(visibleIDs)
        selectedItemIDs = hiddenSelection.union(itemIDs.intersection(visibleIDs))
    }

    mutating func selectAll(visibleItemIDs: [UUID]) {
        guard isActive else { return }
        selectedItemIDs.formUnion(visibleItemIDs)
    }

    mutating func reconcile(availableItemIDs: [UUID]) {
        selectedItemIDs.formIntersection(availableItemIDs)
    }

    mutating func cancel() {
        isActive = false
        selectedItemIDs = []
    }
}

struct InventoryBulkMovementDestination: Equatable, Identifiable, Sendable {
    enum Identity: Hashable, Sendable {
        case location(UUID)
        case place(UUID)
    }

    let id: Identity
    let locationID: UUID
    let locationName: String
    let placeID: UUID?
    let placeName: String?
    let displayPath: String
    let placePathIDs: [UUID]
    let placePathComponents: [String]

    init(
        id: Identity,
        locationID: UUID,
        locationName: String,
        placeID: UUID?,
        placeName: String?,
        displayPath: String,
        placePathIDs: [UUID] = [],
        placePathComponents: [String] = []
    ) {
        self.id = id
        self.locationID = locationID
        self.locationName = locationName
        self.placeID = placeID
        self.placeName = placeName
        self.displayPath = displayPath
        self.placePathIDs = placePathIDs
        self.placePathComponents = placePathComponents
    }

    var endpoint: InventoryMovementEndpointSnapshot {
        InventoryMovementEndpointSnapshot(
            locationID: locationID,
            locationName: locationName,
            placeID: placeID,
            placeName: placeName
        )
    }
}

enum InventoryBulkMovementDestinationDirectory {
    static func destinations(
        locations: [StorageLocation],
        places: [InventoryPlace]
    ) -> [InventoryBulkMovementDestination] {
        locations
            .sorted(by: locationSort)
            .flatMap { location in
                let locationDestination = InventoryBulkMovementDestination(
                    id: .location(location.id),
                    locationID: location.id,
                    locationName: location.name,
                    placeID: nil,
                    placeName: nil,
                    displayPath: location.name
                )
                let placeDestinations = places
                    .filter { $0.locationID == location.id }
                    .compactMap { place -> InventoryBulkMovementDestination? in
                        let path = InventoryPlaceHierarchy.path(for: place, places: places)
                        guard path.status == .complete else { return nil }

                        return InventoryBulkMovementDestination(
                            id: .place(place.id),
                            locationID: location.id,
                            locationName: location.name,
                            placeID: place.id,
                            placeName: place.name,
                            displayPath: ([location.name] + path.components).joined(separator: " › "),
                            placePathIDs: path.placeIDs,
                            placePathComponents: path.components
                        )
                    }
                    .sorted(by: destinationSort)

                return [locationDestination] + placeDestinations
            }
    }

    private static func locationSort(_ lhs: StorageLocation, _ rhs: StorageLocation) -> Bool {
        let comparison = lhs.name.localizedStandardCompare(rhs.name)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func destinationSort(
        _ lhs: InventoryBulkMovementDestination,
        _ rhs: InventoryBulkMovementDestination
    ) -> Bool {
        let comparison = lhs.displayPath.localizedStandardCompare(rhs.displayPath)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return String(describing: lhs.id) < String(describing: rhs.id)
    }
}

struct InventoryBulkMovementSourceSummary: Equatable, Identifiable, Sendable {
    let snapshot: InventoryMovementEndpointSnapshot
    let itemCount: Int

    var id: InventoryMovementEndpointSnapshot {
        snapshot
    }
}

struct InventoryBulkMovementPreflight: Equatable {
    let selectedItemIDs: [UUID]
    let expectedSources: [UUID: InventoryMovementEndpointSnapshot]
    let sourceSummaries: [InventoryBulkMovementSourceSummary]
    let destination: InventoryBulkMovementDestination
    let changedItemCount: Int

    var selectedItemCount: Int {
        selectedItemIDs.count
    }
}

enum InventoryBulkMovementPreparationOutcome: Equatable {
    case ready(InventoryBulkMovementPreflight)
    case accessRequired
    case emptySelection
    case staleSelection
    case invalidDestination
}

enum InventoryBulkMovementCommitOutcome: Equatable {
    case moved(operationID: UUID, itemCount: Int)
    case unchanged
    case accessRequired
    case staleSelection
    case invalidDestination
    case cancelled
    case failed
}

enum InventoryBulkMovement {
    @MainActor
    static func prepare(
        selectedItemIDs: Set<UUID>,
        items: [InventoryItem],
        locations: [StorageLocation],
        places: [InventoryPlace],
        destination: InventoryBulkMovementDestination,
        access: PremiumAccessProviding,
        requiredFeature: PremiumFeature = .moveSelectedItems
    ) -> InventoryBulkMovementPreparationOutcome {
        guard access.availability(of: requiredFeature) == .available else {
            return .accessRequired
        }
        guard !selectedItemIDs.isEmpty else {
            return .emptySelection
        }
        guard isValid(destination, locations: locations, places: places) else {
            return .invalidDestination
        }

        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let orderedIDs = selectedItemIDs.sorted { $0.uuidString < $1.uuidString }
        guard orderedIDs.allSatisfy({ itemsByID[$0] != nil }) else {
            return .staleSelection
        }

        let sources = orderedIDs.compactMap { itemID in
            itemsByID[itemID].map {
                InventoryMovementEndpointSnapshot(item: $0, locations: locations)
            }
        }
        let expectedSources = Dictionary(
            uniqueKeysWithValues: zip(orderedIDs, sources)
        )
        let sourceSummaries = summarize(sources)
        let changedCount = sources.filter { $0 != destination.endpoint }.count

        return .ready(
            InventoryBulkMovementPreflight(
                selectedItemIDs: orderedIDs,
                expectedSources: expectedSources,
                sourceSummaries: sourceSummaries,
                destination: destination,
                changedItemCount: changedCount
            )
        )
    }

    @MainActor
    static func commit(
        _ preflight: InventoryBulkMovementPreflight,
        access: PremiumAccessProviding,
        in modelContext: ModelContext,
        requiredFeature: PremiumFeature = .moveSelectedItems,
        origin: InventoryMovementOrigin = .selectedItems,
        operationID: UUID = UUID(),
        occurredAt: Date = .now,
        isCancelled: () -> Bool = { false },
        persist: (() throws -> Void)? = nil
    ) -> InventoryBulkMovementCommitOutcome {
        guard access.availability(of: requiredFeature) == .available else {
            return .accessRequired
        }
        guard !isCancelled() else {
            return .cancelled
        }

        do {
            let items = try modelContext.fetch(FetchDescriptor<InventoryItem>())
            let locations = try modelContext.fetch(FetchDescriptor<StorageLocation>())
            let places = try modelContext.fetch(FetchDescriptor<InventoryPlace>())
            guard isValid(preflight.destination, locations: locations, places: places) else {
                return .invalidDestination
            }

            let itemsByID = Dictionary(
                items.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            guard preflight.selectedItemIDs.allSatisfy({ itemsByID[$0] != nil }) else {
                return .staleSelection
            }

            let currentSources = Dictionary(
                uniqueKeysWithValues: preflight.selectedItemIDs.compactMap { itemID in
                    itemsByID[itemID].map {
                        (
                            itemID,
                            InventoryMovementEndpointSnapshot(item: $0, locations: locations)
                        )
                    }
                }
            )
            guard currentSources == preflight.expectedSources else {
                return .staleSelection
            }

            let requests = preflight.selectedItemIDs.compactMap { itemID -> InventoryMovementRequest? in
                guard let item = itemsByID[itemID],
                      let expectedSource = preflight.expectedSources[itemID]
                else {
                    return nil
                }
                return InventoryMovementRequest(
                    item: item,
                    expectedSource: expectedSource,
                    destination: preflight.destination.endpoint
                )
            }
            guard requests.count == preflight.selectedItemIDs.count else {
                return .staleSelection
            }
            let records = try InventoryMovementHistory.move(
                requests,
                origin: origin,
                in: modelContext,
                locations: locations,
                operationID: operationID,
                occurredAt: occurredAt,
                isCancelled: isCancelled,
                persist: persist
            )
            guard !records.isEmpty else {
                return .unchanged
            }
            return .moved(operationID: operationID, itemCount: records.count)
        } catch InventoryMovementFailure.cancelled {
            return .cancelled
        } catch InventoryMovementFailure.staleSource {
            return .staleSelection
        } catch {
            return .failed
        }
    }

    private static func isValid(
        _ destination: InventoryBulkMovementDestination,
        locations: [StorageLocation],
        places: [InventoryPlace]
    ) -> Bool {
        guard let location = locations.first(where: { $0.id == destination.locationID }),
              InventoryNormalizedName.location(location.name)
                == InventoryNormalizedName.location(destination.locationName)
        else {
            return false
        }

        guard let placeID = destination.placeID else {
            return destination.placeName == nil
                && destination.placePathIDs.isEmpty
                && destination.placePathComponents.isEmpty
                && destination.displayPath == location.name
        }
        guard let place = places.first(where: { $0.id == placeID }),
              place.locationID == location.id,
              InventoryNormalizedName.place(place.name)
                == InventoryNormalizedName.place(destination.placeName)
        else {
            return false
        }
        let path = InventoryPlaceHierarchy.path(for: place, places: places)
        guard path.status == .complete,
              path.placeIDs == destination.placePathIDs,
              path.components == destination.placePathComponents,
              destination.displayPath
                == ([location.name] + path.components).joined(separator: " › ")
        else {
            return false
        }
        return true
    }

    private static func summarize(
        _ sources: [InventoryMovementEndpointSnapshot]
    ) -> [InventoryBulkMovementSourceSummary] {
        Dictionary(grouping: sources, by: { $0 })
            .map { snapshot, occurrences in
                InventoryBulkMovementSourceSummary(
                    snapshot: snapshot,
                    itemCount: occurrences.count
                )
            }
            .sorted {
                sourceSortKey($0.snapshot) < sourceSortKey($1.snapshot)
            }
    }

    private static func sourceSortKey(
        _ source: InventoryMovementEndpointSnapshot
    ) -> String {
        [
            source.locationID?.uuidString ?? "",
            source.locationName,
            source.placeID?.uuidString ?? "",
            source.placeName ?? ""
        ]
        .map { "\($0.utf8.count):\($0)" }
        .joined()
    }
}
