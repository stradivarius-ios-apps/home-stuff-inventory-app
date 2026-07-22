import SwiftUI

enum InventoryCardSurface: Equatable {
    case content
    case interactive
}

struct InventoryCard<Content: View>: View {
    private let surface: InventoryCardSurface
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let minHeight: CGFloat?
    private let content: Content

    init(
        surface: InventoryCardSurface = .content,
        padding: CGFloat = InventoryDesign.cardPadding,
        cornerRadius: CGFloat = InventoryDesign.cardCornerRadius,
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.surface = surface
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .leading)
            .padding(padding)
            .inventoryCardSurface(surface, cornerRadius: cornerRadius)
    }

    private var contentMinHeight: CGFloat? {
        minHeight.map { max(0, $0 - padding * 2) }
    }
}

struct InventoryPropertyCard: View {
    private let title: Text
    private let value: Text
    private let systemImage: String?
    private let role: InventoryDesign.AccentRole
    private let minHeight: CGFloat?

    init(
        _ title: LocalizedStringKey,
        value: LocalizedStringKey,
        systemImage: String? = nil,
        role: InventoryDesign.AccentRole = .storage,
        minHeight: CGFloat? = nil
    ) {
        self.title = Text(title)
        self.value = Text(value)
        self.systemImage = systemImage
        self.role = role
        self.minHeight = minHeight
    }

    init(
        _ title: LocalizedStringKey,
        value: String,
        systemImage: String? = nil,
        role: InventoryDesign.AccentRole = .storage,
        minHeight: CGFloat? = nil
    ) {
        self.title = Text(title)
        self.value = Text(verbatim: value)
        self.systemImage = systemImage
        self.role = role
        self.minHeight = minHeight
    }

    var body: some View {
        InventoryCard(
            padding: InventoryDesign.compactCardPadding,
            cornerRadius: InventoryDesign.compactCornerRadius,
            minHeight: minHeight
        ) {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .imageScale(.small)
                            .foregroundStyle(role.color)
                            .accessibilityHidden(true)
                    }

                    title
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .fixedSize(horizontal: false, vertical: true)
                }

                value
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
