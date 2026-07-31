import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryFreeDowngradeRegressionGateTests {
    private let states: [(state: InventoryEntitlementState, localPro: Bool, family: Bool)] = [
        (.free, false, false),
        (.lifetimePro, true, false),
        (.activeFamilySubscription, true, true),
        (.lifetimeProWithActiveFamilySubscription, true, true),
        (.expiredFamilySubscription, false, false),
        (.lifetimeProWithExpiredFamilySubscription, true, false)
    ]

    @Test func sixStateMatrixProtectsEveryFreeCapabilityWhilePremiumAccessChanges() {
        #expect(states.count == 6)
        #expect(Set(states.map(\.state)) == Set(InventoryEntitlementState.allCases))

        let freePolicy = InventoryFreeAccessPolicy()
        let premiumPolicy = PremiumAccessPolicy()
        let localFeatures: Set<PremiumFeature> = [
            .roomSweep,
            .moveSelectedItems,
            .movePlaceContents,
            .extendedMovementUndo,
            .storageHierarchyEditing
        ]

        for fixture in states {
            for capability in InventoryFreeCapability.allCases {
                #expect(
                    freePolicy.availability(of: capability, entitlementState: fixture.state)
                        == .available
                )
                #expect(
                    premiumPolicy.freeAvailability(of: capability, entitlementState: fixture.state)
                        == .available
                )
            }

            let entitlements = InventoryEntitlements(state: fixture.state)
            for feature in localFeatures {
                #expect(
                    premiumPolicy.availability(of: feature, entitlements: entitlements)
                        == (fixture.localPro ? .available : .unavailable)
                )
            }
            for feature in [PremiumFeature.personalSync, .householdSharing] {
                #expect(
                    premiumPolicy.availability(of: feature, entitlements: entitlements)
                        == (fixture.family ? .available : .unavailable)
                )
            }
        }
    }

    @Test func premiumCreatedResultsStayVisibleReadableSearchableAndExportableAfterDowngrade() async throws {
        let expected = fixtureSnapshot()
        var stateResults: [InventoryEntitlementState: StateResult] = [:]

        for fixture in states {
            let context = try populatedContext()
            let items = try context.fetch(FetchDescriptor<InventoryItem>())
            let locations = try context.fetch(FetchDescriptor<StorageLocation>())
            let categories = try context.fetch(FetchDescriptor<InventoryCustomCategory>())
            let viewEvents = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())

            #expect(Set(items.map(\.id)) == expected.itemIDs)
            #expect(Set(locations.map(\.id)) == expected.locationIDs)
            #expect(Set(categories.map(\.id)) == expected.categoryIDs)
            #expect(Set(viewEvents.map(\.id)) == expected.viewEventIDs)

            let readableValues = Set(items.map {
                [$0.name, $0.category, $0.locationName, $0.containerName ?? "", $0.notes]
                    .joined(separator: "|")
            })
            #expect(readableValues == expected.readableItemValues)
            #expect(Set(InventorySearch.matchingItems(in: items, query: "premium result").map(\.id)) == expected.itemIDs)

            let location = try #require(
                InventorySearch.locationSummaries(from: items, storageLocations: locations)
                    .first(where: { $0.name == "Premium results room" })
            )
            #expect(location.itemCount == expected.itemIDs.count)
            let places = InventorySearch.placeSummaries(in: items, matching: location)
            #expect(Set(places.map(\.name)) == expected.placeNames)
            #expect(
                Set(places.flatMap { InventorySearch.items(in: items, matching: $0).map(\.id) })
                    == expected.itemIDs
            )

            let artifact = try InventoryReadableExportService().export(
                items: items,
                locations: locations,
                customCategories: categories,
                createdAt: expected.timestamp,
                artifactID: expected.exportArtifactID
            )
            defer { artifact.cleanup() }
            let export = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: artifact.url))
            #expect(Set(export.inventory.items.compactMap { UUID(uuidString: $0.id) }) == expected.itemIDs)
            #expect(Set(export.inventory.locations.compactMap { UUID(uuidString: $0.id) }) == expected.locationIDs)
            #expect(Set(export.inventory.customCategories.compactMap { UUID(uuidString: $0.id) }) == expected.categoryIDs)

            let backup = try InventoryBackupSnapshotter.capture(in: context)
            #expect(Set(backup.items.compactMap { UUID(uuidString: $0.id) }) == expected.itemIDs)
            #expect(Set(backup.locations.compactMap { UUID(uuidString: $0.id) }) == expected.locationIDs)
            #expect(Set(backup.customCategories.compactMap { UUID(uuidString: $0.id) }) == expected.categoryIDs)
            #expect(
                Set((backup.recentItemViewEvents ?? []).compactMap { UUID(uuidString: $0.id) })
                    == expected.viewEventIDs
            )

            stateResults[fixture.state] = StateResult(
                itemIDs: Set(items.map(\.id)),
                readableItemValues: readableValues,
                searchResultIDs: Set(InventorySearch.matchingItems(in: items, query: "premium result").map(\.id)),
                exportItemIDs: Set(export.inventory.items.compactMap { UUID(uuidString: $0.id) }),
                backupViewEventIDs: Set((backup.recentItemViewEvents ?? []).compactMap { UUID(uuidString: $0.id) })
            )
        }

        let premiumBaseline = try #require(stateResults[.lifetimeProWithActiveFamilySubscription])
        for downgradedState in [InventoryEntitlementState.free, .expiredFamilySubscription] {
            #expect(stateResults[downgradedState] == premiumBaseline)
        }
    }

    @Test func nestedStorageTreeRemainsPersistedBrowsableAndBackedUpAfterDowngrade() throws {
        for fixture in states {
            let container = try InventoryModelContainer.make(inMemory: true)
            let writeContext = ModelContext(container)
            let location = StorageLocation(name: "Workshop")
            let root = InventoryPlace(locationID: location.id, name: "Cabinet")
            let child = InventoryPlace(
                locationID: location.id,
                parentPlaceID: root.id,
                name: "Drawer"
            )
            let grandchild = InventoryPlace(
                locationID: location.id,
                parentPlaceID: child.id,
                name: "Parts box"
            )
            let item = InventoryItem(
                name: "Spare hinge",
                locationName: location.name,
                containerName: grandchild.name,
                placeID: grandchild.id
            )
            writeContext.insert(location)
            writeContext.insert(root)
            writeContext.insert(child)
            writeContext.insert(grandchild)
            writeContext.insert(item)
            try writeContext.save()

            let context = ModelContext(container)
            let places = try context.fetch(FetchDescriptor<InventoryPlace>())
            let items = try context.fetch(FetchDescriptor<InventoryItem>())
            let locations = try context.fetch(FetchDescriptor<StorageLocation>())
            let persistedGrandchild = try #require(
                places.first { $0.id == grandchild.id }
            )
            let path = InventoryPlaceHierarchy.path(
                for: persistedGrandchild,
                places: places
            )
            #expect(path.status == .complete)
            #expect(path.placeIDs == [root.id, child.id, grandchild.id])
            #expect(path.components == ["Cabinet", "Drawer", "Parts box"])

            let locationSummary = try #require(
                InventoryBrowseSummaries.locationSummaries(
                    from: items,
                    storageLocations: locations
                ).first { $0.name == "Workshop" }
            )
            let browseRoots = InventoryBrowseSummaries.placeSummaries(
                in: items,
                matching: locationSummary,
                places: places
            )
            let browseChildren = InventoryBrowseSummaries.placeSummaries(
                in: items,
                matching: locationSummary,
                places: places,
                parentPlaceID: root.id
            )
            let browseGrandchildren = InventoryBrowseSummaries.placeSummaries(
                in: items,
                matching: locationSummary,
                places: places,
                parentPlaceID: child.id
            )
            #expect(browseRoots.map(\.placeID) == [root.id])
            #expect(browseRoots.first?.recursiveItemCount == 1)
            #expect(browseChildren.map(\.placeID) == [child.id])
            #expect(browseGrandchildren.map(\.placeID) == [grandchild.id])
            #expect(browseGrandchildren.first?.pathComponents == ["Cabinet", "Drawer", "Parts box"])
            #expect(
                InventoryBrowseSummaries.items(
                    in: items,
                    matching: try #require(browseGrandchildren.first)
                ).map(\.id) == [item.id]
            )

            let backup = try InventoryBackupSnapshotter.capture(in: context)
            #expect(
                backup.places.first { $0.id == child.id.inventoryPortabilityString }?
                    .parentPlaceID == root.id.inventoryPortabilityString
            )
            #expect(
                backup.places.first { $0.id == grandchild.id.inventoryPortabilityString }?
                    .parentPlaceID == child.id.inventoryPortabilityString
            )
            #expect(
                backup.items.first { $0.id == item.id.inventoryPortabilityString }?
                    .placeID == grandchild.id.inventoryPortabilityString
            )

            let entitlements = InventoryEntitlements(state: fixture.state)
            #expect(
                PremiumAccessPolicy().availability(
                    of: .storageHierarchyEditing,
                    entitlements: entitlements
                ) == (fixture.localPro ? .available : .unavailable)
            )
            #expect(items.map(\.id) == [item.id])
        }
    }

    private func populatedContext() throws -> ModelContext {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let fixture = fixtureSnapshot()

        let location = StorageLocation(
            id: fixture.locationIDs.first!,
            name: "Premium results room",
            iconID: "archivebox",
            notes: "Existing data remains local and readable.",
            createdAt: fixture.timestamp,
            updatedAt: fixture.timestamp
        )
        let category = InventoryCustomCategory(
            id: fixture.categoryIDs.first!,
            name: "Premium-created results",
            createdAt: fixture.timestamp,
            updatedAt: fixture.timestamp
        )
        context.insert(location)
        context.insert(category)

        let results: [(UUID, String, String)] = [
            (Self.id("30000000-0000-0000-0000-000000000001"), "Room Sweep premium result", "Sweep shelf"),
            (Self.id("30000000-0000-0000-0000-000000000002"), "Selected move premium result", "Moved drawer"),
            (Self.id("30000000-0000-0000-0000-000000000003"), "Place move premium result", "Moved cabinet"),
            (Self.id("30000000-0000-0000-0000-000000000004"), "Inbox cleanup premium result", "Sorted box")
        ]

        for (index, result) in results.enumerated() {
            let item = InventoryItem(
                id: result.0,
                name: result.1,
                category: category.name,
                locationName: location.name,
                containerName: result.2,
                quantity: index + 1,
                condition: InventoryCondition.good.rawValue,
                tags: ["premium result", "owned data"],
                notes: "Readable after downgrade: \(result.1)",
                createdAt: fixture.timestamp,
                updatedAt: fixture.timestamp
            )
            context.insert(item)
            context.insert(
                InventoryItemViewEvent(
                    id: Self.id(String(format: "40000000-0000-0000-0000-%012d", index + 1)),
                    itemID: item.id,
                    viewedAt: fixture.timestamp
                )
            )
        }
        try context.save()
        return context
    }

    private func fixtureSnapshot() -> FixtureSnapshot {
        let itemIDs = Set((1...4).map {
            Self.id(String(format: "30000000-0000-0000-0000-%012d", $0))
        })
        let viewEventIDs = Set((1...4).map {
            Self.id(String(format: "40000000-0000-0000-0000-%012d", $0))
        })
        let timestamp = Date(timeIntervalSince1970: 1_752_489_000)
        let namesAndPlaces = [
            ("Room Sweep premium result", "Sweep shelf"),
            ("Selected move premium result", "Moved drawer"),
            ("Place move premium result", "Moved cabinet"),
            ("Inbox cleanup premium result", "Sorted box")
        ]
        return FixtureSnapshot(
            itemIDs: itemIDs,
            locationIDs: [Self.id("10000000-0000-0000-0000-000000000001")],
            categoryIDs: [Self.id("20000000-0000-0000-0000-000000000001")],
            viewEventIDs: viewEventIDs,
            placeNames: Set(namesAndPlaces.map(\.1)),
            readableItemValues: Set(namesAndPlaces.map { name, place in
                [name, "Premium-created results", "Premium results room", place, "Readable after downgrade: \(name)"]
                    .joined(separator: "|")
            }),
            timestamp: timestamp,
            exportArtifactID: Self.id("90000000-0000-0000-0000-000000000001")
        )
    }

    private static func id(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}

private struct FixtureSnapshot {
    let itemIDs: Set<UUID>
    let locationIDs: Set<UUID>
    let categoryIDs: Set<UUID>
    let viewEventIDs: Set<UUID>
    let placeNames: Set<String>
    let readableItemValues: Set<String>
    let timestamp: Date
    let exportArtifactID: UUID
}

private struct StateResult: Equatable {
    let itemIDs: Set<UUID>
    let readableItemValues: Set<String>
    let searchResultIDs: Set<UUID>
    let exportItemIDs: Set<UUID>
    let backupViewEventIDs: Set<UUID>
}
