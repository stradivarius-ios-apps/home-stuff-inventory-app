import SwiftUI

enum InventoryDesign {
    /// Asset-backed adaptive colors. Feature composition should prefer semantic roles below.
    enum Appearance {
        static let groupedBackground = Color("InventoryGroupedBackground")
        static let locationAtmosphere = Color("InventoryLocationAtmosphere")
        static let contentSurface = Color("InventoryContentSurface")
        static let contentStroke = Color("InventoryContentStroke")
        static let storageAccent = Color("InventoryStorageAccent")
        static let placeAccent = Color("InventoryPlaceAccent")
        static let primaryAction = Color("InventoryPrimaryAction")
        static let secondaryAccent = Color("InventorySecondaryAccent")
        static let contextHighlight = Color("InventoryContextHighlight")
    }

    /// Palette accents describe visual treatment, not Item, Location, or Place meaning.
    enum AccentRole: Equatable {
        case storage
        case place
        case primaryAction
        case secondary
        case context
        case muted
        case tag(String)

        var color: Color {
            switch self {
            case .storage:
                Appearance.storageAccent
            case .place:
                Appearance.placeAccent
            case .primaryAction:
                Appearance.primaryAction
            case .secondary:
                Appearance.secondaryAccent
            case .context:
                Appearance.contextHighlight
            case .muted:
                .secondary
            case let .tag(tag):
                InventoryTagStyle.tint(for: tag)
            }
        }
    }

    /// Product semantics own the single mapping to the shipped accent palette.
    enum ContentRole: CaseIterable, Equatable {
        case item
        case location
        case place

        var accentRole: AccentRole {
            switch self {
            case .item:
                .secondary
            case .location:
                .storage
            case .place:
                .place
            }
        }

        var color: Color {
            accentRole.color
        }

        var surfaceTint: Color {
            switch self {
            case .item:
                Appearance.secondaryAccent
            case .location:
                Appearance.locationAtmosphere
            case .place:
                Appearance.placeAccent
            }
        }
    }

    enum TextRole {
        case screenTitle
        case entityTitle
        case sectionTitle
        case rowTitle
        case fieldLabel
        case fieldValue
        case supportingText
        case metadata
        case actionLabel

        var font: Font {
            switch self {
            case .screenTitle:
                return .largeTitle.weight(.bold)
            case .entityTitle:
                return .title2.weight(.semibold)
            case .sectionTitle:
                return .headline.weight(.semibold)
            case .rowTitle:
                return .headline
            case .fieldLabel:
                return .caption.weight(.semibold)
            case .fieldValue:
                return .headline.weight(.semibold)
            case .supportingText:
                return .subheadline.weight(.medium)
            case .metadata:
                return .caption
            case .actionLabel:
                return .body.weight(.semibold)
            }
        }

        func color(accentRole: AccentRole?) -> Color {
            switch self {
            case .fieldLabel:
                return accentRole?.color ?? .secondary
            case .supportingText, .metadata:
                return .secondary
            case .screenTitle, .entityTitle, .sectionTitle, .rowTitle, .fieldValue, .actionLabel:
                return .primary
            }
        }
    }

    /// Semantic content roles keep domain accents coordinated without tinting primary text.
    enum SurfaceRole: CaseIterable, Identifiable {
        case item
        case location
        case place
        case context
        case neutral

        var id: Self { self }

        var tint: Color {
            switch self {
            case .context:
                Appearance.contextHighlight
            case .item, .location, .place, .neutral:
                contentRole?.surfaceTint ?? Appearance.contentStroke
            }
        }

