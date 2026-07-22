import SwiftUI

enum InventoryHeroIconPresentation {
    case elevated
    case compact
}

enum InventoryHeroCardPresentation {
    case detail
    case compact
}

enum InventoryHeroIconShape {
    case roundedRectangle
    case circle
}

struct InventoryHeroCard<Content: View>: View {
    private let presentation: InventoryHeroCardPresentation
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let minHeight: CGFloat?
    private let contentRole: InventoryDesign.ContentRole
    private let content: Content

    init(
        presentation: InventoryHeroCardPresentation = .detail,
        padding: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        contentRole: InventoryDesign.ContentRole = .location,
        @ViewBuilder content: () -> Content
    ) {
        self.presentation = presentation
        self.padding = padding ?? InventoryHeroCard.defaultPadding(for: presentation)
        self.cornerRadius = cornerRadius ?? InventoryHeroCard.defaultCornerRadius(for: presentation)
        self.minHeight = minHeight
        self.contentRole = contentRole
        self.content = content()
    }

    var body: some View {
        heroContent
            .inventoryHeroCardSurface(
                presentation,
                accentRole: contentRole.accentRole,
                cornerRadius: cornerRadius
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var contentMinHeight: CGFloat? {
        minHeight.map { max(0, $0 - padding * 2) }
    }

    private var heroContent: some View {
        content
            .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .leading)
            .padding(padding)
    }

    private static func defaultPadding(for presentation: InventoryHeroCardPresentation) -> CGFloat {
        switch presentation {
        case .detail:
            InventoryDesign.cardPadding
        case .compact:
            InventoryDesign.cardPadding
        }
    }

    private static func defaultCornerRadius(for presentation: InventoryHeroCardPresentation) -> CGFloat {
        switch presentation {
        case .detail:
            InventoryDesign.heroCornerRadius
        case .compact:
            InventoryDesign.cardCornerRadius
        }
    }
}

struct InventoryHeroIcon: View {
    private let systemName: String
    private let displayName: String?
    private let size: CGFloat
    private let symbolSize: CGFloat
    private let cornerRadius: CGFloat
    private let presentation: InventoryHeroIconPresentation
    private let contentRole: InventoryDesign.ContentRole
    private let shape: InventoryHeroIconShape

    init(
        systemName: String,
        displayName: String? = nil,
        size: CGFloat = 72,
        symbolSize: CGFloat = 34,
        cornerRadius: CGFloat = 24,
        presentation: InventoryHeroIconPresentation = .elevated,
        contentRole: InventoryDesign.ContentRole = .location,
        shape: InventoryHeroIconShape = .roundedRectangle
    ) {
        self.systemName = systemName
        self.displayName = displayName
        self.size = size
        self.symbolSize = symbolSize
        self.cornerRadius = cornerRadius
        self.presentation = presentation
        self.contentRole = contentRole
        self.shape = shape
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(contentRole.color)
            .frame(width: size, height: size)
            .inventoryHeroIconSurface(
                presentation,
                accentRole: contentRole.accentRole,
                shape: shape,
                cornerRadius: cornerRadius
            )
            .inventoryHeroIconStroke(
                presentation,
                accentRole: contentRole.accentRole,
                shape: shape,
                cornerRadius: cornerRadius
            )
            .accessibilityHidden(displayName == nil)
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        guard let displayName else {
            return Text(verbatim: "")
        }

        return Text(
            InventoryLocalization.formatted(
                "itemIcons.selected.accessibilityLabel",
                defaultValue: "Item icon: %@",
                displayName
            )
        )
    }
}

struct InventoryDetailHeroHeader<TitleContent: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let iconSystemName: String
    private let iconDisplayName: String?
    private let contentRole: InventoryDesign.ContentRole
    private let titleContent: TitleContent

    init(
        iconSystemName: String,
        iconDisplayName: String? = nil,
        contentRole: InventoryDesign.ContentRole = .location,
        @ViewBuilder titleContent: () -> TitleContent
    ) {
        self.iconSystemName = iconSystemName
        self.iconDisplayName = iconDisplayName
        self.contentRole = contentRole
        self.titleContent = titleContent()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                heroIcon

                titleContent
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                heroIcon

                titleContent
            }
        }
    }

    private var heroIcon: some View {
        InventoryHeroIcon(
            systemName: iconSystemName,
            displayName: iconDisplayName,
            contentRole: contentRole
        )
    }
}

