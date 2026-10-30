import CoreGraphics
import Testing
@testable import HomeStuffInventoryApp

struct InventoryHeroNavigationTitleMetricsTests {
    @Test func stableTitleIsRestrictedToTheSupportedDuoHardware() {
        #expect(InventoryHeroNavigationTitleMetrics.requiresStableNavigationTitle(modelIdentifier: "iPhone19,4"))
        for model in ["iPhone19,3", "iPhone19,5", "iPhone18,3", "iPad16,6", "arm64", "x86_64", "", "iPhone19,40"] {
            #expect(!InventoryHeroNavigationTitleMetrics.requiresStableNavigationTitle(modelIdentifier: model))
        }
    }

    @Test func navigationTitleStaysHiddenWhileHeroExtendsBelowInlineTitleArea() {
        let frame = CGRect(x: 0, y: 12, width: 320, height: 220)

        #expect(InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(for: frame) == false)
    }

    @Test func navigationTitleAppearsWhenHeroHasYieldedInlineTitleArea() {
        let frame = CGRect(
            x: 0,
            y: -180,
            width: 320,
            height: 220
        )

        #expect(InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(for: frame) == true)
    }

    @Test func navigationTitleAppearsAtMeasuredHeroFrameBoundary() {
        let frame = CGRect(
            x: 0,
            y: -InventoryHeroNavigationTitleMetrics.revealScrollDistance,
            width: 320,
            height: InventoryHeroNavigationTitleMetrics.inlineNavigationBarHeight
        )

        #expect(InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(for: frame) == true)
    }

    @Test func scrollOffsetRuleMatchesMeasuredFrameRuleWithTopPadding() {
        let restingAnchorMinY = InventoryDesign.gridSpacing
        let contentOffsetY = restingAnchorMinY
            + InventoryHeroNavigationTitleMetrics.revealScrollDistance
        let measuredFrame = CGRect(
            x: 0,
            y: restingAnchorMinY - contentOffsetY,
            width: 320,
            height: 220
        )

        #expect(
            InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(
                forContentOffsetY: contentOffsetY,
                restingAnchorMinY: restingAnchorMinY
            )
                == InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(for: measuredFrame)
        )
    }

    @Test func navigationTitleMakesNoVisibilityDecisionForMissingHeroFrame() {
        #expect(InventoryHeroNavigationTitleMetrics.shouldShowNavigationTitle(for: .null) == nil)
    }
}
