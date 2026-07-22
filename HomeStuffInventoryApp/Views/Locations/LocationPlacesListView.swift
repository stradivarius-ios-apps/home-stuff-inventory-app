import SwiftUI

struct LocationPlacesListView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let location: InventoryBrowseSummaries.LocationSummary
    let items: [InventoryItem]
    let recentViewEvents: [InventoryItemViewEvent]

    @State private var isAllItemsPresented = false
    @State private var selectedPlace: SelectedPlace?
    @State private var selectedRecentItemID: UUID?
    @State private var isShowingItemForm = false
    @State private var isShowingNavigationTitle = false
    @Namespace private var recentItemNavigationNamespace

    private var placeSummaries: [InventoryBrowseSummaries.PlaceSummary] {
        InventoryBrowseSummaries.placeSummaries(
            in: items,
            matching: location,
            recentViewEvents: recentViewEvents,
            vocabulary: .localized
        )
    }

    private var scopedItemIDs: Set<UUID> {
        Set(scopedItems.map(\.id))
    }

    private var scopedItems: [InventoryItem] {
        InventoryBrowseSummaries.items(in: items, matching: location, vocabulary: .localized)
    }

    private var recentItemsPresentation: InventoryPreviewGroupPresentation? {
        location.previewGroups
            .first { $0.kind == .recentItem }
            .flatMap(InventoryPreviewGroupPresentation.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                LocationDetailIdentityHeader(location: location)
                    .inventoryHeroNavigationTitleVisibilityAnchor()

                itemsSection

                LocationDetailPlacesSection(
                    location: location,
                    places: placeSummaries,
                    onPlaceSelected: selectPlace,
                    onAddItem: { isShowingItemForm = true }
                )
            }
            .inventoryDetailContentWidth()
            .padding(.top, detailTopPadding)
        }
        .inventoryScrollContentClearance()
        .accessibilityIdentifier("locations.locationDetail")
        .inventoryHeroNavigationTitleVisibilityObserver(
            isShowingNavigationTitle: $isShowingNavigationTitle,
            restingAnchorMinY: detailTopPadding
        )
        .accessibilityValue(isShowingNavigationTitle ? location.name : "")
        .inventoryLocationAtmosphereBackground()
        .navigationDestination(isPresented: $isAllItemsPresented) {
            LocationItemsListView(location: location, items: items)
        }
        .navigationDestination(item: $selectedPlace) { selectedPlace in
            PlaceItemsListView(
                place: currentPlace(for: selectedPlace),
                items: items,
                recentViewEvents: recentViewEvents
            )
        }
        .navigationDestination(item: $selectedRecentItemID) { itemID in
            if let item = items.first(where: { $0.id == itemID }) {
                InventoryItemDetailView(item: item)
                    .inventoryItemNavigationDestination(
                        id: item.id,
                        namespace: recentItemNavigationNamespace,
                        reduceMotion: reducesMotion
                    )
            }
        }
        .navigationTitle(isShowingNavigationTitle ? location.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingItemForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .inventoryPrimaryActionTint()
                .accessibilityLabel("inventory.action.addItem.accessibilityLabel")
                .accessibilityIdentifier("locations.locationDetail.addItemButton")
            }
        }
        .sheet(isPresented: $isShowingItemForm) {
            InventoryItemFormView(createContext: createContext)
        }
    }

    private var createContext: InventoryItemCreateContext {
        InventoryLocationCreateContext.make(for: location)
    }

    @ViewBuilder
    private var itemsSection: some View {
        if let recentItemsPresentation {
            LocationRecentItemsCard(
                presentation: recentItemsPresentation,
                locationName: location.name,
                transitionNamespace: recentItemNavigationNamespace,
                reduceMotion: reducesMotion,
                isRecentItemResolvable: isRecentItemResolvable,
                recentItemSystemImage: recentItemSystemImage,
                onRecentItemTapped: selectRecentItem
            ) {
                isAllItemsPresented = true
            }
        } else if !scopedItems.isEmpty {
            LocationItemsAccessCard(locationName: location.name) {
                isAllItemsPresented = true
            }
        }
    }

    private func selectPlace(_ place: InventoryBrowseSummaries.PlaceSummary) {
        selectedPlace = SelectedPlace(place)
    }

    private func selectRecentItem(_ chip: InventoryPreviewGroupPresentation.Chip) {
        guard !chip.isOverflow,
              let itemID = UUID(uuidString: chip.id),
              scopedItemIDs.contains(itemID)
        else {
            return
        }

        selectedRecentItemID = itemID
    }

    private func isRecentItemResolvable(_ chip: InventoryPreviewGroupPresentation.Chip) -> Bool {
        guard !chip.isOverflow,
              let itemID = UUID(uuidString: chip.id)
        else {
            return false
        }

        return scopedItemIDs.contains(itemID)
    }

    private func recentItemSystemImage(_ chip: InventoryPreviewGroupPresentation.Chip) -> String {
        guard let itemID = UUID(uuidString: chip.id),
              let item = items.first(where: { $0.id == itemID })
        else {
            return ItemIconCatalog.fallbackSymbolName
        }

        let iconID = item.iconID ?? ItemIconCatalog.defaultIconID(forCategory: item.category)
        return ItemIconCatalog.symbolName(for: iconID)
    }

    private var detailTopPadding: CGFloat {
        colorScheme == .dark ? InventoryDesign.screenPadding : InventoryDesign.gridSpacing
    }

    private var reducesMotion: Bool {
        #if DEBUG
        accessibilityReduceMotion || InventoryQAAccessibilityConfiguration.current.reduceMotion
        #else
        accessibilityReduceMotion
        #endif
    }

    private func currentPlace(for selectedPlace: SelectedPlace) -> InventoryBrowseSummaries.PlaceSummary {
        placeSummaries.first(where: { $0.id == selectedPlace.id })
            ?? InventoryBrowseSummaries.PlaceSummary(
                id: selectedPlace.id,
                placeID: selectedPlace.placeID,
                name: selectedPlace.name,
                itemCount: 0,
                locationID: selectedPlace.locationID,
                locationName: selectedPlace.locationName,
                isMissingLocation: selectedPlace.isMissingLocation,
                isMissingPlace: selectedPlace.isMissingPlace
            )
    }

    private struct SelectedPlace: Hashable, Identifiable {
        let id: String
        let placeID: UUID?
        let name: String
        let locationID: String
        let locationName: String
        let isMissingLocation: Bool
        let isMissingPlace: Bool

        init(_ place: InventoryBrowseSummaries.PlaceSummary) {
            id = place.id
            placeID = place.placeID
            name = place.name
            locationID = place.locationID
            locationName = place.locationName
            isMissingLocation = place.isMissingLocation
            isMissingPlace = place.isMissingPlace
        }
    }
}

