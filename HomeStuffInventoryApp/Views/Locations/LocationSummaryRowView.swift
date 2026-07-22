import SwiftUI

struct LocationSummaryRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let location: InventoryBrowseSummaries.LocationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.previewValueSpacing) {
            header
            placeSummaryLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(InventoryDesign.cardPadding)
        .inventorySemanticSurface(
            .location,
            cornerRadius: InventoryDesign.cardCornerRadius
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: InventoryDesign.cardCornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    @ViewBuilder
    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    titleStack
                    HStack(spacing: 12) {
                        locationIcon
                        InventoryRowChevron()
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    titleStack
                    locationIcon
                    InventoryRowChevron()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(location.name)
                .inventoryTextRole(.entityTitle)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: itemCountText)
                .inventoryTextRole(.supportingText)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var locationIcon: some View {
        Image(systemName: locationIconSystemName)
            .font(.system(size: InventoryDesign.locationSummaryIconSize, weight: .semibold))
            .foregroundStyle(location.isMissingLocation ? Color.secondary : InventoryDesign.ContentRole.location.color)
            .frame(
                width: InventoryDesign.locationSummaryIconFrame,
                height: InventoryDesign.locationSummaryIconFrame
            )
            .accessibilityHidden(true)
    }

    private var locationIconSystemName: String {
        location.isMissingLocation
            ? LocationIconCatalog.missingLocationSymbolName
            : LocationIconCatalog.symbolName(for: location.iconID)
    }

    private var itemCountText: String {
        InventoryLocalization.itemCount(location.itemCount)
    }

    private var placeSummaryLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "shippingbox")
                .imageScale(.small)
                .foregroundStyle(InventoryDesign.ContentRole.place.color)
                .accessibilityHidden(true)

            Text(verbatim: placeSummary.text ?? placeSummary.placeCountText)
                .inventoryTextRole(.supportingText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHidden(true)
    }

    private var placeSummary: LocationPlaceSummary {
        LocationPlaceSummary(
            places: location.placePreview,
            hiddenPlaceCount: location.hiddenPlaceCount
        )
    }

    private var accessibilityLabel: String {
        return InventoryLocalization.formatted(
            "locations.row.accessibilityLabelWithPlaces",
            defaultValue: "%1$@, %2$@, storage places: %3$@",
            location.name,
            itemCountText,
            placeSummary.text ?? placeSummary.placeCountText
        )
    }

}
