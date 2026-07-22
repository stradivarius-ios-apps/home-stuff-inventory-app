import SwiftUI

struct InventoryPreviewGroupRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let presentation: InventoryPreviewGroupPresentation

    init(_ presentation: InventoryPreviewGroupPresentation) {
        self.presentation = presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.previewValueSpacing) {
            sectionLabel

            previewValues
                .padding(.leading, InventoryDesign.previewValueIndent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(presentation.accessibilityText))
    }

    private var sectionLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: presentation.systemImage)
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(presentation.label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .inventoryTextRole(.fieldLabel, accentRole: presentation.kind.role)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var previewValues: some View {
        switch presentation.kind {
        case .place:
            placeValues
        case .category, .recentItem:
            summaryValues
        }
    }

    private var placeValues: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: InventoryDesign.previewGroupSpacing) {
                placeBadges
            }

            VStack(alignment: .leading, spacing: InventoryDesign.previewValueSpacing) {
                placeBadges
            }
        }
    }

    @ViewBuilder
    private var placeBadges: some View {
        ForEach(presentation.visibleChips) { chip in
            InventoryPlacePreviewBadge(chip.title)
        }

        if let overflowChip = presentation.overflowChip {
            InventoryPreviewOverflowBadge(overflowChip.title)
        }
    }

    private var summaryValues: some View {
        HStack(alignment: .firstTextBaseline, spacing: InventoryDesign.previewGroupSpacing) {
            Text(verbatim: presentation.visibleValueText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.tail)
                .layoutPriority(1)

            if let overflowChip = presentation.overflowChip {
                InventoryPreviewOverflowBadge(overflowChip.title)
            }
        }
    }
}

private struct InventoryPlacePreviewBadge: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Label {
            Text(verbatim: title)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "shippingbox")
                .imageScale(.small)
                .foregroundStyle(InventoryDesign.ContentRole.place.color)
                .accessibilityHidden(true)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, InventoryDesign.editorHorizontalPadding)
        .padding(.vertical, InventoryDesign.previewOverflowChipVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: InventoryDesign.compactCornerRadius, style: .continuous)
                .fill(InventoryDesign.Appearance.contentSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: InventoryDesign.compactCornerRadius, style: .continuous)
                        .fill(InventoryDesign.ContentRole.place.color.opacity(InventoryDesign.Opacity.badgeFill))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: InventoryDesign.compactCornerRadius, style: .continuous)
                .strokeBorder(
                    InventoryDesign.ContentRole.place.color.opacity(
                        colorSchemeContrast == .increased ? 0.8 : InventoryDesign.Opacity.placeBadgeStroke
                    ),
                    lineWidth: InventoryDesign.Stroke.badge
                )
        }
        .accessibilityElement(children: .combine)
    }
}

private struct InventoryPreviewOverflowBadge: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(verbatim: title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, InventoryDesign.previewOverflowChipHorizontalPadding)
            .padding(.vertical, InventoryDesign.previewOverflowChipVerticalPadding)
            .inventoryBadgeSurface(role: .muted)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(true)
    }
}

private extension InventoryBrowseSummaries.PreviewGroup.Kind {
    var role: InventoryDesign.AccentRole {
        switch self {
        case .category:
            return .secondary
        case .place:
            return InventoryDesign.ContentRole.place.accentRole
        case .recentItem:
            return .context
        }
    }
}
