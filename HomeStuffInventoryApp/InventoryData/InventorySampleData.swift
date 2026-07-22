import Foundation
import SwiftData

#if DEBUG
enum InventorySampleData {
    static var items: [SampleInventoryItem] {
        standardItems + (SampleDataConfiguration.usesLongPlaceFixture ? [longPlaceFixtureItem] : [])
    }

    private static let standardItems: [SampleInventoryItem] = [
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D001")!,
            name: "USB-C to HDMI adapter",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Office",
            containerName: "Desk drawer",
            quantity: 1,
            condition: InventoryCondition.good.rawValue,
            tags: [
                "usb-c",
                "hdmi",
                "adapter",
                "display",
                "laptop",
                "monitor",
                "presentation",
                "travel",
                "desk setup",
                "video",
                "conference",
                "spare"
            ],
            notes: """
            Usually used for connecting the laptop to the living room TV.
            Keep it with the travel adapters so it is easy to grab for presentations, monitor testing, and desk setup changes.
            """
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D002")!,
            name: "Precision screwdriver set",
            category: InventoryCategory.tools.rawValue,
            locationName: "Hall closet",
            containerName: "Small tool box",
            quantity: 1,
            condition: InventoryCondition.good.rawValue,
            tags: ["tools", "electronics", "repair"],
            notes: "Includes tiny Phillips and Torx bits for laptop and glasses repairs."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D003")!,
            name: "CR2032 batteries",
            category: InventoryCategory.batteries.rawValue,
            locationName: "Kitchen",
            containerName: "Utility drawer",
            quantity: 4,
            condition: InventoryCondition.new.rawValue,
            tags: ["battery", "coin cell", "scale", "remote"],
            notes: "Spare coin cells for the kitchen scale and small remotes."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D004")!,
            name: "Ethernet cable 5m",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Living room",
            containerName: "TV cabinet",
            quantity: 2,
            condition: InventoryCondition.good.rawValue,
            tags: ["network", "ethernet", "cable"],
            notes: "Long enough to reach from the router shelf to the console."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D005")!,
            name: "Old router",
            category: InventoryCategory.electronics.rawValue,
            locationName: "Storage room",
            containerName: "Electronics bin",
            quantity: 1,
            condition: InventoryCondition.worn.rawValue,
            tags: ["network", "router", "backup"],
            notes: "Factory reset before using. Kept as a short-term backup router."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D006")!,
            name: "Thermal paste",
            category: InventoryCategory.spareParts.rawValue,
            locationName: "Office",
            containerName: "PC parts box",
            quantity: 1,
            condition: InventoryCondition.good.rawValue,
            tags: ["pc", "repair", "cpu"],
            notes: "Half-used tube from the last desktop maintenance."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D007")!,
            name: "Drill bits",
            category: InventoryCategory.tools.rawValue,
            locationName: "Balcony cabinet",
            containerName: "Red organizer",
            quantity: 12,
            condition: InventoryCondition.good.rawValue,
            tags: ["tools", "drill", "hardware"],
            notes: "Mixed wood and metal bits. The 6 mm bit is in the drill case."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D008")!,
            name: "Bike pump",
            category: InventoryCategory.outdoorAndTravel.rawValue,
            locationName: "Entryway",
            containerName: "Shoe cabinet",
            quantity: 1,
            condition: InventoryCondition.good.rawValue,
            tags: ["bike", "pump", "outdoor"],
            notes: "Fits Presta and Schrader valves. Pressure gauge is a little stiff."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D009")!,
            name: "Spare charging cables",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Bedroom",
            containerName: "Nightstand drawer",
            quantity: 5,
            condition: InventoryCondition.good.rawValue,
            tags: ["charging", "usb-c", "lightning", "cables"],
            notes: "Mixed USB-C and Lightning cables for guests and travel bags."
        ),
        SampleInventoryItem(
            id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D010")!,
            name: "Cable ties",
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: "Storage room",
            containerName: "Hardware drawer",
            quantity: 50,
            condition: InventoryCondition.new.rawValue,
            tags: ["cable management", "ties", "organizing"],
            notes: "Small black ties for tidying cables behind desks and shelves."
        )
    ]

    private static let longPlaceFixtureItem = SampleInventoryItem(
        id: UUID(uuidString: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3D011")!,
        name: "Довгий комплект дрібних кабелів, зарядних пристроїв і перехідників для сімейних подорожей",
        category: InventoryCategory.householdSupplies.rawValue,
        locationName: "Office",
        containerName: "Clear hardware drawer with an unusually long descriptive label",
        quantity: 1,
        condition: InventoryCondition.good.rawValue,
        tags: ["fixture"],
        notes: "UI-test-only fixture for long Place row coverage."
    )
}

struct SampleInventoryItem: Equatable {
    let id: UUID
    let name: String
    let category: String
    let locationName: String
    let containerName: String
    let quantity: Int
    let condition: String
    let tags: [String]
    let notes: String

    func makeInventoryItem(createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> InventoryItem {
        InventoryItem(
            id: id,
            name: name,
            category: category,
            locationName: locationName,
            containerName: containerName,
            quantity: quantity,
            condition: condition,
            tags: tags,
            notes: notes,
            createdAt: createdAt
        )
    }
}

enum ManagedValueRowRegressionData {
    static func seed(in context: ModelContext) throws {
        for index in 1...3 {
            context.insert(item(
                id: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3A\(String(format: "%03d", index))",
                name: "Балконська річ \(index)",
                locationName: "Шафа на балконі"
            ))
        }

        for index in 1...6 {
            context.insert(item(
                id: "F4C4BEE7-38B0-40C8-A8E1-1DB8E6E3B\(String(format: "%03d", index))",
                name: "Комірна річ \(index)",
                locationName: "Комора"
            ))
        }

        try context.save()
    }

    private static func item(id: String, name: String, locationName: String) -> InventoryItem {
        InventoryItem(
            id: UUID(uuidString: id)!,
            name: name,
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: locationName,
            containerName: "Полиця",
            quantity: 1,
            condition: InventoryCondition.good.rawValue,
            tags: [],
            notes: ""
        )
    }
}
#endif
