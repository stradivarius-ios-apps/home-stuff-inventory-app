import SwiftData
import SwiftUI

enum InventoryListPresentation {
    case compactInventory
    case searchResults
}

struct InventoryListView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PremiumAccessState.self) private var premiumAccess
    @Environment(PremiumUpgradeCoordinator.self) private var upgradeCoordinator
    @State private var isShowingItemForm = false
    @State private var isShowingRoomSweep = false
    @Binding private var searchText: String
    @State private var selectedItemID: UUID?
    @State private var selectedCategory: String?
    @State private var selectedLocationName: String?
    @State private var selectedPlace: InventorySearch.PlaceFilter?
    @State private var bulkSelection = InventoryBulkSelectionState()
    @State private var bulkMovementRequest: InventoryBulkMovementSheetRequest?
    @Namespace private var itemNavigationNamespace

    private let presentation: InventoryListPresentation

    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    init(searchText: Binding<String> = .constant(""), presentation: InventoryListPresentation) {
        _searchText = searchText
        self.presentation = presentation
    }

    private func currentFilteredItems() -> [InventoryItem] {
        InventorySearch.matchingItems(
            in: items, query: searchText, filters: filters,
            places: places, vocabulary: .localized
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

    private func filteredEmptyStateActionTitle(context: InventoryFilterContext) -> String {
        context.clearAction?.localizedTitle
            ?? InventoryLocalization.string("inventory.action.clearFilters", defaultValue: "Clear Filters")
    }

    private func filteredEmptyStateSystemImage(context: InventoryFilterContext) -> String {
        switch context.clearAction {
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

    var body: some View {
        let placePaths = InventoryPlacePathIndex(places: places)
        let filteredResults = InventorySearch.matchingResults(
            in: items, query: searchText, filters: filters,
            placePaths: placePaths, vocabulary: .localized
        )
        let filteredItems = filteredResults.map(\.item)
        let filterContext = InventoryFilterContext(
            resultCount: filteredItems.count, searchText: searchText,
            category: selectedCategory, locationName: selectedLocationName, place: selectedPlace
        )
        let contentState = InventoryListContentState.make(itemCount: items.count, filteredItemCount: filteredItems.count)
        Group {
            if bulkSelection.isActive {
                InventoryBulkSelectionList(
                    items: filteredItems,
                    selectedItemIDs: bulkSelectionBinding
                )
            } else if contentState == .initial {
                InventoryEmptyStateView(viewModel: .initial) {
                    isShowingItemForm = true
                }
            } else if filteredItems.isEmpty {
                filteredEmptyState(context: filterContext)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                        if filterContext.isActive {
                            ActiveInventoryFilterContextHeader(context: filterContext) {
                                clearSearchAndFilters()
                            }
                        }

                        LazyVStack(alignment: .leading, spacing: itemRowSpacing) {
                            inventoryRows(results: filteredResults, placePaths: placePaths)
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
            if bulkSelection.isActive {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.bulkMove.cancel") {
                        bulkSelection.cancel()
                    }
                    .accessibilityIdentifier("inventory.bulkSelection.cancelButton")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("inventory.bulkMove.move.action") {
                        presentBulkMovement()
                    }
                    .disabled(bulkSelection.selectedCount == 0)
                    .accessibilityIdentifier("inventory.bulkSelection.moveButton")
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("inventory.bulkMove.selectAll") {
                        bulkSelection.selectAll(visibleItemIDs: filteredItems.map(\.id))
                    }
                    .disabled(filteredItems.isEmpty)
                    .accessibilityIdentifier("inventory.bulkSelection.selectAllButton")
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Menu("inventory.field.category") {
                            Picker("inventory.field.category", selection: $selectedCategory) {
                                Text("inventory.filter.anyCategory").tag(String?.none)

                                ForEach(availableCategories, id: \.self) { category in
                                    Text(category).tag(Optional(category))
                                }
                            }
                            .pickerStyle(.inline)
                            .accessibilityIdentifier("inventory.filter.categoryPicker")
                        }
                        .accessibilityIdentifier("inventory.filter.categoryMenu")

                        Menu("inventory.field.location") {
                            Picker("inventory.field.location", selection: $selectedLocationName) {
                                Text("inventory.filter.anyLocation").tag(String?.none)

                                ForEach(availableLocations, id: \.self) { locationName in
                                    Text(locationName).tag(Optional(locationName))
                                }
                            }
                            .pickerStyle(.inline)
                            .accessibilityIdentifier("inventory.filter.locationPicker")
                        }
                        .accessibilityIdentifier("inventory.filter.locationMenu")

                        Menu("inventory.field.container") {
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
                            .pickerStyle(.inline)
                            .accessibilityIdentifier("inventory.filter.placePicker")
                        }
                        .accessibilityIdentifier("inventory.filter.placeMenu")

                        if hasActiveFilters {
                            Divider()

                            Button {
                                clearFilters()
                            } label: {
                                Label("inventory.action.clearFilters", systemImage: "xmark.circle")
                            }
                            .accessibilityIdentifier("inventory.filter.clearFiltersButton")
                        }
                    } label: {
                        Label("inventory.filter.menu", systemImage: filterMenuSystemImage)
                    }
                    .accessibilityLabel("inventory.filter.accessibilityLabel")
                    .accessibilityHint("inventory.filter.accessibilityHint")
                    .accessibilityIdentifier("inventory.filter.menu")
                }

                if upgradeCoordinator.isLifetimeProLaunchEnabled {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            beginBulkSelection()
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .disabled(filteredItems.isEmpty)
                        .accessibilityLabel("inventory.bulkMove.select.action")
                        .accessibilityHint("inventory.bulkMove.select.hint")
                        .accessibilityIdentifier("inventory.bulkSelection.startButton")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isShowingItemForm = true
                        } label: {
                            Label("inventory.action.addItem", systemImage: "plus")
                        }

                        if upgradeCoordinator.isLifetimeProLaunchEnabled {
                            Button {
                                requestRoomSweep()
                            } label: {
                                Label("inventory.roomSweep.action", systemImage: "square.stack.3d.up")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    } primaryAction: {
                        isShowingItemForm = true
                    }
                    .inventoryPrimaryActionTint()
                    .accessibilityLabel("inventory.action.addItem.accessibilityLabel")
                    .accessibilityIdentifier("inventory.addItemButton")
                }
            }
        }
        .sheet(isPresented: $isShowingItemForm) {
            InventoryItemFormView()
        }
        .sheet(item: $bulkMovementRequest, onDismiss: {
            bulkSelection.cancel()
        }) { request in
            InventoryBulkMovementView(
                selectedItemIDs: request.selectedItemIDs,
                onAccessRequired: {
                    bulkMovementRequest = nil
                    upgradeCoordinator.request(.selectedItemMovement) {
                        presentBulkMovement()
                    }
                }
            )
        }
        .sheet(isPresented: $isShowingRoomSweep) {
            InventoryRoomSweepView {
                isShowingRoomSweep = false
                upgradeCoordinator.request(.roomSweep) {
                    isShowingRoomSweep = true
                }
            }
        }
        .onChange(of: selectedLocationName) { _, _ in
            reconcilePlaceSelection()
        }
        .onChange(of: items.map { "\($0.id)|\($0.locationName)|\($0.containerName ?? "")" }) { _, _ in
            reconcilePlaceSelection()
            bulkSelection.reconcile(availableItemIDs: items.map(\.id))
        }
    }

    private func inventoryRows(
        results: [InventorySearch.Result], placePaths: InventoryPlacePathIndex
    ) -> some View {
        ForEach(results) { result in
            InventoryItemNavigationCard(
                item: result.item,
                placePath: placePaths[result.item.placeID]?.displayName,
                matchContext: result.matchContext,
                presentation: presentation,
                transitionNamespace: itemNavigationNamespace,
                reduceMotion: accessibilityReduceMotion
            ) {
                selectedItemID = result.item.id
            }
        }
    }

    private var bulkSelectionBinding: Binding<Set<UUID>> {
        Binding(
            get: { bulkSelection.selectedItemIDs },
            set: {
                bulkSelection.replaceSelection(
                    with: $0,
                    visibleItemIDs: currentFilteredItems().map(\.id)
                )
            }
        )
    }

    private var filterMenuSystemImage: String {
        hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    private var itemRowSpacing: CGFloat {
        presentation == .compactInventory ? InventoryDesign.rowSpacing : InventoryDesign.gridSpacing
    }

    private func filteredEmptyState(context filterContext: InventoryFilterContext) -> some View {
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
                systemImage: filteredEmptyStateSystemImage(context: filterContext)
            ) {
                Button(filteredEmptyStateActionTitle(context: filterContext)) {
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

    private func requestRoomSweep() {
        upgradeCoordinator.request(.roomSweep) {
            isShowingRoomSweep = true
        }
    }

    private func reconcilePlaceSelection() {
        selectedPlace = InventorySearch.reconciledPlaceSelection(selectedPlace, availablePlaces: availablePlaces)
    }

    private func clearSearchAndFilters() {
        searchText = ""
        clearFilters()
    }

    private func beginBulkSelection() {
        upgradeCoordinator.request(.selectedItemMovement) {
            _ = bulkSelection.begin(
                visibleItemIDs: currentFilteredItems().map(\.id),
                availability: .available
            )
        }
    }

    private func presentBulkMovement() {
        guard premiumAccess.availability(of: .moveSelectedItems) == .available else {
            upgradeCoordinator.request(.selectedItemMovement) {
                presentBulkMovement()
            }
            return
        }
        guard !bulkSelection.selectedItemIDs.isEmpty else { return }
        bulkMovementRequest = InventoryBulkMovementSheetRequest(
            selectedItemIDs: bulkSelection.selectedItemIDs
        )
    }
}
