import SwiftUI

struct InventoryItemIconSelectionLabel: View {
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
        LabeledContent {
            HStack(spacing: 8) {
                InventoryContentGlyph(
                    systemName: symbolName,
                    role: InventoryDesign.ContentRole.item.accentRole
                )

                Text(verbatim: displayName)
            }
        } label: {
            Text("inventory.field.itemIcon")
        }
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
}
