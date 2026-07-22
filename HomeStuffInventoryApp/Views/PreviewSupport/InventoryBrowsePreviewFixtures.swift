import Foundation

#if DEBUG
extension InventoryItem {
    static var previewLongEnglish: InventoryItem {
        InventoryItem(
            id: UUID(uuidString: "C0A9A8F2-CC8B-4F3D-AB59-120B68D8D901")!,
            name: "USB-C multiport adapter with unusually long household label",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Hallway cabinet with spare electronics and travel accessories",
            containerName: "Clear organizer tray on the upper shelf near the router box",
            iconID: "cable",
            quantity: 12,
            condition: InventoryCondition.good.rawValue,
            tags: ["usb-c", "display adapter", "travel desk setup", "guest cables"],
            notes: "Kept with travel chargers so it is easy to find before presentations or family trips.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_704_320_000)
        )
    }

    static var previewLongUkrainian: InventoryItem {
        InventoryItem(
            id: UUID(uuidString: "C0A9A8F2-CC8B-4F3D-AB59-120B68D8D902")!,
            name: "Набір запасних зарядних кабелів для гостей і подорожей",
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: "Шафа у передпокої з довгою назвою місця зберігання",
            containerName: "Прозорий контейнер на верхній полиці біля дорожніх сумок",
            iconID: "power-plug",
            quantity: 8,
            condition: InventoryCondition.new.rawValue,
            tags: ["зарядні кабелі", "подорожі", "гості", "USB-C"],
            notes: "Підходить для перевірки довгих українських підписів, нотаток і перенесення тексту у великих розмірах Dynamic Type.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_704_320_000)
        )
    }

    static var previewMissingStorage: InventoryItem {
        InventoryItem(
            id: UUID(uuidString: "C0A9A8F2-CC8B-4F3D-AB59-120B68D8D903")!,
            name: "Loose warranty card",
            category: InventoryCategory.documents.rawValue,
            locationName: "",
            containerName: nil,
            iconID: "document",
            quantity: 1,
            condition: InventoryCondition.unknown.rawValue,
            tags: [],
            notes: "",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_704_320_000)
        )
    }
}

extension InventoryBrowseSummaries.LocationSummary {
    static var previewWithPreviewGroups: InventoryBrowseSummaries.LocationSummary {
        InventoryBrowseSummaries.LocationSummary(
            name: "Living room",
            iconID: "cabinet",
            itemCount: 8,
            isMissingLocation: false,
            previewGroups: [
                .init(
                    kind: .category,
                    visibleItems: [
                        .init(id: "documents", title: "Documents"),
                        .init(id: "tools", title: "Tools"),
                        .init(id: "cables", title: "Cables & Adapters")
                    ],
                    hiddenCount: 1
                ),
                .init(
                    kind: .place,
                    visibleItems: [
                        .init(id: "dresser", title: "Dresser"),
                        .init(id: "console tray", title: "Console tray by the TV"),
                        .init(id: "lower shelf", title: "Lower shelf")
                    ],
                    hiddenCount: 1
                ),
                .init(
                    kind: .recentItem,
                    visibleItems: [
                        .init(id: "cards", title: "Family card set"),
                        .init(id: "manuals", title: "Router manuals")
                    ],
                    hiddenCount: 0
                )
            ]
        )
    }

    static var previewLongPlaces: InventoryBrowseSummaries.LocationSummary {
        InventoryBrowseSummaries.LocationSummary(
            name: "Storage room with seasonal household supplies",
            iconID: "cabinet",
            itemCount: 24,
            isMissingLocation: false,
            placePreview: [
                "Clear hardware drawer with long label",
                "Top shelf near tool batteries",
                "Blue cable organizer"
            ]
        )
    }

    static var previewLongUkrainianGroups: InventoryBrowseSummaries.LocationSummary {
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

    static var previewNoRecentItems: InventoryBrowseSummaries.LocationSummary {
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
                        .init(id: "spare parts", title: "Spare Parts"),
                        .init(id: "outdoor", title: "Outdoor & Travel")
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

    static var previewMissingLocation: InventoryBrowseSummaries.LocationSummary {
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
                        .init(id: "unknown box", title: "Unknown box"),
                        .init(id: "temporary bag", title: "Temporary bag by the entryway")
                    ],
                    hiddenCount: 0
                )
            ]
        )
    }
}

extension InventoryBrowseSummaries.PlaceSummary {
    static var previewLongName: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.PlaceSummary(
            id: "Storage::clear hardware drawer",
            name: "Clear hardware drawer with unusually long label",
            itemCount: 12,
            locationID: "Storage",
            locationName: "Storage",
            isMissingLocation: false,
            isMissingPlace: false
        )
    }

    static var previewMissingPlace: InventoryBrowseSummaries.PlaceSummary {
        InventoryBrowseSummaries.PlaceSummary(
            id: "Storage::__missing_place__",
            name: InventoryLocalization.noContainer,
            itemCount: 3,
            locationID: "Storage",
            locationName: "Storage",
            isMissingLocation: false,
            isMissingPlace: true
        )
    }
}
#endif
