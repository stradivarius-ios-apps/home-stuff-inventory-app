import SwiftData
import SwiftUI

struct LocationDetailIdentityHeader: View {
    let location: InventoryBrowseSummaries.LocationSummary

    var body: some View {
        InventoryDetailIdentityHeader(
            iconSystemName: locationIconSystemName,
            contentRole: .location,
            title: location.name,
            secondary: Text(verbatim: itemCountText),
            accessibilityLabel: Text(summaryAccessibilityLabel),
            accessibilityIdentifier: "locations." + "detailHero",
            titleAccessibilityIdentifier: "locations." + "detailHero.title",
            secondaryAccessibilityIdentifier: "locations." + "detailHero.subtitle"
        )
    }

    private var locationIconSystemName: String {
        location.isMissingLocation
            ? LocationIconCatalog.missingLocationSymbolName
            : LocationIconCatalog.symbolName(for: location.iconID)
    }

    private var itemCountText: String {
        InventoryLocalization.itemCount(location.itemCount)
    }

    private var summaryAccessibilityLabel: String {
        return InventoryLocalization.formatted(
            "locations.detailHero.accessibilityLabel",
            defaultValue: "Location summary, %@, %@",
            location.name,
            itemCountText
        )
    }
}

struct PlaceDetailIdentityHeader: View {
    let place: InventoryBrowseSummaries.PlaceSummary
    @Query private var places: [InventoryPlace]

    var body: some View {
        InventoryDetailIdentityHeader(
            iconSystemName: placeIconSystemName,
            contentRole: .place,
            title: place.name,
            secondary: Text(verbatim: itemCountText),
            secondaryLeadingMetadata: parentLocationText,
            accessibilityLabel: Text(summaryAccessibilityLabel),
            accessibilityIdentifier: "locations." + "placeDetailHero",
            titleAccessibilityIdentifier: "locations." + "placeDetailHero.title",
            secondaryAccessibilityIdentifier: "locations." + "placeDetailHero.subtitle",
            secondaryLeadingAccessibilityIdentifier: "locations." + "placeDetailHero.parentLocation"
        )
    }

    private var parentLocationText: Text {
        Text(verbatim: place.locationName)
            .foregroundColor(place.isMissingLocation ? .secondary : InventoryDesign.ContentRole.location.color)
    }

    private var itemCountText: String {
        InventoryLocalization.itemCount(place.itemCount)
    }

    private var parentLocationAccessibilityText: String {
        InventoryLocalization.formatted(
            "locations.placeDetailHero.parentLocation.accessibilityText",
            defaultValue: "Location: %@",
            place.locationName
        )
    }

    private var placeIconSystemName: String {
        InventoryPlaceIconPresentation.symbolName(placeID: place.placeID, isMissingPlace: place.isMissingPlace, places: places)
    }

    private var summaryAccessibilityLabel: String {
        return InventoryLocalization.formatted(
            "locations.placeDetailHero.accessibilityLabel",
            defaultValue: "Storage Place summary, %1$@, %2$@, %3$@",
            place.name,
            parentLocationAccessibilityText,
            itemCountText
        )
    }
}

#if DEBUG
#Preview("Location Detail Hero - Normal") {
    InventoryDetailPreviewSurface {
        LocationDetailIdentityHeader(location: .locationDetailHeroNormal)
    }
}

#Preview("Location Detail Hero - Long Ukrainian") {
    InventoryDetailPreviewSurface {
        LocationDetailIdentityHeader(location: .locationDetailHeroLongUkrainian)
    }
    .environment(\.locale, Locale(identifier: "uk"))
}

#Preview("Location Detail Hero - No Recent Items") {
    InventoryDetailPreviewSurface {
        LocationDetailIdentityHeader(location: .locationDetailHeroNoRecentItems)
    }
}

#Preview("Location Detail Hero - Missing Location") {
    InventoryDetailPreviewSurface {
        LocationDetailIdentityHeader(location: .locationDetailHeroMissingLocation)
    }
}

#Preview("Location Detail Hero - Large Dynamic Type") {
    InventoryDetailPreviewSurface {
        LocationDetailIdentityHeader(location: .locationDetailHeroLongUkrainian)
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Location Detail Hero - Dark") {
    InventoryDetailPreviewSurface {
        LocationDetailIdentityHeader(location: .locationDetailHeroNormal)
    }
    .preferredColorScheme(.dark)
}

#Preview("Place Detail Hero - Accessibility") {
    InventoryDetailPreviewSurface {
        PlaceDetailIdentityHeader(place: .placeDetailHeroAccessibility)
    }
    .environment(\.locale, Locale(identifier: "uk"))
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Place Detail Hero - Normal") {
    InventoryDetailPreviewSurface {
        PlaceDetailIdentityHeader(place: .placeDetailHeroNormal)
    }
}

#Preview("Place Detail Hero - Long Name") {
    InventoryDetailPreviewSurface {
        PlaceDetailIdentityHeader(place: .placeDetailHeroLongName)
    }
}

#Preview("Place Detail Hero - Dark") {
    InventoryDetailPreviewSurface {
        PlaceDetailIdentityHeader(place: .placeDetailHeroNormal)
    }
    .preferredColorScheme(.dark)
}

#Preview("Place Detail Hero - Missing Place And Location") {
    InventoryDetailPreviewSurface {
        PlaceDetailIdentityHeader(place: .placeDetailHeroMissingPlaceAndLocation)
    }
    .environment(\.locale, Locale(identifier: "uk"))
}

#Preview("Place Detail Hero - 320 pt") {
    InventoryDetailPreviewSurface {
        PlaceDetailIdentityHeader(place: .placeDetailHeroNormal)
    }
    .frame(width: 320)
}

