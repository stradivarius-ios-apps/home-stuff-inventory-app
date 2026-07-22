import SwiftUI

enum InventoryScreenBackgroundStyle {
    case grouped
    case locationAtmosphere
}

private struct InventoryGlassAccessibility {
    let reduceTransparency: Bool
    let contrast: ColorSchemeContrast

    var allowsGlass: Bool {
        !reduceTransparency && contrast != .increased
    }
}

private enum InventoryGlassMetrics {
    static func heroIconFillOpacity(
        for presentation: InventoryHeroIconPresentation,
        accentRole: InventoryDesign.AccentRole
    ) -> CGFloat {
        if case .place = accentRole, case .elevated = presentation {
            return InventoryDesign.Opacity.placeIconFill
        }

        return switch presentation {
        case .elevated:
            InventoryDesign.Opacity.detailHeroIconFill
        case .compact:
            InventoryDesign.Opacity.compactHeroIconFill
        }
    }

    static func heroIconStrokeOpacity(
        for presentation: InventoryHeroIconPresentation,
        accentRole: InventoryDesign.AccentRole
    ) -> CGFloat {
        if case .place = accentRole, case .elevated = presentation {
            return InventoryDesign.Opacity.placeIconStroke
        }

        return switch presentation {
        case .elevated:
            InventoryDesign.Opacity.detailHeroIconStroke
        case .compact:
            InventoryDesign.Opacity.compactHeroIconStroke
        }
    }

    static func heroCardGlassTint(for presentation: InventoryHeroCardPresentation) -> CGFloat {
        switch presentation {
        case .detail:
            InventoryDesign.Glass.detailHeroTint
        case .compact:
            InventoryDesign.Glass.compactHeroTint
        }
    }

    static func heroCardFallbackTint(for presentation: InventoryHeroCardPresentation) -> CGFloat {
        switch presentation {
        case .detail:
            InventoryDesign.Opacity.detailHeroFallbackTint
        case .compact:
            InventoryDesign.Opacity.compactHeroFallbackTint
        }
    }
}

extension View {
    func inventoryHeroCardSurface(
        _ presentation: InventoryHeroCardPresentation,
        accentRole: InventoryDesign.AccentRole,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(InventoryHeroCardSurfaceModifier(presentation: presentation, accentRole: accentRole, cornerRadius: cornerRadius))
    }

    func inventoryHeroIconSurface(
        _ presentation: InventoryHeroIconPresentation,
        accentRole: InventoryDesign.AccentRole,
        shape: InventoryHeroIconShape,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(InventoryHeroIconSurfaceModifier(presentation: presentation, accentRole: accentRole, shape: shape, cornerRadius: cornerRadius))
    }

    func inventoryHeroIconStroke(
        _ presentation: InventoryHeroIconPresentation,
        accentRole: InventoryDesign.AccentRole,
        shape: InventoryHeroIconShape,
        cornerRadius: CGFloat
    ) -> some View {
        overlay {
            switch shape {
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        accentRole.color.opacity(
                            InventoryGlassMetrics.heroIconStrokeOpacity(
                                for: presentation,
                                accentRole: accentRole
                            )
                        ),
                        lineWidth: 1
                    )
            case .circle:
                Circle()
                    .strokeBorder(
                        accentRole.color.opacity(
                            InventoryGlassMetrics.heroIconStrokeOpacity(
                                for: presentation,
                                accentRole: accentRole
                            )
                        ),
                        lineWidth: 1
                    )
            }
        }
        .allowsHitTesting(false)
    }

    func inventoryCardSurface(_ surface: InventoryCardSurface, cornerRadius: CGFloat) -> some View {
        modifier(InventoryCardSurfaceModifier(surface: surface, cornerRadius: cornerRadius))
    }

    func inventorySemanticSurface(
        _ role: InventoryDesign.SurfaceRole,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(InventorySemanticSurfaceModifier(role: role, cornerRadius: cornerRadius))
    }

    func inventoryBadgeSurface(role: InventoryDesign.AccentRole) -> some View {
        modifier(InventoryBadgeSurfaceModifier(role: role))
    }

    func inventoryStorageIconSurface(role: InventoryDesign.AccentRole) -> some View {
        modifier(InventoryStorageIconSurfaceModifier(role: role))
    }

    func inventoryGroupedBackground() -> some View {
        background(InventoryDesign.Appearance.groupedBackground)
    }

    func inventoryLocationAtmosphereBackground() -> some View {
        background {
            InventoryLocationAtmosphereBackground()
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    func inventoryScreenBackground(_ style: InventoryScreenBackgroundStyle) -> some View {
        switch style {
        case .grouped:
            inventoryGroupedBackground()
        case .locationAtmosphere:
            inventoryLocationAtmosphereBackground()
        }
    }
}

private struct InventoryLocationAtmosphereBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack {
            InventoryDesign.Appearance.groupedBackground

            LinearGradient(
                stops: [
                    .init(
                        color: InventoryDesign.Appearance.locationAtmosphere.opacity(leadingOpacity),
                        location: 0
                    ),
                    .init(
                        color: InventoryDesign.Appearance.locationAtmosphere.opacity(leadingOpacity * 0.58),
                        location: 0.42
                    ),
                    .init(
                        color: InventoryDesign.Appearance.locationAtmosphere.opacity(leadingOpacity * 0.16),
                        location: 0.76
                    ),
                    .init(color: .clear, location: 0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// The opaque grouped base preserves Reduce Transparency while the Location color stays atmospheric.
    private var leadingOpacity: Double {
        if increasesContrast {
            return 0.68
        }

        if reducesTransparency {
            return 0.60
        }

        return 0.52
    }

    private var reducesTransparency: Bool {
        #if DEBUG
        reduceTransparency || InventoryQAAccessibilityConfiguration.current.reduceTransparency
        #else
        reduceTransparency
        #endif
    }

    private var increasesContrast: Bool {
        #if DEBUG
        colorSchemeContrast == .increased || InventoryQAAccessibilityConfiguration.current.increaseContrast
        #else
        colorSchemeContrast == .increased
        #endif
    }
}

private struct InventoryHeroCardSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let presentation: InventoryHeroCardPresentation
    let accentRole: InventoryDesign.AccentRole
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let accessibility = InventoryGlassAccessibility(
            reduceTransparency: reducesTransparency,
            contrast: increasesContrast ? .increased : colorSchemeContrast
        )

        if #available(iOS 26.0, *), accessibility.allowsGlass {
            content
                .glassEffect(
                    .regular.tint(accentRole.color.opacity(InventoryGlassMetrics.heroCardGlassTint(for: presentation))),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(InventoryDesign.Appearance.contentSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(accentRole.color.opacity(InventoryGlassMetrics.heroCardFallbackTint(for: presentation)))
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            InventoryDesign.Appearance.contentStroke,
                            lineWidth: InventoryDesign.Stroke.card
                        )
                        .allowsHitTesting(false)
                }
        }
    }

    private var reducesTransparency: Bool {
        #if DEBUG
        reduceTransparency || InventoryQAAccessibilityConfiguration.current.reduceTransparency
        #else
        reduceTransparency
        #endif
    }

    private var increasesContrast: Bool {
        #if DEBUG
        colorSchemeContrast == .increased || InventoryQAAccessibilityConfiguration.current.increaseContrast
        #else
        colorSchemeContrast == .increased
        #endif
    }
}

private struct InventoryHeroIconSurfaceModifier: ViewModifier {
    let presentation: InventoryHeroIconPresentation
    let accentRole: InventoryDesign.AccentRole
    let shape: InventoryHeroIconShape
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                switch shape {
                case .roundedRectangle:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(InventoryDesign.Appearance.contentSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    accentRole.color.opacity(
                                        InventoryGlassMetrics.heroIconFillOpacity(
                                            for: presentation,
                                            accentRole: accentRole
                                        )
                                    )
                                )
                        }
                case .circle:
                    Circle()
                        .fill(InventoryDesign.Appearance.contentSurface)
                        .overlay {
                            Circle()
                                .fill(
                                    accentRole.color.opacity(
                                        InventoryGlassMetrics.heroIconFillOpacity(
                                            for: presentation,
                                            accentRole: accentRole
                                        )
                                    )
                                )
                        }
                }
            }
    }
}

