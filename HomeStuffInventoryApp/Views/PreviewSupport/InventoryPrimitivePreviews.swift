import SwiftUI

#if DEBUG
#Preview("Inventory Primitives") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Storage",
                subtitle: "Location-first metadata with a deliberately long line for Dynamic Type wrapping."
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: InventoryDesign.gridSpacing)], spacing: InventoryDesign.gridSpacing) {
                InventoryPropertyCard("inventory.field.location", value: "Hallway drawer with spare adapters", systemImage: "mappin.and.ellipse")
                InventoryPropertyCard("inventory.field.container", value: "Small blue box", systemImage: "shippingbox", role: .secondary)
            }

            HStack {
                InventoryBadge(verbatim: "Cables & Adapters", systemImage: "tag")
                InventoryBadge(verbatim: "Кількість: 12", systemImage: "number", role: .muted)
            }

            InventoryListRowCard {
                HStack(spacing: 12) {
                    InventoryCompactIconBubble(systemName: "shippingbox")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "Hallway cabinet")
                            .font(.headline)

                        Text(verbatim: "Compact row primitives with shared accessories")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    InventoryRowCountBadge("12 items", systemImage: "shippingbox")
                    InventoryRowChevron()
                }
            }

            InventoryEmptyStateCard(
                title: "Nothing stored yet",
                message: "Додайте речі, локації й точні місця зберігання, щоб швидко знаходити потрібне пізніше."
            ) {
                Button {} label: {
                    Text("inventory.action.addItem")
                }
                .inventoryEmptyStatePrimaryAction()
            }
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
}

#Preview("Inventory Primitives - Dark") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Дуже довга назва секції для перевірки перенесення",
                subtitle: "Quiet native surfaces, semantic colors, and no inventory behavior inside the primitive views."
            )

            InventoryCard {
                HStack(alignment: .top, spacing: InventoryDesign.rowSpacing) {
                    InventoryStorageIcon(systemName: "archivebox", role: .context)

                    VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                        Text(verbatim: "Toolbox shelf")
                            .font(.headline)

                        Text(verbatim: "Precision screwdriver set and small spare parts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
    .preferredColorScheme(.dark)
}

#Preview("Tag Badges - Adaptive Colors") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Tag badges",
                subtitle: "Content-sized tags with deterministic shared tint tokens."
            )

            InventoryPrimitiveTagPreviewCloud(tags: [
                "USB",
                "Tools",
                "Travel",
                "Spare Parts",
                "Documents",
                "Guest kit"
            ])
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
}

#Preview("Tag Badges - Ukrainian Long Tags") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Українські теги",
                subtitle: "Довгі назви мають безпечно обрізатися без фіксованої ширини коротких тегів."
            )

            InventoryPrimitiveTagPreviewCloud(tags: [
                "кабелі",
                "подорожі",
                "документи",
                "запасні частини",
                "дуже довгий український тег для прозорого органайзера"
            ])
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
    .environment(\.locale, Locale(identifier: "uk"))
}

