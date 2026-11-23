import SwiftUI

struct InventoryItemIconSelectionLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let iconID: String?

    private var symbolName: String {
        ItemIconCatalog.symbolName(for: iconID)
    }

    private var displayName: String {
        guard ItemIconCatalog.option(for: iconID) != nil else {
            return InventoryLocalization.string("itemIcons.default.title", defaultValue: "Default")
        }

        return ItemIconCatalog.displayName(for: iconID)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                    Text("inventory.field.itemIcon")
                    glyph
                    value
                }
            } else {
                LabeledContent {
                    HStack(spacing: 8) {
                        glyph
                        value
                    }
                } label: {
                    Text("inventory.field.itemIcon")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                InventoryLocalization.formatted(
                    "itemIcons.selected.accessibilityLabel",
                    defaultValue: "Item icon: %@",
                    displayName
                )
            )
        )
    }

    private var glyph: some View {
        InventoryContentGlyph(
            systemName: symbolName,
            role: InventoryDesign.ContentRole.item.accentRole,
            domain: .item
        )
    }

    private var value: some View {
        Text(verbatim: displayName)
            .fixedSize(horizontal: false, vertical: true)
    }
}
