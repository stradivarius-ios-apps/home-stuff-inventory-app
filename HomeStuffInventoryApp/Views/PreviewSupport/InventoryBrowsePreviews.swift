import SwiftUI

#if DEBUG
#Preview("Inventory List - Light") {
    NavigationStack {
        InventoryListView(presentation: .compactInventory)
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .environment(PremiumAccessState(debugPreset: .lifetimePro))
    .preferredColorScheme(.light)
}

#Preview("Inventory List - Dark") {
    NavigationStack {
        InventoryListView(presentation: .compactInventory)
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .environment(PremiumAccessState(debugPreset: .lifetimePro))
    .preferredColorScheme(.dark)
}

#Preview("Inventory List - 320 pt") {
    NavigationStack {
        InventoryListView(presentation: .compactInventory)
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .environment(PremiumAccessState(debugPreset: .lifetimePro))
    .frame(width: 320)
    .preferredColorScheme(.light)
}

#Preview("Locations") {
    NavigationStack {
        LocationsListView()
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
}

#Preview("Inventory Row - Long English") {
    InventoryDetailPreviewSurface {
        InventoryItemRowView(item: .previewLongEnglish)
    }
    .preferredColorScheme(.light)
}

#Preview("Inventory Row - Accessibility Ukrainian") {
    InventoryDetailPreviewSurface {
        InventoryItemRowView(item: .previewLongUkrainian)
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Inventory Row - Missing Storage") {
    InventoryDetailPreviewSurface {
        InventoryItemRowView(item: .previewMissingStorage)
    }
    .preferredColorScheme(.dark)
}

#Preview("Location Row - Preview Groups") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewWithPreviewGroups)
    }
}

#Preview("Location Row - Dark") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewWithPreviewGroups)
    }
    .preferredColorScheme(.dark)
}

#Preview("Location Row - 320 pt") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewLongUkrainianGroups)
    }
    .frame(width: 320)
    .environment(\.locale, Locale(identifier: "uk"))
}

#Preview("Location Row - Ukrainian Labels") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewLongUkrainianGroups)
    }
    .environment(\.locale, Locale(identifier: "uk"))
}

#Preview("Location Row - Accessibility") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewLongUkrainianGroups)
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Location Row - No Recent Items") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewNoRecentItems)
    }
}

#Preview("Location Row - Missing Location") {
    InventoryDetailPreviewSurface {
        LocationSummaryRowView(location: .previewMissingLocation)
    }
    .preferredColorScheme(.dark)
}

#Preview("All Items Hero - Compact") {
    InventoryDetailPreviewSurface {
        LocationAllItemsRowView(location: .previewLongPlaces)
    }
}

#Preview("All Items Hero - Accessibility") {
    InventoryDetailPreviewSurface {
        LocationAllItemsRowView(location: .previewLongPlaces)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Place Row - Long Name") {
    InventoryDetailPreviewSurface {
        PlaceSummaryRowView(place: .previewLongName)
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Place Row - Missing Place") {
    InventoryDetailPreviewSurface {
        PlaceSummaryRowView(place: .previewMissingPlace)
    }
    .preferredColorScheme(.dark)
}

#Preview("Active Filter Header - Accessibility") {
    InventoryDetailPreviewSurface {
        ActiveInventoryFilterContextHeader(
            context: InventoryFilterContext(
                resultCount: 3,
                searchText: "very long HDMI charging adapter",
                category: "Cables & Adapters",
                locationName: "Hallway cabinet with spare electronics"
            )
        ) { }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Detail Identity And Storage - Long Ukrainian") {
    InventoryDetailPreviewSurface {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventoryItemDetailIdentityHeader(viewModel: InventoryItemDetailViewModel(item: .previewLongUkrainian))
            InventoryDetailStorageAnswerCard(viewModel: InventoryItemDetailViewModel(item: .previewLongUkrainian))
        }
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Detail Identity And Storage - Missing Storage") {
    InventoryDetailPreviewSurface {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventoryItemDetailIdentityHeader(viewModel: InventoryItemDetailViewModel(item: .previewMissingStorage))
            InventoryDetailStorageAnswerCard(viewModel: InventoryItemDetailViewModel(item: .previewMissingStorage))
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Detail Tags And Notes - Accessibility") {
    InventoryDetailPreviewSurface {
        VStack(alignment: .leading, spacing: InventoryDesign.gridSpacing) {
            InventoryDetailNotesPreview(notes: InventoryItem.previewLongUkrainian.notes)

            InventoryDetailTagsCard(tags: InventoryItem.previewLongUkrainian.tags)

            InventoryDetailDatesCard(viewModel: InventoryItemDetailViewModel(item: .previewLongUkrainian))
        }
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Detail Tags - Long Accessibility") {
    InventoryDetailPreviewSurface {
        InventoryDetailTagsCard(
            tags: [
                "travel desk setup for family presentations",
                "USB-C",
                "гостьові зарядні кабелі для тривалих подорожей"
            ]
        )
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Item Detail - Missing Storage") {
    NavigationStack {
        InventoryItemDetailView(item: .previewMissingStorage)
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
}

#Preview("Item Detail - Dark") {
    NavigationStack {
        InventoryItemDetailView(item: .previewLongEnglish)
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .preferredColorScheme(.dark)
}

#Preview("Item Detail - 320 pt") {
    NavigationStack {
        InventoryItemDetailView(item: .previewLongEnglish)
    }
    .modelContainer(try! InventoryModelContainer.makeSample())
    .frame(width: 320)
}

private struct InventoryDetailNotesPreview: View {
    let notes: String

    var body: some View {
        InventoryDetailNotesCard(notes: notes, editAction: { })
    }
}
#endif
