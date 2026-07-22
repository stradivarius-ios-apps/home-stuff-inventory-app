import Foundation

#if DEBUG
enum InventoryAppStoreDemoLocale: String, CaseIterable {
    case en
    case uk
}

struct InventoryAppStoreDemoDataset: Equatable {
    let locations: [InventoryAppStoreDemoLocation]
    let items: [InventoryAppStoreDemoItem]
    let recentViews: [InventoryAppStoreDemoRecentView]
}

struct InventoryAppStoreDemoLocation: Equatable {
    let id: UUID
    let name: String
    let iconID: String
}

struct InventoryAppStoreDemoItem: Equatable {
    let id: UUID
    let name: String
    let category: String
    let locationName: String
    let containerName: String
    let iconID: String
    let quantity: Int
    let condition: String
    let tags: [String]
    let notes: String
}

struct InventoryAppStoreDemoRecentView: Equatable {
    let id: UUID
    let itemID: UUID
    let offset: TimeInterval
}

enum InventoryAppStoreDemoData {
    static let itemTimestamp = Date(timeIntervalSince1970: 1_784_140_200)

    static func dataset(for locale: InventoryAppStoreDemoLocale) -> InventoryAppStoreDemoDataset {
        let isUkrainian = locale == .uk
        func text(_ english: String, _ ukrainian: String) -> String { isUkrainian ? ukrainian : english }
        let locations = [
            InventoryAppStoreDemoLocation(id: id("A5500000-0000-4000-8001-000000000001"), name: text("Home Office", "Домашній кабінет"), iconID: "office"),
            InventoryAppStoreDemoLocation(id: id("A5500000-0000-4000-8001-000000000002"), name: text("Hall Closet", "Шафа у коридорі"), iconID: "closet"),
            InventoryAppStoreDemoLocation(id: id("A5500000-0000-4000-8001-000000000003"), name: text("Kitchen", "Кухня"), iconID: "kitchen"),
            InventoryAppStoreDemoLocation(id: id("A5500000-0000-4000-8001-000000000004"), name: text("Entryway", "Передпокій"), iconID: "entryway")
        ]
        func item(_ number: Int, _ en: String, _ uk: String, _ category: InventoryCategory, _ location: Int, _ placeEN: String, _ placeUK: String, _ icon: String, _ quantity: Int, _ condition: InventoryCondition, _ tagsEN: [String], _ tagsUK: [String], _ notesEN: String, _ notesUK: String) -> InventoryAppStoreDemoItem {
            .init(id: id(String(format: "A5500000-0000-4000-8000-%012d", number)), name: text(en, uk), category: category.rawValue, locationName: locations[location].name, containerName: text(placeEN, placeUK), iconID: icon, quantity: quantity, condition: condition.rawValue, tags: isUkrainian ? tagsUK : tagsEN, notes: text(notesEN, notesUK))
        }
        let items = [
            item(1, "USB-C display adapter", "Відеоадаптер USB-C", .cablesAndAdapters, 0, "Top desk drawer", "Верхня шухляда столу", "display", 1, .good, ["HDMI", "display", "travel"], ["HDMI", "дисплей", "подорожі"], "For connecting the laptop to the living-room TV.", "Щоб під’єднати ноутбук до телевізора у вітальні."),
            item(2, "Presentation clicker", "Пульт для презентацій", .electronics, 0, "Top desk drawer", "Верхня шухляда столу", "gear", 1, .good, ["presentation", "meeting"], ["презентація", "зустріч"], "The USB receiver stays inside the battery compartment.", "USB-приймач зберігається у відсіку для батарейки."),
            item(3, "65W USB-C charger", "Зарядний пристрій USB-C 65 Вт", .cablesAndAdapters, 0, "Top desk drawer", "Верхня шухляда столу", "power-plug", 1, .good, ["USB-C", "laptop", "travel"], ["USB-C", "ноутбук", "подорожі"], "Works with the laptop and the travel power adapter.", "Підходить до ноутбука й дорожнього адаптера живлення."),
            item(4, "Electronics warranty folder", "Папка з гарантіями на техніку", .documents, 0, "Top desk drawer", "Верхня шухляда столу", "document", 1, .good, ["warranty", "receipts", "electronics"], ["гарантія", "чеки", "техніка"], "Receipts and warranty cards for the laptop and monitor.", "Чеки й гарантійні талони на ноутбук і монітор."),
            item(5, "HDMI cable, 2 m", "Кабель HDMI, 2 м", .cablesAndAdapters, 0, "Cable box", "Коробка з кабелями", "cable", 2, .good, ["HDMI", "TV", "spare"], ["HDMI", "телевізор", "запасний"], "Two-metre cables for the TV and spare monitor.", "Двометрові кабелі для телевізора й запасного монітора."),
            item(6, "Spare charging cables", "Запасні зарядні кабелі", .cablesAndAdapters, 0, "Cable box", "Коробка з кабелями", "cable", 4, .good, ["USB-C", "Lightning", "guests"], ["USB-C", "Lightning", "гості"], "Mixed cables for guests and travel bags.", "Різні кабелі для гостей і дорожніх сумок."),
            item(7, "Precision screwdriver set", "Набір точних викруток", .tools, 1, "Tool box", "Ящик з інструментами", "screwdriver", 1, .good, ["repair", "electronics"], ["ремонт", "техніка"], "Small Phillips and Torx bits for glasses and electronics.", "Малі біти Phillips і Torx для окулярів та електроніки."),
            item(8, "Tape measure, 5 m", "Рулетка, 5 м", .tools, 1, "Tool box", "Ящик з інструментами", "toolkit", 1, .good, ["measure", "home"], ["вимірювання", "дім"], "Five-metre tape for furniture and small repairs.", "П’ятиметрова рулетка для меблів і дрібного ремонту."),
            item(9, "First aid kit", "Аптечка", .miscellaneous, 1, "Top shelf", "Верхня полиця", "first-aid", 1, .new, ["health", "home"], ["здоров’я", "дім"], "Basic supplies for small cuts and burns.", "Основні засоби для невеликих порізів і опіків."),
            item(10, "CR2032 batteries", "Батарейки CR2032", .batteries, 2, "Utility drawer", "Господарська шухляда", "battery", 4, .new, ["scale", "remote"], ["ваги", "пульт"], "Spare coin cells for the kitchen scale and small remotes.", "Запасні батарейки для кухонних ваг і невеликих пультів."),
            item(11, "Flashlight", "Ліхтарик", .tools, 2, "Utility drawer", "Господарська шухляда", "toolkit", 1, .good, ["power cut", "utility"], ["відключення", "побут"], "Kept close to the batteries for power cuts.", "Зберігається біля батарейок на випадок відключення світла."),
            item(12, "Reusable shopping bags", "Багаторазові торбинки", .householdSupplies, 2, "Pantry top shelf", "Верхня полиця комори", "bag", 5, .good, ["shopping", "reusable"], ["покупки", "багаторазові"], "Folded bags for grocery trips.", "Складені торбинки для походів по продукти."),
            item(13, "Bike pump", "Велосипедний насос", .outdoorAndTravel, 3, "Shoe cabinet", "Взуттєва шафа", "toolkit", 1, .good, ["bike", "outdoor"], ["велосипед", "вулиця"], "Fits both Presta and Schrader valves.", "Підходить до клапанів Presta і Schrader."),
            item(14, "Spare keys", "Запасні ключі", .miscellaneous, 3, "Key tray", "Таця для ключів", "key", 2, .good, ["spare", "home"], ["запасні", "дім"], "Spare keys for the apartment and mailbox.", "Запасні ключі від квартири й поштової скриньки.")
        ]
        return .init(locations: locations, items: items, recentViews: [
            .init(id: id("A5500000-0000-4000-8002-000000000001"), itemID: items[0].id, offset: -60),
            .init(id: id("A5500000-0000-4000-8002-000000000002"), itemID: items[1].id, offset: -120),
            .init(id: id("A5500000-0000-4000-8002-000000000003"), itemID: items[2].id, offset: -180)
        ])
    }

    private static func id(_ value: String) -> UUID { UUID(uuidString: value)! }
}
#endif
