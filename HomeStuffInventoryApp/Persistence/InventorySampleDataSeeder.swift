import Foundation
import SwiftData

#if DEBUG
enum InventorySampleDataSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        let sampleItems = InventorySampleData.items
        let existingItems = try context.fetch(FetchDescriptor<InventoryItem>())
        let existingItemsByID = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.id, $0) })

        // DEBUG sample launches refresh fixed sample rows so UI smoke fixtures
        // stay deterministic after sample content changes.
        for sampleItem in sampleItems {
            if let existingItem = existingItemsByID[sampleItem.id] {
                existingItem.applyUserEdit(
                    name: sampleItem.name,
                    category: sampleItem.category,
                    locationName: sampleItem.locationName,
                    containerName: sampleItem.containerName,
                    iconID: nil,
                    quantity: sampleItem.quantity,
                    condition: sampleItem.condition,
                    tags: sampleItem.tags,
                    notes: sampleItem.notes,
                    updatedAt: existingItem.updatedAt
                )
            } else {
                context.insert(sampleItem.makeInventoryItem())
            }
        }

        try context.save()
    }
}

enum InventoryRecentItemsLayoutFixture {
    static let launchArgument = "--qa-recent-items-layout-fixture"
    static let itemCountLaunchArgument = "--qa-recent-items-layout-fixture-count"
    static let locationName = "Recent Items Test Location"
    static let placeName = "Recent Items Test Place"

    static let items: [FixtureItem] = [
        FixtureItem(
            id: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000001")!,
            eventID: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000101")!,
            name: "Recent layout item one",
            recencyOffset: 1
        ),
        FixtureItem(
            id: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000002")!,
            eventID: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000102")!,
            name: "Recent layout item two",
            recencyOffset: 2
        ),
        FixtureItem(
            id: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000003")!,
            eventID: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000103")!,
            name: "Recent layout item three",
            recencyOffset: 3
        ),
        FixtureItem(
            id: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000004")!,
            eventID: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000104")!,
            name: "Recent layout item four",
            recencyOffset: 4
        ),
        FixtureItem(
            id: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000005")!,
            eventID: UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000105")!,
            name: "Recent layout item five",
            recencyOffset: 5
        )
    ]

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func itemCount(arguments: [String]) -> Int {
        guard
            let countArgumentIndex = arguments.firstIndex(of: itemCountLaunchArgument),
            arguments.indices.contains(countArgumentIndex + 1),
            let requestedCount = Int(arguments[countArgumentIndex + 1])
        else {
            return items.count
        }

        return min(max(requestedCount, 1), items.count)
    }