#Preview("Tag Badges - Dark Dynamic Type") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Adaptive tag badges",
                subtitle: "Large text and dark appearance keep the badge surface readable."
            )

            InventoryPrimitiveTagPreviewCloud(tags: [
                "USB",
                "Travel",
                "запасні кабелі для гостей",
                "дуже довгий український тег для прозорого органайзера"
            ])
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Hero Primitives - Large And Compact") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Hero cards",
                subtitle: "Large detail and compact row presentations share the same calm location-first styling."
            )

            InventoryHeroCard(presentation: .detail) {
                HStack(alignment: .top, spacing: 14) {
                    InventoryHeroIcon(
                        systemName: "cabinet",
                        displayName: "Cabinet",
                        size: 72,
                        symbolSize: 34,
                        cornerRadius: 24,
                        presentation: .elevated
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "Hallway cabinet")
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(verbatim: "Upper shelf, clear organizer with spare adapters and travel chargers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            InventoryHeroCard(presentation: .compact) {
                HStack(spacing: 12) {
                    InventoryHeroIcon(
                        systemName: "tray.full",
                        displayName: "All items",
                        size: 52,
                        symbolSize: 24,
                        cornerRadius: 18,
                        presentation: .compact
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "All items in this location")
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(verbatim: "12 items")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    InventoryRowChevron()
                }
            }
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
}

#Preview("Inventory Primitives - Accessibility Ukrainian") {
    ScrollView {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventorySectionHeader(
                verbatim: "Дуже довга назва секції зберігання",
                subtitle: "Перевірка перенесення довгого українського тексту у великих розмірах Dynamic Type."
            )

            InventoryCard {
                VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                    InventoryStorageIcon(
                        systemName: "cabinet",
                        role: .context,
                        accessibilityLabel: "Шафа у передпокої"
                    )

                    Text(verbatim: "Запасні зарядні кабелі для гостей і подорожей")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verbatim: "Шафа у передпокої, верхня полиця, прозорий органайзер з довгою етикеткою")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            InventoryCard(surface: .content) {
                VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                    Text(verbatim: "Semantic fallback surface")
                        .font(.headline)

                    Text(verbatim: "This plain card checks readability when native glass is unavailable or intentionally skipped.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            InventoryListRowCard {
                HStack(spacing: 12) {
                    InventoryCompactIconBubble(systemName: "archivebox", role: .context)

                    Text(verbatim: "Reusable row accessory preview")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    InventoryRowDefaultBadge(verbatim: "Default")
                    InventoryRowOverflowMenu(accessibilityLabel: "Preview actions") {
                        Button("Rename") { }
                        Button("Delete", role: .destructive) { }
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    InventoryBadge(verbatim: "довга категорія побутових речей", systemImage: "tag")
                    InventoryBadge(verbatim: "Кількість: 999", systemImage: "number", role: .muted)
                }

                VStack(alignment: .leading, spacing: 6) {
                    InventoryBadge(verbatim: "довга категорія побутових речей", systemImage: "tag")
                    InventoryBadge(verbatim: "Кількість: 999", systemImage: "number", role: .muted)
                }
            }
        }
        .padding(InventoryDesign.screenPadding)
    }
    .inventoryGroupedBackground()
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Editor Surfaces - Focus States") {
    InventoryPrimitiveEditorPreview()
}

#Preview("Inventory Primitives - Dark Empty State") {
    InventoryEmptyStateScreen {
        InventoryEmptyStateCard(
            title: "No matching household items",
            message: "Clear the search or record a new item with a location and exact storage place.",
            systemImage: "magnifyingglass"
        ) {
            Button("Clear search") { }
                .inventoryEmptyStatePrimaryAction()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty State Screen - Accessibility Ukrainian") {
    InventoryEmptyStateScreen {
        InventoryEmptyStateCard(
            title: "Поки що немає збережених речей у цій локації",
            message: "Додайте речі з локацією та точним місцем зберігання, щоб цей екран міг швидко показати, де саме вони лежать.",
            systemImage: "map"
        ) {
            Button("Додати річ") { }
                .inventoryEmptyStatePrimaryAction()
        }
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Soft Cabinet Appearance Roles - Light") {
    InventoryAppearanceRolesPreview()
}

#Preview("Soft Cabinet Appearance Roles - Dark") {
    InventoryAppearanceRolesPreview()
        .preferredColorScheme(.dark)
}

#Preview("Cabinet Atlas Semantic Surface Roles - Light") {
    InventorySemanticSurfaceRolesPreview()
}

#Preview("Cabinet Atlas Semantic Surface Roles - Dark") {
    InventorySemanticSurfaceRolesPreview()
        .preferredColorScheme(.dark)
}

#Preview("Content Glyphs - Light") {
    InventoryContentGlyphsPreview()
}

#Preview("Content Glyphs - Dark") {
    InventoryContentGlyphsPreview()
        .preferredColorScheme(.dark)
}

#Preview("Content Glyphs - Accessibility") {
    InventoryContentGlyphsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Soft Cabinet Components - Light") {
    InventorySoftCabinetComponentsPreview()
}

#Preview("Soft Cabinet Components - Dark") {
    InventorySoftCabinetComponentsPreview()
        .preferredColorScheme(.dark)
}

