import Foundation

enum ItemIconCategory: String, CaseIterable, Identifiable {
    case toolsAndRepair
    case cablesAndElectronics
    case boxesAndSupplies
    case homeAndPersonal
    case kitchenCleaningAndUtility
    case healthAndSafety

    var id: String {
        rawValue
    }

    var titleKey: String {
        "itemIcons.category.\(rawValue)"
    }
}

struct ItemIconOption: Identifiable, Hashable {
    let id: String
    let symbolName: String
    let nameKey: String
    let category: ItemIconCategory
}

enum ItemIconCatalog {
    static let fallbackIconID = "box"
    static let fallbackSymbolName = "shippingbox"

    static let options: [ItemIconOption] = [
        ItemIconOption(id: "toolkit", symbolName: "wrench.and.screwdriver", nameKey: "itemIcons.option.toolkit", category: .toolsAndRepair),
        ItemIconOption(id: "screwdriver", symbolName: "screwdriver", nameKey: "itemIcons.option.screwdriver", category: .toolsAndRepair),
        ItemIconOption(id: "hammer", symbolName: "hammer", nameKey: "itemIcons.option.hammer", category: .toolsAndRepair),
        ItemIconOption(id: "gear", symbolName: "gearshape", nameKey: "itemIcons.option.gear", category: .toolsAndRepair),

        ItemIconOption(id: "cable", symbolName: "cable.connector", nameKey: "itemIcons.option.cable", category: .cablesAndElectronics),
        ItemIconOption(id: "power-plug", symbolName: "powerplug", nameKey: "itemIcons.option.powerPlug", category: .cablesAndElectronics),
        ItemIconOption(id: "display", symbolName: "display", nameKey: "itemIcons.option.display", category: .cablesAndElectronics),
        ItemIconOption(id: "desktop", symbolName: "desktopcomputer", nameKey: "itemIcons.option.desktop", category: .cablesAndElectronics),
        ItemIconOption(id: "laptop", symbolName: "laptopcomputer", nameKey: "itemIcons.option.laptop", category: .cablesAndElectronics),
        ItemIconOption(id: "phone", symbolName: "iphone", nameKey: "itemIcons.option.phone", category: .cablesAndElectronics),
        ItemIconOption(id: "headphones", symbolName: "headphones", nameKey: "itemIcons.option.headphones", category: .cablesAndElectronics),
        ItemIconOption(id: "battery", symbolName: "battery.100percent", nameKey: "itemIcons.option.battery", category: .cablesAndElectronics),

        ItemIconOption(id: "box", symbolName: "shippingbox", nameKey: "itemIcons.option.box", category: .boxesAndSupplies),
        ItemIconOption(id: "archive", symbolName: "archivebox", nameKey: "itemIcons.option.archive", category: .boxesAndSupplies),
        ItemIconOption(id: "tray", symbolName: "tray.full", nameKey: "itemIcons.option.tray", category: .boxesAndSupplies),
        ItemIconOption(id: "folder", symbolName: "folder", nameKey: "itemIcons.option.folder", category: .boxesAndSupplies),
        ItemIconOption(id: "document", symbolName: "doc.text", nameKey: "itemIcons.option.document", category: .boxesAndSupplies),

        ItemIconOption(id: "clothing", symbolName: "tshirt", nameKey: "itemIcons.option.clothing", category: .homeAndPersonal),
        ItemIconOption(id: "bag", symbolName: "bag", nameKey: "itemIcons.option.bag", category: .homeAndPersonal),
        ItemIconOption(id: "glasses", symbolName: "eyeglasses", nameKey: "itemIcons.option.glasses", category: .homeAndPersonal),
        ItemIconOption(id: "key", symbolName: "key", nameKey: "itemIcons.option.key", category: .homeAndPersonal),
        ItemIconOption(id: "wallet", symbolName: "wallet.pass", nameKey: "itemIcons.option.wallet", category: .homeAndPersonal),

        ItemIconOption(id: "kitchen", symbolName: "fork.knife", nameKey: "itemIcons.option.kitchen", category: .kitchenCleaningAndUtility),
        ItemIconOption(id: "cup", symbolName: "cup.and.saucer", nameKey: "itemIcons.option.cup", category: .kitchenCleaningAndUtility),
        ItemIconOption(id: "drop", symbolName: "drop", nameKey: "itemIcons.option.drop", category: .kitchenCleaningAndUtility),
        ItemIconOption(id: "sparkles", symbolName: "sparkles", nameKey: "itemIcons.option.sparkles", category: .kitchenCleaningAndUtility),
        ItemIconOption(id: "leaf", symbolName: "leaf", nameKey: "itemIcons.option.leaf", category: .kitchenCleaningAndUtility),

        ItemIconOption(id: "first-aid", symbolName: "cross.case", nameKey: "itemIcons.option.firstAid", category: .healthAndSafety),
        ItemIconOption(id: "bandage", symbolName: "bandage", nameKey: "itemIcons.option.bandage", category: .healthAndSafety),
        ItemIconOption(id: "pills", symbolName: "pills", nameKey: "itemIcons.option.pills", category: .healthAndSafety),
        ItemIconOption(id: "stethoscope", symbolName: "stethoscope", nameKey: "itemIcons.option.stethoscope", category: .healthAndSafety)
    ]

    static func option(for id: String?) -> ItemIconOption? {
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

    static func defaultIconID(forCategory category: String) -> String? {
        guard let category = InventoryCategory(storedValue: category) else {
            return nil
        }

        switch category {
        case .tools:
            return "toolkit"
        case .cablesAndAdapters:
            return "cable"
        case .electronics:
            return "desktop"
        case .spareParts:
            return "gear"
        case .batteries:
            return "battery"
        case .documents:
            return "document"
        case .householdSupplies:
            return "box"
        case .outdoorAndTravel:
            return "bag"
        case .miscellaneous:
            return nil
        }
    }

    static func options(in category: ItemIconCategory) -> [ItemIconOption] {
        options.filter { $0.category == category }
    }
}
