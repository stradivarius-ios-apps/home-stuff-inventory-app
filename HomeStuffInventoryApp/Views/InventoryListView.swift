import SwiftData
import SwiftUI

enum InventoryListPresentation {
    case compactInventory
    case searchResults
}

struct InventoryListView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isShowingItemForm = false
    @Binding private var searchText: String
    @State private var selectedItemID: UUID?
    @State private var selectedCategory: String?
    @State private var selectedLocationName: String?
    @State private var selectedPlace: InventorySearch.PlaceFilter?
    @Namespace private var itemNavigationNamespace

    private let presentation: InventoryListPresentation

    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]

    init(searchText: Binding<String> = .constant(""), presentation: InventoryListPresentation) {
        _searchText = searchText
        self.presentation = presentation
    }

    private var filteredResults: [InventorySearch.Result] {
        InventorySearch.matchingResults(in: items, query: searchText, filters: filters, vocabulary: .localized)
    }

    private var filteredItems: [InventoryItem] { filteredResults.map(\.item) }

    private var filterContext: InventoryFilterContext {
        InventoryFilterContext(
            resultCount: filteredItems.count,
            searchText: searchText,
            category: selectedCategory,
            locationName: selectedLocationName,
            place: selectedPlace
        )
    }

    private var filters: InventorySearch.Filters {
        InventorySearch.Filters(category: selectedCategory, locationName: selectedLocationName, place: selectedPlace)
    }

    private var hasActiveFilters: Bool {
        filters.hasActiveFilters
    }

    private var availableCategories: [String] {
        InventorySearch.availableCategories(from: items, vocabulary: .localized)
    }

    private var availableLocations: [String] {
        InventorySearch.availableLocations(from: items, storageLocations: locations, vocabulary: .localized)
    }

    private var availablePlaces: [InventorySearch.PlaceFilter] {
        InventorySearch.availablePlaces(from: items, locationName: selectedLocationName, vocabulary: .localized)
    }

    private var filteredEmptyStateMessage: String {
        if hasActiveFilters && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return InventoryLocalization.string(
                "inventory.empty.filtered.searchAndFilters",
                defaultValue: "No items match this search and filter combination."
            )
        }

        if hasActiveFilters {
            return InventoryLocalization.string(
                "inventory.empty.filtered.filters",
                defaultValue: "No items match the selected filters."
            )
        }

        return InventoryLocalization.string(
            "inventory.empty.filtered.search",
            defaultValue: "No stored items match this search."
        )
    }

    private var filteredEmptyStateActionTitle: String {
        filterContext.clearAction?.localizedTitle
            ?? InventoryLocalization.string("inventory.action.clearFilters", defaultValue: "Clear Filters")
    }

    private var filteredEmptyStateSystemImage: String {
        switch filterContext.clearAction {
        case .search:
            "magnifyingglass"
        case .filters:
            "line.3.horizontal.decrease.circle"
        case .searchAndFilters:
            "magnifyingglass.circle"
        case nil:
            "shippingbox"
        }
    }

    private var contentState: InventoryListContentState {
        InventoryListContentState.make(itemCount: items.count, filteredItemCount: filteredItems.count)
    }

    var body: some View {
        Group {
            if contentState == .initial {
                InventoryEmptyStateView(viewModel: .initial) {
                    isShowingItemForm = true
                }
            } else if filteredItems.isEmpty {
                filteredEmptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                        if filterContext.isActive {
                            ActiveInventoryFilterContextHeader(context: filterContext) {
                                clearSearchAndFilters()
                            }
                        }

                        LazyVStack(alignment: .leading, spacing: itemRowSpacing) {
                            inventoryRows
                        }
                    }
                    .inventoryDetailContentWidth()
                    .padding(.top, InventoryDesign.gridSpacing)
                }
                .inventoryScrollContentClearance()
                .inventoryGroupedBackground()
            }
        }
        .accessibilityIdentifier("inventory.list")
        .navigationDestination(item: $selectedItemID) { itemID in
            if let item = items.first(where: { $0.id == itemID }) {
                InventoryItemDetailView(item: item)
                    .inventoryItemNavigationDestination(
                        id: item.id,
                        namespace: itemNavigationNamespace,
                        reduceMotion: accessibilityReduceMotion
                    )
            }
        }
        .navigationTitle("inventory.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("inventory.field.category", selection: $selectedCategory) {
                        Text("inventory.filter.anyCategory").tag(String?.none)

                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(Optional(category))
                        }
                    }

                    Picker("inventory.field.location", selection: $selectedLocationName) {
                        Text("inventory.filter.anyLocation").tag(String?.none)

                        ForEach(availableLocations, id: \.self) { locationName in
                            Text(locationName).tag(Optional(locationName))
                        }
                    }

                    Picker("inventory.field.container", selection: $selectedPlace) {
                        Text("inventory.filter.anyPlace").tag(InventorySearch.PlaceFilter?.none)

                        ForEach(availablePlaces, id: \.self) { place in
                            switch place {
                            case let .named(name):
                                Text(name).tag(Optional(place))
                            case .missing:
                                Text(InventoryLocalization.noContainer).tag(Optional(place))
                            }
                        }
                    }
                    .accessibilityIdentifier("inventory.filter.placePicker")

                    if hasActiveFilters {
                        Divider()

                        Button {
                            clearFilters()
                        } label: {
                            Label("inventory.action.clearFilters", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Label("inventory.filter.menu", systemImage: filterMenuSystemImage)
                }
                .accessibilityLabel("inventory.filter.accessibilityLabel")
                .accessibilityHint("inventory.filter.accessibilityHint")
                .accessibilityIdentifier("inventory.filter.menu")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingItemForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .inventoryPrimaryActionTint()
                .accessibilityLabel("inventory.action.addItem.accessibilityLabel")
                .accessibilityIdentifier("inventory.addItemButton")
            }
        }
        .sheet(isPresented: $isShowingItemForm) {
            InventoryItemFormView()
        }
        .onChange(of: selectedLocationName) { _, _ in
            reconcilePlaceSelection()
        }
        .onChange(of: items.map { "\($0.id)|\($0.locationName)|\($0.containerName ?? "")" }) { _, _ in
            reconcilePlaceSelection()
        }
    }

    private var inventoryRows: some View {
        ForEach(filteredResults) { result in
            InventoryItemNavigationCard(
                item: result.item,
                matchContext: result.matchContext,
                presentation: presentation,
                transitionNamespace: itemNavigationNamespace,
                reduceMotion: accessibilityReduceMotion
            ) {
                selectedItemID = result.item.id
            }
        }
    }

    private var filterMenuSystemImage: String {
        hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    private var itemRowSpacing: CGFloat {
        presentation == .compactInventory ? InventoryDesign.rowSpacing : InventoryDesign.gridSpacing
    }

    private var filteredEmptyState: some View {
        InventoryEmptyStateScreen(maxWidth: InventoryDesign.emptyStateWideMaxWidth) {
            if filterContext.isActive {
                ActiveInventoryFilterContextHeader(context: filterContext) {
                    clearSearchAndFilters()
                }
            }

            InventoryEmptyStateCard(
                title: InventoryLocalization.string(
                    "inventory.empty.filtered.title",
                    defaultValue: "No Matching Items"
                ),
                message: filteredEmptyStateMessage,
                systemImage: filteredEmptyStateSystemImage
            ) {
                Button(filteredEmptyStateActionTitle) {
                    clearSearchAndFilters()
                }
                .inventoryEmptyStatePrimaryAction()
            }
        }
    }

    private func clearFilters() {
        selectedCategory = nil
        selectedLocationName = nil
        selectedPlace = nil
    }

    private func reconcilePlaceSelection() {
        selectedPlace = InventorySearch.reconciledPlaceSelection(selectedPlace, availablePlaces: availablePlaces)
    }

    private func clearSearchAndFilters() {
        searchText = ""
        clearFilters()
    }
}
