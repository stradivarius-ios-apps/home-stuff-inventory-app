import SwiftUI
import SwiftData

struct LocationItemsListView: View {
    let location: InventoryBrowseSummaries.LocationSummary
    let items: [InventoryItem]

    private var matchingItems: [InventoryItem] {
        InventoryBrowseSummaries.items(in: items, matching: location, vocabulary: .localized)
    }

    var body: some View {
        ScopedInventoryItemsListView(
            title: location.name,
            items: matchingItems,
            emptyTitleKey: "locations.items.empty.title",
            emptyTitleDefaultValue: "No Items Here",
            emptyMessageKey: "locations.items.empty.message",
            emptyMessageDefaultValue: "Items moved out of this location will appear in their new storage spot.",
            emptySystemImage: location.isMissingLocation
                ? LocationIconCatalog.missingLocationSymbolName
                : LocationIconCatalog.symbolName(for: location.iconID),
            backgroundStyle: .locationAtmosphere
        )
    }
}

struct PlaceItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    let place: InventoryBrowseSummaries.PlaceSummary
    let items: [InventoryItem]
    let recentViewEvents: [InventoryItemViewEvent]
    @Query private var places: [InventoryPlace]

    @State private var isShowingItemForm = false
    @State private var openRegistration = InventoryPlaceOpenRegistration()
    @State private var selectedChildPlaceID: UUID?
    @State private var isAllContainedItemsPresented = false

    private var detailPlace: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.placeDetailSummary(
            in: items,
            matching: place,
            places: places,
            recentViewEvents: recentViewEvents,
            vocabulary: .localized
        )
    }

    private var matchingItems: [InventoryItem] {
        InventoryBrowseSummaries.items(in: items, matching: place, vocabulary: .localized)
    }

    private var containedItems: [InventoryItem] {
        InventoryBrowseSummaries.containedItems(
            in: items,
            matching: place,
            places: places,
            vocabulary: .localized
        )
    }

    private var childPlaces: [InventoryBrowseSummaries.PlaceSummary] {
        guard let placeID = place.placeID,
              let model = places.first(where: { $0.id == placeID })
        else {
            return []
        }
        let location = InventoryBrowseSummaries.LocationSummary(
            storageLocationID: model.locationID,
            name: place.locationName,
            itemCount: containedItems.count,
            isMissingLocation: place.isMissingLocation
        )
        return InventoryBrowseSummaries.placeSummaries(
            in: items,
            matching: location,
            places: places,
            parentPlaceID: placeID,
            recentViewEvents: recentViewEvents,
            vocabulary: .localized
        )
    }

    var body: some View {
        ScopedInventoryItemsListView(
            title: place.name,
            items: matchingItems,
            emptyTitleKey: "locations.placeItems.empty.title",
            emptyTitleDefaultValue: "No Items in This Storage Place",
            emptyMessageKey: "locations.placeItems.empty.message",
            emptyMessageDefaultValue: "Items moved out of this storage place will appear in their new storage place.",
            emptySystemImage: placeIconSystemName,
            backgroundStyle: .grouped,
            accessibilityContext: .placeDetail
        ) {
            PlaceDetailItemsHeader(
                place: detailPlace,
                matchingItems: matchingItems,
                childPlaces: childPlaces,
                onChildPlaceSelected: { selectedChildPlaceID = $0.placeID },
                onAllContainedItemsSelected: { isAllContainedItemsPresented = true }
            )
        }
        .navigationDestination(item: $selectedChildPlaceID) { childPlaceID in
            if let child = childPlaces.first(where: { $0.placeID == childPlaceID }) {
                PlaceItemsListView(
                    place: child,
                    items: items,
                    recentViewEvents: recentViewEvents
                )
            }
        }
        .navigationDestination(isPresented: $isAllContainedItemsPresented) {
            ScopedInventoryItemsListView(
                title: InventoryLocalization.string(
                    "locations.placeDetail.allContainedItems",
                    defaultValue: "All Contained Items"
                ),
                items: containedItems,
                emptyTitleKey: "locations.placeItems.empty.title",
                emptyTitleDefaultValue: "No Items in This Storage Place",
                emptyMessageKey: "locations.placeItems.empty.message",
                emptyMessageDefaultValue: "Items moved out of this storage place will appear in their new storage place.",
                emptySystemImage: placeIconSystemName,
                backgroundStyle: .grouped
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingItemForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .inventoryPrimaryActionTint()
                .accessibilityLabel("inventory.action.addItem.accessibilityLabel")
                .accessibilityIdentifier("locations.placeDetail.addItemButton")
            }
        }
        .sheet(isPresented: $isShowingItemForm) {
            InventoryItemFormView(createContext: createContext)
        }
        .task {
            // This state object belongs to one navigation destination instance; repeated
            // task execution therefore cannot inflate the aggregate.
            try? openRegistration.registerIfNeeded(
                identity: InventoryPlaceIdentity.make(
                    locationName: place.isMissingLocation ? "" : place.locationName,
                    placeName: place.isMissingPlace ? nil : place.name,
                    vocabulary: .localized
                ),
                placeID: place.placeID,
                in: modelContext
            )
        }
    }

    private var createContext: InventoryItemCreateContext {
        InventoryItemCreateContext(
            locationName: place.isMissingLocation ? "" : place.locationName,
            placeName: place.isMissingPlace ? "" : place.name,
            placeID: place.placeID
        )
    }

    private var placeIconSystemName: String {
        InventoryPlaceIconPresentation.symbolName(placeID: place.placeID, isMissingPlace: place.isMissingPlace, places: places)
    }
}