struct InventoryDetailHeroTitleStack: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    let titleAccessibilityIdentifier: String?
    let subtitleAccessibilityIdentifier: String?

    init(
        title: String,
        subtitle: String,
        titleAccessibilityIdentifier: String? = nil,
        subtitleAccessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .inventoryTextRole(.entityTitle)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .modifier(InventoryOptionalAccessibilityIdentifierModifier(titleAccessibilityIdentifier))

            Text(verbatim: subtitle)
                .inventoryTextRole(.supportingText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.tail)
                .modifier(InventoryOptionalAccessibilityIdentifierModifier(subtitleAccessibilityIdentifier))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compact, backgroundless identity for Location, Place, and Item detail screens.
struct InventoryDetailIdentityHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemName: String
    let contentRole: InventoryDesign.ContentRole
    let title: String
    let secondary: Text
    let secondaryLeadingMetadata: Text?
    let tertiary: Text?
    let accessibilityLabel: Text
    let accessibilityIdentifier: String
    let titleAccessibilityIdentifier: String?
    let secondaryAccessibilityIdentifier: String?
    let secondaryLeadingAccessibilityIdentifier: String?

    init(
        iconSystemName: String,
        contentRole: InventoryDesign.ContentRole,
        title: String,
        secondary: Text,
        secondaryLeadingMetadata: Text? = nil,
        tertiary: Text? = nil,
        accessibilityLabel: Text,
        accessibilityIdentifier: String,
        titleAccessibilityIdentifier: String? = nil,
        secondaryAccessibilityIdentifier: String? = nil,
        secondaryLeadingAccessibilityIdentifier: String? = nil
    ) {
        systemName = iconSystemName
        self.contentRole = contentRole
        self.title = title
        self.secondary = secondary
        self.secondaryLeadingMetadata = secondaryLeadingMetadata
        self.tertiary = tertiary
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.secondaryAccessibilityIdentifier = secondaryAccessibilityIdentifier
        self.secondaryLeadingAccessibilityIdentifier = secondaryLeadingAccessibilityIdentifier
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                    icon
                    text
                }
            } else {
                HStack(alignment: .top, spacing: InventoryDesign.cardPadding) {
                    icon
                    text
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var icon: some View {
        InventoryContentGlyph(
            systemName: systemName,
            role: contentRole.accentRole,
            presentation: .identity
        )
        .padding(InventoryDesign.rowSpacing)
        .background {
            Circle()
                .fill(contentRole.color.opacity(InventoryDesign.Opacity.identityHeaderIconFill))
        }
        .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .inventoryTextRole(.entityTitle)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .modifier(InventoryOptionalAccessibilityIdentifierModifier(titleAccessibilityIdentifier))

            if let secondaryLeadingMetadata {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    secondaryLeadingMetadata
                        .modifier(InventoryOptionalAccessibilityIdentifierModifier(secondaryLeadingAccessibilityIdentifier))

                    Text(verbatim: " · ")
                        .accessibilityHidden(true)

                    secondary
                        .modifier(InventoryOptionalAccessibilityIdentifierModifier(secondaryAccessibilityIdentifier))
                }
                .inventoryTextRole(.supportingText)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                secondary
                    .inventoryTextRole(.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(InventoryOptionalAccessibilityIdentifierModifier(secondaryAccessibilityIdentifier))
            }

            if let tertiary {
                tertiary
                    .inventoryTextRole(.metadata)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InventoryHeroMetadataSection<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
    }
}

struct InventoryHeroMetadataLine: View {
    @ScaledMetric(relativeTo: .headline) private var iconWidth: CGFloat = 20

    let title: Text
    let value: String
    let systemImage: String
    let role: InventoryDesign.AccentRole
    let valueForegroundStyle: Color
    let showsTitle: Bool
    let accessibilityIdentifier: String?

    init(
        _ title: LocalizedStringKey,
        value: String,
        systemImage: String,
        role: InventoryDesign.AccentRole = .storage,
        valueForegroundStyle: Color = .primary,
        showsTitle: Bool = false,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = Text(title)
        self.value = value
        self.systemImage = systemImage
        self.role = role
        self.valueForegroundStyle = valueForegroundStyle
        self.showsTitle = showsTitle
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    init(
        title: String,
        value: String,
        systemImage: String,
        role: InventoryDesign.AccentRole = .storage,
        valueForegroundStyle: Color = .primary,
        showsTitle: Bool = false,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = Text(verbatim: title)
        self.value = value
        self.systemImage = systemImage
        self.role = role
        self.valueForegroundStyle = valueForegroundStyle
        self.showsTitle = showsTitle
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        HStack(alignment: showsTitle ? .top : .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(role.color)
                .imageScale(.medium)
                .frame(width: iconWidth)
                .padding(.top, showsTitle ? 2 : 0)
                .accessibilityHidden(true)

            if showsTitle {
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .inventoryTextRole(.fieldLabel, accentRole: role)

                    valueText
                }
            } else {
                valueText
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + Text(verbatim: ", \(value)"))
        .modifier(InventoryOptionalAccessibilityIdentifierModifier(accessibilityIdentifier))
    }

    private var valueText: some View {
        Text(verbatim: value)
            .font(InventoryDesign.TextRole.fieldValue.font)
            .foregroundStyle(valueForegroundStyle)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct InventoryOptionalAccessibilityIdentifierModifier: ViewModifier {
    let identifier: String?

    init(_ identifier: String?) {
        self.identifier = identifier
    }

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

enum InventoryHeroNavigationTitleMetrics {
    static let inlineNavigationBarHeight: CGFloat = 44

    static let revealScrollDistance: CGFloat = inlineNavigationBarHeight
        + InventoryDesign.screenPadding
        + InventoryDesign.gridSpacing
    static let bottomScrollReserve: CGFloat = 160

    static func shouldShowNavigationTitle(for anchorFrame: CGRect) -> Bool? {
        guard !anchorFrame.isNull else {
            return nil
        }

        return anchorFrame.minY <= -revealScrollDistance
    }

    static func shouldShowNavigationTitle(
        forContentOffsetY contentOffsetY: CGFloat,
        restingAnchorMinY: CGFloat
    ) -> Bool {
        contentOffsetY >= restingAnchorMinY + revealScrollDistance
    }
}

private enum InventoryHeroNavigationTitleCoordinateSpace {
    static let name = "inventoryHeroNavigationTitleScroll"
}

private struct InventoryHeroTitleFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct InventoryHeroNavigationTitleVisibilityAnchorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: InventoryHeroTitleFramePreferenceKey.self,
                    value: proxy.frame(in: .named(InventoryHeroNavigationTitleCoordinateSpace.name))
                )
            }
        }
    }
}

private struct InventoryHeroNavigationTitleVisibilityObserverModifier: ViewModifier {
    @Binding var isShowingNavigationTitle: Bool
    let restingAnchorMinY: CGFloat

    func body(content: Content) -> some View {
        observedContent(content)
            .coordinateSpace(name: InventoryHeroNavigationTitleCoordinateSpace.name)
    }

    @ViewBuilder
    private func observedContent(_ content: Content) -> some View {
        if #available(iOS 18.0, *) {
            preferenceObservedContent(content)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(
                        forContentOffsetY: geometry.contentOffset.y,
                        restingAnchorMinY: restingAnchorMinY
                    )
                } action: { _, isScrolledPastHero in
                    isShowingNavigationTitle = isScrolledPastHero
                }
        } else {
            preferenceObservedContent(content)
        }
    }

    private func preferenceObservedContent(_ content: Content) -> some View {
        content.onPreferenceChange(InventoryHeroTitleFramePreferenceKey.self) { heroFrame in
            if let isShowing = InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(for: heroFrame) {
                isShowingNavigationTitle = isShowing
            }
        }
    }
}

extension View {
    func inventoryDetailContentWidth(horizontalPadding: CGFloat = InventoryDesign.screenPadding) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .frame(
                maxWidth: InventoryDesign.detailContentMaxWidth + horizontalPadding * 2,
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func inventoryHeroNavigationTitleVisibilityAnchor() -> some View {
        modifier(InventoryHeroNavigationTitleVisibilityAnchorModifier())
    }

    func inventoryHeroNavigationTitleVisibilityObserver(
        isShowingNavigationTitle: Binding<Bool>,
        restingAnchorMinY: CGFloat = 0
    ) -> some View {
        modifier(
            InventoryHeroNavigationTitleVisibilityObserverModifier(
                isShowingNavigationTitle: isShowingNavigationTitle,
                restingAnchorMinY: restingAnchorMinY
            )
        )
    }
}