private struct InventoryAppearanceRolesPreview: View {
    private let accents: [(String, Color)] = [
        ("Storage", InventoryDesign.Appearance.storageAccent),
        ("Primary action", InventoryDesign.Appearance.primaryAction),
        ("Secondary", InventoryDesign.Appearance.secondaryAccent),
        ("Recent / context", InventoryDesign.Appearance.contextHighlight)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                InventorySectionHeader(
                    verbatim: "Soft Cabinet appearance",
                    subtitle: "Semantic roles adapt together without relying on one global tint."
                )

                InventoryCard {
                    VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                        Label("Opaque content surface", systemImage: "cabinet")
                            .font(.headline)
                            .foregroundStyle(InventoryDesign.Appearance.storageAccent)

                        Text(verbatim: "Dense inventory text stays on an opaque, stroked surface.")
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 142), spacing: InventoryDesign.gridSpacing)],
                    spacing: InventoryDesign.gridSpacing
                ) {
                    ForEach(accents.indices, id: \.self) { index in
                        InventoryAppearanceSwatch(
                            name: accents[index].0,
                            color: accents[index].1
                        )
                    }
                }

                Button("Primary action") { }
                    .inventoryEmptyStatePrimaryAction()
            }
            .padding(InventoryDesign.screenPadding)
        }
        .background {
            InventoryDesign.Appearance.locationAtmosphere
                .padding(.top, 150)
                .background(InventoryDesign.Appearance.groupedBackground)
        }
    }
}

private struct InventorySemanticSurfaceRolesPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                InventorySectionHeader(
                    verbatim: "Cabinet Atlas surface roles",
                    subtitle: "Item, Location, Storage Place, and neutral content retain the existing opaque surface behavior."
                )

                ForEach(InventoryDesign.SurfaceRole.allCases) { role in
                    VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                        HStack(spacing: 6) {
                            Image(systemName: role.systemImage)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            Text(verbatim: role.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Text(verbatim: role.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(InventoryDesign.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inventorySemanticSurface(role, cornerRadius: InventoryDesign.cardCornerRadius)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(InventoryDesign.screenPadding)
        }
        .inventoryLocationAtmosphereBackground()
    }
}

private struct InventoryContentGlyphsPreview: View {
    private let glyphs: [(name: String, systemName: String, role: InventoryDesign.AccentRole)] = [
        ("Item", "shippingbox", .secondary),
        ("Location", "map", .storage),
        ("Storage Place", "cabinet", .place),
        ("Recent", "clock", .context),
        ("Muted", "tray", .muted)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                InventorySectionHeader(
                    verbatim: "Content glyphs",
                    subtitle: "Semantically tinted symbols use an invisible optical frame, without a visible icon container."
                )

                ForEach(glyphs.indices, id: \.self) { index in
                    HStack(spacing: InventoryDesign.rowSpacing) {
                        InventoryContentGlyph(
                            systemName: glyphs[index].systemName,
                            role: glyphs[index].role,
                            accessibilityLabel: glyphs[index].name
                        )

                        InventoryContentGlyph(
                            systemName: glyphs[index].systemName,
                            role: glyphs[index].role,
                            accessibilityLabel: glyphs[index].name,
                            presentation: .identity
                        )

                        Text(verbatim: glyphs[index].name)
                            .font(.headline)
                    }
                }
            }
            .padding(InventoryDesign.screenPadding)
        }
        .inventoryGroupedBackground()
    }
}

