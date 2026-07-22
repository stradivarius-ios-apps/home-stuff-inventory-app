import SwiftUI

struct LocationAllItemsRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let location: InventoryBrowseSummaries.LocationSummary

    var body: some View {
        InventoryHeroCard(
            presentation: .compact,
            padding: InventoryDesign.cardPadding,
            minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 104,
            contentRole: .location
        ) {
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                horizontalContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var horizontalContent: some View {
        HStack(alignment: .center, spacing: 14) {
            allItemsIcon

            titleAndSubtitle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                allItemsIcon

                Spacer(minLength: 8)
            }

            titleAndSubtitle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var allItemsIcon: some View {
        InventoryHeroIcon(
            systemName: "tray.full",
            size: 52,
            symbolSize: 24,
            cornerRadius: 18,
            presentation: .compact,
            contentRole: .location
        )
    }

    private var titleAndSubtitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(InventoryLocalization.string(
                "locations.allItems.title",
                defaultValue: "All items"
            ))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
    }

    private var itemCountText: String {
        InventoryLocalization.itemCount(location.itemCount)
    }

    private var subtitleText: String {
        InventoryLocalization.formatted(
            "locations.allItems.subtitle",
            defaultValue: "%@ in this location",
            itemCountText
        )
    }

    private var accessibilityLabel: String {
        InventoryLocalization.formatted(
            "locations.allItems.row.accessibilityLabel",
            defaultValue: "All items, %@",
            subtitleText
        )
    }
}
