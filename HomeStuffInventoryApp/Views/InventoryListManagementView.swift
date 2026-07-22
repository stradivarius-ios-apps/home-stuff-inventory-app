import os
import SwiftData
import SwiftUI

struct InventoryListManagementView: View {
    private static let persistenceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "HomeStuffInventoryApp",
        category: "ListManagementPersistence"
    )

    @Environment(\.modelContext) private var modelContext

    let scope: InventoryListManagementScope

    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]
    @Query(sort: \InventoryCustomCategory.name) private var customCategories: [InventoryCustomCategory]

    @State private var sheet: InventoryListManagementSheet?
    @State private var dialog: InventoryListManagementDialog?
    @State private var itemsSelection: InventoryManagedItemsSelection?

    init(scope: InventoryListManagementScope = .all) {
        self.scope = scope
    }

    private var managedCategories: [InventoryManagedCategory] {
        InventoryListManagement.managedCategories(
            customCategories: customCategories,
            items: items,
            vocabulary: .localized
        )
    }

    var body: some View {
        List {
            if scope.includesLocations {
                locationsSection
            }

            if scope.includesCategories {
                categoriesSection
            }
        }
        .inventoryFormPresentation(contentRole: scope.contentRole)
        .inventoryScrollContentClearance()
        .navigationTitle(localized(scope.titleKey, defaultValue: scope.titleDefaultValue))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { sheet in
            InventoryManagedValueEditor(sheet: sheet) { draft in
                save(sheet: sheet, draft: draft)
            }
        }
        .alert(item: $dialog) { dialog in
            switch dialog {
            case let .delete(request):
                Alert(
                    title: Text(localized("inventory.lists.delete.title", defaultValue: "Delete Value?")),
                    message: Text(deleteMessage(for: request)),
                    primaryButton: .destructive(Text(localized("inventory.action.delete", defaultValue: "Delete"))) {
                        confirmDelete(request)
                    },
                    secondaryButton: .cancel()
                )
            case let .message(alert):
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(localized("inventory.action.ok", defaultValue: "OK")))
                )
            case let .valueInUse(alert, selection):
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(localized("inventory.lists.viewItems", defaultValue: "View Items"))) {
                        self.dialog = nil
                        itemsSelection = selection
                    },
                    secondaryButton: .cancel(Text(localized("inventory.action.ok", defaultValue: "OK")))
                )
            }
        }
        .navigationDestination(item: $itemsSelection) { selection in
            managedItemsList(selection)
        }
    }

    private var locationsSection: some View {
        Section {
            if locations.isEmpty {
                InventoryInlineEmptyState(
                    title: localized("inventory.lists.locations.empty", defaultValue: "No reusable locations yet."),
                    systemImage: "map"
                )
            } else {
                ForEach(locations) { location in
                    InventoryManagedValueRow(
                        title: location.name,
                        systemImage: LocationIconCatalog.symbolName(for: location.iconID),
                        iconRole: scope.managedValueIconRole,
                        itemCount: InventoryListManagement.usageCount(forLocationName: location.name, in: items),
                        isEditable: true,
                        viewItemsAccessibilityLabel: viewItemsAccessibilityLabel(
                            for: InventoryListManagement.selection(for: location),
                            itemCount: InventoryListManagement.usageCount(forLocationName: location.name, in: items)
                        ),
                        viewItemsAction: InventoryListManagement.usageCount(forLocationName: location.name, in: items) > 0
                            ? { itemsSelection = InventoryListManagement.selection(for: location) }
                            : nil,
                        editActionLabel: localized("inventory.action.edit", defaultValue: "Edit"),
                        editAction: { sheet = .editLocation(location) },
                        deleteAction: { requestDelete(.location(location)) }
                    )
                }
            }
        } header: {
            Text(localized("inventory.lists.locations", defaultValue: "Locations"))
        } footer: {
            Button {
                sheet = .addLocation
            } label: {
                InventoryAddNewRow(verbatim: localized("inventory.lists.addLocation", defaultValue: "Add Location"))
            }
            .accessibilityIdentifier("inventory.lists.addLocationButton")
            .inventoryPrimaryActionTint()
        }
        .inventoryFormRowSurface()
    }

    private var categoriesSection: some View {
        Section {
            ForEach(managedCategories) { category in
                InventoryManagedValueRow(
                    title: category.displayName,
                    systemImage: "tag",
                    itemCount: category.itemCount,
                    isEditable: category.isEditable,
                    viewItemsAccessibilityLabel: viewItemsAccessibilityLabel(
                        for: InventoryListManagement.selection(for: category),
                        itemCount: category.itemCount
                    ),
                    viewItemsAction: category.itemCount > 0
                        ? { itemsSelection = InventoryListManagement.selection(for: category) }
                        : nil,
                    editActionLabel: localized("inventory.action.rename", defaultValue: "Rename"),
                    editAction: { editCategory(category) },
                    deleteAction: { deleteCategory(category) }
                )
            }
        } header: {
            Text(localized("inventory.lists.categories", defaultValue: "Categories"))
        } footer: {
            Button {
                sheet = .addCategory
            } label: {
                InventoryAddNewRow(verbatim: localized("inventory.lists.addCategory", defaultValue: "Add Category"))
            }
            .accessibilityIdentifier("inventory.lists.addCategoryButton")
            .inventoryPrimaryActionTint()
        }
        .inventoryFormRowSurface()
    }

    private func editCategory(_ category: InventoryManagedCategory) {
        switch category.kind {
        case .defaultCategory:
            dialog = .message(.error(.defaultCategoryProtected))
        case let .custom(customCategory):
            sheet = .editCategory(customCategory)
        }
    }

    private func deleteCategory(_ category: InventoryManagedCategory) {
        switch category.kind {
        case .defaultCategory:
            dialog = .message(.error(.defaultCategoryProtected))
        case let .custom(customCategory):
            requestDelete(.category(customCategory))
        }
    }

    private func save(sheet: InventoryListManagementSheet, draft: InventoryListManagementValueDraft) {
        do {
            try InventoryListManagementPersistence.save(
                persistenceOperation(for: sheet, draft: draft),
                locations: locations,
                places: places,
                customCategories: customCategories,
                items: items,
                in: modelContext
            )
            self.sheet = nil
        } catch let error as InventoryListManagementError {
            dialog = .message(.error(error))
        } catch {
            showPersistenceFailure(.save, underlyingError: error)
        }
    }

    private func persistenceOperation(
        for sheet: InventoryListManagementSheet,
        draft: InventoryListManagementValueDraft
    ) -> InventoryListManagementPersistenceOperation {
        switch sheet {
        case .addLocation:
            return .addLocation(name: draft.value, iconID: draft.iconID)
        case let .editLocation(location):
            return .renameLocation(location, name: draft.value, iconID: draft.iconID)
        case .addCategory:
            return .addCustomCategory(name: draft.value)
        case let .editCategory(category):
            return .renameCustomCategory(category, name: draft.value)
        }
    }

    private func requestDelete(_ request: InventoryListManagementDeleteRequest) {
        do {
            try validateDelete(request)
            dialog = .delete(request)
        } catch let error as InventoryListManagementError {
            showDeleteError(error, for: request)
        } catch {
            showPersistenceFailure(.deleteValidation, underlyingError: error)
        }
    }

    private func confirmDelete(_ request: InventoryListManagementDeleteRequest) {
        do {
            switch request {
            case let .location(location):
                try InventoryListManagementPersistence.delete(location, items: items, places: places, in: modelContext)
            case let .category(category):
                try InventoryListManagementPersistence.delete(category, items: items, in: modelContext)
            }
            dialog = nil
        } catch let error as InventoryListManagementError {
            showDeleteError(error, for: request)
        } catch {
            showPersistenceFailure(.delete, underlyingError: error)
        }
    }

    private func validateDelete(_ request: InventoryListManagementDeleteRequest) throws {
        switch request {
        case let .location(location):
            try InventoryListManagement.deleteLocation(location, items: items, places: places)
        case let .category(category):
            try InventoryListManagement.deleteCustomCategory(category, items: items)
        }
    }

    private func deleteMessage(for request: InventoryListManagementDeleteRequest) -> String {
        switch request {
        case let .location(location):
            return String(
                format: localized("inventory.lists.delete.locationMessage", defaultValue: "This removes %@ from reusable locations."),
                location.name
            )
        case let .category(category):
            return String(
                format: localized("inventory.lists.delete.categoryMessage", defaultValue: "This removes %@ from custom categories."),
                category.name
            )
        }
    }

    private func showDeleteError(_ error: InventoryListManagementError, for request: InventoryListManagementDeleteRequest) {
        let alert = InventoryListManagementAlert.error(error)

        if case .valueInUse = error {
            let selection: InventoryManagedItemsSelection

            switch request {
            case let .location(location):
                selection = InventoryListManagement.selection(for: location)
            case let .category(category):
                selection = InventoryListManagement.selection(for: category)
            }

            dialog = .valueInUse(alert, selection)
        } else {
            dialog = .message(alert)
        }
    }

    private func showPersistenceFailure(
        _ failure: InventoryListManagementPersistenceFailure,
        underlyingError: any Error
    ) {
        Self.persistenceLogger.error(
            "List management \(failure.logOperation, privacy: .public) failed: \(underlyingError.localizedDescription, privacy: .private)"
        )
        dialog = .message(failure.alert)
    }

    private func managedItemsList(_ selection: InventoryManagedItemsSelection) -> some View {
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

    private func viewItemsAccessibilityLabel(
        for selection: InventoryManagedItemsSelection,
        itemCount: Int
    ) -> String? {
        guard itemCount > 0 else {
            return nil
        }

        let key: StaticString
        let defaultValue: String

        switch selection {
        case .location:
            key = "inventory.lists.viewItems.location.accessibilityLabel"
            defaultValue = "View items in %@, %@"
        case .place:
            key = "inventory.lists.viewItems.location.accessibilityLabel"
            defaultValue = "View items in %@, %@"
        case .category:
            key = "inventory.lists.viewItems.category.accessibilityLabel"
            defaultValue = "View items in category %@, %@"
        }

        return String(format: localized(key, defaultValue: defaultValue), selection.title, InventoryLocalization.itemCount(itemCount))
    }

    private func localized(_ key: StaticString, defaultValue: String) -> String {
        InventoryLocalization.string(key, defaultValue: defaultValue)
    }
}

enum InventoryListManagementScope {
    case all
    case locations
    case categories

    var includesLocations: Bool {
        switch self {
        case .all, .locations:
            return true
        case .categories:
            return false
        }
    }

    var includesCategories: Bool {
        switch self {
        case .all, .categories:
            return true
        case .locations:
            return false
        }
    }

    /// Only the dedicated Locations management flow carries Location identity semantics.
    var contentRole: InventoryDesign.ContentRole? {
        switch self {
        case .locations:
            .location
        case .all, .categories:
            nil
        }
    }

    var managedValueIconRole: InventoryDesign.AccentRole {
        contentRole?.accentRole ?? .secondary
    }

    var titleKey: StaticString {
        switch self {
        case .all:
            return "inventory.lists.title"
        case .locations:
            return "inventory.lists.locations.title"
        case .categories:
            return "inventory.lists.categories.title"
        }
    }

    var titleDefaultValue: String {
        switch self {
        case .all:
            return "Manage Lists"
        case .locations:
            return "Manage Locations"
        case .categories:
            return "Manage Categories"
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        InventoryListManagementView()
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
}
#endif
