import os
import SwiftData
import SwiftUI

struct PlaceManagementView: View {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HomeStuffInventoryApp", category: "PlaceManagement")

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]

    @State private var sheet: PlaceSheet?
    @State private var dialog: PlaceManagementDialog?
    @State private var itemsSelection: InventoryManagedItemsSelection?

    private var sections: [InventoryPlaceDirectorySection] {
        InventoryPlaceDirectorySection.make(locations: locations, places: places)
    }

    var body: some View {
        List {
            if sections.isEmpty {
                emptyState
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.places) { place in
                            placeRow(place, in: section.location)
                        }
                    } header: {
                        Text(verbatim: section.location.name)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("settings.places.locationHeader.\(section.location.id.uuidString)")
                    }
                    .inventoryFormRowSurface()
                }
            }
        }
        .inventoryFormPresentation()
        .inventoryScrollContentClearance()
        .navigationTitle("inventory.places.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { presentAdd() } label: { Label("inventory.places.add", systemImage: "plus") }
                    .disabled(locations.isEmpty)
                    .accessibilityIdentifier("settings.places.addButton")
                    .inventoryPrimaryActionTint()
            }
        }
        .sheet(item: $sheet) { sheet in
            PlaceEditorView(sheet: sheet, locations: locations) { name, iconID, location in save(sheet, name: name, iconID: iconID, location: location) }
        }
        .alert(item: $dialog) { dialog in
            switch dialog {
            case let .delete(request):
                Alert(
                    title: Text("inventory.places.delete.title"),
                    message: Text(String(format: String(localized: "inventory.places.delete.message", defaultValue: "Delete %@ from reusable Storage Places?"), request.place.name)),
                    primaryButton: .destructive(Text("inventory.action.delete")) { delete(request) },
                    secondaryButton: .cancel()
                )
            case let .message(alert):
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("inventory.action.ok")))
            case let .valueInUse(alert, selection):
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("inventory.lists.viewItems")) {
                        self.dialog = nil
                        itemsSelection = selection
                    },
                    secondaryButton: .cancel(Text("inventory.action.ok"))
                )
            }
        }
        .navigationDestination(item: $itemsSelection) { selection in
            ScopedInventoryItemsListView(title: selection.title, items: InventoryListManagement.items(in: items, matching: selection), emptyTitleKey: "inventory.lists.items.empty.title", emptyTitleDefaultValue: "No Items", emptyMessageKey: "inventory.lists.items.empty.message", emptyMessageDefaultValue: "Items that use this value appear here.", emptySystemImage: selection.emptySystemImage)
        }
    }

    @ViewBuilder private var emptyState: some View {
        if locations.isEmpty {
            InventoryInlineEmptyState(title: String(localized: "inventory.places.empty.noLocations.title", defaultValue: "Add a Location first"), systemImage: "shippingbox")
            Text("inventory.places.empty.noLocations.message")
                .foregroundStyle(.secondary)
            NavigationLink { InventoryListManagementView(scope: .locations) } label: {
                InventoryAddNewRow("inventory.lists.addLocation")
            }
            .accessibilityIdentifier("settings.places.addLocationButton")
            .inventoryPrimaryActionTint()
        } else {
            InventoryInlineEmptyState(title: String(localized: "inventory.places.empty.title", defaultValue: "No Storage Places yet"), systemImage: "shippingbox")
            Text("inventory.places.empty.message")
                .foregroundStyle(.secondary)
            Button { presentAdd() } label: { InventoryAddNewRow("inventory.places.add") }
                .accessibilityIdentifier("settings.places.emptyAddButton")
                .inventoryPrimaryActionTint()
        }
    }

    private func placeRow(_ place: InventoryPlace, in location: StorageLocation) -> some View {
        let count = InventoryListManagement.usageCount(for: place, in: location, items: items)
        return InventoryManagedValueRow(title: place.name, systemImage: PlaceIconCatalog.symbolName(for: place.iconID), iconRole: .place, itemCount: count, isEditable: true, viewItemsAccessibilityLabel: count == 0 ? nil : String(format: String(localized: "inventory.places.viewItems.accessibilityLabel", defaultValue: "View items in %@ at %@, %@"), place.name, location.name, InventoryLocalization.itemCount(count)), viewItemsAction: count == 0 ? nil : { itemsSelection = try? InventoryListManagement.selection(for: place, in: location) }, editActionLabel: String(localized: "inventory.action.edit", defaultValue: "Edit"), editAction: { sheet = .edit(place, location) }, deleteAction: { dialog = .delete(PlaceRequest(place: place, location: location)) })
    }

    private func presentAdd() {
        sheet = .add
    }

    private func save(_ sheet: PlaceSheet, name: String, iconID: String, location: StorageLocation) {
        do {
            let operation: InventoryListManagementPersistenceOperation
            switch sheet {
            case .add: operation = .addPlace(name: name, iconID: iconID, location: location)
            case let .edit(place, location): operation = .renamePlace(place, name: name, iconID: iconID, location: location)
            }
            try InventoryListManagementPersistence.save(operation, locations: locations, places: places, customCategories: [], items: items, in: modelContext)
            self.sheet = nil
        } catch let error as InventoryListManagementError { dialog = .message(.error(error)) }
        catch { showSaveFailure(error) }
    }

    private func delete(_ request: PlaceRequest) {
        do {
            try InventoryListManagementPersistence.delete(request.place, in: request.location, items: items, in: modelContext)
            dialog = nil
        } catch let error as InventoryListManagementError {
            if case .valueInUse = error {
                guard let selection = try? InventoryListManagement.selection(for: request.place, in: request.location) else {
                    dialog = .message(.error(error))
                    return
                }
                dialog = .valueInUse(.error(error), selection)
            } else { dialog = .message(.error(error)) }
        } catch { showSaveFailure(error) }
    }

    private func showSaveFailure(_ error: Error) {
        Self.logger.error("Place management save failed: \(error.localizedDescription, privacy: .private)")
        dialog = .message(InventoryListManagementPersistenceFailure.save.alert)
    }
}

