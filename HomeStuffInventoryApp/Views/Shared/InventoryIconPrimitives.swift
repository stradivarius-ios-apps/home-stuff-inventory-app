import SwiftUI

enum InventoryContentGlyphPresentation {
    case compact
    case identity
    case locationIdentity
}

struct InventoryContentGlyph: View {
    @ScaledMetric(relativeTo: .title3) private var compactSize = InventoryDesign.contentGlyphSize
    @ScaledMetric(relativeTo: .title2) private var identitySize = InventoryDesign.identityContentGlyphSize
    @ScaledMetric(relativeTo: .title2) private var locationIdentitySize = InventoryDesign.locationDetailIconSize

    private let systemName: String
    private let role: InventoryDesign.AccentRole
    private let accessibilityLabel: Text?
    private let presentation: InventoryContentGlyphPresentation
    private let domain: InventoryGlyph.Domain?
    private let isSelected: Bool

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: LocalizedStringKey? = nil,
        presentation: InventoryContentGlyphPresentation = .compact,
        domain: InventoryGlyph.Domain? = nil,
        isSelected: Bool = false
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text($0) }
        self.presentation = presentation
        self.domain = domain
        self.isSelected = isSelected
    }

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: String?,
        presentation: InventoryContentGlyphPresentation = .compact,
        domain: InventoryGlyph.Domain? = nil,
        isSelected: Bool = false
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text(verbatim: $0) }
        self.presentation = presentation
        self.domain = domain
        self.isSelected = isSelected
    }

    var body: some View {
        InventoryGlyphImage(systemName: systemName, role: role, size: size, identity: presentation != .compact, domain: domain, isSelected: isSelected)
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel ?? Text(verbatim: ""))
            .accessibilityHidden(accessibilityLabel == nil)
    }

    private var size: CGFloat {
        switch presentation {
        case .compact:
            compactSize
        case .identity:
            identitySize
        case .locationIdentity:
            locationIdentitySize
        }
    }
}

struct InventoryStorageIcon: View {
    @ScaledMetric(relativeTo: .title3) private var size = InventoryDesign.storageIconSize

    private let systemName: String
    private let role: InventoryDesign.AccentRole
    private let accessibilityLabel: Text?

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text($0) }
    }

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: String?
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text(verbatim: $0) }
    }

    var body: some View {
        InventoryGlyphImage(systemName: systemName, role: role, size: size * 32 / 44)
            .frame(width: size, height: size)
            .inventoryStorageIconSurface(role: role)
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(accessibilityLabel ?? Text(verbatim: ""))
    }
}

struct InventoryCompactIconBubble: View {
    @ScaledMetric(relativeTo: .subheadline) private var size = InventoryDesign.compactIconSize

    private let systemName: String
    private let role: InventoryDesign.AccentRole
    private let accessibilityLabel: Text?

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = nil
    }

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text($0) }
    }

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: String?
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text(verbatim: $0) }
    }

    var body: some View {
        InventoryGlyphImage(systemName: systemName, role: role, size: size * 24 / 34)
            .frame(width: size, height: size)
            .inventoryStorageIconSurface(role: role)
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(accessibilityLabel ?? Text(verbatim: ""))
    }
}

struct InventoryGlyphImage: View {
    let systemName: String
    let role: InventoryDesign.AccentRole
    let size: CGFloat
    var identity = false
    var domain: InventoryGlyph.Domain? = nil
    var isSelected = false

    var body: some View {
        Group {
            if systemName == InventoryPlaceIconPresentation.missingPlaceSymbolName || systemName == "list.bullet" {
                Image(systemName: systemName)
                    .font(.system(size: size * 20 / 24, weight: .medium))
                    .foregroundStyle(role.color)
                    .accessibilityHidden(true)
            } else {
                InventoryGlyphArtwork(
                    glyph: InventoryGlyph.content(systemName: systemName, domain: domain ?? .init(accentRole: role)),
                    variant: .resolve(identity: identity, isSelected: isSelected),
                    tint: role.color
                )
            }
        }
        .frame(width: size, height: size)
    }
}

struct InventoryInlineGlyph: View {
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 14
    let systemName: String
    var role: InventoryDesign.AccentRole = .muted
    var domain: InventoryGlyph.Domain? = nil
    var isSelected = false

    var body: some View {
        InventoryGlyphImage(
            systemName: systemName,
            role: role,
            size: size,
            domain: domain,
            isSelected: isSelected
        )
        .accessibilityHidden(true)
    }
}

struct InventoryPlaceIconPicker: View {
    @Environment(\.self) private var environment
    @Binding var selection: String

    var body: some View {
        // Native menus can snapshot labels outside the form's color environment.
        let tint = InventoryDesign.ContentRole.place.color.resolve(in: environment)
        Picker("inventory.selection.place.icon", selection: $selection) {
            ForEach(PlaceIconCatalog.options) { option in
                Label {
                    Text(verbatim: option.localizedName)
                } icon: {
                    InventoryGlyphArtwork.menuImage(
                        glyph: InventoryGlyph.content(systemName: option.symbolName, domain: .place),
                        variant: selection == option.id ? .selected : .outline,
                        tint: tint,
                        displayScale: environment.displayScale
                    )
                }
                .tag(option.id)
            }
        }
    }
}

extension InventoryGlyph.Domain {
    init(contentRole: InventoryDesign.ContentRole) {
        switch contentRole {
        case .location: self = .location
        case .place: self = .place
        case .item: self = .item
        }
    }

    init(accentRole: InventoryDesign.AccentRole) {
        switch accentRole {
        case .storage: self = .location
        case .place: self = .place
        default: self = .item
        }
    }
}
