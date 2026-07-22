import SwiftUI

struct InventoryBadge: View {
    private let title: Text
    private let systemImage: String?
    private let role: InventoryDesign.AccentRole

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        role: InventoryDesign.AccentRole = .storage
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.role = role
    }

    init(
        verbatim title: String,
        systemImage: String? = nil,
        role: InventoryDesign.AccentRole = .storage
    ) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
        self.role = role
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }

            title
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(role.color)
        .padding(.horizontal, InventoryDesign.badgeHorizontalPadding)
        .padding(.vertical, InventoryDesign.badgeVerticalPadding)
        .inventoryBadgeSurface(role: role)
        .accessibilityElement(children: .combine)
    }
}

struct InventoryTagBadge: View {
    private let title: String
    private let role: InventoryDesign.AccentRole

    init(_ title: String, role: InventoryDesign.AccentRole? = nil) {
        self.title = title
        self.role = role ?? .tag(title)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "tag")
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(verbatim: title)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(role.color)
        .padding(.horizontal, InventoryDesign.badgeHorizontalPadding)
        .padding(.vertical, InventoryDesign.badgeVerticalPadding)
        .frame(minHeight: InventoryDesign.tagBadgeMinHeight)
        .frame(maxWidth: InventoryDesign.tagBadgeMaxWidth, alignment: .leading)
        .inventoryBadgeSurface(role: role)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
    }
}

enum InventoryTagCloudRowAlignment {
    case leading
    case centered
}

struct InventoryTagCloudLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let rowAlignment: InventoryTagCloudRowAlignment

    init(
        horizontalSpacing: CGFloat = InventoryDesign.tagBadgeHorizontalSpacing,
        verticalSpacing: CGFloat = InventoryDesign.tagBadgeVerticalSpacing,
        rowAlignment: InventoryTagCloudRowAlignment = .leading
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.rowAlignment = rowAlignment
    }

    private struct Row {
        var range: Range<Int>
        var width: CGFloat
        var height: CGFloat
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? fallbackWidth(for: subviews)
        let rows = rows(in: availableWidth, subviews: subviews)
        let height = rows.enumerated().reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.element.height + (row.offset == 0 ? 0 : verticalSpacing)
        }

        return CGSize(width: availableWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX + xOffset(for: row, in: bounds.width)

            for index in row.range {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func xOffset(for row: Row, in availableWidth: CGFloat) -> CGFloat {
        switch rowAlignment {
        case .leading:
            return 0
        case .centered:
            return max(0, (availableWidth - row.width) / 2)
        }
    }

    private func fallbackWidth(for subviews: Subviews) -> CGFloat {
        let contentWidth = subviews.reduce(CGFloat.zero) { partialResult, subview in
            partialResult + subview.sizeThatFits(.unspecified).width
        }
        let spacingWidth = CGFloat(max(0, subviews.count - 1)) * horizontalSpacing
        return contentWidth + spacingWidth
    }

    private func rows(in availableWidth: CGFloat, subviews: Subviews) -> [Row] {
        guard !subviews.isEmpty else {
            return []
        }

        var rows: [Row] = []
        var rowStartIndex = subviews.startIndex
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = rowWidth == 0 ? size.width : rowWidth + horizontalSpacing + size.width

            if proposedWidth > availableWidth, rowWidth > 0 {
                rows.append(Row(range: rowStartIndex..<index, width: rowWidth, height: rowHeight))
                rowStartIndex = index
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = proposedWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        rows.append(Row(range: rowStartIndex..<subviews.endIndex, width: rowWidth, height: rowHeight))
        return rows
    }
}

struct InventoryRowCountBadge: View {
    private let countText: String
    private let systemImage: String
    private let role: InventoryDesign.AccentRole

    init(
        _ countText: String,
        systemImage: String = "number",
        role: InventoryDesign.AccentRole = .storage
    ) {
        self.countText = countText
        self.systemImage = systemImage
        self.role = role
    }

    var body: some View {
        InventoryBadge(verbatim: countText, systemImage: systemImage, role: role)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct InventoryRowDefaultBadge: View {
    private let title: Text

    init(_ title: LocalizedStringKey) {
        self.title = Text(title)
    }

    init(verbatim title: String) {
        self.title = Text(verbatim: title)
    }

    var body: some View {
        title
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, InventoryDesign.badgeHorizontalPadding)
            .padding(.vertical, InventoryDesign.badgeVerticalPadding)
            .inventoryBadgeSurface(role: .muted)
            .fixedSize(horizontal: true, vertical: false)
    }
}
