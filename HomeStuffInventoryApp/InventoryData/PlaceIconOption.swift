import Foundation

struct PlaceIconOption: Identifiable, Hashable {
    let id: String
    let symbolName: String

    var localizedName: String {
        switch id {
        case "box": String(localized: "inventory.placeIcon.box", defaultValue: "Box")
        case "archive": String(localized: "inventory.placeIcon.archive", defaultValue: "Archive box")
        case "cabinet": String(localized: "inventory.placeIcon.cabinet", defaultValue: "Cabinet")
        case "drawer": String(localized: "inventory.placeIcon.drawer", defaultValue: "Drawer")
        case "shelf": String(localized: "inventory.placeIcon.shelf", defaultValue: "Shelf")
        case "tray": String(localized: "inventory.placeIcon.tray", defaultValue: "Tray")
        case "folder": String(localized: "inventory.placeIcon.folder", defaultValue: "Folder")
        case "hanger": String(localized: "inventory.placeIcon.hanger", defaultValue: "Hanger")
        case "basket": String(localized: "inventory.placeIcon.basket", defaultValue: "Basket")
        default: String(localized: "inventory.placeIcon.box", defaultValue: "Box")
        }
    }
}

enum PlaceIconCatalog {
    static let defaultIconID = "box"
    static let fallbackSymbolName = "shippingbox"

    static let options: [PlaceIconOption] = [
        PlaceIconOption(id: "box", symbolName: "shippingbox"),
        PlaceIconOption(id: "archive", symbolName: "archivebox"),
        PlaceIconOption(id: "cabinet", symbolName: "cabinet"),
        PlaceIconOption(id: "drawer", symbolName: "cabinet.fill"),
        PlaceIconOption(id: "shelf", symbolName: "square.split.2x2"),
        PlaceIconOption(id: "tray", symbolName: "tray.full"),
        PlaceIconOption(id: "folder", symbolName: "folder"),
        PlaceIconOption(id: "hanger", symbolName: "hanger"),
        PlaceIconOption(id: "basket", symbolName: "basket")
    ]

    static func option(for id: String?) -> PlaceIconOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }

    static func symbolName(for id: String?) -> String {
        option(for: id)?.symbolName ?? fallbackSymbolName
    }

    static func normalizedIconID(_ id: String?) -> String {
        option(for: id)?.id ?? defaultIconID
    }
}
