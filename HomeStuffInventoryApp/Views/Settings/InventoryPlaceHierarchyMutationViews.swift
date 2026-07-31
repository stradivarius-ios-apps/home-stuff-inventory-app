import SwiftData
import SwiftUI

struct InventoryPlaceHierarchyDirectoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \InventoryPlaceMutationRecord.occurredAt, order: .reverse)
    private var mutationRecords: [InventoryPlaceMutationRecord]

    let onAddTopLevel: () -> Void
    let onViewItems: (UUID) -> Void
    let onCreateChild: (UUID) -> Void
    let onEdit: (UUID) -> Void
    let onRestructure: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onUndoRequested: () -> Void

    private var sections: [InventoryPlaceHierarchyManagement.DirectorySection] {
        InventoryPlaceHierarchyManagement.sections(
            locations: locations,
            places: places,
            items: items
        )
    }

    var body: some View {
        List {
            if sections.isEmpty {
                emptyState
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            placeRow(row)
                        }
                    } header: {
                        Text(verbatim: section.location.name)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier(
                                "settings.places.locationHeader.\(section.location.id.uuidString)"
                            )
                    }
                    .inventoryFormRowSurface()
                }
            }

            if !mutationRecords.isEmpty {
                hierarchyHistory
            }
        }
        .inventoryFormPresentation()
        .inventoryScrollContentClearance()
        .navigationTitle("inventory.places.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddTopLevel) {
                    Label("inventory.places.add", systemImage: "plus")
                }
                .disabled(locations.isEmpty)
                .accessibilityIdentifier("settings.places.addButton")
                .inventoryPrimaryActionTint()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if locations.isEmpty {
            InventoryInlineEmptyState(
                title: InventoryLocalization.string(
                    "inventory.places.empty.noLocations.title",
                    defaultValue: "Add a Location first"
                ),
                systemImage: "shippingbox"
            )
            Text("inventory.places.empty.noLocations.message")
                .foregroundStyle(.secondary)
            NavigationLink {
                InventoryListManagementView(scope: .locations)
            } label: {
                InventoryAddNewRow("inventory.lists.addLocation")
            }
            .accessibilityIdentifier("settings.places.addLocationButton")
            .inventoryPrimaryActionTint()
        } else {
            InventoryInlineEmptyState(
                title: InventoryLocalization.string(
                    "inventory.places.empty.title",
                    defaultValue: "No Storage Places yet"
                ),
                systemImage: "shippingbox"
            )
            Text("inventory.places.empty.message")
                .foregroundStyle(.secondary)
            Button(action: onAddTopLevel) {
                InventoryAddNewRow("inventory.places.add")
            }
            .accessibilityIdentifier("settings.places.emptyAddButton")
            .inventoryPrimaryActionTint()
        }
    }

    private func placeRow(
        _ row: InventoryPlaceHierarchyManagement.Row
    ) -> some View {
        let isEditable = InventoryPlaceHierarchyManagement.canDirectlyEdit(
            row,
            entitlements: premiumAccess.entitlements
        )
        return HStack(alignment: .top, spacing: 12) {
            Color.clear
                .frame(width: CGFloat(row.depth) * 16)
                .accessibilityHidden(true)

            InventoryContentGlyph(
                systemName: PlaceIconCatalog.symbolName(for: row.iconID),
                role: .place,
                presentation: .identity
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: row.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("inventory.lists.valueTitle")
                if row.depth > 0 {
                    Text(verbatim: row.pathText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    InventoryRowCountBadge(
                        InventoryLocalization.itemCount(row.containedItemCount),
                        role: .muted
                    )
                    if !isEditable {
                        Label(
                            "inventory.places.hierarchy.readOnly",
                            systemImage: "lock"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "settings.places.hierarchy.readOnly.\(row.placeID.uuidString)"
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.directItemCount > 0 {
                Button {
                    onViewItems(row.placeID)
                } label: {
                    Image(systemName: "tray.full")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(
                    Text(
                        InventoryLocalization.formatted(
                            "inventory.places.viewItems.accessibilityLabel",
                            defaultValue: "View items in %@ at %@, %@",
                            row.name,
                            locations.first(where: { $0.id == row.locationID })?.name ?? "",
                            InventoryLocalization.itemCount(row.directItemCount)
                        )
                    )
                )
                .accessibilityIdentifier("inventory.lists.viewItems")
            }

            Group {
                Menu {
                    Button {
                        onCreateChild(row.placeID)
                    } label: {
                        Label(
                            "inventory.places.hierarchy.addChild.action",
                            systemImage: "rectangle.stack.badge.plus"
                        )
                    }
                    .disabled(!row.hasCompletePath)

                    Button {
                        onRestructure(row.placeID)
                    } label: {
                        Label(
                            "inventory.places.hierarchy.restructure.action",
                            systemImage: "arrow.triangle.branch"
                        )
                    }
                    .disabled(!row.hasCompletePath)

                    if isEditable {
                        Button {
                            onEdit(row.placeID)
                        } label: {
                            Label("inventory.action.edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(row.placeID)
                        } label: {
                            Label("inventory.action.delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(
                    Text(
                        InventoryLocalization.formatted(
                            "inventory.places.hierarchy.actions.accessibilityLabel",
                            defaultValue: "Actions for %@",
                            row.pathText
                        )
                    )
                )
                .accessibilityIdentifier("inventory.lists.valueActions")
            }
            .accessibilityIdentifier(
                "settings.places.hierarchy.actions.\(row.placeID.uuidString)"
            )
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "settings.places.hierarchy.row.\(row.placeID.uuidString)"
        )
    }

    private var hierarchyHistory: some View {
        Section {
            ForEach(mutationRecords.prefix(10)) { record in
                let summary = historySummary(record)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: summary.title)
                    Text(verbatim: summary.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    "settings.places.hierarchy.history.\(record.id.uuidString)"
                )
            }

            if canOfferUndo {
                Button(action: onUndoRequested) {
                    Label(
                        "inventory.places.hierarchy.undoLatest",
                        systemImage: "arrow.uturn.backward"
                    )
                }
                .accessibilityHint("inventory.places.hierarchy.undoLatest.help")
                .accessibilityIdentifier("settings.places.hierarchy.undoLatest")
            }
        } header: {
            Text("inventory.places.hierarchy.history.title")
        } footer: {
            Text("inventory.places.hierarchy.history.help")
        }
        .inventoryFormRowSurface()
    }

    private var canOfferUndo: Bool {
        switch InventoryPlaceMutationPersistence.undoLatestAvailability(
            entitlements: premiumAccess.entitlements,
            in: modelContext
        ) {
        case .available, .accessRequired:
            true
        case .unavailable, .currentStateChanged, .unsafeRestoration:
            false
        }
    }

    private func historySummary(
        _ record: InventoryPlaceMutationRecord
    ) -> (title: String, detail: String) {
        let before = record.beforeSnapshot
        let after = record.afterSnapshot
        let rootID = after?.rootPlaceID ?? before?.rootPlaceID
        let rootName = after?.places.first(where: { $0.id == rootID })?.name
            ?? before?.places.first(where: { $0.id == rootID })?.name
            ?? InventoryLocalization.string(
                "inventory.places.hierarchy.history.unknownPlace",
                defaultValue: "Storage Place"
            )
        let placeCount = after?.places.count ?? before?.places.count ?? 0
        let itemCount = after?.items.count ?? before?.items.count ?? 0
        let status = record.undoneAt == nil
            ? InventoryLocalization.string(
                "inventory.places.hierarchy.history.applied",
                defaultValue: "Applied"
            )
            : InventoryLocalization.string(
                "inventory.places.hierarchy.history.undone",
                defaultValue: "Undone"
            )
        return (
            rootName,
            [
                status,
                InventoryLocalization.placeCount(placeCount),
                InventoryLocalization.itemCount(itemCount),
                record.occurredAt.formatted(date: .abbreviated, time: .shortened)
            ].joined(separator: " · ")
        )
    }
}

struct InventoryPlaceHierarchyEditorView: View {
    enum Mode {
        case createChild(parentID: UUID)
        case edit(placeID: UUID)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    let mode: Mode

    @State private var name: String
    @State private var iconID: String
    @State private var error: InventoryPlaceMutationError?

    init(mode: Mode, initialName: String = "", initialIconID: String? = nil) {
        self.mode = mode
        _name = State(initialValue: initialName)
        _iconID = State(initialValue: PlaceIconCatalog.normalizedIconID(initialIconID))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let contextPath {
                    Section("inventory.places.hierarchy.context.section") {
                        LabeledContent("inventory.places.hierarchy.context.path") {
                            Text(verbatim: contextPath)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .inventoryFormRowSurface()
                }

                Section {
                    TextField("inventory.places.name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("settings.places.hierarchy.nameField")
                    Picker("inventory.selection.place.icon", selection: $iconID) {
                        ForEach(PlaceIconCatalog.options) { option in
                            Label(option.localizedName, systemImage: option.symbolName)
                                .tag(option.id)
                        }
                    }
                    .tint(InventoryDesign.ContentRole.place.color)
                    .accessibilityHint("inventory.places.icon.help")
                    .accessibilityIdentifier("settings.places.hierarchy.iconPicker")
                }
                .inventoryFormRowSurface()
            }
            .inventoryFormPresentation(contentRole: .place)
            .navigationTitle(
                isCreatingChild
                    ? "inventory.places.hierarchy.addChild.title"
                    : "inventory.places.edit"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.action.cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.places.hierarchy.editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("inventory.action.save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .inventoryPrimaryActionTint()
                    .accessibilityIdentifier("settings.places.hierarchy.editor.save")
                }
            }
            .alert(
                "inventory.places.hierarchy.error.title",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { _ in
                Button("inventory.action.ok", role: .cancel) {
                    error = nil
                }
            } message: { error in
                Text(errorMessage(error))
            }
        }
    }

    private var isCreatingChild: Bool {
        if case .createChild = mode { true } else { false }
    }

    private var contextPath: String? {
        let placeID: UUID
        switch mode {
        case let .createChild(parentID):
            placeID = parentID
        case let .edit(editedPlaceID):
            placeID = editedPlaceID
        }
        guard let place = places.first(where: { $0.id == placeID }) else {
            return nil
        }
        return InventoryPlaceHierarchy.path(for: place, places: places).displayName
    }

    private func save() {
        do {
            switch mode {
            case let .createChild(parentID):
                guard let parent = places.first(where: { $0.id == parentID }) else {
                    throw InventoryPlaceMutationError.missingPlace
                }
                _ = try InventoryPlaceMutationPersistence.createChild(
                    named: name,
                    iconID: iconID,
                    under: .init(place: parent),
                    entitlements: premiumAccess.entitlements,
                    in: modelContext
                )
            case let .edit(placeID):
                guard let place = places.first(where: { $0.id == placeID }) else {
                    throw InventoryPlaceMutationError.missingPlace
                }
                try InventoryPlaceMutationPersistence.rename(
                    .init(place: place),
                    to: name,
                    iconID: iconID,
                    entitlements: premiumAccess.entitlements,
                    in: modelContext
                )
            }
            dismiss()
        } catch let mutationError as InventoryPlaceMutationError {
            error = mutationError
        } catch {
            self.error = .persistenceFailed
        }
    }
}

struct InventoryPlaceHierarchyMoveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumAccessState.self) private var premiumAccess
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]
    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]

    let sourcePlaceID: UUID

    @State private var destinationID: InventoryPlaceHierarchyManagement.Destination.ID?
    @State private var preflight: InventoryPlaceHierarchyManagement.MovePreflight?
    @State private var error: InventoryPlaceMutationError?

    private var destinations: [InventoryPlaceHierarchyManagement.Destination] {
        InventoryPlaceHierarchyManagement.destinations(
            for: sourcePlaceID,
            locations: locations,
            places: places
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let preflight {
                    review(preflight)
                } else {
                    destinationSelection
                }
            }
            .inventoryFormPresentation(contentRole: .place)
            .navigationTitle("inventory.places.hierarchy.move.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.action.cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("settings.places.hierarchy.move.cancel")
                }
                if preflight != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("inventory.places.hierarchy.move.changeDestination") {
                            preflight = nil
                        }
                        .accessibilityIdentifier("settings.places.hierarchy.move.changeDestination")
                    }
                }
            }
            .alert(
                "inventory.places.hierarchy.error.title",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { _ in
                Button("inventory.action.ok", role: .cancel) {
                    error = nil
                }
            } message: { error in
                Text(errorMessage(error))
            }
        }
    }

    private var destinationSelection: some View {
        Section {
            ForEach(destinations) { destination in
                Button {
                    destinationID = destination.id
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: destination.displayPath)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if destinationID == destination.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: destination.displayPath))
                .accessibilityValue(
                    destinationID == destination.id
                        ? Text("inventory.selection.selected")
                        : Text("")
                )
                .accessibilityIdentifier(
                    "settings.places.hierarchy.destination.\(destinationIdentifier(destination.id))"
                )
            }

            Button("inventory.places.hierarchy.move.review") {
                prepare()
            }
            .disabled(destinationID == nil)
            .inventoryPrimaryActionTint()
            .accessibilityIdentifier("settings.places.hierarchy.move.review")
        } header: {
            Text("inventory.places.hierarchy.move.destination.section")
        } footer: {
            Text("inventory.places.hierarchy.move.destination.help")
        }
        .inventoryFormRowSurface()
    }

    @ViewBuilder
    private func review(
        _ preflight: InventoryPlaceHierarchyManagement.MovePreflight
    ) -> some View {
        Section("inventory.places.hierarchy.move.review.paths") {
            LabeledContent("inventory.places.hierarchy.move.source") {
                Text(verbatim: preflight.sourcePath)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("inventory.places.hierarchy.move.destination") {
                Text(verbatim: preflight.destinationPath)
                    .multilineTextAlignment(.trailing)
            }
        }
        .inventoryFormRowSurface()

        Section("inventory.places.hierarchy.move.review.contents") {
            LabeledContent(
                "inventory.places.hierarchy.move.placeCount",
                value: InventoryLocalization.placeCount(preflight.movedPlaceCount)
            )
            LabeledContent(
                "inventory.places.hierarchy.move.descendantCount",
                value: InventoryLocalization.placeCount(preflight.descendantPlaceCount)
            )
            LabeledContent(
                "inventory.places.hierarchy.move.itemCount",
                value: InventoryLocalization.itemCount(preflight.containedItemCount)
            )
        }
        .inventoryFormRowSurface()

        Section {
            Button("inventory.places.hierarchy.move.confirm") {
                commit(preflight)
            }
            .inventoryPrimaryActionTint()
            .accessibilityHint("inventory.places.hierarchy.move.confirm.help")
            .accessibilityIdentifier("settings.places.hierarchy.move.confirm")
        } footer: {
            Text("inventory.places.hierarchy.move.atomicity")
        }
        .inventoryFormRowSurface()
    }

    private func prepare() {
        guard let destinationID else { return }
        switch InventoryPlaceHierarchyManagement.prepareMove(
            sourcePlaceID: sourcePlaceID,
            destinationID: destinationID,
            locations: locations,
            places: places,
            items: items
        ) {
        case let .ready(preflight):
            self.preflight = preflight
        case .missingSource:
            error = .missingPlace
        case .incompleteSourcePath, .invalidDestination:
            error = .missingParent
        case .unchanged:
            error = .staleState
        }
    }

    private func commit(
        _ preflight: InventoryPlaceHierarchyManagement.MovePreflight
    ) {
        guard InventoryPlaceHierarchyManagement.isValid(
            preflight,
            locations: locations,
            places: places,
            items: items
        ) else {
            error = .staleState
            self.preflight = nil
            return
        }
        do {
            _ = try InventoryPlaceMutationPersistence.moveSubtree(
                preflight.sourceExpectation,
                toLocationID: preflight.destination.locationID,
                parentPlaceID: preflight.destination.parentPlaceID,
                entitlements: premiumAccess.entitlements,
                in: modelContext,
                contentsExpectation: preflight.contentsExpectation
            )
            dismiss()
        } catch let mutationError as InventoryPlaceMutationError {
            error = mutationError
            self.preflight = nil
        } catch {
            self.error = .persistenceFailed
            self.preflight = nil
        }
    }

    private func destinationIdentifier(
        _ id: InventoryPlaceHierarchyManagement.Destination.ID
    ) -> String {
        switch id {
        case let .location(id):
            "location.\(id.uuidString)"
        case let .place(id):
            "place.\(id.uuidString)"
        }
    }
}

private func errorMessage(_ error: InventoryPlaceMutationError) -> LocalizedStringKey {
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
