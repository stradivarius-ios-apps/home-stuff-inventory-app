import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryBrowseSummariesTests {
    private let items = [
        InventoryItem(
            name: "USB-C to HDMI adapter",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Office",
            containerName: "Desk drawer",
            tags: ["display", "adapter"],
            notes: "Connects the laptop to the living room TV."
        ),
        InventoryItem(
            name: "CR2032 batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen",
            containerName: "Utility drawer",
            tags: ["coin cell", "remote"],
            notes: "Spare cells for the scale."
        ),
        InventoryItem(
            name: "Thermal paste",
            category: InventoryCategory.spareParts.rawValue,
            locationName: "Office",
            containerName: "PC parts box",
            tags: ["cpu", "repair"],
            notes: "Half-used tube from desktop maintenance."
        ),
        InventoryItem(
            name: "Passport photos",
            category: InventoryCategory.documents.rawValue,
            locationName: "Hallway drawer",
            containerName: nil,
            tags: ["documents"],
            notes: "Small envelope with ID photos."
        ),
        InventoryItem(
            name: "Loose hex key",
            category: InventoryCategory.tools.rawValue,
            locationName: " ",
            containerName: "Small tray",
            tags: ["tools"],
            notes: "Needs a storage spot."
        )
    ]

    private func placeDetailSummary(
        items: [InventoryItem],
        events: [InventoryItemViewEvent] = [],
        isMissingPlace: Bool = false,
        now: Date = Date(timeIntervalSince1970: 10_000)
    ) -> InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.placeDetailSummary(
            in: items,
            matching: .init(
                id: "Office::place",
                name: isMissingPlace ? "No Place" : "Desk drawer",
                itemCount: 0,
                locationID: "Office",
                locationName: "Office",
                isMissingLocation: false,
                isMissingPlace: isMissingPlace
            ),
            recentViewEvents: events,
            now: now,
            rollingWindow: 100
        )
    }

    private func placeItems(count: Int, place: String? = "Desk drawer") -> [InventoryItem] {
        (0..<count).map { index in
            InventoryItem(
                name: "Item \(index)",
                locationName: "Office",
                containerName: place
            )
        }
    }

    private func makeItem(
        name: String,
        location: String = "Office",
        place: String?
    ) -> InventoryItem {
        InventoryItem(name: name, locationName: location, containerName: place)
    }

    private func placeOpenRecord(
        location: String,
        place: String,
        count: Int,
        at timestamp: TimeInterval
    ) -> InventoryPlaceOpenRecord {
        InventoryPlaceOpenRecord(
            placeIdentity: InventoryPlaceIdentity.make(locationName: location, placeName: place).rawValue,
            openCount: count,
            lastOpenedAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    @Test func locationSummariesAreSortedAndCountItems() {
        let summaries = InventoryBrowseSummaries.locationSummaries(from: items)

        #expect(
            summaries == [
                InventoryBrowseSummaries.LocationSummary(
                    name: "Hallway drawer",
                    itemCount: 1,
                    isMissingLocation: false,
                    categoryPreview: [InventoryCategory.documents.rawValue]
                ),
                InventoryBrowseSummaries.LocationSummary(
                    name: "Kitchen",
                    itemCount: 1,
                    isMissingLocation: false,
                    categoryPreview: [InventoryCategory.batteries.rawValue],
                    placePreview: ["Utility drawer"]
                ),
                InventoryBrowseSummaries.LocationSummary(
                    name: "Office",
                    itemCount: 2,
                    isMissingLocation: false,
                    categoryPreview: [
                        InventoryCategory.cablesAndAdapters.rawValue,
                        InventoryCategory.spareParts.rawValue
                    ],
                    placePreview: ["Desk drawer", "PC parts box"]
                ),
                InventoryBrowseSummaries.LocationSummary(
                    name: "No location",
                    itemCount: 1,
                    isMissingLocation: true,
                    categoryPreview: [InventoryCategory.tools.rawValue],
                    placePreview: ["Small tray"]
                )
            ]
        )
    }

    @Test func locationSummariesUseReusableLocationIcons() {
        let locations = [
            StorageLocation(name: "Kitchen", iconID: "kitchen"),
            StorageLocation(name: "Office", iconID: "office")
        ]
        let summaries = InventoryBrowseSummaries.locationSummaries(from: items, storageLocations: locations)

        #expect(summaries.first { $0.name == "Kitchen" }?.iconID == "kitchen")
        #expect(summaries.first { $0.name == "Office" }?.iconID == "office")
        #expect(summaries.first { $0.name == "Hallway drawer" }?.iconID == nil)
        #expect(summaries.first { $0.isMissingLocation }?.iconID == nil)
    }

    @Test func locationSummariesIncludeReusableZeroItemLocationsInAlphabeticalOrder() {
        let summaries = InventoryBrowseSummaries.locationSummaries(
            from: [],
            storageLocations: [
                StorageLocation(name: "Workshop"),
                StorageLocation(name: "Attic")
            ]
        )

        #expect(summaries.map(\.name) == ["Attic", "Workshop"])
        #expect(summaries.map(\.itemCount) == [0, 0])
    }

    @Test func locationSummariesMergeReusableAndItemLocationsUsingReusableNameAndIcon() {
        let items = [
            InventoryItem(name: "Cable", locationName: " office "),
            InventoryItem(name: "Adapter", locationName: "OFFICE")
        ]
        let summaries = InventoryBrowseSummaries.locationSummaries(
            from: items,
            storageLocations: [StorageLocation(name: "Office", iconID: "office")]
        )

        #expect(summaries.count == 1)
        #expect(summaries[0].name == "Office")
        #expect(summaries[0].iconID == "office")
        #expect(summaries[0].itemCount == 2)
        #expect(InventoryBrowseSummaries.items(in: items, matching: summaries[0]).count == 2)
    }

    @Test func locationSummariesKeepMissingLocationLastAndOnlyForBlankItems() {
        let summaries = InventoryBrowseSummaries.locationSummaries(
            from: [InventoryItem(name: "Loose cable", locationName: "  ")],
            storageLocations: [StorageLocation(name: "Garage")]
        )

        #expect(summaries.map(\.name) == ["Garage", InventoryLocalization.noLocation])
        #expect(summaries.last?.isMissingLocation == true)
        #expect(summaries.last?.itemCount == 1)
    }

    @Test func locationsRootHasContentForReusableLocationWithoutItems() {
        #expect(
            InventoryBrowseSummaries.hasLocationsRootContent(
                items: [],
                storageLocations: [StorageLocation(name: "Garage")]
            )
        )
        #expect(!InventoryBrowseSummaries.hasLocationsRootContent(items: [], storageLocations: []))
    }

    @Test func locationSummariesPreviewMostCommonPlacesFirst() {
        let items = [
            InventoryItem(
                name: "Adapter",
                category: InventoryCategory.cablesAndAdapters.rawValue,
                locationName: "Office",
                containerName: "Desk drawer"
            ),
            InventoryItem(
                name: "Cable",
                category: InventoryCategory.cablesAndAdapters.rawValue,
                locationName: "Office",
                containerName: "Desk drawer"
            ),
            InventoryItem(
                name: "Screws",
                category: InventoryCategory.spareParts.rawValue,
                locationName: "Office",
                containerName: "Parts box"
            ),
            InventoryItem(
                name: "Tape",
                category: InventoryCategory.householdSupplies.rawValue,
                locationName: "Office",
                containerName: "Shelf"
            ),
            InventoryItem(
                name: "Label maker",
                category: InventoryCategory.tools.rawValue,
                locationName: "Office",
                containerName: "Cabinet"
            )
        ]

        let summary = InventoryBrowseSummaries.locationSummaries(from: items)[0]

        #expect(summary.placePreview == ["Desk drawer", "Cabinet", "Parts box"])
    }

    @Test func locationPlacePreviewsRankByPopularityThenFrozenTieBreaks() {
        let items = [
            makeItem(name: "Desk 1", place: "Desk drawer"),
            makeItem(name: "Desk 2", place: "Desk drawer"),
            makeItem(name: "Desk 3", place: "Desk drawer"),
            makeItem(name: "Desk 4", place: "Desk drawer"),
            makeItem(name: "Shelf 1", place: "Shelf"),
            makeItem(name: "Shelf 2", place: "Shelf"),
            makeItem(name: "Parts", place: "Parts box"),
            makeItem(name: "Cabinet", place: "Cabinet"),
            makeItem(name: "Loose", place: nil)
        ]
        let records = [
            placeOpenRecord(location: "Office", place: "Parts box", count: 4, at: 100),
            placeOpenRecord(location: "Office", place: "Cabinet", count: 4, at: 200),
            placeOpenRecord(location: "Office", place: "Shelf", count: 8, at: 10),
            InventoryPlaceOpenRecord(placeIdentity: "stale", openCount: 99, lastOpenedAt: .distantFuture),
            placeOpenRecord(location: "Office", place: "Desk drawer", count: -1, at: 300)
        ]

        let summary = InventoryBrowseSummaries.locationSummaries(
            from: items,
            placeOpenRecords: records
        )[0]

        #expect(summary.placePreview == ["Shelf", "Cabinet", "Parts box"])
        #expect(summary.hiddenPlaceCount == 1)
    }

    @Test func locationPlacePreviewsScopePopularityAndRetainFallbackAndDetailOrdering() {
        let items = [
            makeItem(name: "Office desk 1", location: "Office", place: "Desk drawer"),
            makeItem(name: "Office desk 2", location: "Office", place: "Desk drawer"),
            makeItem(name: "Office parts", location: "Office", place: "Parts box"),
            makeItem(name: "Kitchen desk", location: "Kitchen", place: "Desk drawer")
        ]
        let kitchenRecord = placeOpenRecord(location: "Kitchen", place: "Desk drawer", count: 9, at: 100)
        let office = InventoryBrowseSummaries.locationSummaries(from: items, placeOpenRecords: [kitchenRecord])
            .first { $0.name == "Office" }!
        let noRecords = InventoryBrowseSummaries.locationSummaries(from: items)
            .first { $0.name == "Office" }!

        #expect(office.placePreview == ["Desk drawer", "Parts box"])
        #expect(noRecords.placePreview == ["Desk drawer", "Parts box"])
        #expect(
            InventoryBrowseSummaries.placeSummaries(in: items, matching: office)
                .map(\.name) == ["Desk drawer", "Parts box"]
        )
    }

    @Test func locationPlacePreviewsRecomputeWhenPopularityRecordsChange() {
        let items = [
            makeItem(name: "Desk 1", place: "Desk drawer"),
            makeItem(name: "Desk 2", place: "Desk drawer"),
            makeItem(name: "Parts", place: "Parts box")
        ]
        let initial = InventoryBrowseSummaries.locationSummaries(from: items)[0]
        let updated = InventoryBrowseSummaries.locationSummaries(
            from: items,
            placeOpenRecords: [placeOpenRecord(location: "Office", place: "Parts box", count: 1, at: 1)]
        )[0]

        #expect(initial.placePreview == ["Desk drawer", "Parts box"])
        #expect(updated.placePreview == ["Parts box", "Desk drawer"])
    }

    @Test func locationPlacePreviewsUseItemCountNameAndIdentityAfterEqualPopularity() {
        let items = [
            makeItem(name: "Alpha 1", place: "Alpha"),
            makeItem(name: "Alpha 2", place: "Alpha"),
            makeItem(name: "Bravo", place: "Bravo"),
            makeItem(name: "Charcoal", place: "charcoal"),
            makeItem(name: "Charcoal 2", place: "Charcoal")
        ]
        let records = [
            placeOpenRecord(location: "Office", place: "Alpha", count: 1, at: 100),
            placeOpenRecord(location: "Office", place: "Bravo", count: 1, at: 100),
            placeOpenRecord(location: "Office", place: "charcoal", count: 1, at: 100)
        ]

        let summary = InventoryBrowseSummaries.locationSummaries(from: items, placeOpenRecords: records)[0]

        #expect(summary.placePreview == ["Alpha", "charcoal", "Bravo"])
    }

    @Test func locationSummariesExposeSemanticCategoryAndPlacePreviewGroups() {
        let items = [
            InventoryItem(name: "Adapter", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Cable", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Manual", category: InventoryCategory.documents.rawValue, locationName: "Office", containerName: "Cabinet"),
            InventoryItem(name: "Receipt", category: InventoryCategory.documents.rawValue, locationName: "Office", containerName: "Shelf"),
            InventoryItem(name: "Battery", category: InventoryCategory.batteries.rawValue, locationName: "Office", containerName: "Parts box"),
            InventoryItem(name: "Tape", category: InventoryCategory.householdSupplies.rawValue, locationName: "Office", containerName: "Supply bin")
        ]

        let summary = InventoryBrowseSummaries.locationSummaries(from: items)[0]

        #expect(
            summary.previewGroups == [
                InventoryBrowseSummaries.PreviewGroup(
                    kind: .category,
                    visibleItems: [
                        InventoryBrowseSummaries.PreviewItem(id: InventoryCategory.cablesAndAdapters.rawValue, title: InventoryCategory.cablesAndAdapters.rawValue),
                        InventoryBrowseSummaries.PreviewItem(id: InventoryCategory.documents.rawValue, title: InventoryCategory.documents.rawValue),
                        InventoryBrowseSummaries.PreviewItem(id: InventoryCategory.batteries.rawValue, title: InventoryCategory.batteries.rawValue)
                    ],
                    hiddenCount: 1
                ),
                InventoryBrowseSummaries.PreviewGroup(
                    kind: .place,
                    visibleItems: [
                        InventoryBrowseSummaries.PreviewItem(id: "Desk drawer", title: "Desk drawer"),
                        InventoryBrowseSummaries.PreviewItem(id: "Cabinet", title: "Cabinet"),
                        InventoryBrowseSummaries.PreviewItem(id: "Parts box", title: "Parts box")
                    ],
                    hiddenCount: 2
                )
            ]
        )
    }

    @Test func locationSummariesPreviewMostCommonCategoriesWithAlphabeticalTies() {
        let items = [
            InventoryItem(name: "Cable", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office"),
            InventoryItem(name: "Adapter", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office"),
            InventoryItem(name: "Manual", category: InventoryCategory.documents.rawValue, locationName: "Office"),
            InventoryItem(name: "Receipt", category: InventoryCategory.documents.rawValue, locationName: "Office"),
            InventoryItem(name: "Wrench", category: InventoryCategory.tools.rawValue, locationName: "Office"),
            InventoryItem(name: "Tape", category: InventoryCategory.householdSupplies.rawValue, locationName: "Office"),
            InventoryItem(name: "Battery", category: InventoryCategory.batteries.rawValue, locationName: "Office")
        ]

        let summary = InventoryBrowseSummaries.locationSummaries(from: items)[0]

        #expect(
            summary.categoryPreview == [
                InventoryCategory.cablesAndAdapters.rawValue,
                InventoryCategory.documents.rawValue,
                InventoryCategory.batteries.rawValue
            ]
        )
        #expect(summary.hiddenCategoryCount == 2)
    }

    @Test func categoryPreviewsUseInjectedVocabularyAndPreserveCustomNames() {
        let vocabulary = InventoryBrowseVocabulary(
            missingLocationName: "Missing location",
            missingPlaceName: "Missing place",
            categoryNames: [.tools: "Workshop tools"]
        )
        let items = [
            InventoryItem(name: "Hammer", category: InventoryCategory.tools.rawValue, locationName: "Garage"),
            InventoryItem(name: "Glue", category: "Craft Supplies", locationName: "Garage")
        ]

        let summary = InventoryBrowseSummaries.locationSummaries(
            from: items,
            vocabulary: vocabulary
        )[0]

        #expect(summary.categoryPreview == ["Craft Supplies", "Workshop tools"])
        #expect(items.map(\.category) == [InventoryCategory.tools.rawValue, "Craft Supplies"])
    }

    @Test func locationSummariesOmitRecentItemGroupWhenNoRecentEventsExist() {
        let summary = InventoryBrowseSummaries.locationSummaries(from: items)[0]

        #expect(summary.previewGroups.contains { $0.kind == .recentItem } == false)
    }

    @Test func locationSummariesScopeRecentItemPreviewToSelectedLocation() {
        let now = Date(timeIntervalSince1970: 10_000)
        let officeCable = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            name: "Office cable",
            locationName: "Office"
        )
        let officeAdapter = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            name: "Office adapter",
            locationName: "Office"
        )
        let kitchenBattery = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            name: "Kitchen battery",
            locationName: "Kitchen"
        )
        let events = [
            InventoryItemViewEvent(itemID: kitchenBattery.id, viewedAt: now.addingTimeInterval(-1)),
            InventoryItemViewEvent(itemID: kitchenBattery.id, viewedAt: now.addingTimeInterval(-2)),
            InventoryItemViewEvent(itemID: officeAdapter.id, viewedAt: now.addingTimeInterval(-3)),
            InventoryItemViewEvent(itemID: officeCable.id, viewedAt: now.addingTimeInterval(-4)),
            InventoryItemViewEvent(itemID: officeCable.id, viewedAt: now.addingTimeInterval(-5))
        ]

        let office = InventoryBrowseSummaries.locationSummaries(
            from: [officeCable, officeAdapter, kitchenBattery],
            recentViewEvents: events,
            now: now,
            rollingWindow: 100
        )
        .first { $0.name == "Office" }

        let recentGroup = office?.previewGroups.first { $0.kind == .recentItem }

        #expect(recentGroup?.visibleItems.map(\.title) == ["Office adapter", "Office cable"])
        #expect(recentGroup?.hiddenCount == 0)
    }

    @Test func locationSummariesLimitRecentItemPreviewAndExposeHiddenCount() {
        let now = Date(timeIntervalSince1970: 10_000)
        let officeItems = [
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!, name: "Adapter", locationName: "Office"),
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!, name: "Cable", locationName: "Office"),
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!, name: "Manual", locationName: "Office"),
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000204")!, name: "Tape", locationName: "Office")
        ]
        let events = officeItems.enumerated().map { offset, item in
            InventoryItemViewEvent(itemID: item.id, viewedAt: now.addingTimeInterval(TimeInterval(-offset)))
        }

        let summary = InventoryBrowseSummaries.locationSummaries(
            from: officeItems,
            recentViewEvents: events,
            now: now,
            rollingWindow: 100
        )[0]
        let recentGroup = summary.previewGroups.first { $0.kind == .recentItem }

        #expect(recentGroup?.visibleItems.map(\.title) == ["Adapter", "Cable", "Manual"])
        #expect(recentGroup?.hiddenCount == 1)
    }

    @Test func locationSummariesGroupNamedLocationsCaseInsensitively() {
        let duplicateLocationItem = InventoryItem(
            name: "USB hub",
            category: InventoryCategory.electronics.rawValue,
            locationName: "office",
            containerName: "Desk drawer"
        )
        let summaries = InventoryBrowseSummaries.locationSummaries(from: items + [duplicateLocationItem])

        #expect(summaries.first { $0.name == "Office" }?.itemCount == 3)
        #expect(summaries.filter { !$0.isMissingLocation && $0.name.localizedCaseInsensitiveCompare("office") == .orderedSame }.count == 1)
    }

    @Test func itemsMatchingLocationSummaryReturnsOnlyItemsInThatLocation() {
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 2, isMissingLocation: false)
        let matches = InventoryBrowseSummaries.items(in: items, matching: office)

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter", "Thermal paste"])
    }

    @Test func itemsMatchingLocationSummaryNormalizesSummaryNameWhitespace() {
        let office = InventoryBrowseSummaries.LocationSummary(name: " \n Office  ", itemCount: 2, isMissingLocation: false)
        let matches = InventoryBrowseSummaries.items(in: items, matching: office)

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter", "Thermal paste"])
    }

    @Test func itemsMatchingMissingLocationSummaryReturnsOnlyItemsWithoutLocation() {
        let missingLocation = InventoryBrowseSummaries.LocationSummary(name: "No location", itemCount: 1, isMissingLocation: true)
        let matches = InventoryBrowseSummaries.items(in: items, matching: missingLocation)

        #expect(matches.map(\.name) == ["Loose hex key"])
    }

    @Test func placeSummariesGroupNamedPlacesWithinSelectedLocation() {
        let officeItems = items + [
            InventoryItem(
                name: "Display cable",
                category: InventoryCategory.cablesAndAdapters.rawValue,
                locationName: "Office",
                containerName: "desk drawer"
            )
        ]
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 3, isMissingLocation: false)
        let summaries = InventoryBrowseSummaries.placeSummaries(in: officeItems, matching: office)

        #expect(
            summaries == [
                InventoryBrowseSummaries.PlaceSummary(
                    id: "Office::desk drawer",
                    name: "Desk drawer",
                    itemCount: 2,
                    locationID: "Office",
                    locationName: "Office",
                    isMissingLocation: false,
                    isMissingPlace: false,
                    categoryPreview: [InventoryCategory.cablesAndAdapters.rawValue],
                    categorySummaries: [
                        .init(
                            storageIdentity: InventoryCategory.cablesAndAdapters.rawValue,
                            displayName: InventoryCategory.cablesAndAdapters.rawValue,
                            itemCount: 2
                        )
                    ]
                ),
                InventoryBrowseSummaries.PlaceSummary(
                    id: "Office::pc parts box",
                    name: "PC parts box",
                    itemCount: 1,
                    locationID: "Office",
                    locationName: "Office",
                    isMissingLocation: false,
                    isMissingPlace: false,
                    categoryPreview: [InventoryCategory.spareParts.rawValue],
                    categorySummaries: [
                        .init(
                            storageIdentity: InventoryCategory.spareParts.rawValue,
                            displayName: InventoryCategory.spareParts.rawValue,
                            itemCount: 1
                        )
                    ]
                )
            ]
        )
    }

    @Test func placeSummariesGroupWhitespacePlacesUnderMissingPlace() {
        let hallwayItems = items + [
            InventoryItem(
                name: "Spare keys",
                category: InventoryCategory.tools.rawValue,
                locationName: "Hallway drawer",
                containerName: " \n "
            )
        ]
        let hallway = InventoryBrowseSummaries.LocationSummary(name: "Hallway drawer", itemCount: 2, isMissingLocation: false)
        let summaries = InventoryBrowseSummaries.placeSummaries(in: hallwayItems, matching: hallway)

        #expect(
            summaries == [
                InventoryBrowseSummaries.PlaceSummary(
                    id: "Hallway drawer::__missing_place__",
                    name: "No Place",
                    itemCount: 2,
                    locationID: "Hallway drawer",
                    locationName: "Hallway drawer",
                    isMissingLocation: false,
                    isMissingPlace: true,
                    categoryPreview: [
                        InventoryCategory.documents.rawValue,
                        InventoryCategory.tools.rawValue
                    ],
                    categorySummaries: [
                        .init(
                            storageIdentity: InventoryCategory.documents.rawValue,
                            displayName: InventoryCategory.documents.rawValue,
                            itemCount: 1
                        ),
                        .init(
                            storageIdentity: InventoryCategory.tools.rawValue,
                            displayName: InventoryCategory.tools.rawValue,
                            itemCount: 1
                        )
                    ]
                )
            ]
        )
    }

    @Test func placeSummariesSortNamedPlacesByCountThenNameWithMissingPlaceLast() {
        let officeItems = [
            InventoryItem(name: "Adapter", locationName: "Office", containerName: "Shelf"),
            InventoryItem(name: "Cable", locationName: "Office", containerName: "Shelf"),
            InventoryItem(name: "USB hub", locationName: "Office", containerName: "Cabinet"),
            InventoryItem(name: "Tape", locationName: "Office", containerName: "Bin"),
            InventoryItem(name: "Manual", locationName: "Office", containerName: nil)
        ]
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 5, isMissingLocation: false)
        let summaries = InventoryBrowseSummaries.placeSummaries(in: officeItems, matching: office)

        #expect(summaries.map(\.name) == ["Shelf", "Bin", "Cabinet", "No Place"])
        #expect(summaries.map(\.itemCount) == [2, 1, 1, 1])
        #expect(summaries.last?.isMissingPlace == true)
    }

    @Test func placeSummariesPreviewMostCommonCategoriesWithLimitsAndOverflow() {
        let officeItems = [
            InventoryItem(name: "Cable", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Adapter", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Manual", category: InventoryCategory.documents.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Receipt", category: InventoryCategory.documents.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Battery", category: InventoryCategory.batteries.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Tape", category: InventoryCategory.householdSupplies.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Wrench", category: InventoryCategory.tools.rawValue, locationName: "Office", containerName: "Desk drawer")
        ]
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 7, isMissingLocation: false)
        let summary = InventoryBrowseSummaries.placeSummaries(in: officeItems, matching: office)[0]

        #expect(
            summary.categoryPreview == [
                InventoryCategory.cablesAndAdapters.rawValue,
                InventoryCategory.documents.rawValue,
                InventoryCategory.batteries.rawValue
            ]
        )
        #expect(summary.hiddenCategoryCount == 2)
    }

    @Test func placeSummariesExposeSemanticCategoryPreviewGroup() {
        let officeItems = [
            InventoryItem(name: "Cable", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Adapter", category: InventoryCategory.cablesAndAdapters.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Manual", category: InventoryCategory.documents.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Battery", category: InventoryCategory.batteries.rawValue, locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(name: "Tape", category: InventoryCategory.householdSupplies.rawValue, locationName: "Office", containerName: "Desk drawer")
        ]
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 5, isMissingLocation: false)
        let summary = InventoryBrowseSummaries.placeSummaries(in: officeItems, matching: office)[0]

        #expect(
            summary.previewGroups == [
                InventoryBrowseSummaries.PreviewGroup(
                    kind: .category,
                    visibleItems: [
                        InventoryBrowseSummaries.PreviewItem(id: InventoryCategory.cablesAndAdapters.rawValue, title: InventoryCategory.cablesAndAdapters.rawValue),
                        InventoryBrowseSummaries.PreviewItem(id: InventoryCategory.batteries.rawValue, title: InventoryCategory.batteries.rawValue),
                        InventoryBrowseSummaries.PreviewItem(id: InventoryCategory.documents.rawValue, title: InventoryCategory.documents.rawValue)
                    ],
                    hiddenCount: 1
                )
            ]
        )
    }

    @Test func placeCategorySummariesRankAllCategoriesByCountLocalizedNameAndStoredIdentity() {
        let vocabulary = InventoryBrowseVocabulary(
            missingLocationName: "No location",
            missingPlaceName: "No Place",
            categoryNames: [.tools: "Workshop", .documents: "Archive"]
        )
        let builtInAlias = InventoryItem(name: "Hammer", category: InventoryCategory.tools.rawValue, locationName: "Garage", containerName: "Bench")
        builtInAlias.category = "Інструменти"
        let items = [
            builtInAlias,
            InventoryItem(name: "Saw", category: InventoryCategory.tools.rawValue, locationName: "Garage", containerName: "Bench"),
            InventoryItem(name: "Manual", category: InventoryCategory.documents.rawValue, locationName: "Garage", containerName: "Bench"),
            InventoryItem(name: "Craft", category: "Craft Supplies", locationName: "Garage", containerName: "Bench"),
            InventoryItem(name: "Lighting", category: "Lighting", locationName: "Garage", containerName: "Bench")
        ]

        let summaries = InventoryBrowseSummaries.placeCategorySummaries(from: items, vocabulary: vocabulary)

        #expect(summaries.map(\.storageIdentity) == ["tools", "documents", "Craft Supplies", "Lighting"])
        #expect(summaries.map(\.displayName) == ["Workshop", "Archive", "Craft Supplies", "Lighting"])
        #expect(summaries.map(\.itemCount) == [2, 1, 1, 1])
    }

    @Test func placeSummariesScopeRecentItemPreviewToSelectedLocationAndPlace() {
        let now = Date(timeIntervalSince1970: 10_000)
        let officeDeskCable = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
            name: "Office desk cable",
            locationName: "Office",
            containerName: "Desk drawer"
        )
        let officeDeskAdapter = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
            name: "Office desk adapter",
            locationName: "Office",
            containerName: "Desk drawer"
        )
        let officeShelfManual = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
            name: "Office shelf manual",
            locationName: "Office",
            containerName: "Shelf"
        )
        let kitchenDeskTape = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000304")!,
            name: "Kitchen desk tape",
            locationName: "Kitchen",
            containerName: "Desk drawer"
        )
        let events = [
            InventoryItemViewEvent(itemID: kitchenDeskTape.id, viewedAt: now.addingTimeInterval(-1)),
            InventoryItemViewEvent(itemID: kitchenDeskTape.id, viewedAt: now.addingTimeInterval(-2)),
            InventoryItemViewEvent(itemID: officeShelfManual.id, viewedAt: now.addingTimeInterval(-3)),
            InventoryItemViewEvent(itemID: officeDeskAdapter.id, viewedAt: now.addingTimeInterval(-4)),
            InventoryItemViewEvent(itemID: officeDeskCable.id, viewedAt: now.addingTimeInterval(-5)),
            InventoryItemViewEvent(itemID: officeDeskCable.id, viewedAt: now.addingTimeInterval(-6))
        ]
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 3, isMissingLocation: false)

        let deskDrawer = InventoryBrowseSummaries.placeSummaries(
            in: [officeDeskCable, officeDeskAdapter, officeShelfManual, kitchenDeskTape],
            matching: office,
            recentViewEvents: events,
            now: now,
            rollingWindow: 100
        )
        .first { $0.name == "Desk drawer" }
        let recentGroup = deskDrawer?.previewGroups.first { $0.kind == .recentItem }

        #expect(recentGroup?.visibleItems.map(\.title) == ["Office desk adapter", "Office desk cable"])
        #expect(recentGroup?.hiddenCount == 0)
    }

    @Test func placeSummariesLimitRecentItemPreviewAndExposeHiddenCount() {
        let now = Date(timeIntervalSince1970: 10_000)
        let officeItems = [
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!, name: "Adapter", locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!, name: "Cable", locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!, name: "Manual", locationName: "Office", containerName: "Desk drawer"),
            InventoryItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!, name: "Tape", locationName: "Office", containerName: "Desk drawer")
        ]
        let events = officeItems.enumerated().map { offset, item in
            InventoryItemViewEvent(itemID: item.id, viewedAt: now.addingTimeInterval(TimeInterval(-offset)))
        }
        let office = InventoryBrowseSummaries.LocationSummary(name: "Office", itemCount: 4, isMissingLocation: false)
        let summary = InventoryBrowseSummaries.placeSummaries(
            in: officeItems,
            matching: office,
            recentViewEvents: events,
            now: now,
            rollingWindow: 100
        )[0]
        let recentGroup = summary.previewGroups.first { $0.kind == .recentItem }

        #expect(recentGroup?.visibleItems.map(\.title) == ["Adapter", "Cable", "Manual"])
        #expect(recentGroup?.hiddenCount == 1)
    }

    @Test func placeDetailSummaryRecomputesSelectedPlaceAndPreservesParentLocationMetadata() {
        let now = Date(timeIntervalSince1970: 10_000)
        let selectedPlace = InventoryBrowseSummaries.PlaceSummary(
            id: "Office::desk drawer",
            name: " \n Desk drawer  ",
            itemCount: 2,
            locationID: "Office",
            locationName: " \n Office  ",
            isMissingLocation: false,
            isMissingPlace: false
        )
        let remainingItem = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
            name: "Cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "office",
            containerName: "desk drawer"
        )
        let otherPlaceItem = InventoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
            name: "Manual",
            category: InventoryCategory.documents.rawValue,
            locationName: "Office",
            containerName: "Shelf"
        )
        let events = [
            InventoryItemViewEvent(itemID: otherPlaceItem.id, viewedAt: now),
            InventoryItemViewEvent(itemID: remainingItem.id, viewedAt: now.addingTimeInterval(-1))
        ]

        let summary = InventoryBrowseSummaries.placeDetailSummary(
            in: [remainingItem, otherPlaceItem],
            matching: selectedPlace,
            recentViewEvents: events,
            now: now,
            rollingWindow: 100
        )

        #expect(summary.id == selectedPlace.id)
        #expect(summary.locationID == selectedPlace.locationID)
        #expect(summary.locationName == selectedPlace.locationName)
        #expect(summary.name == "Desk drawer")
        #expect(summary.itemCount == 1)
        #expect(summary.categoryPreview == [InventoryCategory.cablesAndAdapters.rawValue])
        #expect(summary.previewGroups.contains { $0.kind == .recentItem } == false)
    }

    @Test func placeDetailRecentItemsStayHiddenBelowFiveCurrentItems() {
        let now = Date(timeIntervalSince1970: 10_000)
        let oneItem = placeItems(count: 1)
        let fourItems = placeItems(count: 4)

        #expect(placeDetailSummary(items: []).previewGroups.contains { $0.kind == .recentItem } == false)
        #expect(
            placeDetailSummary(
                items: oneItem,
                events: [InventoryItemViewEvent(itemID: oneItem[0].id, viewedAt: now)]
            ).previewGroups.contains { $0.kind == .recentItem } == false
        )
        #expect(
            placeDetailSummary(
                items: fourItems,
                events: fourItems.map { InventoryItemViewEvent(itemID: $0.id, viewedAt: now) }
            ).previewGroups.contains { $0.kind == .recentItem } == false
        )
    }

    @Test func placeDetailRecentItemsRequireMatchingHistoryAtFiveItems() {
        let now = Date(timeIntervalSince1970: 10_000)
        let fiveItems = placeItems(count: 5)

        #expect(placeDetailSummary(items: fiveItems).previewGroups.contains { $0.kind == .recentItem } == false)

        let summary = placeDetailSummary(
            items: fiveItems,
            events: [InventoryItemViewEvent(itemID: fiveItems[0].id, viewedAt: now)]
        )
        let recentItems = summary.previewGroups.first { $0.kind == .recentItem }
        #expect(recentItems?.visibleItems.map(\.id) == [fiveItems[0].id.uuidString])
        #expect(recentItems?.hiddenCount == 0)
    }

    @Test func placeDetailRecentItemsKeepThreePlusOverflowAtFiveItems() {
        let now = Date(timeIntervalSince1970: 10_000)
        let fiveItems = placeItems(count: 5)
        let events = fiveItems.enumerated().map { offset, item in
            InventoryItemViewEvent(itemID: item.id, viewedAt: now.addingTimeInterval(-TimeInterval(offset)))
        }

        let recentItems = placeDetailSummary(items: fiveItems, events: events)
            .previewGroups.first { $0.kind == .recentItem }
        #expect(recentItems?.visibleItems.map(\.id) == fiveItems.prefix(3).map { $0.id.uuidString })
        #expect(recentItems?.hiddenCount == 2)
    }

    @Test func placeDetailRecentItemsIgnoreEventsOutsideTheCurrentPlace() {
        let now = Date(timeIntervalSince1970: 10_000)
        let fiveItems = placeItems(count: 5)
        let otherPlaceItem = InventoryItem(name: "Other place", locationName: "Office", containerName: "Shelf")
        let otherLocationItem = InventoryItem(name: "Other location", locationName: "Kitchen", containerName: "Desk drawer")

        let summary = placeDetailSummary(
            items: fiveItems + [otherPlaceItem, otherLocationItem],
            events: [
                InventoryItemViewEvent(itemID: otherPlaceItem.id, viewedAt: now),
                InventoryItemViewEvent(itemID: otherLocationItem.id, viewedAt: now)
            ]
        )

        #expect(summary.previewGroups.contains { $0.kind == .recentItem } == false)
    }

    @Test func missingPlaceDetailRecentItemsUseTheSameFourFiveBoundary() {
        let now = Date(timeIntervalSince1970: 10_000)
        let fourItems = placeItems(count: 4, place: nil)
        let fiveItems = placeItems(count: 5, place: nil)

        #expect(
            placeDetailSummary(
                items: fourItems,
                events: fourItems.map { InventoryItemViewEvent(itemID: $0.id, viewedAt: now) },
                isMissingPlace: true
            ).previewGroups.contains { $0.kind == .recentItem } == false
        )
        #expect(
            placeDetailSummary(
                items: fiveItems,
                events: [InventoryItemViewEvent(itemID: fiveItems[0].id, viewedAt: now)],
                isMissingPlace: true
            ).previewGroups.first { $0.kind == .recentItem }?.visibleItems.map(\.id) == [fiveItems[0].id.uuidString]
        )
    }

    @Test func locationRecentItemsRemainVisibleBelowFiveItems() {
        let now = Date(timeIntervalSince1970: 10_000)
        let locationItems = placeItems(count: 1)

        let summary = InventoryBrowseSummaries.locationSummaries(
            from: locationItems,
            recentViewEvents: [InventoryItemViewEvent(itemID: locationItems[0].id, viewedAt: now)],
            now: now,
            rollingWindow: 100
        ).first

        #expect(summary?.previewGroups.first { $0.kind == .recentItem }?.visibleItems.map(\.id) == [locationItems[0].id.uuidString])
    }

    @Test func placeDetailSummaryHandlesEmptySelectedPlace() {
        let selectedPlace = InventoryBrowseSummaries.PlaceSummary(
            id: "Office::desk drawer",
            name: "Desk drawer",
            itemCount: 2,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        )

        let summary = InventoryBrowseSummaries.placeDetailSummary(in: [], matching: selectedPlace)

        #expect(summary.id == selectedPlace.id)
        #expect(summary.locationID == "Office")
        #expect(summary.locationName == "Office")
        #expect(summary.name == "Desk drawer")
        #expect(summary.itemCount == 0)
        #expect(summary.categoryPreview.isEmpty)
        #expect(summary.previewGroups.isEmpty)
    }

    @Test func itemsMatchingPlaceSummaryReturnsOnlyItemsFromThatLocationAndPlace() {
        let mixedItems = items + [
            InventoryItem(
                name: "Desk drawer tape",
                category: InventoryCategory.householdSupplies.rawValue,
                locationName: "Kitchen",
                containerName: "Desk drawer"
            ),
            InventoryItem(
                name: "Desk drawer spare cable",
                category: InventoryCategory.cablesAndAdapters.rawValue,
                locationName: "office",
                containerName: "desk drawer"
            )
        ]
        let place = InventoryBrowseSummaries.PlaceSummary(
            id: "Office::desk drawer",
            name: "Desk drawer",
            itemCount: 2,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        )
        let matches = InventoryBrowseSummaries.items(in: mixedItems, matching: place)

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter", "Desk drawer spare cable"])
    }

    @Test func itemsMatchingPlaceSummaryNormalizesSummaryNamesWhitespace() {
        let place = InventoryBrowseSummaries.PlaceSummary(
            id: "Office::desk drawer",
            name: " \n Desk drawer  ",
            itemCount: 1,
            locationID: "Office",
            locationName: " \n Office  ",
            isMissingLocation: false,
            isMissingPlace: false
        )
        let matches = InventoryBrowseSummaries.items(in: items, matching: place)

        #expect(matches.map(\.name) == ["USB-C to HDMI adapter"])
    }

    @Test func itemsMatchingMissingPlaceSummaryReturnsOnlyItemsWithoutPlaceInThatLocation() {
        let hallwayItems = items + [
            InventoryItem(
                name: "Unsorted receipt",
                category: InventoryCategory.documents.rawValue,
                locationName: "Hallway drawer",
                containerName: " \n "
            ),
            InventoryItem(
                name: "Loose manual",
                category: InventoryCategory.documents.rawValue,
                locationName: "Office",
                containerName: nil
            )
        ]
        let missingPlace = InventoryBrowseSummaries.PlaceSummary(
            id: "Hallway drawer::__missing_place__",
            name: "No Place",
            itemCount: 2,
            locationID: "Hallway drawer",
            locationName: "Hallway drawer",
            isMissingLocation: false,
            isMissingPlace: true
        )
        let matches = InventoryBrowseSummaries.items(in: hallwayItems, matching: missingPlace)

        #expect(matches.map(\.name) == ["Passport photos", "Unsorted receipt"])
    }

    @Test func stablePlaceSummaryKeepsScopedUnlinkedLegacyItemsVisible() {
        let office = StorageLocation(name: "Office")
        let garage = StorageLocation(name: "Garage")
        let officeBox = InventoryPlace(locationID: office.id, name: "Red Box")
        let garageBox = InventoryPlace(locationID: garage.id, name: "Red Box")
        let linked = InventoryItem(name: "Linked", locationName: "Office", containerName: "Red Box", placeID: officeBox.id)
        let legacy = InventoryItem(name: "Legacy", locationName: " office ", containerName: " red box ")
        let otherLinked = InventoryItem(name: "Other", locationName: "Office", containerName: "Red Box", placeID: garageBox.id)
        let summary = InventoryBrowseSummaries.PlaceSummary(id: "office::red", placeID: officeBox.id, name: "Red Box", itemCount: 2, locationID: "Office", locationName: "Office", isMissingLocation: false, isMissingPlace: false)

        #expect(InventoryBrowseSummaries.items(in: [linked, legacy, otherLinked], matching: summary).map(\.name) == ["Linked", "Legacy"])
    }

    @Test func renamedStablePlaceStillResolvesItsItemsWhileMissingBucketStaysSeparate() {
        let location = StorageLocation(name: "Office")
        let place = InventoryPlace(locationID: location.id, name: "New Drawer")
        let linked = InventoryItem(name: "Linked", locationName: "Office", containerName: "New Drawer", placeID: place.id)
        let missing = InventoryItem(name: "Missing", locationName: "Office", containerName: nil)
        let renamed = InventoryBrowseSummaries.PlaceSummary(id: "office::new", placeID: place.id, name: "New Drawer", itemCount: 1, locationID: "Office", locationName: "Office", isMissingLocation: false, isMissingPlace: false)
        let missingSummary = InventoryBrowseSummaries.PlaceSummary(id: "office::missing", name: "No Place", itemCount: 1, locationID: "Office", locationName: "Office", isMissingLocation: false, isMissingPlace: true)

        #expect(InventoryBrowseSummaries.items(in: [linked, missing], matching: renamed).map(\.name) == ["Linked"])
        #expect(InventoryBrowseSummaries.items(in: [linked, missing], matching: missingSummary).map(\.name) == ["Missing"])
    }

    @Test func stablePlaceIconPresentationDrivesBrowseHeroAndEmptySurfaces() {
        let place = InventoryPlace(locationID: UUID(), name: "Drawer", iconID: "drawer")
        #expect(InventoryPlaceIconPresentation.symbolName(placeID: place.id, isMissingPlace: false, places: [place]) == "cabinet.fill")
        place.iconID = "invalid"
        #expect(InventoryPlaceIconPresentation.symbolName(placeID: place.id, isMissingPlace: false, places: [place]) == "shippingbox")
        #expect(InventoryPlaceIconPresentation.symbolName(placeID: nil, isMissingPlace: true, places: [place]) == "shippingbox.circle")
    }
}
