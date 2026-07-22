import SwiftUI

struct InventoryItemIconPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: String?

    var body: some View {
        List {
            Section {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    iconRow(
                        symbolName: ItemIconCatalog.fallbackSymbolName,
                        title: InventoryLocalization.string("itemIcons.default.title", defaultValue: "Default"),
                        isSelected: selection == nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inventory.itemIconPicker.default")
            } footer: {
                Text("itemIcons.footer.optional")
                    .inventoryHelperText()
            }
            .inventoryFormRowSurface()

            ForEach(ItemIconCategory.allCases) { category in
                Section(categoryTitle(for: category)) {
                    ForEach(ItemIconCatalog.options(in: category)) { option in
                        Button {
                            selection = option.id
                            dismiss()
                        } label: {
                            iconRow(
                                symbolName: option.symbolName,
                                title: ItemIconCatalog.displayName(for: option.id),
                                isSelected: selection == option.id
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("inventory.itemIconPicker.option.\(option.id)")
                    }
                }
                .inventoryFormRowSurface()
            }
        }
        .inventoryFormPresentation()
        .navigationTitle("itemIcons.picker.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryTitle(for category: ItemIconCategory) -> String {
        Bundle.main.localizedString(forKey: category.titleKey, value: nil, table: "Localizable")
    }

    private func iconRow(symbolName: String, title: String, isSelected: Bool) -> some View {
        InventoryPickerIconRow(
            title: title,
            systemImage: symbolName,
            isSelected: isSelected,
            accessibilityLabel: Text(
                InventoryLocalization.formatted(
                    "itemIcons.option.accessibilityLabel",
                    defaultValue: "%@ item icon",
                    title
                )
            )
        )
    }
}

#if DEBUG
#Preview("Item Icon Picker - Accessibility") {
    NavigationStack {
        InventoryItemIconPickerPreview()
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

private struct InventoryItemIconPickerPreview: View {
    @State private var selection: String? = "power-plug"

    var body: some View {
        InventoryItemIconPickerView(selection: $selection)
    }
}
#endif
