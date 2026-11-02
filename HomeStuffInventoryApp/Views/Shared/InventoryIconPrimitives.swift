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

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: LocalizedStringKey? = nil,
        presentation: InventoryContentGlyphPresentation = .compact
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text($0) }
        self.presentation = presentation
    }

    init(
        systemName: String,
        role: InventoryDesign.AccentRole = .storage,
        accessibilityLabel: String?,
        presentation: InventoryContentGlyphPresentation = .compact
    ) {
        self.systemName = systemName
        self.role = role
        self.accessibilityLabel = accessibilityLabel.map { Text(verbatim: $0) }
        self.presentation = presentation
    }

    var body: some View {
        InventoryGlyphImage(systemName: systemName, role: role, size: size, font: font, identity: presentation == .identity)
            .frame(width: size, height: size)
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(accessibilityLabel ?? Text(verbatim: ""))
    }

    private var font: Font {
        switch presentation {
        case .compact:
            .title3.weight(.semibold)
        case .identity:
            .title2.weight(.semibold)
        }
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
        InventoryGlyphImage(systemName: systemName, role: role, size: size * 32 / 44, font: .title3.weight(.semibold))
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
        InventoryGlyphImage(systemName: systemName, role: role, size: size * 24 / 34, font: .subheadline.weight(.semibold))
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
    let font: Font
    var identity = false

    var body: some View {
        if let domain, let glyph = InventoryGlyph.resolve(systemName: systemName, domain: domain) {
            InventoryGlyphArtwork(glyph: glyph, identity: identity, tint: role.color)
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemName)
                .font(font)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(role.color)
        }
    }

    private var domain: InventoryGlyph.Domain? {
        switch role {
        case .storage: .location
        case .place: .place
        case .secondary: .item
        default: nil
        }
    }
}
