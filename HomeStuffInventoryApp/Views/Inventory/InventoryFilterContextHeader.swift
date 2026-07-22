import SwiftUI

extension InventoryFilterContext.ClearAction {
    var localizedTitle: String {
        switch self {
        case .search:
            InventoryLocalization.string("inventory.action.clearSearch", defaultValue: "Clear Search")
        case .filters:
            InventoryLocalization.string("inventory.action.clearFilters", defaultValue: "Clear Filters")
        case .searchAndFilters:
            InventoryLocalization.string(
                "inventory.action.clearSearchAndFilters",
                defaultValue: "Clear Search and Filters"
            )
        }
    }
}

struct ActiveInventoryFilterContextHeader: View {
    let context: InventoryFilterContext
    let clearAction: () -> Void

    var body: some View {
        InventoryCard(
            padding: InventoryDesign.compactCardPadding,
            cornerRadius: InventoryDesign.compactCornerRadius
        ) {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(resultCountText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Button(action: clearAction) {
                        Label(clearActionTitle, systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .frame(
                                minWidth: InventoryDesign.minimumTapTarget,
                                minHeight: InventoryDesign.minimumTapTarget
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(clearActionTitle)
                    .accessibilityIdentifier("inventory.filterContext.clearButton")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        contextBadges
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        contextBadges
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contextBadges: some View {
        if let searchText = context.searchText {
            InventoryBadge(
                verbatim: badgeText("inventory.filterContext.search", defaultValue: "Search: %@", value: searchText),
                systemImage: "magnifyingglass"
            )
        }

        if let category = context.category {
            InventoryBadge(
                verbatim: badgeText("inventory.filterContext.category", defaultValue: "Category: %@", value: category),
                systemImage: "tag",
                role: .muted
            )
        }

        if let locationName = context.locationName {
            InventoryBadge(
                verbatim: badgeText("inventory.filterContext.location", defaultValue: "Location: %@", value: locationName),
                systemImage: "mappin.and.ellipse"
            )
        }

        if let place = context.place {
            InventoryBadge(
                verbatim: badgeText(
                    "inventory.filterContext.place",
                    defaultValue: "Storage Place: %@",
                    value: place.displayName(vocabulary: .localized)
                ),
                systemImage: "archivebox"
            )
        }
    }

    private var resultCountText: String {
        InventoryLocalization.itemCount(context.resultCount)
    }

    private var clearActionTitle: String {
        context.clearAction?.localizedTitle
            ?? InventoryLocalization.string("inventory.action.clearFilters", defaultValue: "Clear Filters")
    }

    private func badgeText(_ key: StaticString, defaultValue: String, value: String) -> String {
        InventoryLocalization.formatted(key, defaultValue: defaultValue, value)
    }
}
