import SwiftData
import SwiftUI

struct InventoryItemNavigationCard: View {
    let item: InventoryItem
    let matchContext: InventorySearch.MatchContext?
    let presentation: InventoryListPresentation
    let transitionNamespace: Namespace.ID
    let reduceMotion: Bool
    let accessibilityIdentifier: String
    let action: () -> Void
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    init(
        item: InventoryItem,
        matchContext: InventorySearch.MatchContext? = nil,
        presentation: InventoryListPresentation = .searchResults,
        transitionNamespace: Namespace.ID,
        reduceMotion: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.matchContext = matchContext
        self.presentation = presentation
        self.transitionNamespace = transitionNamespace
        self.reduceMotion = reduceMotion
        self.accessibilityIdentifier = accessibilityIdentifier ?? "inventory." + "itemRow.\(item.name)"
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            switch presentation {
            case .compactInventory:
                InventoryCompactItemCard(item: item, placePath: placePath)
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

    private var placePath: String? {
        guard let placeID = item.placeID,
              let place = places.first(where: { $0.id == placeID })
        else {
            return nil
        }
        return InventoryPlaceHierarchy.path(for: place, places: places).displayName
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
