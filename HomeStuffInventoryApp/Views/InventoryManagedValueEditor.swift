import SwiftUI

struct InventoryManagedValueEditor: View {
    let sheet: InventoryListManagementSheet
    let onSave: (InventoryListManagementValueDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    @State private var iconID: String?
    @FocusState private var focusedField: FocusedField?

    init(sheet: InventoryListManagementSheet, onSave: @escaping (InventoryListManagementValueDraft) -> Void) {
        self.sheet = sheet
        self.onSave = onSave
        _value = State(initialValue: sheet.initialValue)
        _iconID = State(initialValue: sheet.initialIconID)
    }

    private var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(sheet.prompt, text: $value)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .inventoryFocusableFormRow(focusedField: $focusedField, equals: .value)
                    .inventoryFormRowSurface()
                    .accessibilityIdentifier("inventory.lists.valueField")

                if sheet.supportsLocationIcon {
                    locationIconSection
                }
            }
            .inventoryFormPresentation(contentRole: sheet.contentRole)
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "inventory.action.cancel", defaultValue: "Cancel", bundle: .main)) {
                        dismiss()
                    }
                    .accessibilityIdentifier("inventory.lists.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "inventory.action.save", defaultValue: "Save", bundle: .main)) {
                        save()
                    }
                    .disabled(trimmedValue.isEmpty)
                    .accessibilityIdentifier("inventory.lists.saveButton")
                    .inventoryPrimaryActionTint()
                }
            }
        }
    }

    private var locationIconSection: some View {
        Section {
            NavigationLink {
                LocationIconPickerView(selection: $iconID)
            } label: {
                InventoryPickerIconRow(
                    selectedIconTitleKey,
                    systemImage: selectedIconSystemName,
                    iconRole: .storage,
                    isSelected: false
                )
            }
            .accessibilityIdentifier("inventory.lists.locationIconPicker")
        } header: {
            Text("locationIcons.section.icon")
        } footer: {
            Text("locationIcons.footer.optional")
                .inventoryHelperText()
        }
        .inventoryFormRowSurface()
    }

    private var selectedIcon: LocationIconOption? {
        LocationIconCatalog.option(for: iconID)
    }

    private var selectedIconSystemName: String {
        selectedIcon?.symbolName ?? LocationIconCatalog.fallbackSymbolName
    }

    private var selectedIconTitleKey: LocalizedStringKey {
        LocalizedStringKey(selectedIcon?.nameKey ?? "locationIcons.option.default")
    }

    private func save() {
        guard !trimmedValue.isEmpty else {
            return
        }

        onSave(InventoryListManagementValueDraft(value: trimmedValue, iconID: iconID))
    }

    private enum FocusedField: Hashable {
        case value
    }
}

private extension InventoryListManagementSheet {
    var contentRole: InventoryDesign.ContentRole? {
        supportsLocationIcon ? .location : nil
    }
}
