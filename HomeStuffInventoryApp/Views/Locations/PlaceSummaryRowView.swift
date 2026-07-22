import SwiftData
import SwiftUI

struct PlaceSummaryRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let place: InventoryBrowseSummaries.PlaceSummary
    @Query private var places: [InventoryPlace]

    var body: some View {
        InventoryListRowCard(
            surface: .content,
            minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 72
        ) {
            topRow
        }
        .accessibilityElement(children: .combine)
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            placeIcon

            VStack(alignment: .leading, spacing: 3) {
                titleAndCount
                categoryRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleAndCount: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                placeTitle
                itemCount
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                placeTitle
                    .frame(maxWidth: .infinity, alignment: .leading)
                itemCount
            }
        }
    }

    private var placeTitle: some View {
        Text(place.name)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var itemCount: some View {
        Text(verbatim: itemCountText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private var categoryRow: some View {
        if !place.categorySummaries.isEmpty {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    categoryVariant(visibleCount: 0)
                } else {
                    ViewThatFits(in: .horizontal) {
                        categoryVariant(visibleCount: 3)
                        categoryVariant(visibleCount: 2)
                        categoryVariant(visibleCount: 1)
                        categoryVariant(visibleCount: 0)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func categoryVariant(visibleCount: Int) -> some View {
        let presentation = PlaceCategoryRowPresentation(
            categories: place.categorySummaries,
            visibleCount: visibleCount
        )

        return HStack(spacing: 8) {
            ForEach(presentation.visibleCategories) { category in
                let entry = PlaceCategoryEntryPresentation(category: category)
                HStack(spacing: 4) {
                    Image(systemName: entry.symbolName)
                        .accessibilityHidden(true)
                    Text(verbatim: entry.displayName)
                }
                .fixedSize()
            }

            if let overflowText = presentation.overflowText {
                Text(verbatim: overflowText)
                    .monospacedDigit()
                    .fixedSize()
                    .accessibilityLabel(Text(presentation.accessibilityOverflowText ?? overflowText))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var placeIcon: some View {
        InventoryContentGlyph(
            systemName: placeIconSystemName,
            role: place.isMissingPlace ? .muted : InventoryDesign.ContentRole.place.accentRole,
            presentation: .identity
        )
        .accessibilityHidden(true)
    }

    private var placeIconSystemName: String {
        InventoryPlaceIconPresentation.symbolName(placeID: place.placeID, isMissingPlace: place.isMissingPlace, places: places)
    }

    private var itemCountText: String {
        InventoryLocalization.itemCount(place.itemCount)
    }

}

#if DEBUG
#Preview("Place Rows - English Light") {
    PlaceSummaryRowsPreview(rows: PlaceSummaryPreviewData.englishRows)
        .preferredColorScheme(.light)
}

#Preview("Place Rows - English Dark") {
    PlaceSummaryRowsPreview(rows: PlaceSummaryPreviewData.englishRows)
        .preferredColorScheme(.dark)
}

#Preview("Place Rows - Ukrainian Names Light") {
    PlaceSummaryRowsPreview(rows: PlaceSummaryPreviewData.ukrainianRows)
        .preferredColorScheme(.light)
}

#Preview("Place Rows - Ukrainian Names Dark") {
    PlaceSummaryRowsPreview(rows: PlaceSummaryPreviewData.ukrainianRows)
        .preferredColorScheme(.dark)
}

#Preview("Place Rows - Ukrainian Names Dark Accessibility") {
    PlaceSummaryRowsPreview(rows: PlaceSummaryPreviewData.ukrainianRows)
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}

private struct PlaceSummaryRowsPreview: View {
    let rows: [InventoryBrowseSummaries.PlaceSummary]

    var body: some View {
        ScrollView {
            VStack(spacing: InventoryDesign.gridSpacing) {
                ForEach(rows) { place in
                    PlaceSummaryRowView(place: place)
                }
            }
            .padding(InventoryDesign.screenPadding)
        }
        .inventoryGroupedBackground()
    }
}

private enum PlaceSummaryPreviewData {
    static let englishRows: [InventoryBrowseSummaries.PlaceSummary] = [
        .init(
            id: "Office::desk-drawer",
            name: "Desk drawer",
            itemCount: 0,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        ),
        .init(
            id: "Office::charger-tray",
            name: "Charger tray",
            itemCount: 1,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        ),
        .init(
            id: "Office::long-place",
            name: "Clear hardware drawer with an unusually long descriptive label",
            itemCount: 12,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        )
    ]

    static let ukrainianRows: [InventoryBrowseSummaries.PlaceSummary] = [
        .init(
            id: "Office::desk-drawer-ukrainian",
            name: "Шухляда письмового столу",
            itemCount: 0,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        ),
        .init(
            id: "Office::charger-tray-ukrainian",
            name: "Лоток для зарядних пристроїв",
            itemCount: 1,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        ),
        .init(
            id: "Office::long-place-ukrainian",
            name: "Прозора шухляда для дрібних деталей і запасних кабелів біля робочого столу",
            itemCount: 12,
            locationID: "Office",
            locationName: "Office",
            isMissingLocation: false,
            isMissingPlace: false
        )
    ]
}
#endif
