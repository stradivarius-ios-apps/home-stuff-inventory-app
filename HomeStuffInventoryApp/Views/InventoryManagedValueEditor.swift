import SwiftData
import SwiftUI

struct InventoryManagedValueEditor: View {
    let sheet: InventoryListManagementSheet
    let onSave: (InventoryListManagementValueDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    @State private var iconID: String?
    @FocusState private var focusedField: FocusedField?

    init(
        sheet: InventoryListManagementSheet,
        initialDraft: InventoryListManagementValueDraft? = nil,
        onSave: @escaping (InventoryListManagementValueDraft) -> Void
    ) {
        self.sheet = sheet
        self.onSave = onSave
        _value = State(initialValue: initialDraft?.value ?? sheet.initialValue)
        _iconID = State(initialValue: initialDraft.map(\.iconID) ?? sheet.initialIconID)
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

struct InventoryLocationEditorTarget: Identifiable {
    let id: UUID
    let sheet: InventoryListManagementSheet
    let draft: InventoryListManagementValueDraft

    init(location: StorageLocation) {
        id = location.id
        sheet = .editLocation(location)
        draft = InventoryListManagementValueDraft(value: sheet.initialValue, iconID: sheet.initialIconID)
    }
}

struct InventoryLocationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]
    @Query(sort: \InventoryCustomCategory.name) private var customCategories: [InventoryCustomCategory]
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @State private var alert: InventoryListManagementAlert?

    let target: InventoryLocationEditorTarget

    var body: some View {
        InventoryManagedValueEditor(sheet: target.sheet, initialDraft: target.draft, onSave: save)
            .alert(item: $alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message))
            }
    }

    private func save(_ draft: InventoryListManagementValueDraft) {
        do {
            // Fetch at commit time while keeping the editor and its captured draft alive.
            let locationID = target.id
            let descriptor = FetchDescriptor<StorageLocation>(predicate: #Predicate { $0.id == locationID })
            guard let location = try modelContext.fetch(descriptor).first else {
                alert = InventoryListManagementAlert(
                    title: InventoryLocalization.string(
                        "locations.management.unavailable.title", defaultValue: "Location Unavailable"
                    ),
                    message: InventoryLocalization.string(
                        "locations.management.unavailable.message",
                        defaultValue: "This location is no longer available. Close the editor and return to Locations."
                    )
                )
                return
            }

            try InventoryListManagementPersistence.save(
                .renameLocation(location, name: draft.value, iconID: draft.iconID),
                locations: locations,
                places: places,
                customCategories: customCategories,
                items: items,
                in: modelContext
            )
            dismiss()
        } catch let error as InventoryListManagementError {
            alert = .error(error)
        } catch {
            alert = InventoryListManagementPersistenceFailure.save.alert
        }
    }
}
