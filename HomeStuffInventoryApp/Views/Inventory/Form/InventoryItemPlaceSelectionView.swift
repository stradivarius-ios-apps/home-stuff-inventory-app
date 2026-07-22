import SwiftUI

/// Location-scoped first-class Place selection for Item forms.
struct InventoryItemPlaceSelectionView: View {
    let location: StorageLocation?
    let places: [InventoryPlace]
    @Binding var selection: UUID?
    @Binding var placeName: String
    let createPlace: (String, String?) -> InventoryValueCreationOutcome

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCreateSheet = false
    @State private var searchText = ""

    private var scopedPlaces: [InventoryPlace] {
        InventoryItemPlaceLink.places(in: location, from: places).filter {
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selection = nil
                    placeName = ""
                    dismiss()
                } label: {
                    InventorySelectionRow("inventory.fallback.noContainer", isSelected: selection == nil && placeName.isEmpty)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inventory.placeSelection.empty")
            }
            .inventoryFormRowSurface()

            if !scopedPlaces.isEmpty {
                Section("inventory.selection.existing") {
                    ForEach(scopedPlaces) { place in
                        Button {
                            selection = place.id
                            placeName = place.name
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: PlaceIconCatalog.symbolName(for: place.iconID))
                                    .foregroundStyle(InventoryDesign.ContentRole.place.color)
                                InventorySelectionRow(verbatim: place.name, isSelected: selection == place.id)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("inventory.placeSelection.option.\(place.id.uuidString)")
                    }
                }
                .inventoryFormRowSurface()
            }

            if location != nil {
                Section {
                    Button { isShowingCreateSheet = true } label: {
                        InventoryAddNewRow("inventory.selection.place.addNew")
                    }
                    .inventoryPrimaryActionTint()
                    .accessibilityIdentifier("inventory.placeSelection.createButton")
                }
                .inventoryFormRowSurface()
            }
        }
        .inventoryFormPresentation()
        .navigationTitle("inventory.field.container")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .sheet(isPresented: $isShowingCreateSheet) {
            InventoryItemPlaceCreationView { name, iconID in
                let outcome = createPlace(name, iconID)
                if case .success = outcome { dismiss() }
                return outcome
            }
        }
    }
}

private struct InventoryItemPlaceCreationView: View {
    let create: (String, String?) -> InventoryValueCreationOutcome
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var iconID = PlaceIconCatalog.defaultIconID
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("inventory.selection.place.newPrompt", text: $name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("inventory.placeSelection.nameField")
                Picker("inventory.selection.place.icon", selection: $iconID) {
                    ForEach(PlaceIconCatalog.options) { option in
                        Label(option.localizedName, systemImage: option.symbolName).tag(option.id)
                    }
                }
                .accessibilityIdentifier("inventory.placeSelection.iconPicker")
                .accessibilityLabel("inventory.selection.place.icon")
                .accessibilityHint("inventory.selection.place.icon.help")
            }
            .navigationTitle("inventory.selection.place.create")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("inventory.action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("inventory.action.save") {
                        switch create(name, iconID) {
                        case .success: dismiss()
                        case let .failure(message): errorMessage = message
                        }
                    }
                    .inventoryPrimaryActionTint()
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("inventory.placeSelection.saveButton")
                }
            }
            .alert("inventory.selection.creation.error.title", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("inventory.action.ok", role: .cancel) { }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
