import Foundation

enum InventoryGlyph: String, CaseIterable {
    case archiveBox = "archive-box"
    case bandage
    case basket
    case battery
    case bedroom
    case bicycle
    case books
    case box
    case cabinet
    case cable
    case car
    case clothing
    case cupAndSaucer = "cup-and-saucer"
    case cutlery
    case desktopComputer = "desktop-computer"
    case display
    case document
    case drawer
    case entrywayDoor = "entryway-door"
    case eyeglasses
    case firstAid = "first-aid"
    case floorLamp = "floor-lamp"
    case folder
    case gear
    case hammer
    case hanger
    case headphones
    case home
    case keys
    case kitchen = "kitchen-scene"
    case laptop
    case leaf
    case office = "office-scene"
    case organizer
    case phone
    case pills
    case powerPlug = "power-plug"
    case refrigerator
    case screwdriver
    case shedBuilding = "shed-building"
    case shelf
    case shoppingBag = "shopping-bag"
    case shower
    case sofa
    case sparkles
    case stethoscope
    case television
    case tools
    case tray
    case wallet
    case washingMachine = "washing-machine"
    case waterDrop = "water-drop"
    case roomFloorplan = "room-floorplan"
    case locationMarker = "location-marker"
    case missingLocationMarker = "missing-location-marker"
    case locationArrow = "location-arrow"
    case map
    case tag
    case quantity
    case notes
    case condition
    case clock

    enum Domain: Equatable {
        case location, place, item

        var fallback: InventoryGlyph {
            self == .location ? .locationMarker : .box
        }
    }

    enum Variant: String, CaseIterable {
        case outline, material, selected

        static func resolve(identity: Bool, isSelected: Bool) -> Self {
            isSelected ? .selected : (identity ? .material : .outline)
        }
    }

    func assetName(for variant: Variant) -> String {
        "InventoryGlyph-\(rawValue)-\(variant.rawValue)"
    }

    static func content(systemName: String, domain: Domain) -> Self {
        resolve(systemName: systemName, domain: domain) ?? domain.fallback
    }

    static func resolve(systemName: String, domain: Domain) -> Self? {
        switch (domain, systemName) {
        case (_, "house"): .home
        case (_, "door.left.hand.open"): .entrywayDoor
        case (.location, "square.grid.2x2"): .roomFloorplan
        case (_, "square.grid.2x2"): .organizer
        case (_, "sofa"): .sofa
        case (_, "tv"): .television
        case (_, "lamp.floor"): .floorLamp
        case (.location, "fork.knife"): .kitchen
        case (.item, "fork.knife"): .cutlery
        case (_, "cup.and.saucer"): .cupAndSaucer
        case (_, "refrigerator"): .refrigerator
        case (_, "shippingbox"): .box
        case (_, "archivebox"): .archiveBox
        case (_, "cabinet"): .cabinet
        case (_, "tray.full"): .tray
        case (_, "car"): .car
        case (_, "wrench.and.screwdriver"): .tools
        case (_, "hammer"): .hammer
        case (.location, "desktopcomputer"): .office
        case (.item, "desktopcomputer"): .desktopComputer
        case (_, "folder"): .folder
        case (_, "books.vertical"): .books
        case (_, "bed.double"): .bedroom
        case (.location, "hanger"): .cabinet
        case (.place, "hanger"): .hanger
        case (_, "shower"): .shower
        case (_, "washer"): .washingMachine
        case (_, "drop"): .waterDrop
        case (_, "leaf"): .leaf
        case (_, "bicycle"): .bicycle
        case (_, "building.2"): .shedBuilding
        case (_, "cabinet.fill"): .drawer
        case (_, "square.split.2x2"): .shelf
        case (_, "basket"): .basket
        case (_, "screwdriver"): .screwdriver
        case (_, "gearshape"): .gear
        case (_, "cable.connector"): .cable
        case (_, "powerplug"): .powerPlug
        case (_, "display"): .display
        case (_, "laptopcomputer"): .laptop
        case (_, "iphone"): .phone
        case (_, "headphones"): .headphones
        case (_, "battery.100percent"): .battery
        case (_, "doc.text"): .document
        case (_, "tshirt"): .clothing
        case (_, "bag"): .shoppingBag
        case (_, "eyeglasses"): .eyeglasses
        case (_, "key"): .keys
        case (_, "wallet.pass"): .wallet
        case (_, "sparkles"): .sparkles
        case (_, "cross.case"): .firstAid
        case (_, "bandage"): .bandage
        case (_, "pills"): .pills
        case (_, "stethoscope"): .stethoscope
        case (_, "mappin.and.ellipse"), (_, "mappin.circle"): .locationMarker
        case (_, "mappin.slash"): .missingLocationMarker
        case (_, "location"): .locationArrow
        case (_, "map"): .map
        case (_, "tag"): .tag
        case (_, "number"): .quantity
        case (_, "note.text"): .notes
        case (_, "checkmark.seal"): .condition
        case (_, "clock"), (_, "clock.arrow.circlepath"): .clock
        case (_, "shippingbox.circle"): .box
        case (_, "square.text.square"): .document
        default: nil
        }
    }
}
