import SwiftUI

enum InventoryScreenBackgroundStyle {
    case grouped
    case locationAtmosphere
}

private struct InventoryGlassAccessibility: DynamicProperty {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var reducesTransparency: Bool {
        #if DEBUG
        reduceTransparency || InventoryQAAccessibilityConfiguration.current.reduceTransparency
        #else
        reduceTransparency
        #endif
    }

    var increasesContrast: Bool {
        #if DEBUG
        contrast == .increased || InventoryQAAccessibilityConfiguration.current.increaseContrast
        #else
        contrast == .increased
        #endif
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
}

extension View {
    func inventoryHeroCardSurface(
        _ presentation: InventoryHeroCardPresentation,
        accentRole: InventoryDesign.AccentRole,
        cornerRadius: CGFloat
    ) -> some View {
        inventoryCardSurface(.content, cornerRadius: cornerRadius)
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
        modifier(InventoryCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    /// Entity color belongs to the glyph or label; dense content shares one opaque base.
    func inventorySemanticSurface(
        _ role: InventoryDesign.SurfaceRole,
        cornerRadius: CGFloat
    ) -> some View {
        inventoryCardSurface(.content, cornerRadius: cornerRadius)
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
    private var accessibility = InventoryGlassAccessibility()

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
        if accessibility.increasesContrast {
            return 0.68
        }

        if accessibility.reducesTransparency {
            return 0.60
        }

        return 0.52
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
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(InventoryDesign.Appearance.contentSurface)
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

private struct InventoryBadgeSurfaceModifier: ViewModifier {
    private var accessibility = InventoryGlassAccessibility()

    let role: InventoryDesign.AccentRole

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(InventoryDesign.Appearance.contentSurface)
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(role.color.opacity(accessibility.reducesTransparency ? 0 : InventoryDesign.Opacity.badgeFill))
                    }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        role.color.opacity(accessibility.increasesContrast ? 0.8 : InventoryDesign.Opacity.badgeStroke),
                        lineWidth: InventoryDesign.Stroke.badge
                    )
            }
    }
}

private struct InventoryStorageIconSurfaceModifier: ViewModifier {
    private var accessibility = InventoryGlassAccessibility()

    let role: InventoryDesign.AccentRole

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(InventoryDesign.Appearance.contentSurface)
                    .overlay {
                        Circle()
                            .fill(role.color.opacity(accessibility.reducesTransparency ? 0 : InventoryDesign.Opacity.storageIconFill))
                    }
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        role.color.opacity(accessibility.increasesContrast ? 0.8 : InventoryDesign.Opacity.badgeStroke),
                        lineWidth: InventoryDesign.Stroke.badge
                    )
            }
    }
}