private extension InventoryBrowseSummaries.LocationSummary {
    static var locationDetailHeroNormal: InventoryBrowseSummaries.LocationSummary {
        InventoryBrowseSummaries.LocationSummary(
            name: "Вітальня",
            iconID: "sofa",
            itemCount: 3,
            isMissingLocation: false,
            previewGroups: [
                .init(
                    kind: .category,
                    visibleItems: [
                        .init(id: "documents", title: "Документи"),
                        .init(id: "tools", title: "Інструменти")
                    ],
                    hiddenCount: 1
                ),
                .init(
                    kind: .place,
                    visibleItems: [
                        .init(id: "dresser", title: "Комод"),
                        .init(id: "desk-tray", title: "Лоток Біля Компʼютерного Столу")
                    ],
                    hiddenCount: 1
                ),
                .init(
                    kind: .recentItem,
                    visibleItems: [
                        .init(id: "screwdrivers", title: "Набір Викруток"),
                        .init(id: "iphone-cases", title: "Чохли Для iPhone 17 Pro"),
                        .init(id: "stalker-cards", title: "Набір Карток S.T.A.L.K.E.R. 2")
                    ],
                    hiddenCount: 0
                )
            ]
        )
    }

    static var locationDetailHeroLongUkrainian: InventoryBrowseSummaries.LocationSummary {
        InventoryBrowseSummaries.LocationSummary(
            name: "Шафа у передпокої з дуже довгою назвою",
            iconID: "closet",
            itemCount: 14,
            isMissingLocation: false,
            previewGroups: [
                .init(
                    kind: .category,
                    visibleItems: [
                        .init(id: "household", title: "Побутові речі"),
                        .init(id: "travel", title: "Для вулиці й подорожей"),
                        .init(id: "documents", title: "Документи")
                    ],
                    hiddenCount: 2
                ),
                .init(
                    kind: .place,
                    visibleItems: [
                        .init(id: "organizer", title: "Прозорий органайзер на верхній полиці"),
                        .init(id: "bag", title: "Дорожня сумка біля дверей"),
                        .init(id: "drawer", title: "Нижня шухляда")
                    ],
                    hiddenCount: 1
                ),
                .init(
                    kind: .recentItem,
                    visibleItems: [
                        .init(id: "charger", title: "Набір запасних зарядних кабелів"),
                        .init(id: "cards", title: "Гарантійні документи")
                    ],
                    hiddenCount: 0
                )
            ]
        )
    }

    static var locationDetailHeroNoRecentItems: InventoryBrowseSummaries.LocationSummary {
        InventoryBrowseSummaries.LocationSummary(
            name: "Garage shelves",
            iconID: "garage",
            itemCount: 6,
            isMissingLocation: false,
            previewGroups: [
                .init(
                    kind: .category,
                    visibleItems: [
                        .init(id: "tools", title: "Tools"),
                        .init(id: "spare-parts", title: "Spare Parts")
                    ],
                    hiddenCount: 0
                ),
                .init(
                    kind: .place,
                    visibleItems: [
                        .init(id: "pegboard", title: "Pegboard bins"),
                        .init(id: "toolbox", title: "Red toolbox")
                    ],
                    hiddenCount: 0
                )
            ]
        )
    }

    static var locationDetailHeroMissingLocation: InventoryBrowseSummaries.LocationSummary {
        InventoryBrowseSummaries.LocationSummary(
            name: InventoryLocalization.noLocation,
            itemCount: 2,
            isMissingLocation: true,
            previewGroups: [
                .init(
                    kind: .category,
                    visibleItems: [
                        .init(id: "documents", title: "Documents"),
                        .init(id: "misc", title: "Miscellaneous")
                    ],
                    hiddenCount: 0
                ),
                .init(
                    kind: .place,
                    visibleItems: [
                        .init(id: "unknown-box", title: "Unknown box"),
                        .init(id: "temporary-bag", title: "Temporary bag by the entryway")
                    ],
                    hiddenCount: 0
                )
            ]
        )
    }
}

private extension InventoryBrowseSummaries.PlaceSummary {
    static var placeDetailHeroNormal: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.PlaceSummary(
            id: "Комора::Сіра Коробка",
            name: "Сіра Коробка",
            itemCount: 1,
            locationID: "Комора",
            locationName: "Комора",
            isMissingLocation: false,
            isMissingPlace: false,
            categoryPreview: [InventoryCategory.miscellaneous.displayName]
        )
    }

    static var placeDetailHeroAccessibility: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.PlaceSummary(
            id: "Передпокій::__missing_place__",
            name: InventoryLocalization.noContainer,
            itemCount: 4,
            locationID: "Передпокій",
            locationName: "Шафа у передпокої з дуже довгою назвою",
            isMissingLocation: false,
            isMissingPlace: true,
            categoryPreview: [
                InventoryCategory.householdSupplies.displayName,
                InventoryCategory.tools.displayName
            ]
        )
    }

    static var placeDetailHeroLongName: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.PlaceSummary(
            id: "Комора::органайзер-для-зарядних-пристроїв",
            name: "Органайзер для зарядних пристроїв, кабелів і перехідників на верхній полиці",
            itemCount: 12,
            locationID: "Комора",
            locationName: "Комора біля вхідних дверей із сезонними речами",
            isMissingLocation: false,
            isMissingPlace: false
        )
    }

    static var placeDetailHeroMissingPlaceAndLocation: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.PlaceSummary(
            id: "__missing_location__::__missing_place__",
            name: InventoryLocalization.noContainer,
            itemCount: 0,
            locationID: "__missing_location__",
            locationName: InventoryLocalization.noLocation,
            isMissingLocation: true,
            isMissingPlace: true
        )
    }
}
#endif
