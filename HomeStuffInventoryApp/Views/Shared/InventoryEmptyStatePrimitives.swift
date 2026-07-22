import SwiftUI

struct InventoryInlineEmptyState: View {
    private let title: Text
    private let systemImage: String

    init(title: String, systemImage: String = "shippingbox") {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
    }

    init(_ title: LocalizedStringKey, systemImage: String = "shippingbox") {
        self.title = Text(title)
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InventoryCompactIconBubble(systemName: systemImage, role: .storage)

            title
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct InventoryEmptyStateCard<Actions: View>: View {
    private let title: Text
    private let message: Text
    private let systemImage: String
    private let actions: Actions

    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String = "shippingbox",
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = Text(title)
        self.message = Text(message)
        self.systemImage = systemImage
        self.actions = actions()
    }

    init(
        title: String,
        message: String,
        systemImage: String = "shippingbox",
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = Text(verbatim: title)
        self.message = Text(verbatim: message)
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        InventoryCard(cornerRadius: InventoryDesign.heroCornerRadius) {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                InventoryStorageIcon(systemName: systemImage)
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)

                title
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                message
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                actions
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct InventoryEmptyStateScreen<Content: View>: View {
    private let maxWidth: CGFloat
    private let minHeight: CGFloat
    private let spacing: CGFloat
    private let backgroundStyle: InventoryScreenBackgroundStyle
    private let content: Content

    init(
        maxWidth: CGFloat = InventoryDesign.emptyStateMaxWidth,
        minHeight: CGFloat = InventoryDesign.emptyStateMinHeight,
        spacing: CGFloat = InventoryDesign.gridSpacing,
        backgroundStyle: InventoryScreenBackgroundStyle = .grouped,
        @ViewBuilder content: () -> Content
    ) {
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.spacing = spacing
        self.backgroundStyle = backgroundStyle
        self.content = content()
    }

    var body: some View {
        screenContent.inventoryScreenBackground(backgroundStyle)
    }

    private var screenContent: some View {
        ScrollView {
            VStack(spacing: spacing) {
                content
            }
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(InventoryDesign.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InventoryEmptyStatePrimaryActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .inventoryPrimaryActionTint()
    }
}

private struct InventoryPrimaryActionTintModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.tint(InventoryDesign.Appearance.primaryAction)
    }
}

extension InventoryEmptyStateCard where Actions == EmptyView {
    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String = "shippingbox"
    ) {
        self.init(title: title, message: message, systemImage: systemImage) {
            EmptyView()
        }
    }

    init(
        title: String,
        message: String,
        systemImage: String = "shippingbox"
    ) {
        self.init(title: title, message: message, systemImage: systemImage) {
            EmptyView()
        }
    }
}

extension View {
    /// Applies the shared semantic tint while retaining each context's native button style.
    func inventoryPrimaryActionTint() -> some View {
        modifier(InventoryPrimaryActionTintModifier())
    }

    func inventoryEmptyStatePrimaryAction() -> some View {
        modifier(InventoryEmptyStatePrimaryActionModifier())
    }

}