    static func seed(in context: ModelContext, count: Int = items.count, now: Date = .now) throws {
        let fixtureItems = Array(items.prefix(min(max(count, 1), items.count)))
        let fixtureItemIDs = Set(fixtureItems.map(\.id))
        let allFixtureItemIDs = Set(items.map(\.id))
        let existingItemsByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<InventoryItem>()).map { ($0.id, $0) }
        )

        for existingItem in existingItemsByID.values where allFixtureItemIDs.contains(existingItem.id) && !fixtureItemIDs.contains(existingItem.id) {
            context.delete(existingItem)
        }

        for fixtureItem in fixtureItems {
            if let item = existingItemsByID[fixtureItem.id] {
                item.applyUserEdit(
                    name: fixtureItem.name,
                    category: InventoryCategory.miscellaneous.rawValue,
                    locationName: locationName,
                    containerName: placeName,
                    iconID: nil,
                    quantity: 1,
                    condition: InventoryCondition.good.rawValue,
                    tags: ["qa", "recent-items-layout"],
                    notes: "Dedicated DEBUG fixture for Recent items layout UI tests.",
                    updatedAt: item.updatedAt
                )
            } else {
                context.insert(
                    InventoryItem(
                        id: fixtureItem.id,
                        name: fixtureItem.name,
                        category: InventoryCategory.miscellaneous.rawValue,
                        locationName: locationName,
                        containerName: placeName,
                        quantity: 1,
                        condition: InventoryCondition.good.rawValue,
                        tags: ["qa", "recent-items-layout"],
                        notes: "Dedicated DEBUG fixture for Recent items layout UI tests.",
                        createdAt: now
                    )
                )
            }
        }

        let existingLocations = try context.fetch(FetchDescriptor<StorageLocation>())
        if !existingLocations.contains(where: { $0.name == locationName }) {
            context.insert(StorageLocation(name: locationName, notes: "Dedicated DEBUG fixture location."))
        }

        // Keep five current Items with four recent events to exercise the inclusive
        // Place Detail threshold while retaining the existing three-plus-overflow layout.
        let recentFixtureItems = fixtureItems.prefix(4)
        let fixtureEventIDs = Set(recentFixtureItems.map(\.eventID))
        let existingEvents = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
        for event in existingEvents where allFixtureItemIDs.contains(event.itemID) && !fixtureEventIDs.contains(event.id) {
            context.delete(event)
        }

        let existingEventsByID = Dictionary(
            uniqueKeysWithValues: existingEvents.filter { fixtureEventIDs.contains($0.id) }.map { ($0.id, $0) }
        )
        for fixtureItem in recentFixtureItems {
            let viewedAt = now.addingTimeInterval(-fixtureItem.recencyOffset)
            if let event = existingEventsByID[fixtureItem.eventID] {
                event.itemID = fixtureItem.id
                event.viewedAt = viewedAt
            } else {
                context.insert(InventoryItemViewEvent(
                    id: fixtureItem.eventID,
                    itemID: fixtureItem.id,
                    viewedAt: viewedAt
                ))
            }
        }

        try context.save()
    }

    struct FixtureItem: Equatable {
        let id: UUID
        let eventID: UUID
        let name: String
        let recencyOffset: TimeInterval
    }
}

enum InventoryPlacePopularityFixture {
    static let launchArgument = "--qa-place-popularity-fixture"

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func seed(in context: ModelContext) throws {
        let identity = InventoryPlaceIdentity.make(locationName: "Office", placeName: "PC parts box")
        context.insert(
            InventoryPlaceOpenRecord(
                placeIdentity: identity.rawValue,
                openCount: 9,
                lastOpenedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        )
        try context.save()
    }
}

enum InventoryPlaceCategoryFixture {
    static let launchArgument = "--qa-place-category-fixture"
    static let locationName = "Office"
    static let placeName = "Category test drawer"

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func seed(in context: ModelContext) throws {
        let fixtures = [
            ("B1F0A001-EE01-4E10-9000-000000000301", "Category cables", InventoryCategory.cablesAndAdapters.rawValue),
            ("B1F0A001-EE01-4E10-9000-000000000302", "Category documents", InventoryCategory.documents.rawValue),
            ("B1F0A001-EE01-4E10-9000-000000000303", "Category long custom", "Extremely Long English Category Name That Must Stay Whole"),
            ("B1F0A001-EE01-4E10-9000-000000000304", "Second long custom category", "Extremely Long English Category Name That Must Stay Whole"),
            ("B1F0A001-EE01-4E10-9000-000000000305", "Category Ukrainian custom", "Надзвичайно довга українська назва категорії без скорочення"),
            ("B1F0A001-EE01-4E10-9000-000000000306", "Second Ukrainian custom category", "Надзвичайно довга українська назва категорії без скорочення")
        ]

        let existingItems = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<InventoryItem>()).map { ($0.id, $0) })
        for (identifier, name, category) in fixtures {
            let id = UUID(uuidString: identifier)!
            if let item = existingItems[id] {
                item.applyUserEdit(
                    name: name,
                    category: category,
                    locationName: locationName,
                    containerName: placeName,
                    iconID: nil,
                    quantity: 1,
                    condition: InventoryCondition.good.rawValue,
                    tags: ["qa", "place-categories"],
                    notes: "Dedicated DEBUG fixture for adaptive Place category rows.",
                    updatedAt: item.updatedAt
                )
            } else {
                context.insert(InventoryItem(
                    id: id,
                    name: name,
                    category: category,
                    locationName: locationName,
                    containerName: placeName,
                    quantity: 1,
                    condition: InventoryCondition.good.rawValue,
                    tags: ["qa", "place-categories"],
                    notes: "Dedicated DEBUG fixture for adaptive Place category rows."
                ))
            }
        }
        try context.save()
    }
}