private struct LocationDetailPlacesSection: View {
    let location: InventoryBrowseSummaries.LocationSummary
    let places: [InventoryBrowseSummaries.PlaceSummary]
    let onPlaceSelected: (InventoryBrowseSummaries.PlaceSummary) -> Void
    let onAddItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader("locations.previewGroup.places.label")
                .accessibilityIdentifier("locations.placesSectionHeader")

            if places.isEmpty {
                emptyState
            } else {
                VStack(spacing: InventoryDesign.gridSpacing) {
                    ForEach(places) { place in
                        Button {
                            onPlaceSelected(place)
                        } label: {
                            PlaceSummaryRowView(place: place)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("locations.placeRow.\(place.name)")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        InventoryEmptyStateCard(
            title: InventoryLocalization.string(
                "locations.items.empty.title",
                defaultValue: "No Items Here"
            ),
            message: InventoryLocalization.string(
                "locations.places.empty.message",
                defaultValue: "Add an item to start organizing this location by storage place."
            ),
            systemImage: location.isMissingLocation
                ? LocationIconCatalog.missingLocationSymbolName
                : LocationIconCatalog.symbolName(for: location.iconID)
        ) {
            Button(InventoryLocalization.string("inventory.action.addItem", defaultValue: "Add Item")) {
                onAddItem()
            }
            .inventoryEmptyStatePrimaryAction()
            .accessibilityIdentifier("locations.placesEmptyState.addItemButton")
        }
        .accessibilityIdentifier("locations.placesEmptyState")
        .frame(maxWidth: InventoryDesign.emptyStateMaxWidth)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#if DEBUG
#Preview("Location Detail - Populated Light") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.populatedLocation,
        items: LocationDetailPreviewData.populatedItems,
        recentViewEvents: LocationDetailPreviewData.recentViewEvents
    )
    .preferredColorScheme(.light)
}

#Preview("Location Detail - Populated Dark") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.populatedLocation,
        items: LocationDetailPreviewData.populatedItems,
        recentViewEvents: LocationDetailPreviewData.recentViewEvents
    )
    .preferredColorScheme(.dark)
}

#Preview("Location Detail - Places Index 320 pt") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.populatedLocation,
        items: LocationDetailPreviewData.populatedItems,
        recentViewEvents: LocationDetailPreviewData.recentViewEvents
    )
    .frame(width: 320)
    .preferredColorScheme(.light)
}

#Preview("Location Detail - Single Missing Place") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.singlePlaceLocation,
        items: LocationDetailPreviewData.singleUnplacedItem,
        recentViewEvents: []
    )
    .preferredColorScheme(.light)
}

