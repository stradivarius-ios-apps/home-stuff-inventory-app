import SwiftData
import SwiftUI

struct PlaceManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess
    @Environment(PremiumUpgradeCoordinator.self) private var upgradeCoordinator
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]

    @State private var sheet: PlaceManagementSheet?
    @State private var dialog: PlaceManagementDialog?
    @State private var itemsSelection: InventoryManagedItemsSelection?

    var body: some View {
        InventoryPlaceHierarchyDirectoryView(
            onAddTopLevel: presentTopLevelEditor,
            onViewItems: presentItems,
            onCreateChild: requestChildCreation,
            onEdit: presentHierarchyEditor,
            onRestructure: requestRestructure,
            onDelete: requestDelete,
            onUndoRequested: requestUndo
        )
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .addTopLevel:
                TopLevelPlaceEditorView(locations: locations) {
                    saveTopLevel(name: $0, iconID: $1, location: $2)
                }
            case let .hierarchyEditor(mode, name, iconID):
                InventoryPlaceHierarchyEditorView(
                    mode: mode,
                    initialName: name,
                    initialIconID: iconID
                )
            case let .restructure(placeID):
                InventoryPlaceHierarchyMoveView(sourcePlaceID: placeID)
            }
        }
        .alert(item: $dialog) { dialog in
            switch dialog {
            case let .delete(placeID, name):
                Alert(
                    title: Text("inventory.places.delete.title"),
                    message: Text(
                        InventoryLocalization.formatted(
                            "inventory.places.delete.message",
                            defaultValue: "Delete %@ from reusable Storage Places?",
                            name
                        )
                    ),
                    primaryButton: .destructive(Text("inventory.action.delete")) {
                        delete(placeID)
                    },
                    secondaryButton: .cancel()
                )
            case .undo:
                Alert(
                    title: Text("inventory.places.hierarchy.undo.confirm.title"),
                    message: Text("inventory.places.hierarchy.undo.confirm.message"),
                    primaryButton: .default(Text("inventory.places.hierarchy.undo.confirm.action")) {
                        undoLatest()
                    },
                    secondaryButton: .cancel()
                )
            case let .message(messageKey):
                Alert(
                    title: Text("inventory.places.hierarchy.error.title"),
                    message: Text(messageKey),
                    dismissButton: .default(Text("inventory.action.ok"))
                )
            case let .valueInUse(selection):
                Alert(
                    title: Text("inventory.lists.error.used.title"),
                    message: Text("inventory.places.hierarchy.error.containsItems"),
                    primaryButton: .default(Text("inventory.lists.viewItems")) {
                        self.dialog = nil
                        itemsSelection = selection
                    },
                    secondaryButton: .cancel(Text("inventory.action.ok"))
                )
            }
        }
        .navigationDestination(item: $itemsSelection) { selection in
            ScopedInventoryItemsListView(
                title: selection.title,
                items: InventoryListManagement.items(in: items, matching: selection),
                emptyTitleKey: "inventory.lists.items.empty.title",
                emptyTitleDefaultValue: "No Items",
                emptyMessageKey: "inventory.lists.items.empty.message",
                emptyMessageDefaultValue: "Items that use this value appear here.",
                emptySystemImage: selection.emptySystemImage
            )
        }
    }

    private func presentTopLevelEditor() {
        sheet = .addTopLevel
    }

    private func presentItems(_ placeID: UUID) {
        guard let place = place(placeID),
              let location = location(place.locationID),
              let selection = try? InventoryListManagement.selection(
                for: place,
                in: location
              )
        else {
            dialog = .message("inventory.places.hierarchy.error.changed")
            return
        }
        itemsSelection = selection
    }

    private func requestChildCreation(_ parentID: UUID) {
        upgradeCoordinator.request(.nestedStoragePlaceCreation) {
            guard place(parentID) != nil else {
                dialog = .message("inventory.places.hierarchy.error.changed")
                return
            }
            sheet = .hierarchyEditor(
                .createChild(parentID: parentID),
                name: "",
                iconID: nil
            )
        }
    }

    private func presentHierarchyEditor(_ placeID: UUID) {
        guard let place = place(placeID),
              canDirectlyEdit(place)
        else {
            dialog = .message("inventory.places.hierarchy.error.accessRequired")
            return
        }
        sheet = .hierarchyEditor(
            .edit(placeID: placeID),
            name: place.name,
            iconID: place.iconID
        )
    }

    private func requestRestructure(_ placeID: UUID) {
        upgradeCoordinator.request(.nestedStoragePlaceRestructure) {
            guard place(placeID) != nil else {
                dialog = .message("inventory.places.hierarchy.error.changed")
                return
            }
            sheet = .restructure(placeID)
        }
    }

    private func requestDelete(_ placeID: UUID) {
        guard let place = place(placeID),
              canDirectlyEdit(place)
        else {
            dialog = .message("inventory.places.hierarchy.error.accessRequired")
            return
        }
        dialog = .delete(place.id, name: place.name)
    }

    private func requestUndo() {
        upgradeCoordinator.request(.nestedStoragePlaceRestructure) {
            dialog = .undo
        }
    }

    private func saveTopLevel(
        name: String,
        iconID: String,
        location: StorageLocation
    ) {
        do {
            try InventoryListManagementPersistence.save(
                .addPlace(name: name, iconID: iconID, location: location),
                locations: locations,
                places: places,
                customCategories: [],
                items: items,
                in: modelContext
            )
            sheet = nil
        } catch {
            dialog = .message("inventory.places.hierarchy.error.persistence")
        }
    }

    private func delete(_ placeID: UUID) {
        guard let place = place(placeID) else {
            dialog = .message("inventory.places.hierarchy.error.changed")
            return
        }
        do {
            try InventoryPlaceMutationPersistence.delete(
                .init(place: place),
                entitlements: premiumAccess.entitlements,
                in: modelContext
            )
            dialog = nil
        } catch let error as InventoryPlaceMutationError {
            if case .containsItems = error,
               let location = location(place.locationID),
               let selection = try? InventoryListManagement.selection(
                   for: place,
                   in: location
               ) {
                dialog = .valueInUse(selection)
            } else {
                dialog = .message(mutationMessageKey(error))
            }
        } catch {
            dialog = .message("inventory.places.hierarchy.error.persistence")
        }
    }

    private func undoLatest() {
        let outcome = InventoryPlaceMutationPersistence.undoLatest(
            entitlements: premiumAccess.entitlements,
            in: modelContext
        )
        switch outcome {
        case .undone:
            dialog = nil
        case .accessRequired:
            dialog = .message("inventory.places.hierarchy.error.accessRequired")
        case .currentStateChanged:
            dialog = .message("inventory.places.hierarchy.error.changed")
        case .unsafeRestoration:
            dialog = .message("inventory.places.hierarchy.error.invalidDestination")
        case .unavailable, .failed:
            dialog = .message("inventory.places.hierarchy.error.persistence")
        }
    }

    private func place(_ id: UUID) -> InventoryPlace? {
        places.first { $0.id == id }
    }

    private func location(_ id: UUID) -> StorageLocation? {
        locations.first { $0.id == id }
    }

    private func canDirectlyEdit(_ place: InventoryPlace) -> Bool {
        let participates = place.parentPlaceID != nil
            || places.contains { $0.parentPlaceID == place.id }
        return !participates || premiumAccess.entitlements.hasLocalProFeatures
    }

    private func mutationMessageKey(
        _ error: InventoryPlaceMutationError
    ) -> LocalizedStringKey {
        switch error {
        case .accessRequired:
            "inventory.places.hierarchy.error.accessRequired"
        case .emptyName:
            "inventory.places.hierarchy.error.emptyName"
        case .missingPlace, .missingLocation, .staleState:
            "inventory.places.hierarchy.error.changed"
        case .missingParent, .crossLocationParent, .descendantCycle:
            "inventory.places.hierarchy.error.invalidDestination"
        case .duplicateSiblingName:
            "inventory.places.hierarchy.error.duplicateName"
        case .containsChildren:
            "inventory.places.hierarchy.error.containsChildren"
        case .containsItems:
            "inventory.places.hierarchy.error.containsItems"
        case .persistenceFailed:
            "inventory.places.hierarchy.error.persistence"
        }
    }
}

