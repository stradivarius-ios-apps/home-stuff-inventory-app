import SwiftUI

enum InventoryContentGlyphPresentation {
    case compact
    case identity
}

struct InventoryContentGlyph: View {
    @ScaledMetric(relativeTo: .title3) private var compactSize = InventoryDesign.contentGlyphSize
    @ScaledMetric(relativeTo: .title2) private var identitySize = InventoryDesign.identityContentGlyphSize

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
        InventoryGlyphImage(systemName: systemName, role: role, size: size, identity: presentation == .identity, domain: domain, isSelected: isSelected)
            .frame(width: size, height: size)
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(accessibilityLabel ?? Text(verbatim: ""))
    }

    private var size: CGFloat {
        switch presentation {
        case .compact:
            compactSize
        case .identity:
            identitySize
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
        InventoryGlyphArtwork(
            glyph: InventoryGlyph.content(systemName: systemName, domain: domain ?? .init(accentRole: role)),
            variant: .resolve(identity: identity, isSelected: isSelected),
            tint: role.color
        )
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