private struct PlaceDetailItemsHeader: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let place: InventoryBrowseSummaries.PlaceSummary
    let matchingItems: [InventoryItem]
    let childPlaces: [InventoryBrowseSummaries.PlaceSummary]
    let onChildPlaceSelected: (InventoryBrowseSummaries.PlaceSummary) -> Void
    let onAllContainedItemsSelected: () -> Void

    @State private var selectedRecentItemID: UUID?
    @Namespace private var recentItemNavigationNamespace

    private var recentItemsPresentation: InventoryPreviewGroupPresentation? {
        place.previewGroups
            .first { $0.kind == .recentItem }
            .flatMap(InventoryPreviewGroupPresentation.init)
    }

    private var matchingItemIDs: Set<UUID> {
        Set(matchingItems.map(\.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            PlaceDetailIdentityHeader(place: place)

            pathContext
            countSummary
            childPlacesSection

            if place.recursiveItemCount > place.directItemCount {
                Button(action: onAllContainedItemsSelected) {
                    Label(
                        InventoryLocalization.string(
                            "locations.placeDetail.allContainedItems",
                            defaultValue: "All Contained Items"
                        ),
                        systemImage: "shippingbox.and.arrow.backward"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("locations.placeDetail.allContainedItems")
            }

            if let recentItemsPresentation {
                recentItemsCard(recentItemsPresentation)
            }

            InventorySectionHeader("locations.placeDetail.directItemsSection")
        }
        .navigationDestination(item: $selectedRecentItemID) { itemID in
            if let item = matchingItems.first(where: { $0.id == itemID }) {
                InventoryItemDetailView(item: item)
                    .inventoryItemNavigationDestination(
                        id: item.id,
                        namespace: recentItemNavigationNamespace,
                        reduceMotion: accessibilityReduceMotion
                    )
            }
        }
    }

    private var pathContext: some View {
        Label {
            Text(verbatim: ([place.locationName] + place.pathComponents).joined(separator: " › "))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityLabel(
            Text(
                InventoryLocalization.formatted(
                    "locations.placeDetail.path.accessibilityLabel",
                    defaultValue: "Storage path: %@",
                    ([place.locationName] + place.pathComponents).joined(separator: ", ")
                )
            )
        )
        .accessibilityIdentifier("locations.placeDetail.path")
    }

    private var countSummary: some View {
        InventoryCard {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                LabeledContent(
                    "locations.placeDetail.directItemsCount",
                    value: InventoryLocalization.itemCount(place.directItemCount)
                )
                LabeledContent(
                    "locations.placeDetail.containedItemsCount",
                    value: InventoryLocalization.itemCount(place.recursiveItemCount)
                )
                LabeledContent(
                    "locations.placeDetail.childPlacesCount",
                    value: InventoryLocalization.placeCount(place.childPlaceCount)
                )
            }
        }
        .accessibilityIdentifier("locations.placeDetail.countSummary")
    }

    @ViewBuilder
    private var childPlacesSection: some View {
        if !childPlaces.isEmpty {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                InventorySectionHeader("locations.placeDetail.childPlacesSection")
                ForEach(childPlaces) { child in
                    Button {
                        onChildPlaceSelected(child)
                    } label: {
                        PlaceSummaryRowView(place: child)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("locations.placeDetail.childPlace.\(child.id)")
                }
            }
        }
    }

    private func recentItemsCard(_ presentation: InventoryPreviewGroupPresentation) -> some View {
        PlaceRecentItemsCard(
            presentation: presentation,
            transitionNamespace: recentItemNavigationNamespace,
            reduceMotion: accessibilityReduceMotion,
            isRecentItemResolvable: isRecentItemResolvable,
            recentItemSystemImage: recentItemSystemImage,
            onRecentItemTapped: selectRecentItem
        )
    }

    private func selectRecentItem(_ chip: InventoryPreviewGroupPresentation.Chip) {
        guard let itemID = itemID(for: chip) else {
            return
        }

        selectedRecentItemID = itemID
    }

    private func isRecentItemResolvable(_ chip: InventoryPreviewGroupPresentation.Chip) -> Bool {
        itemID(for: chip) != nil
    }

    private func recentItemSystemImage(_ chip: InventoryPreviewGroupPresentation.Chip) -> String {
        guard let itemID = itemID(for: chip),
              let item = matchingItems.first(where: { $0.id == itemID })
        else {
            return ItemIconCatalog.fallbackSymbolName
        }

        let iconID = item.iconID ?? ItemIconCatalog.defaultIconID(forCategory: item.category)
        return ItemIconCatalog.symbolName(for: iconID)
    }

    private func itemID(for chip: InventoryPreviewGroupPresentation.Chip) -> UUID? {
        guard !chip.isOverflow,
              let itemID = UUID(uuidString: chip.id),
              matchingItemIDs.contains(itemID)
        else {
            return nil
        }

        return itemID
    }
}

#if DEBUG
#Preview("Place Detail - Light") {
    PlaceDetailPreviewSurface()
        .preferredColorScheme(.light)
}

#Preview("Place Detail - Dark") {
    PlaceDetailPreviewSurface()
        .preferredColorScheme(.dark)
}

private struct PlaceDetailPreviewSurface: View {
    private let place = InventoryBrowseSummaries.PlaceSummary(
        id: "Preview Storage::Preview organizer",
        name: "Preview organizer for household cables and adapters",
        itemCount: 1,
        locationID: "Preview Storage",
        locationName: "Preview Storage",
        isMissingLocation: false,
        isMissingPlace: false
    )

    private let items = [
        InventoryItem(
            name: "Preview HDMI adapter",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Preview Storage",
            containerName: "Preview organizer for household cables and adapters",
            iconID: "cable",
            quantity: 1,
            condition: InventoryCondition.good.rawValue
        )
    ]

    var body: some View {
        NavigationStack {
            PlaceItemsListView(place: place, items: items, recentViewEvents: [])
        }
        .modelContainer(try! InventoryModelContainer.make(inMemory: true))
        .environment(
            PremiumAccessState(
                entitlements: .init(
                    ownsLifetimePro: true,
                    hasActiveFamilySubscription: false
                )
            )
        )
    }
}
#endif