#Preview("Location Detail - Empty Light") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.emptyLocation,
        items: [],
        recentViewEvents: []
    )
    .preferredColorScheme(.light)
}

#Preview("Location Detail - Empty Dark") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.emptyLocation,
        items: [],
        recentViewEvents: []
    )
    .preferredColorScheme(.dark)
}

#Preview("Location Detail - Missing Location") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.missingLocation,
        items: [],
        recentViewEvents: []
    )
    .preferredColorScheme(.light)
}

#Preview("Location Detail - Long Ukrainian Accessibility") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.longLocation,
        items: LocationDetailPreviewData.longItems,
        recentViewEvents: []
    )
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.light)
}

#Preview("Location Detail - Long Ukrainian Accessibility Dark") {
    LocationDetailPreviewSurface(
        location: LocationDetailPreviewData.longLocation,
        items: LocationDetailPreviewData.longItems,
        recentViewEvents: []
    )
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

private struct LocationDetailPreviewSurface: View {
    let location: InventoryBrowseSummaries.LocationSummary
    let items: [InventoryItem]
    let recentViewEvents: [InventoryItemViewEvent]

    var body: some View {
        NavigationStack {
            LocationPlacesListView(
                location: location,
                items: items,
                recentViewEvents: recentViewEvents
            )
        }
        .modelContainer(try! InventoryModelContainer.make(inMemory: true))
    }
}

@MainActor
private enum LocationDetailPreviewData {
    private static let adapterID = UUID(uuidString: "8B1A778E-64D1-43F0-9CA8-96F5466B6E51")!
    private static let cableID = UUID(uuidString: "8D75AA4B-EC16-4742-A4AE-3AF8C6829203")!
    private static let batteryID = UUID(uuidString: "A5371BF0-31BC-4D7D-8E3C-783B735B2525")!
    private static let unplacedItemID = UUID(uuidString: "F796FE03-2166-4DDC-9CA9-429FF28404F5")!

    static let populatedItems = [
        InventoryItem(
            id: adapterID,
            name: "USB-C to HDMI adapter",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Office",
            containerName: "Desk drawer"
        ),
        InventoryItem(
            id: cableID,
            name: "USB-C cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Office",
            containerName: "PC parts box"
        ),
        InventoryItem(
            id: batteryID,
            name: "Rechargeable batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Office",
            containerName: "Shelf organizer"
        ),
        InventoryItem(
            id: unplacedItemID,
            name: "Label maker tape",
            category: InventoryCategory.miscellaneous.rawValue,
            locationName: "Office",
            containerName: ""
        )
    ]

    static let populatedLocation = InventoryBrowseSummaries.LocationSummary(
        name: "Office",
        iconID: "office",
        itemCount: populatedItems.count,
        isMissingLocation: false,
        previewGroups: [
            .init(
                kind: .recentItem,
                visibleItems: [
                    .init(id: adapterID.uuidString, title: "USB-C to HDMI adapter"),
                    .init(id: cableID.uuidString, title: "USB-C cable")
                ],
                hiddenCount: 0
            )
        ]
    )

    static let singleUnplacedItem = [
        InventoryItem(
            name: "Label maker tape",
            category: InventoryCategory.miscellaneous.rawValue,
            locationName: "Office",
            containerName: ""
        )
    ]

    static let singlePlaceLocation = InventoryBrowseSummaries.LocationSummary(
        name: "Office",
        iconID: "office",
        itemCount: singleUnplacedItem.count,
        isMissingLocation: false
    )

    static let recentViewEvents = [
        InventoryItemViewEvent(itemID: adapterID, viewedAt: .now),
        InventoryItemViewEvent(itemID: cableID, viewedAt: .now.addingTimeInterval(-60))
    ]

    static let emptyLocation = InventoryBrowseSummaries.LocationSummary(
        name: "Garage shelves",
        iconID: "garage",
        itemCount: 0,
        isMissingLocation: false
    )

    static let missingLocation = InventoryBrowseSummaries.LocationSummary(
        name: InventoryLocalization.noLocation,
        itemCount: 0,
        isMissingLocation: true
    )

    static let longItems = [
        InventoryItem(
            name: "Набір запасних зарядних кабелів",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: longLocation.name,
            containerName: "Прозорий органайзер на верхній полиці біля дорожніх сумок"
        )
    ]

    static let longLocation = InventoryBrowseSummaries.LocationSummary(
        name: "Шафа у передпокої з дуже довгою назвою місця зберігання",
        iconID: "closet",
        itemCount: 1,
        isMissingLocation: false
    )
}
#endif