private struct PlaceRequest: Identifiable {
    let place: InventoryPlace
    let location: StorageLocation
    var id: String { "\(location.id.uuidString)-\(place.id.uuidString)" }
}

private enum PlaceManagementDialog: Identifiable {
    case delete(PlaceRequest)
    case message(InventoryListManagementAlert)
    case valueInUse(InventoryListManagementAlert, InventoryManagedItemsSelection)

    var id: String {
        switch self {
        case let .delete(request):
            "delete-\(request.id)"
        case let .message(alert):
            "message-\(alert.id.uuidString)"
        case let .valueInUse(alert, selection):
            "value-in-use-\(alert.id.uuidString)-\(selection.id)"
        }
    }
}

private enum PlaceSheet: Identifiable {
    case add
    case edit(InventoryPlace, StorageLocation)
    var id: String { switch self { case .add: "add"; case let .edit(place, _): "edit-\(place.id.uuidString)" } }
    var location: StorageLocation? { switch self { case .add: nil; case let .edit(_, location): location } }
    var place: InventoryPlace? { if case let .edit(place, _) = self { place } else { nil } }
}

private struct PlaceEditorView: View {
    let sheet: PlaceSheet
    let locations: [StorageLocation]
    let save: (String, String, StorageLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconID: String
    @State private var locationID: UUID

    init(sheet: PlaceSheet, locations: [StorageLocation], save: @escaping (String, String, StorageLocation) -> Void) {
        self.sheet = sheet; self.locations = locations; self.save = save
        _name = State(initialValue: sheet.place?.name ?? "")
        _iconID = State(initialValue: PlaceIconCatalog.normalizedIconID(sheet.place?.iconID))
        _locationID = State(initialValue: sheet.place.map { _ in sheet.location!.id } ?? locations.first?.id ?? UUID())
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let location = sheet.location {
                        LabeledContent("inventory.places.location") { Text(verbatim: location.name).foregroundStyle(.secondary) }
                    } else {
                        Picker("inventory.places.location", selection: $locationID) {
                            ForEach(locations) { location in Text(verbatim: location.name).tag(location.id) }
                        }
                        .accessibilityHint("inventory.places.location.help")
                        .accessibilityIdentifier("settings.places.locationPicker")
                    }
                }
                Section {
                    TextField("inventory.places.name", text: $name).textInputAutocapitalization(.words).accessibilityIdentifier("settings.places.nameField")
                    Picker("inventory.selection.place.icon", selection: $iconID) {
                        ForEach(PlaceIconCatalog.options) { option in Label(option.localizedName, systemImage: option.symbolName).tag(option.id) }
                    }
                    .tint(InventoryDesign.ContentRole.place.color)
                    .accessibilityHint("inventory.places.icon.help")
                    .accessibilityIdentifier("settings.places.iconPicker")
                }
                .inventoryFormRowSurface()
            }
            .inventoryFormPresentation(contentRole: .place)
            .navigationTitle(sheet.place == nil ? "inventory.places.add" : "inventory.places.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("inventory.action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("inventory.action.save") { if let location = locations.first(where: { $0.id == locationID }) { save(name, iconID, location) } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).inventoryPrimaryActionTint().accessibilityIdentifier("settings.places.saveButton") }
            }
        }
    }
}
