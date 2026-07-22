import SwiftUI

struct InventoryCompactItemCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: InventoryItem

    var body: some View {
        HStack(alignment: .top, spacing: InventoryDesign.rowSpacing) {
            InventoryContentGlyph(
                systemName: ItemIconCatalog.symbolName(for: item.iconID),
                role: InventoryDesign.ContentRole.item.accentRole,
                presentation: .compact
            )

            VStack(alignment: .leading, spacing: 4) {
                title
                storageSummary
                metadataRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, InventoryDesign.compactInventoryCardHorizontalPadding)
        .padding(.vertical, InventoryDesign.rowSpacing)
        .frame(minHeight: InventoryDesign.minimumTapTarget)
        .inventorySemanticSurface(.item, cornerRadius: InventoryDesign.compactCornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: InventoryDesign.compactCornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var title: some View {
        Text(item.name)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var metadataRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                categoryText
                quantityTextView
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: InventoryDesign.rowSpacing) {
                categoryText
                    .frame(maxWidth: .infinity, alignment: .leading)

                quantityTextView
            }
        }
    }

    private var categoryText: some View {
        Text(verbatim: categoryName)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var quantityTextView: some View {
        Text(verbatim: quantityText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize()
    }

    @ViewBuilder
    private var storageSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                storageValue(
                    locationName,
                    systemImage: "mappin.and.ellipse",
                    hasValue: hasLocation,
                    contentRole: .location
                )
                storageValue(
                    placeName,
                    systemImage: "shippingbox",
                    hasValue: hasPlace,
                    contentRole: .place
                )
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                storageValue(
                    locationName,
                    systemImage: "mappin.and.ellipse",
                    hasValue: hasLocation,
                    contentRole: .location
                )

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                storageValue(
                    placeName,
                    systemImage: "shippingbox",
                    hasValue: hasPlace,
                    contentRole: .place
                )
            }
        }
    }

    private func storageValue(
        _ value: String,
        systemImage: String,
        hasValue: Bool,
        contentRole: InventoryDesign.ContentRole
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(hasValue ? contentRole.color : Color.secondary)
                .accessibilityHidden(true)

            Text(verbatim: value)
                .font(.subheadline.weight(contentRole == .place ? .semibold : .regular))
                .foregroundStyle(hasValue ? Color.primary : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var locationName: String {
        let name = item.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? InventoryLocalization.noLocation : name
    }

    private var placeName: String {
        guard let name = item.containerName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return InventoryLocalization.noContainer
        }

        return name
    }

    private var hasLocation: Bool {
        !item.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPlace: Bool {
        guard let name = item.containerName else {
            return false
        }

        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var categoryName: String {
        InventoryCategory.displayName(forStoredValue: item.category)
    }

    private var quantityText: String {
        "×\(item.quantity)"
    }

    private var accessibilityLabel: String {
        [item.name, locationName, placeName, categoryName, accessibilityQuantityText]
            .joined(separator: ", ")
    }

    private var accessibilityQuantityText: String {
        InventoryLocalization.formatted(
            "inventory.quantity.inline",
            defaultValue: "Quantity %d",
            item.quantity
        )
    }
}

#if DEBUG
#Preview("Compact Item Card - Five Short Items") {
    InventoryCompactItemCardPreviewSurface {
        LazyVStack(spacing: InventoryDesign.rowSpacing) {
            ForEach(InventoryItem.compactCardShortItems) { item in
                InventoryCompactItemCard(item: item)
            }
        }
    }
}

#Preview("Compact Item Card - Long Ukrainian Accessibility") {
    InventoryCompactItemCardPreviewSurface {
        InventoryCompactItemCard(item: .compactCardLongUkrainian)
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Compact Item Card - Missing Storage") {
    InventoryCompactItemCardPreviewSurface {
        InventoryCompactItemCard(item: .compactCardMissingStorage)
    }
    .preferredColorScheme(.dark)
}

#Preview("Compact Item Card - Short Quantity - 320 pt") {
    InventoryCompactItemCardPreviewSurface {
        InventoryCompactItemCard(item: .compactCardShortMultiDigitQuantity)
    }
    .frame(width: 320)
}

private struct InventoryCompactItemCardPreviewSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(InventoryDesign.screenPadding)
        }
        .inventoryGroupedBackground()
    }
}

private extension InventoryItem {
    static var compactCardShortItems: [InventoryItem] {
        [
            InventoryItem(
                name: "Tape",
                category: InventoryCategory.householdSupplies.rawValue,
                locationName: "Hall closet",
                containerName: "Top shelf",
                iconID: "box"
            ),
            InventoryItem(
                name: "Flashlight",
                category: InventoryCategory.tools.rawValue,
                locationName: "Entryway",
                containerName: "Drawer",
                iconID: "toolkit"
            ),
            InventoryItem(
                name: "Passport",
                category: InventoryCategory.documents.rawValue,
                locationName: "Bedroom",
                containerName: "Safe",
                iconID: "document"
            ),
            InventoryItem(
                name: "Batteries",
                category: InventoryCategory.electronics.rawValue,
                locationName: "Office",
                containerName: "Supply box",
                iconID: "battery"
            ),
            InventoryItem(
                name: "First aid kit",
                category: InventoryCategory.miscellaneous.rawValue,
                locationName: "Bathroom",
                containerName: "Cabinet",
                iconID: "first-aid"
            )
        ]
    }

    static var compactCardLongUkrainian: InventoryItem {
        InventoryItem(
            name: "Набір запасних зарядних кабелів для гостей і подорожей",
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: "Шафа у передпокої з довгою назвою місця зберігання",
            containerName: "Прозорий контейнер на верхній полиці біля дорожніх сумок",
            iconID: "power-plug",
            quantity: 8
        )
    }

    static var compactCardMissingStorage: InventoryItem {
        InventoryItem(
            name: "Loose warranty card",
            category: InventoryCategory.documents.rawValue,
            locationName: "",
            iconID: "document"
        )
    }

    static var compactCardShortMultiDigitQuantity: InventoryItem {
        InventoryItem(
            name: "Tape",
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: "Hall closet",
            containerName: "Top shelf",
            iconID: "shippingbox",
            quantity: 24
        )
    }
}
#endif
