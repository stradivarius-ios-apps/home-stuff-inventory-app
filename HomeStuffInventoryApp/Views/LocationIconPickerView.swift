import SwiftUI

struct LocationIconPickerView: View {
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                iconButton(
                    id: nil,
                    symbolName: LocationIconCatalog.fallbackSymbolName,
                    titleKey: "locationIcons.option.default"
                )
            }
            .inventoryFormRowSurface()

            ForEach(LocationIconCategory.allCases) { category in
                Section {
                    ForEach(LocationIconCatalog.options(in: category)) { option in
                        iconButton(
                            id: option.id,
                            symbolName: option.symbolName,
                            titleKey: option.nameKey
                        )
                    }
                } header: {
                    Text(LocalizedStringKey(category.titleKey))
                }
                .inventoryFormRowSurface()
            }
        }
        .inventoryFormPresentation(contentRole: .location)
        .navigationTitle("locationIcons.picker.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func iconButton(id: String?, symbolName: String, titleKey: String) -> some View {
        Button {
            selection = id
            dismiss()
        } label: {
            InventoryPickerIconRow(
                LocalizedStringKey(titleKey),
                systemImage: symbolName,
                iconRole: .storage,
                isSelected: selection == id
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("locationIcons.option.\(id ?? "default")")
    }
}
