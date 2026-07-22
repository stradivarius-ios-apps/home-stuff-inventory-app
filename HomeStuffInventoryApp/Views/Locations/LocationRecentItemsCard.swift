import SwiftUI

struct LocationRecentItemsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: InventoryPreviewGroupPresentation
    let locationName: String
    let transitionNamespace: Namespace.ID
    let reduceMotion: Bool
    let isRecentItemResolvable: (InventoryPreviewGroupPresentation.Chip) -> Bool
    let recentItemSystemImage: (InventoryPreviewGroupPresentation.Chip) -> String
    let onRecentItemTapped: (InventoryPreviewGroupPresentation.Chip) -> Void
    let onAllItemsTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 0) {
                    LocationRecentItemsHeader(presentation: presentation)

                    LocationAllItemsAccessButton(
                        locationName: locationName,
                        onAllItemsTapped: onAllItemsTapped
                    )
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    LocationRecentItemsHeader(presentation: presentation)

                    Spacer(minLength: 8)

                    LocationAllItemsAccessButton(
                        locationName: locationName,
                        onAllItemsTapped: onAllItemsTapped
                    )
                }
            }

            LocationRecentItemTilesSection(
                presentation: presentation,
                transitionNamespace: transitionNamespace,
                reduceMotion: reduceMotion,
                isRecentItemResolvable: isRecentItemResolvable,
                recentItemSystemImage: recentItemSystemImage,
                onRecentItemTapped: onRecentItemTapped
            )
        }
        .recentItemsSectionLayout()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locations.recentItems")
    }
}

struct PlaceRecentItemsCard: View {
    let presentation: InventoryPreviewGroupPresentation
    let transitionNamespace: Namespace.ID
    let reduceMotion: Bool
    let isRecentItemResolvable: (InventoryPreviewGroupPresentation.Chip) -> Bool
    let recentItemSystemImage: (InventoryPreviewGroupPresentation.Chip) -> String
    let onRecentItemTapped: (InventoryPreviewGroupPresentation.Chip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LocationRecentItemsHeader(presentation: presentation)

            LocationRecentItemTilesSection(
                presentation: presentation,
                transitionNamespace: transitionNamespace,
                reduceMotion: reduceMotion,
                isRecentItemResolvable: isRecentItemResolvable,
                recentItemSystemImage: recentItemSystemImage,
                onRecentItemTapped: onRecentItemTapped
            )
        }
        .recentItemsSectionLayout()
        .accessibilityIdentifier("locations.placeRecentItems")
    }
}

private extension View {
    func recentItemsSectionLayout() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(InventoryDesign.compactCardPadding)
    }
}

