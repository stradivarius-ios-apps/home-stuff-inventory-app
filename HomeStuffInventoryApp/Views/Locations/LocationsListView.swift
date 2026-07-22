import SwiftData
import SwiftUI

struct LocationsListView: View {
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryItemViewEvent.viewedAt, order: .reverse) private var recentViewEvents: [InventoryItemViewEvent]
    @Query(sort: \InventoryPlaceOpenRecord.lastOpenedAt, order: .reverse) private var placeOpenRecords: [InventoryPlaceOpenRecord]

    @State private var isShowingItemForm = false
    @State private var selectedLocation: SelectedLocation?

    private var locationSummaries: [InventoryBrowseSummaries.LocationSummary] {
        InventoryBrowseSummaries.locationSummaries(
            from: items,
            storageLocations: locations,
            recentViewEvents: recentViewEvents,
            placeOpenRecords: placeOpenRecords,
            vocabulary: .localized
        )
    }

    var body: some View {
        Group {
            if !InventoryBrowseSummaries.hasLocationsRootContent(
                items: items,
                storageLocations: locations
            ) {
                locationsEmptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                        ForEach(locationSummaries) { location in
                            Button {
                                selectedLocation = SelectedLocation(location)
                            } label: {
                                LocationSummaryRowView(location: location)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("locations.locationRow.\(location.name)")
                        }
                    }
                    .inventoryDetailContentWidth()
                    .padding(.top, InventoryDesign.gridSpacing)
                }
                .inventoryScrollContentClearance()
                .inventoryGroupedBackground()
            }
        }
        .accessibilityIdentifier("locations.list")
        .navigationDestination(item: $selectedLocation) { selectedLocation in
            LocationPlacesListView(
                location: currentLocation(for: selectedLocation),
                items: items,
                recentViewEvents: recentViewEvents
            )
        }
        .navigationTitle("locations.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingItemForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .inventoryPrimaryActionTint()
                .accessibilityLabel("inventory.action.addItem.accessibilityLabel")
                .accessibilityIdentifier("locations.addItemButton")
            }
        }
        .sheet(isPresented: $isShowingItemForm) {
            InventoryItemFormView()
        }
    }

    private var locationsEmptyState: some View {
        InventoryEmptyStateScreen {
            InventoryEmptyStateCard(
                title: InventoryLocalization.string("locations.empty.title", defaultValue: "No locations yet"),
                message: InventoryLocalization.string(
                    "locations.empty.message",
                    defaultValue: "Add items with a location and exact storage place so this list can show where things live."
                ),
                systemImage: "map"
            ) {
                Button(InventoryLocalization.string("inventory.action.addItem", defaultValue: "Add Item")) {
                    isShowingItemForm = true
                }
                .inventoryEmptyStatePrimaryAction()
                .accessibilityIdentifier("locations.empty.addItemButton")
            }
        }
    }

    private func currentLocation(
        for selectedLocation: SelectedLocation
    ) -> InventoryBrowseSummaries.LocationSummary {
        locationSummaries.first(where: { $0.id == selectedLocation.id })
            ?? InventoryBrowseSummaries.LocationSummary(
                name: selectedLocation.name,
                iconID: selectedLocation.iconID,
                itemCount: 0,
                isMissingLocation: selectedLocation.isMissingLocation
            )
    }

    private struct SelectedLocation: Hashable, Identifiable {
        let id: String
        let name: String
        let iconID: String?
        let isMissingLocation: Bool

        init(_ location: InventoryBrowseSummaries.LocationSummary) {
            id = location.id
            name = location.name
            iconID = location.iconID
            isMissingLocation = location.isMissingLocation
        }
    }
}

#if DEBUG
#Preview("Locations Overview - Populated Light") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .preferredColorScheme(.light)
}

#Preview("Locations Overview - Populated Dark") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .preferredColorScheme(.dark)
}

#Preview("Locations Overview - 320 pt") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .frame(width: 320)
    .preferredColorScheme(.light)
}

#Preview("Locations Overview - Empty Light") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(try! InventoryModelContainer.make(inMemory: true))
    .preferredColorScheme(.light)
}

#Preview("Locations Overview - Empty Dark") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(try! InventoryModelContainer.make(inMemory: true))
    .preferredColorScheme(.dark)
}

#Preview("Locations Overview - Long Content Light") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(LocationsOverviewPreviewData.makeLongContent())
    .environment(\.locale, Locale(identifier: "uk"))
    .preferredColorScheme(.light)
}

#Preview("Locations Overview - Long Content Dark") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(LocationsOverviewPreviewData.makeLongContent())
    .environment(\.locale, Locale(identifier: "uk"))
    .preferredColorScheme(.dark)
}

#Preview("Locations Overview - Long Accessibility Light") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(LocationsOverviewPreviewData.makeLongContent())
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.light)
}

#Preview("Locations Overview - Long Accessibility Dark") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(LocationsOverviewPreviewData.makeLongContent())
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

private enum LocationsOverviewPreviewData {
    static func makeLongContent() -> ModelContainer {
        let container = try! InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let locationName = "Шафа у передпокої з дуже довгою назвою місця зберігання"
        let places = [
            "Прозорий органайзер на верхній полиці біля дорожніх сумок",
            "Нижня шухляда для запасних побутових речей",
            "Великий контейнер біля вхідних дверей"
        ]

        context.insert(StorageLocation(name: locationName, iconID: "closet"))

        for (index, place) in places.enumerated() {
            context.insert(
                InventoryItem(
                    name: "Річ для перевірки довгого вмісту \(index + 1)",
                    category: InventoryCategory.householdSupplies.rawValue,
                    locationName: locationName,
                    containerName: place
                )
            )
        }

        try! context.save()
        return container
    }
}
#endif
