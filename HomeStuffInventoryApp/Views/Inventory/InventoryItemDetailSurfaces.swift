import SwiftUI

struct InventoryItemDetailIdentityHeader: View {
    let viewModel: InventoryItemDetailViewModel

    var body: some View {
        InventoryDetailIdentityHeader(
            iconSystemName: viewModel.iconSymbolName,
            contentRole: .item,
            title: viewModel.name,
            secondary: Text(verbatim: viewModel.category),
            tertiary: nil,
            accessibilityLabel: Text(accessibilityLabel),
            accessibilityIdentifier: "inventory." + "itemDetail.hero",
            titleAccessibilityIdentifier: "inventory." + "itemDetail.title"
        )
    }

    private var accessibilityLabel: String {
        let categoryLabel = InventoryLocalization.string(
            "inventory.field.category",
            defaultValue: "Category"
        )
        return [
            viewModel.name,
            "\(categoryLabel): \(viewModel.category)"
        ]
        .joined(separator: ", ")
    }
}

struct InventoryDetailStorageAnswerCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let viewModel: InventoryItemDetailViewModel

    var body: some View {
        InventoryCard {
            VStack(alignment: .leading, spacing: InventoryDesign.cardPadding) {
                InventorySectionHeader("inventory.section.whereIsIt")

                storageRow(
                    title: "inventory.field.location",
                    value: viewModel.locationName,
                    systemImage: viewModel.hasLocation ? "location" : "location.slash",
                    hasValue: viewModel.hasLocation,
                    contentRole: .location,
                    isExactAnswer: false,
                    identifier: "inventory." + "itemDetail.location"
                )

                Divider()

                storageRow(
                    title: "inventory.field.container",
                    value: viewModel.containerName,
                    systemImage: viewModel.hasContainer ? "shippingbox" : "shippingbox.circle",
                    hasValue: viewModel.hasContainer,
                    contentRole: .place,
                    isExactAnswer: true,
                    identifier: "inventory." + "itemDetail.place"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventory.itemDetail.storage")
    }

    private func storageRow(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        hasValue: Bool,
        contentRole: InventoryDesign.ContentRole,
        isExactAnswer: Bool,
        identifier: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                    glyph(systemImage: systemImage, hasValue: hasValue, contentRole: contentRole)
                    storageText(title: title, value: value, hasValue: hasValue, contentRole: contentRole, isExactAnswer: isExactAnswer)
                }
            } else {
                HStack(alignment: .top, spacing: InventoryDesign.cardPadding) {
                    glyph(systemImage: systemImage, hasValue: hasValue, contentRole: contentRole)
                    storageText(title: title, value: value, hasValue: hasValue, contentRole: contentRole, isExactAnswer: isExactAnswer)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func glyph(systemImage: String, hasValue: Bool, contentRole: InventoryDesign.ContentRole) -> some View {
        InventoryContentGlyph(systemName: systemImage, role: hasValue ? contentRole.accentRole : .muted)
    }

    private func storageText(title: LocalizedStringKey, value: String, hasValue: Bool, contentRole: InventoryDesign.ContentRole, isExactAnswer: Bool) -> some View {
        VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
            Text(title)
                .inventoryTextRole(
                    .fieldLabel,
                    accentRole: hasValue ? contentRole.accentRole : .muted
                )
                .textCase(.uppercase)

            Text(verbatim: value)
                .font(isExactAnswer ? InventoryDesign.TextRole.fieldValue.font : .headline.weight(.medium))
                .foregroundStyle(hasValue ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InventoryDetailPropertiesCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let viewModel: InventoryItemDetailViewModel

    var body: some View {
        InventoryCard(padding: InventoryDesign.compactCardPadding, cornerRadius: InventoryDesign.compactCornerRadius) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: InventoryDesign.cardPadding) {
                    quantityProperty
                    Divider()
                    conditionProperty
                }
            } else {
                HStack(alignment: .top, spacing: InventoryDesign.cardPadding) {
                    quantityProperty
                    Divider()
                    conditionProperty
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var quantityProperty: some View {
        property(
            title: "inventory.field.quantity",
            value: viewModel.quantityText,
            systemImage: "number",
            identifier: "inventory." + "itemDetail.quantity"
        )
    }

    private var conditionProperty: some View {
        property(
            title: "inventory.field.condition",
            value: viewModel.condition,
            systemImage: "checkmark.seal",
            identifier: "inventory." + "itemDetail.condition"
        )
    }

    private func property(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(verbatim: value)
                .font(InventoryDesign.TextRole.fieldValue.font)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

struct InventoryDetailTagsCard: View {
    let tags: [String]

    @State private var isExpanded = false

    private var presentation: InventoryDetailTagsPresentation {
        InventoryDetailTagsPresentation(tags: tags, isExpanded: isExpanded)
    }

    var presentationTags: [InventoryTagPresentation] {
        presentation.visibleTags.enumerated().map {
            InventoryTagPresentation(index: $0.offset, value: $0.element)
        }
    }

    var body: some View {
        InventoryCard {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                InventorySectionHeader("inventory.section.tags")

                InventoryTagCloudLayout(
                    horizontalSpacing: InventoryDesign.tagBadgeHorizontalSpacing,
                    verticalSpacing: InventoryDesign.tagBadgeVerticalSpacing,
                    rowAlignment: .leading
                ) {
                    ForEach(presentationTags) { tag in
                        InventoryTagBadge(tag.value, role: .storage)
                            .accessibilityIdentifier("inventory.itemDetail.tag.\(tag.index)")
                    }

                    if presentation.canExpand {
                        Button {
                            isExpanded = true
                        } label: {
                            Text(verbatim: showMoreCompactLabel)
                                .font(.caption.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel(showMoreAccessibilityLabel)
                        .accessibilityIdentifier("inventory.itemDetail.tags.showMore")
                    }

                    if presentation.canCollapse {
                        Button {
                            isExpanded = false
                        } label: {
                            Label("inventory.tags.collapse", systemImage: "chevron.up")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("inventory.itemDetail.tags.collapse")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventory.itemDetail.tags")
    }

    private var showMoreAccessibilityLabel: String {
        InventoryLocalization.tagOverflowLabel(presentation.overflowCount)
    }

    private var showMoreCompactLabel: String {
        InventoryLocalization.formatted(
            "inventory.tags.showMore.compact",
            defaultValue: "+%d",
            presentation.overflowCount
        )
    }
}

struct InventoryTagPresentation: Identifiable, Equatable {
    let index: Int
    let value: String

    var id: Int { index }
}

struct InventoryDetailNotesCard: View {
    let notes: String
    let editAction: () -> Void

    var body: some View {
        InventoryCard {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                InventorySectionHeader("inventory.section.notes")
                    .accessibilityIdentifier("inventory.detail.notesHeader")

                Button(action: editAction) {
                    Text(visibleNotesText)
                        .font(.body)
                        .foregroundStyle(notes.isEmpty ? .secondary : .primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    InventoryLocalization.formatted(
                        "inventory.notes.card.accessibilityLabel",
                        defaultValue: "Notes: %@",
                        accessibilityNotesText
                    )
                )
                .accessibilityHint("inventory.notes.card.accessibilityHint")
                .accessibilityIdentifier("inventory.detail.notesContent")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventory.detail.notesCard")
    }

    private var visibleNotesText: String {
        notes.isEmpty
            ? InventoryLocalization.string(
                "inventory.notes.emptyPrompt",
                defaultValue: "Tap to add a note"
            )
            : notes
    }

    private var accessibilityNotesText: String {
        notes.isEmpty ? InventoryLocalization.noNotes : notes
    }
}

struct InventoryDetailDatesCard: View {
    let viewModel: InventoryItemDetailViewModel

    var body: some View {
        InventoryCard {
            VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                InventorySectionHeader("inventory.section.dates")

                dateRow(
                    title: "inventory.field.created",
                    value: viewModel.createdText(),
                    identifier: "inventory." + "itemDetail.created"
                )

                dateRow(
                    title: "inventory.field.updated",
                    value: viewModel.lastUpdatedText(),
                    identifier: "inventory." + "itemDetail.updated"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inventory.itemDetail.dates")
    }

    private func dateRow(
        title: LocalizedStringKey,
        value: String,
        identifier: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: InventoryDesign.cardPadding) {
            Text(title)
            Spacer(minLength: InventoryDesign.cardPadding)
            Text(verbatim: value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