private struct InventorySoftCabinetComponentsPreview: View {
    private let placePreview = InventoryPreviewGroupPresentation(
        InventoryBrowseSummaries.PreviewGroup(
            kind: .place,
            visibleItems: [
                .init(id: "desk-drawer", title: "Desk drawer"),
                .init(id: "parts-box", title: "PC parts box")
            ],
            hiddenCount: 1
        )
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                InventoryHeroCard {
                    InventoryDetailHeroHeader(iconSystemName: "briefcase") {
                        InventoryDetailHeroTitleStack(
                            title: "Office",
                            subtitle: "Location · 12 items"
                        )
                    }
                }

                InventoryCard {
                    VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
                        Text(verbatim: "Opaque inventory content")
                            .font(.headline)

                        Text(verbatim: "Dense notes and metadata remain readable over the Location atmosphere.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                InventoryListRowCard {
                    HStack(alignment: .top, spacing: 12) {
                        InventoryCompactIconBubble(systemName: "cabinet")

                        VStack(alignment: .leading, spacing: InventoryDesign.previewGroupSectionSpacing) {
                            Text(verbatim: "Hallway cabinet")
                                .font(.headline)

                            if let placePreview {
                                InventoryPreviewGroupRow(placePreview)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        InventoryRowChevron()
                    }
                }

                InventoryListRowCard {
                    HStack(spacing: 12) {
                        InventoryCompactIconBubble(systemName: "shippingbox.circle", role: .muted)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "No Storage Place recorded")
                                .font(.headline)

                            Text(verbatim: "3 items need an exact drawer, box, shelf, cabinet, or organizer.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        InventoryRowCountBadge("3", role: .muted)
                        InventoryRowChevron()
                    }
                }
            }
            .padding(InventoryDesign.screenPadding)
        }
        .inventoryLocationAtmosphereBackground()
    }
}

private extension InventoryDesign.SurfaceRole {
    var name: String {
        switch self {
        case .item: "Item"
        case .location: "Location"
        case .place: "Storage Place"
        case .context: "Recent / context"
        case .neutral: "Neutral content"
        }
    }

    var description: String {
        switch self {
        case .item: "An inventory object surface for an identified household item."
        case .location: "A spatial surface for a room or broad storage area."
        case .place: "An exact drawer, box, shelf, cabinet, or organizer surface."
        case .context: "A contextual surface for recently viewed Items."
        case .neutral: "Supporting content that does not represent an Item, Location, or Storage Place."
        }
    }

    var systemImage: String {
        switch self {
        case .item: "shippingbox"
        case .location: "map"
        case .place: "cabinet"
        case .context: "clock"
        case .neutral: "square.text.square"
        }
    }
}

private struct InventoryAppearanceSwatch: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
            RoundedRectangle(cornerRadius: InventoryDesign.compactCornerRadius, style: .continuous)
                .fill(color)
                .frame(height: 56)

            Text(verbatim: name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(InventoryDesign.compactCardPadding)
        .background(InventoryDesign.Appearance.contentSurface)
        .clipShape(RoundedRectangle(cornerRadius: InventoryDesign.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: InventoryDesign.cardCornerRadius, style: .continuous)
                .strokeBorder(InventoryDesign.Appearance.contentStroke, lineWidth: InventoryDesign.Stroke.card)
        }
    }
}

private struct InventoryPrimitiveEditorPreview: View {
    @State private var focusedNotes = "Focused editor surface for notes, with enough text to wrap on narrow widths."
    @State private var unfocusedNotes = "Unfocused editor surface keeps the field readable without competing with content cards."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
                InventorySectionHeader(
                    verbatim: "Editor surfaces",
                    subtitle: "Focused and unfocused states use shared form/editor chrome."
                )

                editorCard(title: "Focused notes", text: $focusedNotes, isFocused: true)
                editorCard(title: "Unfocused notes", text: $unfocusedNotes, isFocused: false)

                Text(verbatim: "Name is required.")
                    .inventoryValidationMessage()

                Text(verbatim: "Add the exact drawer, box, shelf, cabinet, or organizer when known.")
                    .inventoryHelperText()
            }
            .padding(InventoryDesign.screenPadding)
        }
        .inventoryGroupedBackground()
    }

    private func editorCard(title: String, text: Binding<String>, isFocused: Bool) -> some View {
        VStack(alignment: .leading, spacing: InventoryDesign.rowSpacing) {
            Text(verbatim: title)
                .font(.headline)

            TextEditor(text: text)
                .inventoryEditorTextStyle(minHeight: 96)
                .inventoryEditorSurface(isFocused: isFocused)
        }
    }
}

private struct InventoryPrimitiveTagPreviewCloud: View {
    let tags: [String]

    var body: some View {
        InventoryTagCloudLayout(
            horizontalSpacing: InventoryDesign.tagBadgeHorizontalSpacing,
            verticalSpacing: InventoryDesign.tagBadgeVerticalSpacing,
            rowAlignment: .leading
        ) {
            ForEach(tags, id: \.self) { tag in
                InventoryTagBadge(tag)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