enum InventoryLocationDetailEmptyFixture {
    static let launchArgument = "--qa-location-detail-empty-fixture"
    static let locationName = "Empty Location Test"
    private static let locationID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000201")!

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func seed(in context: ModelContext) throws {
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        guard !locations.contains(where: { $0.id == locationID }) else {
            return
        }

        context.insert(
            StorageLocation(
                id: locationID,
                name: locationName,
                iconID: "garage",
                notes: "Dedicated DEBUG fixture for the empty Location Detail UI test."
            )
        )
        try context.save()
    }
}

enum InventoryPlaceManagementFixture {
    static let launchArgument = "--qa-place-management-fixture"
    static let firstLocationID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000401")!
    static let secondLocationID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000402")!
    static let firstPlaceID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000403")!
    static let secondPlaceID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000404")!

    static func isEnabled(arguments: [String]) -> Bool { arguments.contains(launchArgument) }

    static func seed(in context: ModelContext) throws {
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let first = locations.first { $0.id == firstLocationID } ?? StorageLocation(id: firstLocationID, name: "Fixture Garage")
        let second = locations.first { $0.id == secondLocationID } ?? StorageLocation(id: secondLocationID, name: "Fixture Office")
        if !locations.contains(where: { $0.id == firstLocationID }) { context.insert(first) }
        if !locations.contains(where: { $0.id == secondLocationID }) { context.insert(second) }

        let places = try context.fetch(FetchDescriptor<InventoryPlace>())
        let firstPlace = places.first { $0.id == firstPlaceID } ?? InventoryPlace(id: firstPlaceID, locationID: first.id, name: "Shared box", iconID: "box")
        let secondPlace = places.first { $0.id == secondPlaceID } ?? InventoryPlace(id: secondPlaceID, locationID: second.id, name: "Shared box", iconID: "drawer")
        if !places.contains(where: { $0.id == firstPlaceID }) { context.insert(firstPlace) }
        if !places.contains(where: { $0.id == secondPlaceID }) { context.insert(secondPlace) }

        let itemID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000405")!
        if !(try context.fetch(FetchDescriptor<InventoryItem>())).contains(where: { $0.id == itemID }) {
            context.insert(InventoryItem(id: itemID, name: "Scoped Place fixture Item", locationName: first.name, containerName: firstPlace.name, placeID: firstPlace.id))
        }
        try context.save()
    }
}

enum InventoryMovementHistoryFixture {
    static let launchArgument = "--qa-movement-history-fixture"
    static let recordID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000501")!
    static let operationID = UUID(uuidString: "B1F0A001-EE01-4E10-9000-000000000502")!

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains(launchArgument)
    }

    static func seed(in context: ModelContext) throws {
        let existingRecords = try context.fetch(FetchDescriptor<InventoryMovementRecord>())
        guard !existingRecords.contains(where: { $0.id == recordID }) else { return }

        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        guard let item = items.first(where: { $0.name == "USB-C to HDMI adapter" }),
              let sourceLocation = locations.first(where: {
                  InventoryNormalizedName.location($0.name)
                      != InventoryNormalizedName.location(item.locationName)
              })
        else {
            throw InventoryMovementHistoryFixtureError.missingSampleData
        }

        context.insert(
            InventoryMovementRecord(
                id: recordID,
                operationID: operationID,
                itemID: item.id,
                occurredAt: Date(timeIntervalSince1970: 1_750_000_000),
                origin: .singleItem,
                source: InventoryMovementEndpointSnapshot(
                    locationID: sourceLocation.id,
                    locationName: sourceLocation.name,
                    placeID: nil,
                    placeName: nil
                ),
                destination: InventoryMovementEndpointSnapshot(
                    item: item,
                    locations: locations
                )
            )
        )
        try context.save()
    }
}

enum InventoryMovementHistoryFixtureError: Error {
    case missingSampleData
}
#endif
