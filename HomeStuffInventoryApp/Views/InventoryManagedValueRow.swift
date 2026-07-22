import SwiftUI

struct InventoryManagedValueRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let systemImage: String?
    let iconRole: InventoryDesign.AccentRole
    let itemCount: Int
    let isEditable: Bool
    let viewItemsAccessibilityLabel: String?
    let viewItemsAction: (() -> Void)?
    let editActionLabel: String
    let actionsAccessibilityIdentifier: String
    let editAction: () -> Void
    let deleteAction: () -> Void

    init(
        title: String,
        systemImage: String?,
        iconRole: InventoryDesign.AccentRole = .secondary,
        itemCount: Int,
        isEditable: Bool,
        viewItemsAccessibilityLabel: String?,
        viewItemsAction: (() -> Void)?,
        editActionLabel: String,
        actionsAccessibilityIdentifier: String = "inventory" + ".lists.valueActions",
        editAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.iconRole = iconRole
        self.itemCount = itemCount
        self.isEditable = isEditable
        self.viewItemsAccessibilityLabel = viewItemsAccessibilityLabel
        self.viewItemsAction = viewItemsAction
        self.editActionLabel = editActionLabel
        self.actionsAccessibilityIdentifier = actionsAccessibilityIdentifier
        self.editAction = editAction
        self.deleteAction = deleteAction
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityRow
            } else {
                standardRow
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventory.lists.valueRow.\(title)")
    }

    private var standardRow: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingIcon
            identityColumn
            trailingActions
        }
    }

    private var accessibilityRow: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
            HStack(alignment: .top, spacing: 12) {
                leadingIcon
                identityColumn
            }

            trailingActions
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let systemImage {
            InventoryContentGlyph(systemName: systemImage, role: iconRole, presentation: .identity)
        }
    }

    private var identityColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleText
            InventoryRowCountBadge(itemCountText, role: .muted)
                .accessibilityIdentifier("inventory.lists.itemCount")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
    }

    private var titleText: some View {
        Text(verbatim: title)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityIdentifier("inventory.lists.valueTitle")
    }

    private var trailingActions: some View {
        HStack(spacing: 8) {
            viewItemsButton
            accessory
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var viewItemsButton: some View {
        if let viewItemsAccessibilityLabel, let viewItemsAction {
            Button(action: viewItemsAction) {
                Image(systemName: "tray.full")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(verbatim: viewItemsAccessibilityLabel))
            .accessibilityIdentifier("inventory.lists.viewItems")
        }
    }

    @ViewBuilder
    private var accessory: some View {
        if isEditable {
            InventoryRowOverflowMenu(
                accessibilityLabel: localized("inventory.lists.actions", defaultValue: "List value actions"),
                accessibilityIdentifier: actionsAccessibilityIdentifier
            ) {
                Button {
                    editAction()
                } label: {
                    Label(editActionLabel, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    Label(localized("inventory.action.delete", defaultValue: "Delete"), systemImage: "trash")
                }
            }
        } else {
            InventoryRowDefaultBadge(verbatim: localized("inventory.lists.defaultBadge", defaultValue: "Default"))
                .accessibilityIdentifier("inventory.lists.defaultStatus")
        }
    }

    private var itemCountText: String {
        InventoryLocalization.itemCount(itemCount)
    }

    private func localized(_ key: StaticString, defaultValue: String) -> String {
        InventoryLocalization.string(key, defaultValue: defaultValue)
    }
}

#if DEBUG
#Preview("Managed Values – Standard") {
    InventoryManagedValueRowPreview()
}

#Preview("Managed Values – Dark") {
    InventoryManagedValueRowPreview()
        .preferredColorScheme(.dark)
}

#Preview("Managed Values – Accessibility") {
    InventoryManagedValueRowPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct InventoryManagedValueRowPreview: View {
    var body: some View {
        List {
            Section("Locations") {
                row(title: "Hall", count: 0, editable: true)
                row(title: "Living room", count: 3, editable: true)
                row(title: "Storage room", count: 6, editable: true)
                row(title: "Long English location title for the cabinet beside the entryway", count: 1, editable: true)
                row(title: "Дуже довга українська назва місця для шафи біля входу", count: 6, editable: true)
            }

            Section("Categories") {
                row(title: "Tools", count: 0, editable: false)
                row(title: "Cables & Adapters", count: 1, editable: false)
                row(title: "Custom category", count: 3, editable: true)
                row(title: "Long English household category name", count: 6, editable: true)
                row(title: "Дуже довга українська назва категорії", count: 6, editable: true)
            }
        }
        .inventoryFormPresentation()
    }

    private func row(title: String, count: Int, editable: Bool) -> InventoryManagedValueRow {
        InventoryManagedValueRow(
            title: title,
            systemImage: "tag",
            itemCount: count,
            isEditable: editable,
            viewItemsAccessibilityLabel: count > 0 ? "View items in \(title), \(InventoryLocalization.itemCount(count))" : nil,
            viewItemsAction: count > 0 ? {} : nil,
            editActionLabel: "Edit",
            editAction: {},
            deleteAction: {}
        )
    }
}
#endif
