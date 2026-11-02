import Foundation

enum InventoryGlyph: String, CaseIterable {
    case kitchen, office, bedroom, cabinet, drawer, box, shelf, organizer
    case cable, keys, battery, tools

    enum Domain {
        case location, place, item
    }

    static func resolve(systemName: String, domain: Domain) -> Self? {
        switch (domain, systemName) {
        case (.location, "fork.knife"): .kitchen
        case (.location, "desktopcomputer"): .office
        case (.location, "bed.double"): .bedroom
        case (.location, "hanger"), (_, "cabinet"): .cabinet
        case (.place, "cabinet.fill"): .drawer
        case (.place, "square.split.2x2"): .shelf
        case (_, "shippingbox"): .box
        case (_, "square.grid.2x2"): .organizer
        case (.item, "cable.connector"): .cable
        case (.item, "key"): .keys
        case (.item, "battery.100percent"): .battery
        case (.item, "wrench.and.screwdriver"): .tools
        default: nil
        }
    }
}
