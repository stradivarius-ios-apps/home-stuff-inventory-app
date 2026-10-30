import SwiftUI

struct InventoryItemNavigationCard: View {
    let item: InventoryItem
    let placePath: String?
    let matchContext: InventorySearch.MatchContext?
    let presentation: InventoryListPresentation
    let showsStorageSummary: Bool
    let transitionNamespace: Namespace.ID
    let reduceMotion: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    init(
        item: InventoryItem,
        placePath: String?,
        matchContext: InventorySearch.MatchContext? = nil,
        presentation: InventoryListPresentation = .searchResults,
        showsStorageSummary: Bool = true,
        transitionNamespace: Namespace.ID,
        reduceMotion: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.placePath = placePath
        self.matchContext = matchContext
        self.presentation = presentation
        self.showsStorageSummary = showsStorageSummary
        self.transitionNamespace = transitionNamespace
        self.reduceMotion = reduceMotion
        self.accessibilityIdentifier = accessibilityIdentifier ?? "inventory." + "itemRow.\(item.name)"
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            switch presentation {
            case .compactInventory:
                InventoryCompactItemCard(item: item, placePath: placePath, showsStorageSummary: showsStorageSummary)
            case .searchResults:
                InventoryItemRowView(item: item, matchContext: matchContext, placePath: placePath)
            }
        }
        .buttonStyle(.plain)
        .inventoryItemNavigationSource(
            id: item.id,
            namespace: transitionNamespace,
            reduceMotion: reduceMotion
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

extension View {
    @ViewBuilder
    func inventoryItemNavigationSource(id: UUID, namespace: Namespace.ID, reduceMotion: Bool) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func inventoryItemNavigationDestination(id: UUID, namespace: Namespace.ID, reduceMotion: Bool) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
