import SwiftUI

#if DEBUG
struct InventoryDetailPreviewSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .inventoryDetailContentWidth()
        }
        .inventoryGroupedBackground()
    }
}

enum InventoryRecentItemsPreviewFixtures {
    static let one = ["USB-C to HDMI adapter"]

    static let two = [
        "USB-C to HDMI adapter",
        "Precision screwdriver set"
    ]

    static let three = [
        "USB-C to HDMI adapter",
        "Precision screwdriver set",
        "Ethernet cable 5m"
    ]

    static let longEnglish = [
        "Spare USB-C charging cables for the travel organizer",
        "Precision screwdriver set with replacement bits",
        "Ethernet cable for the living room television cabinet"
    ]

    static let longUkrainian = [
        "Набір запасних зарядних кабелів для дорожнього органайзера",
        "Точний набір викруток зі змінними бітами",
        "Кабель Ethernet для телевізійної тумби у вітальні"
    ]
}

extension InventoryPreviewGroupPresentation {
    static func recentItemsPreview(
        _ titles: [String],
        hiddenCount: Int = 0
    ) -> InventoryPreviewGroupPresentation? {
        InventoryPreviewGroupPresentation(
            InventoryBrowseSummaries.PreviewGroup(
                kind: .recentItem,
                visibleItems: titles.enumerated().map { index, title in
                    .init(id: "preview-\(index)", title: title)
                },
                hiddenCount: hiddenCount
            )
        )
    }
}

struct LocationRecentItemsPreviewCard: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Namespace private var namespace

    let presentation: InventoryPreviewGroupPresentation

    var body: some View {
        LocationRecentItemsCard(
            presentation: presentation,
            locationName: "Вітальня",
            transitionNamespace: namespace,
            reduceMotion: accessibilityReduceMotion,
            isRecentItemResolvable: { !$0.isOverflow },
            recentItemSystemImage: { _ in "wrench.and.screwdriver" },
            onRecentItemTapped: { _ in }
        ) {}
    }
}

struct PlaceRecentItemsPreviewCard: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Namespace private var namespace

    let presentation: InventoryPreviewGroupPresentation

    var body: some View {
        PlaceRecentItemsCard(
            presentation: presentation,
            transitionNamespace: namespace,
            reduceMotion: accessibilityReduceMotion,
            isRecentItemResolvable: { !$0.isOverflow },
            recentItemSystemImage: { _ in "wrench.and.screwdriver" },
            onRecentItemTapped: { _ in }
        )
    }
}
#endif