private struct InventoryCardSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let surface: InventoryCardSurface
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(InventoryDesign.Appearance.contentSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: strokeWidth)
                    .allowsHitTesting(false)
            }
            .shadow(
                color: shadowColor,
                radius: surface == .interactive ? InventoryDesign.Depth.interactiveRadius : 0,
                y: surface == .interactive ? InventoryDesign.Depth.interactiveY : 0
            )
    }

    private var strokeColor: Color {
        switch surface {
        case .content:
            InventoryDesign.Appearance.contentStroke
        case .interactive:
            InventoryDesign.Appearance.storageAccent.opacity(
                increasesContrast ? 1 : InventoryDesign.Opacity.interactiveStroke
            )
        }
    }

    private var strokeWidth: CGFloat {
        surface == .interactive ? InventoryDesign.Stroke.interactiveCard : InventoryDesign.Stroke.card
    }

    private var shadowColor: Color {
        guard surface == .interactive, !increasesContrast else {
            return .clear
        }

        return .black.opacity(
            colorScheme == .dark
                ? InventoryDesign.Opacity.darkSurfaceShadow
                : InventoryDesign.Opacity.lightSurfaceShadow
        )
    }

    private var increasesContrast: Bool {
        #if DEBUG
        colorSchemeContrast == .increased || InventoryQAAccessibilityConfiguration.current.increaseContrast
        #else
        colorSchemeContrast == .increased
        #endif
    }
}

private struct InventorySemanticSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let role: InventoryDesign.SurfaceRole
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(InventoryDesign.Appearance.contentSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(role.tint.opacity(InventoryDesign.Opacity.badgeFill))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        role.tint.opacity(
                            increasesContrast
                                ? 0.8
                                : InventoryDesign.Opacity.badgeStroke
                        ),
                        lineWidth: InventoryDesign.Stroke.card
                    )
                    .allowsHitTesting(false)
            }
    }

    private var increasesContrast: Bool {
        #if DEBUG
        colorSchemeContrast == .increased || InventoryQAAccessibilityConfiguration.current.increaseContrast
        #else
        colorSchemeContrast == .increased
        #endif
    }
}

private struct InventoryBadgeSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let role: InventoryDesign.AccentRole

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(InventoryDesign.Appearance.contentSurface)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(role.color.opacity(InventoryDesign.Opacity.badgeFill))
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        role.color.opacity(colorSchemeContrast == .increased ? 0.8 : InventoryDesign.Opacity.badgeStroke),
                        lineWidth: InventoryDesign.Stroke.badge
                    )
            }
    }
}

private struct InventoryStorageIconSurfaceModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let role: InventoryDesign.AccentRole

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(InventoryDesign.Appearance.contentSurface)
                    .overlay {
                        Circle()
                            .fill(role.color.opacity(InventoryDesign.Opacity.storageIconFill))
                    }
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        role.color.opacity(colorSchemeContrast == .increased ? 0.8 : InventoryDesign.Opacity.badgeStroke),
                        lineWidth: InventoryDesign.Stroke.badge
                    )
            }
    }
}
