import Foundation

enum LocationIconCategory: String, CaseIterable, Identifiable {
    case home
    case livingAreas
    case kitchenAndDining
    case storage
    case garageAndTools
    case office
    case bedroomAndCloset
    case bathroomAndLaundry
    case outdoorAndUtility

    var id: String {
        rawValue
    }

    var titleKey: String {
        "locationIcons.category.\(rawValue)"
    }
}

struct LocationIconOption: Identifiable, Hashable {
    let id: String
    let symbolName: String
    let nameKey: String
    let category: LocationIconCategory
}

enum LocationIconCatalog {
    static let fallbackSymbolName = "mappin.and.ellipse"
    static let missingLocationSymbolName = "mappin.slash"

    static let options: [LocationIconOption] = [
        LocationIconOption(id: "home", symbolName: "house", nameKey: "locationIcons.option.home", category: .home),
        LocationIconOption(id: "entryway", symbolName: "door.left.hand.open", nameKey: "locationIcons.option.entryway", category: .home),
        LocationIconOption(id: "room", symbolName: "square.grid.2x2", nameKey: "locationIcons.option.room", category: .home),

        LocationIconOption(id: "living-room", symbolName: "sofa", nameKey: "locationIcons.option.livingRoom", category: .livingAreas),
        LocationIconOption(id: "tv-area", symbolName: "tv", nameKey: "locationIcons.option.tvArea", category: .livingAreas),
        LocationIconOption(id: "lamp-area", symbolName: "lamp.floor", nameKey: "locationIcons.option.lampArea", category: .livingAreas),

        LocationIconOption(id: "kitchen", symbolName: "fork.knife", nameKey: "locationIcons.option.kitchen", category: .kitchenAndDining),
        LocationIconOption(id: "coffee-station", symbolName: "cup.and.saucer", nameKey: "locationIcons.option.coffeeStation", category: .kitchenAndDining),
        LocationIconOption(id: "refrigerator", symbolName: "refrigerator", nameKey: "locationIcons.option.refrigerator", category: .kitchenAndDining),

        LocationIconOption(id: "box", symbolName: "shippingbox", nameKey: "locationIcons.option.box", category: .storage),
        LocationIconOption(id: "archive", symbolName: "archivebox", nameKey: "locationIcons.option.archive", category: .storage),
        LocationIconOption(id: "cabinet", symbolName: "cabinet", nameKey: "locationIcons.option.cabinet", category: .storage),
        LocationIconOption(id: "tray", symbolName: "tray.full", nameKey: "locationIcons.option.tray", category: .storage),

        LocationIconOption(id: "garage", symbolName: "car", nameKey: "locationIcons.option.garage", category: .garageAndTools),
        LocationIconOption(id: "tools", symbolName: "wrench.and.screwdriver", nameKey: "locationIcons.option.tools", category: .garageAndTools),
        LocationIconOption(id: "workbench", symbolName: "hammer", nameKey: "locationIcons.option.workbench", category: .garageAndTools),

        LocationIconOption(id: "office", symbolName: "desktopcomputer", nameKey: "locationIcons.option.office", category: .office),
        LocationIconOption(id: "files", symbolName: "folder", nameKey: "locationIcons.option.files", category: .office),
        LocationIconOption(id: "books", symbolName: "books.vertical", nameKey: "locationIcons.option.books", category: .office),

        LocationIconOption(id: "bedroom", symbolName: "bed.double", nameKey: "locationIcons.option.bedroom", category: .bedroomAndCloset),
        LocationIconOption(id: "closet", symbolName: "hanger", nameKey: "locationIcons.option.closet", category: .bedroomAndCloset),
        LocationIconOption(id: "wardrobe", symbolName: "cabinet", nameKey: "locationIcons.option.wardrobe", category: .bedroomAndCloset),

        LocationIconOption(id: "bathroom", symbolName: "shower", nameKey: "locationIcons.option.bathroom", category: .bathroomAndLaundry),
        LocationIconOption(id: "laundry", symbolName: "washer", nameKey: "locationIcons.option.laundry", category: .bathroomAndLaundry),
        LocationIconOption(id: "utility-sink", symbolName: "drop", nameKey: "locationIcons.option.utilitySink", category: .bathroomAndLaundry),

        LocationIconOption(id: "balcony", symbolName: "leaf", nameKey: "locationIcons.option.balcony", category: .outdoorAndUtility),
        LocationIconOption(id: "bike-storage", symbolName: "bicycle", nameKey: "locationIcons.option.bikeStorage", category: .outdoorAndUtility),
        LocationIconOption(id: "shed", symbolName: "building.2", nameKey: "locationIcons.option.shed", category: .outdoorAndUtility)
    ]

    static func option(for id: String?) -> LocationIconOption? {
        guard let id else {
            return nil
        }

        return options.first { $0.id == id }
    }

    static func symbolName(for id: String?) -> String {
        option(for: id)?.symbolName ?? fallbackSymbolName
    }

    static func normalizedIconID(_ id: String?) -> String? {
        guard let id, option(for: id) != nil else {
            return nil
        }

        return id
    }

    static func options(in category: LocationIconCategory) -> [LocationIconOption] {
        options.filter { $0.category == category }
    }
}