private enum PlaceManagementSheet: Identifiable {
    case addTopLevel
    case hierarchyEditor(
        InventoryPlaceHierarchyEditorView.Mode,
        name: String,
        iconID: String?
    )
    case restructure(UUID)

    var id: String {
        switch self {
        case .addTopLevel:
            "add-top-level"
        case let .hierarchyEditor(mode, _, _):
            switch mode {
            case let .createChild(parentID):
                "add-child-\(parentID.uuidString)"
            case let .edit(placeID):
                "edit-\(placeID.uuidString)"
            }
        case let .restructure(placeID):
            "restructure-\(placeID.uuidString)"
        }
    }
}

private enum PlaceManagementDialog: Identifiable {
    case delete(UUID, name: String)
    case undo
    case message(LocalizedStringKey)
    case valueInUse(InventoryManagedItemsSelection)

    var id: String {
        switch self {
        case let .delete(id, _):
            "delete-\(id.uuidString)"
        case .undo:
            "undo"
        case let .message(key):
            "message-\(String(describing: key))"
        case let .valueInUse(selection):
            "value-in-use-\(selection.id)"
        }
    }
}

private struct TopLevelPlaceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let locations: [StorageLocation]
    let save: (String, String, StorageLocation) -> Void

    @State private var name = ""
    @State private var iconID = PlaceIconCatalog.defaultIconID
    @State private var locationID: UUID

    init(
        locations: [StorageLocation],
        save: @escaping (String, String, StorageLocation) -> Void
    ) {
        self.locations = locations
        self.save = save
        _locationID = State(initialValue: locations.first?.id ?? UUID())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("inventory.places.location", selection: $locationID) {
                        ForEach(locations) { location in
                            Text(verbatim: location.name)
                                .tag(location.id)
                        }
                    }
                    .accessibilityHint("inventory.places.location.help")
                    .accessibilityIdentifier("settings.places.locationPicker")
                }

                Section {
                    TextField("inventory.places.name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("settings.places.nameField")
                    Picker("inventory.selection.place.icon", selection: $iconID) {
                        ForEach(PlaceIconCatalog.options) { option in
                            Label(option.localizedName, systemImage: option.symbolName)
                                .tag(option.id)
                        }
                    }
                    .tint(InventoryDesign.ContentRole.place.color)
                    .accessibilityHint("inventory.places.icon.help")
                    .accessibilityIdentifier("settings.places.iconPicker")
                }
                .inventoryFormRowSurface()
            }
            .inventoryFormPresentation(contentRole: .place)
            .navigationTitle("inventory.places.add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("inventory.action.save") {
                        guard let location = locations.first(where: {
                            $0.id == locationID
                        }) else { return }
                        save(name, iconID, location)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .inventoryPrimaryActionTint()
                    .accessibilityIdentifier("settings.places.saveButton")
                }
            }
        }
    }
}