private struct LocationRecentItemTilesSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: InventoryPreviewGroupPresentation
    let transitionNamespace: Namespace.ID
    let reduceMotion: Bool
    let isRecentItemResolvable: (InventoryPreviewGroupPresentation.Chip) -> Bool
    let recentItemSystemImage: (InventoryPreviewGroupPresentation.Chip) -> String
    let onRecentItemTapped: (InventoryPreviewGroupPresentation.Chip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.previewGroupSpacing) {
            recentItemsShelf

            if let overflowChip = presentation.overflowChip {
                InventoryBadge(verbatim: overflowChip.title, role: .muted)
                    .accessibilityLabel(Text(presentation.accessibilityText))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(presentation.accessibilityText))
    }

    @ViewBuilder
    private var recentItemsShelf: some View {
        VStack(spacing: 0) {
            ForEach(Array(presentation.visibleChips.enumerated()), id: \.element.id) { index, chip in
                recentItemPreview(chip)

                if index < presentation.visibleChips.count - 1 {
                    Divider()
                        .padding(.leading, RecentItemsShelfMetric.dividerLeadingInset)
                        .padding(.trailing, RecentItemsShelfMetric.horizontalPadding)
                }
            }
        }
        .inventorySemanticSurface(.context, cornerRadius: InventoryDesign.compactCornerRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func recentItemPreview(_ chip: InventoryPreviewGroupPresentation.Chip) -> some View {
        if let itemID = UUID(uuidString: chip.id), isRecentItemResolvable(chip) {
            Button {
                onRecentItemTapped(chip)
            } label: {
                recentItemRow(chip)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("locations.recentItems.item.\(chip.id)")
            .accessibilityLabel(Text(recentItemAccessibilityLabel(for: chip)))
            .accessibilityHint(Text(recentItemAccessibilityHint))
            .inventoryItemNavigationSource(
                id: itemID,
                namespace: transitionNamespace,
                reduceMotion: reduceMotion
            )
        } else {
            recentItemRow(chip)
        }
    }

    private func recentItemRow(_ chip: InventoryPreviewGroupPresentation.Chip) -> some View {
        HStack(alignment: .top, spacing: RecentItemsShelfMetric.glyphTitleSpacing) {
            recentItemIcon(chip)
            recentItemTitle(chip)
        }
        .padding(.horizontal, RecentItemsShelfMetric.horizontalPadding)
        .padding(.vertical, RecentItemsShelfMetric.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: RecentItemsShelfMetric.minimumRowHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func recentItemIcon(_ chip: InventoryPreviewGroupPresentation.Chip) -> some View {
        InventoryContentGlyph(
            systemName: recentItemSystemImage(chip),
            role: .context,
            presentation: .identity
        )
        .accessibilityHidden(true)
    }

    private func recentItemTitle(_ chip: InventoryPreviewGroupPresentation.Chip) -> some View {
        Text(verbatim: chip.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: RecentItemsShelfMetric.titleMinimumHeight, alignment: .leading)
    }

}

private enum RecentItemsShelfMetric {
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let glyphTitleSpacing: CGFloat = 12
    static let titleMinimumHeight: CGFloat = 40
    static let minimumRowHeight: CGFloat = 60
    static let dividerLeadingInset: CGFloat = horizontalPadding + 40 + glyphTitleSpacing
}

private struct LocationRecentItemsHeader: View {
    let presentation: InventoryPreviewGroupPresentation

    var body: some View {
        Label {
            Text(presentation.label)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: presentation.systemImage)
                .imageScale(.small)
                .accessibilityHidden(true)
        }
        .font(.headline)
        .foregroundStyle(.primary)
    }
}

private extension LocationRecentItemTilesSection {
    func recentItemAccessibilityLabel(for chip: InventoryPreviewGroupPresentation.Chip) -> String {
        InventoryLocalization.formatted(
            "locations.recentItems.itemAction.accessibilityLabel",
            defaultValue: "Open %@",
            chip.title
        )
    }

    var recentItemAccessibilityHint: String {
        InventoryLocalization.string(
            "locations.recentItems.itemAction.accessibilityHint",
            defaultValue: "Opens the item detail screen."
        )
    }
}

struct LocationItemsAccessCard: View {
    let locationName: String
    let onAllItemsTapped: () -> Void

    var body: some View {
        InventoryCard(
            surface: .interactive,
            padding: InventoryDesign.compactCardPadding,
            cornerRadius: InventoryDesign.compactCornerRadius
        ) {
            LocationAllItemsAccessRow(
                locationName: locationName,
                onAllItemsTapped: onAllItemsTapped
            )
        }
        .accessibilityIdentifier("locations.itemsAccess")
    }
}

private struct LocationAllItemsAccessRow: View {
    let locationName: String
    let onAllItemsTapped: () -> Void

    var body: some View {
        Button(action: onAllItemsTapped) {
            HStack(alignment: .center, spacing: 10) {
                Label {
                    Text(InventoryLocalization.string(
                        "locations.allItems.title",
                        defaultValue: "All items"
                    ))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "tray.full")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, minHeight: InventoryDesign.minimumTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
    }

    private var accessibilityLabel: String {
        InventoryLocalization.formatted(
            "locations.itemsAccess.allItemsAction.accessibilityLabel",
            defaultValue: "Show all items in %@",
            locationName
        )
    }

    private var accessibilityHint: String {
        InventoryLocalization.string(
            "locations.itemsAccess.allItemsAction.accessibilityHint",
            defaultValue: "Opens the full item list for this location."
        )
    }
}

private struct LocationAllItemsAccessButton: View {
    let locationName: String
    let onAllItemsTapped: () -> Void

    var body: some View {
        Button(action: onAllItemsTapped) {
            HStack(spacing: 4) {
                Text(InventoryLocalization.string(
                    "locations.allItems.title",
                    defaultValue: "All items"
                ))

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(InventoryDesign.Appearance.contextHighlight)
            .frame(minHeight: InventoryDesign.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
    }

    private var accessibilityLabel: String {
        InventoryLocalization.formatted(
            "locations.itemsAccess.allItemsAction.accessibilityLabel",
            defaultValue: "Show all items in %@",
            locationName
        )
    }

    private var accessibilityHint: String {
        InventoryLocalization.string(
            "locations.itemsAccess.allItemsAction.accessibilityHint",
            defaultValue: "Opens the full item list for this location."
        )
    }
}

#if DEBUG
#Preview("Location Recent Items - One Light") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.one
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Location Recent Items - Two Light") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.two
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Location Recent Items - Three Light") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.three
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Location Recent Items - Three With Overflow Dark") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.three,
            hiddenCount: 1
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Location Recent Items - Long English Normal Dark") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.longEnglish
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Location Recent Items - Long English Accessibility") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.longEnglish
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.light)
}

#Preview("Location Recent Items - Long Ukrainian Accessibility") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.longUkrainian
        ) {
            LocationRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Place Recent Items - One Light") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.one
        ) {
            PlaceRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Place Recent Items - Two Light") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.two
        ) {
            PlaceRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Place Recent Items - Three Light") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.three
        ) {
            PlaceRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .preferredColorScheme(.light)
}

#Preview("Place Recent Items - Three With Overflow Dark") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.longUkrainian,
            hiddenCount: 1
        ) {
            PlaceRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Place Recent Items - Long English Accessibility") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.longEnglish
        ) {
            PlaceRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.light)
}

#Preview("Place Recent Items - Long Ukrainian Normal Dark") {
    InventoryDetailPreviewSurface {
        if let presentation = InventoryPreviewGroupPresentation.recentItemsPreview(
            InventoryRecentItemsPreviewFixtures.longUkrainian
        ) {
            PlaceRecentItemsPreviewCard(presentation: presentation)
        }
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .preferredColorScheme(.dark)
}

#Preview("Location Items Access") {
    InventoryDetailPreviewSurface {
        LocationItemsAccessCard(locationName: "Garage shelves") {}
    }
}

#endif
