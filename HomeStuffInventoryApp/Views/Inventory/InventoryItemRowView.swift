import SwiftUI

struct InventoryItemRowView: View {
    let item: InventoryItem
    let matchContext: InventorySearch.MatchContext?

    init(item: InventoryItem, matchContext: InventorySearch.MatchContext? = nil) {
        self.item = item
        self.matchContext = matchContext
    }

    var body: some View {
        InventoryListRowCard(semanticRole: .item) {
            HStack(alignment: .top, spacing: 12) {
                InventoryContentGlyph(
                    systemName: ItemIconCatalog.symbolName(for: item.iconID),
                    role: InventoryDesign.ContentRole.item.accentRole,
                    accessibilityLabel: itemIconAccessibilityLabel,
                    presentation: .identity
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    storageSummary

                    metadataSummary

                    if let matchContext {
                        matchContextSummary(matchContext)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                InventoryRowChevron()
                    .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var itemIconAccessibilityLabel: String {
        InventoryLocalization.formatted(
            "itemIcons.selected.accessibilityLabel",
            defaultValue: "Item icon: %@",
            ItemIconCatalog.displayName(for: item.iconID)
        )
    }

    private var containerName: String {
        guard let name = item.containerName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return InventoryLocalization.noContainer
        }

        return name
    }

    private var locationName: String {
        let name = item.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? InventoryLocalization.noLocation : name
    }

    private var hasContainer: Bool {
        guard let name = item.containerName else {
            return false
        }

        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasLocation: Bool {
        !item.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var categoryName: String {
        InventoryCategory.displayName(forStoredValue: item.category)
    }

    private var quantityText: String {
        InventoryLocalization.formatted(
            "inventory.quantity.inline",
            defaultValue: "Quantity %d",
            item.quantity
        )
    }

    private var storageSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            storageDetail(
                "inventory.field.location",
                defaultValue: "Location",
                value: locationName,
                systemImage: "mappin.and.ellipse",
                hasValue: hasLocation,
                contentRole: .location
            )
                .font(.subheadline.weight(.semibold))

            storageDetail(
                "inventory.field.container",
                defaultValue: "Storage Place",
                value: containerName,
                systemImage: "shippingbox",
                hasValue: hasContainer,
                contentRole: .place
            )
            .font(.subheadline.weight(.medium))
        }
    }

    private var metadataSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                InventoryBadge(verbatim: categoryName, systemImage: "tag", role: .muted)

                InventoryBadge(verbatim: quantityText, systemImage: "number", role: .muted)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 6) {
                InventoryBadge(verbatim: categoryName, systemImage: "tag", role: .muted)

                InventoryBadge(verbatim: quantityText, systemImage: "number", role: .muted)
                    .monospacedDigit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func matchContextSummary(_ context: InventorySearch.MatchContext) -> some View {
        if let tag = context.matchedTag {
            InventoryBadge(
                verbatim: InventoryLocalization.formatted(
                    "inventory.search.match.tag",
                    defaultValue: "Matched tag: %@",
                    tag
                ),
                systemImage: "tag",
                role: .muted
            )
            .accessibilityIdentifier("inventory.search.match.tag.\(item.id.uuidString)")
        }

        if context.matchedInNotes {
            InventoryBadge(
                "inventory.search.match.notes",
                systemImage: "note.text",
                role: .muted
            )
        }
    }

    private func storageDetail(
        _ labelKey: StaticString,
        defaultValue: String,
        value: String,
        systemImage: String,
        hasValue: Bool,
        contentRole: InventoryDesign.ContentRole
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .imageScale(.small)
                .foregroundStyle(hasValue ? contentRole.color : Color.secondary)
                .accessibilityHidden(true)

            (
                Text(InventoryLocalization.string(labelKey, defaultValue: defaultValue) + ": ")
                    .fontWeight(.semibold)
                + Text(value)
            )
            .foregroundStyle(hasValue ? Color.primary : Color.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