        private var contentRole: ContentRole? {
            switch self {
            case .item:
                .item
            case .location:
                .location
            case .place:
                .place
            case .context, .neutral:
                nil
            }
        }
    }

    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let compactCardPadding: CGFloat = 12
    static let compactInventoryCardMinHeight: CGFloat = 88
    static let compactInventoryCardHorizontalPadding: CGFloat = 12
    static let compactInventoryCardVerticalPadding: CGFloat = 10
    static let cardCornerRadius: CGFloat = 20
    static let heroCornerRadius: CGFloat = 24
    static let compactCornerRadius: CGFloat = 14
    static let gridSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 8
    static let badgeHorizontalPadding: CGFloat = 10
    static let badgeVerticalPadding: CGFloat = 6
    static let tagBadgeMinHeight: CGFloat = 30
    static let tagBadgeMaxWidth: CGFloat = 180
    static let tagBadgeHorizontalSpacing: CGFloat = 8
    static let tagBadgeVerticalSpacing: CGFloat = 6
    static let previewGroupSpacing: CGFloat = 8
    static let previewGroupSectionSpacing: CGFloat = 10
    static let previewValueSpacing: CGFloat = 3
    static let previewValueIndent: CGFloat = 16
    static let previewOverflowChipHorizontalPadding: CGFloat = 7
    static let previewOverflowChipVerticalPadding: CGFloat = 4
    static let storageIconSize: CGFloat = 44
    static let locationSummaryIconSize: CGFloat = 36
    static let locationSummaryIconFrame: CGFloat = 60
    static let compactIconSize: CGFloat = 34
    static let contentGlyphSize: CGFloat = 32
    static let identityContentGlyphSize: CGFloat = 40
    static let minimumTapTarget: CGFloat = 44
    static let editorHorizontalPadding: CGFloat = 10
    static let editorVerticalPadding: CGFloat = 8
    static let emptyStateMaxWidth: CGFloat = 460
    static let emptyStateWideMaxWidth: CGFloat = 520
    static let emptyStateMinHeight: CGFloat = 360
    static let detailContentMaxWidth: CGFloat = 520

    enum Stroke {
        static let card: CGFloat = 1
        static let interactiveCard: CGFloat = 1.5
        static let badge: CGFloat = 1
        static let editorFocused: CGFloat = 1.5
    }

    enum Opacity {
        static let cardStroke: CGFloat = 0.18
        static let badgeFill: CGFloat = 0.12
        static let badgeStroke: CGFloat = 0.22
        static let placeBadgeStroke: CGFloat = 0.32
        static let placeIconFill: CGFloat = 0.12
        static let placeIconStroke: CGFloat = 0.34
        static let editorStroke: CGFloat = 0.28
        static let editorFocusedStroke: CGFloat = 0.7
        static let detailHeroFallbackTint: CGFloat = 0.12
        static let compactHeroFallbackTint: CGFloat = 0.08
        static let storageIconFill: CGFloat = 0.12
        static let detailHeroIconFill: CGFloat = 0.14
        static let detailHeroIconStroke: CGFloat = 0.18
        static let compactHeroIconFill: CGFloat = 0.10
        static let compactHeroIconStroke: CGFloat = 0.14
        static let identityHeaderIconFill: CGFloat = 0.12
        static let interactiveStroke: CGFloat = 0.72
        static let lightSurfaceShadow: CGFloat = 0.08
        static let darkSurfaceShadow: CGFloat = 0.28
    }

    enum Depth {
        static let interactiveRadius: CGFloat = 10
        static let interactiveY: CGFloat = 3
    }

    enum Glass {
        // Keep custom glass selective: coordinated hero surfaces only.
        static let detailHeroTint: CGFloat = 0.18
        static let compactHeroTint: CGFloat = 0.12
    }
}

private struct InventoryTextRoleModifier: ViewModifier {
    let role: InventoryDesign.TextRole
    let accentRole: InventoryDesign.AccentRole?

    func body(content: Content) -> some View {
        content
            .font(role.font)
            .foregroundStyle(role.color(accentRole: accentRole))
    }
}

extension View {
    func inventoryTextRole(
        _ role: InventoryDesign.TextRole,
        accentRole: InventoryDesign.AccentRole? = nil
    ) -> some View {
        modifier(InventoryTextRoleModifier(role: role, accentRole: accentRole))
    }
}
