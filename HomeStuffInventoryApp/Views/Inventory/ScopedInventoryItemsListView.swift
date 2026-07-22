import SwiftUI

struct ScopedInventoryItemsListView<Header: View>: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    enum AccessibilityContext {
        case scoped
        case placeDetail

        var listIdentifier: String {
            switch self {
            case .scoped:
                "locations." + "scopedItemList"
            case .placeDetail:
                "locations." + "placeDetail.itemList"
            }
        }

        func rowIdentifier(for item: InventoryItem) -> String {
            switch self {
            case .scoped:
                "inventory." + "itemRow.\(item.name)"
            case .placeDetail:
                "locations." + "placeDetail.itemRow.\(item.name)"
            }
        }
    }

    let title: String
    let items: [InventoryItem]
    let emptyTitleKey: StaticString
    let emptyTitleDefaultValue: String
    let emptyMessageKey: StaticString
    let emptyMessageDefaultValue: String
    let emptySystemImage: String
    let backgroundStyle: InventoryScreenBackgroundStyle
    let accessibilityContext: AccessibilityContext
    let header: Header

    @State private var selectedItemID: UUID?
    @State private var isShowingNavigationTitle = false
    @Namespace private var itemNavigationNamespace

    init(
        title: String,
        items: [InventoryItem],
        emptyTitleKey: StaticString,
        emptyTitleDefaultValue: String,
        emptyMessageKey: StaticString,
        emptyMessageDefaultValue: String,
        emptySystemImage: String,
        backgroundStyle: InventoryScreenBackgroundStyle = .locationAtmosphere,
        accessibilityContext: AccessibilityContext = .scoped,
        @ViewBuilder header: () -> Header
    ) {
        self.title = title
        self.items = items
        self.emptyTitleKey = emptyTitleKey
        self.emptyTitleDefaultValue = emptyTitleDefaultValue
        self.emptyMessageKey = emptyMessageKey
        self.emptyMessageDefaultValue = emptyMessageDefaultValue
        self.emptySystemImage = emptySystemImage
        self.backgroundStyle = backgroundStyle
        self.accessibilityContext = accessibilityContext
        self.header = header()
    }

    var body: some View {
        Group {
            if items.isEmpty {
                itemsEmptyState
                    .inventoryHeroNavigationTitleVisibilityObserver(
                        isShowingNavigationTitle: $isShowingNavigationTitle
                    )
            } else {
                itemsList
            }
        }
        .navigationDestination(item: $selectedItemID) { itemID in
            itemDetailDestination(for: itemID)
        }
        .navigationDestination(for: UUID.self) { itemID in
            itemDetailDestination(for: itemID)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var itemsList: some View {
        scopedItemsScrollView {
            LazyVStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                ForEach(items) { item in
                    InventoryItemNavigationCard(
                        item: item,
                        presentation: .compactInventory,
                        transitionNamespace: itemNavigationNamespace,
                        reduceMotion: accessibilityReduceMotion,
                        accessibilityIdentifier: accessibilityContext.rowIdentifier(for: item)
                    ) {
                        selectedItemID = item.id
                    }
                }
            }
        }
    }

    private func scopedItemsScrollView<Rows: View>(
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                if hasHeader {
                    header
                        .inventoryHeroNavigationTitleVisibilityAnchor()
                }

                rows()
            }
            .inventoryDetailContentWidth()
            .padding(.top, InventoryDesign.gridSpacing)
        }
        .inventoryScrollContentClearance()
        .accessibilityIdentifier(accessibilityContext.listIdentifier)
        .inventoryScreenBackground(backgroundStyle)
        .inventoryHeroNavigationTitleVisibilityObserver(
            isShowingNavigationTitle: $isShowingNavigationTitle,
            restingAnchorMinY: InventoryDesign.gridSpacing
        )
    }

    private var itemsEmptyState: some View {
        InventoryEmptyStateScreen(backgroundStyle: backgroundStyle) {
            if hasHeader {
                header
                    .inventoryHeroNavigationTitleVisibilityAnchor()
            }

            InventoryEmptyStateCard(
                title: InventoryLocalization.string(
                    emptyTitleKey,
                    defaultValue: emptyTitleDefaultValue
                ),
                message: InventoryLocalization.string(
                    emptyMessageKey,
                    defaultValue: emptyMessageDefaultValue
                ),
                systemImage: emptySystemImage
            )
        }
    }

    private var hasHeader: Bool {
        Header.self != EmptyView.self
    }

    private var navigationTitle: String {
        guard hasHeader else {
            return title
        }

        return isShowingNavigationTitle ? title : ""
    }

    @ViewBuilder
    private func itemDetailDestination(for itemID: UUID) -> some View {
        if let item = items.first(where: { $0.id == itemID }) {
            InventoryItemDetailView(item: item)
                .inventoryItemNavigationDestination(
                    id: item.id,
                    namespace: itemNavigationNamespace,
                    reduceMotion: accessibilityReduceMotion
                )
        }
    }
}

extension ScopedInventoryItemsListView where Header == EmptyView {
    init(
        title: String,
        items: [InventoryItem],
        emptyTitleKey: StaticString,
        emptyTitleDefaultValue: String,
        emptyMessageKey: StaticString,
        emptyMessageDefaultValue: String,
        emptySystemImage: String,
        backgroundStyle: InventoryScreenBackgroundStyle = .locationAtmosphere
    ) {
        self.init(
            title: title,
            items: items,
            emptyTitleKey: emptyTitleKey,
            emptyTitleDefaultValue: emptyTitleDefaultValue,
            emptyMessageKey: emptyMessageKey,
            emptyMessageDefaultValue: emptyMessageDefaultValue,
            emptySystemImage: emptySystemImage,
            backgroundStyle: backgroundStyle,
            accessibilityContext: .scoped
        ) {
            EmptyView()
        }
    }
}
