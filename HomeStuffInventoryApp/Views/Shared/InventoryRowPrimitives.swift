import SwiftUI

struct InventorySectionHeader: View {
    private let title: Text
    private let subtitle: Text?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
    }

    init(verbatim title: String, subtitle: String? = nil) {
        self.title = Text(verbatim: title)
        self.subtitle = subtitle.map { Text(verbatim: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct InventoryListRowCard<Content: View>: View {
    private let surface: InventoryCardSurface
    private let semanticRole: InventoryDesign.SurfaceRole?
    private let minHeight: CGFloat?
    private let content: Content

    init(
        surface: InventoryCardSurface = .interactive,
        semanticRole: InventoryDesign.SurfaceRole? = nil,
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.surface = surface
        self.semanticRole = semanticRole
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        Group {
            if let semanticRole {
                content
                    .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .leading)
                    .padding(InventoryDesign.compactCardPadding)
                    .inventorySemanticSurface(
                        semanticRole,
                        cornerRadius: InventoryDesign.compactCornerRadius
                    )
            } else {
                InventoryCard(
                    surface: surface,
                    padding: InventoryDesign.compactCardPadding,
                    cornerRadius: InventoryDesign.compactCornerRadius,
                    minHeight: minHeight
                ) {
                    content
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: InventoryDesign.compactCornerRadius, style: .continuous))
    }

    private var contentMinHeight: CGFloat? {
        minHeight.map { max(0, $0 - InventoryDesign.compactCardPadding * 2) }
    }
}

struct InventoryRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            .fixedSize()
    }
}

struct InventoryRowCheckmark: View {
    private let accessibilityLabel: LocalizedStringKey

    init(accessibilityLabel: LocalizedStringKey = "inventory.selection.selected") {
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Image(systemName: "checkmark")
            .font(.body.weight(.semibold))
            .foregroundStyle(.tint)
            .accessibilityLabel(accessibilityLabel)
            .fixedSize()
    }
}

struct InventorySelectionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: Text
    private let systemImage: String?
    private let iconRole: InventoryDesign.AccentRole
    private let isSelected: Bool
    private let accessibilityLabel: Text?

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        iconRole: InventoryDesign.AccentRole = .secondary,
        isSelected: Bool,
        accessibilityLabel: Text? = nil
    ) {
        self.init(
            title: Text(title),
            systemImage: systemImage,
            iconRole: iconRole,
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel
        )
    }

    init(
        verbatim title: String,
        systemImage: String? = nil,
        iconRole: InventoryDesign.AccentRole = .secondary,
        isSelected: Bool,
        accessibilityLabel: Text? = nil
    ) {
        self.init(
            title: Text(verbatim: title),
            systemImage: systemImage,
            iconRole: iconRole,
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel
        )
    }

    init(
        title: Text,
        systemImage: String? = nil,
        iconRole: InventoryDesign.AccentRole = .secondary,
        isSelected: Bool,
        accessibilityLabel: Text? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.iconRole = iconRole
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                InventoryContentGlyph(systemName: systemImage, role: iconRole)
            }

            title
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            if isSelected {
                InventoryRowCheckmark()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .optionalAccessibilityLabel(accessibilityLabel)
    }
}

struct InventoryPickerIconRow: View {
    private let title: Text
    private let systemImage: String
    private let iconRole: InventoryDesign.AccentRole
    private let isSelected: Bool
    private let accessibilityLabel: Text?

    init(
        title: String,
        systemImage: String,
        iconRole: InventoryDesign.AccentRole = .secondary,
        isSelected: Bool,
        accessibilityLabel: Text? = nil
    ) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
        self.iconRole = iconRole
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
    }

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        iconRole: InventoryDesign.AccentRole = .secondary,
        isSelected: Bool,
        accessibilityLabel: Text? = nil
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.iconRole = iconRole
        self.isSelected = isSelected
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        InventorySelectionRow(
            title: title,
            systemImage: systemImage,
            iconRole: iconRole,
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel
        )
    }
}

struct InventoryAddNewRow: View {
    private let title: Text

    init(_ title: LocalizedStringKey) {
        self.title = Text(title)
    }

    init(verbatim title: String) {
        self.title = Text(verbatim: title)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.body.weight(.semibold))
                .imageScale(.large)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            title
                .foregroundStyle(.tint)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct InventorySettingsNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: LocalizedStringKey
    private let systemImage: String
    private let iconRole: InventoryDesign.AccentRole

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        iconRole: InventoryDesign.AccentRole = .secondary
    ) {
        self.title = title
        self.systemImage = systemImage
        self.iconRole = iconRole
    }

    var body: some View {
        HStack(spacing: 12) {
            InventoryContentGlyph(systemName: systemImage, role: iconRole)

            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct InventoryRowOverflowMenu<MenuContent: View>: View {
    private let accessibilityLabel: Text
    private let accessibilityIdentifier: String?
    private let menuContent: MenuContent

    init(
        accessibilityLabel: LocalizedStringKey,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> MenuContent
    ) {
        self.accessibilityLabel = Text(accessibilityLabel)
        self.accessibilityIdentifier = accessibilityIdentifier
        self.menuContent = content()
    }

    init(
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> MenuContent
    ) {
        self.accessibilityLabel = Text(verbatim: accessibilityLabel)
        self.accessibilityIdentifier = accessibilityIdentifier
        self.menuContent = content()
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body.weight(.semibold))
                .imageScale(.large)
                .frame(
                    minWidth: InventoryDesign.minimumTapTarget,
                    minHeight: InventoryDesign.minimumTapTarget
                )
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
    }
}

extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalAccessibilityLabel(_ label: Text?) -> some View {
        if let label {
            accessibilityLabel(label)
        } else {
            self
        }
    }
}
