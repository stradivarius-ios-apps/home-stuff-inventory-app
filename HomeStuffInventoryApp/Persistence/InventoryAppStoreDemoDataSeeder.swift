import Foundation
import SwiftData

#if DEBUG
enum InventoryAppStoreDemoDataSeeder {
    static func seed(in context: ModelContext, locale: InventoryAppStoreDemoLocale, now: Date = .now) throws {
        let dataset = InventoryAppStoreDemoData.dataset(for: locale)
        let locationsByID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StorageLocation>()).map { ($0.id, $0) })
        let itemsByID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<InventoryItem>()).map { ($0.id, $0) })
        let eventsByID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).map { ($0.id, $0) })

        for definition in dataset.locations {
            if let location = locationsByID[definition.id] {
                location.name = definition.name
                location.iconID = LocationIconCatalog.normalizedIconID(definition.iconID)
                location.notes = ""
                location.createdAt = InventoryAppStoreDemoData.itemTimestamp
                location.updatedAt = InventoryAppStoreDemoData.itemTimestamp
            } else {
                context.insert(StorageLocation(id: definition.id, name: definition.name, iconID: definition.iconID, notes: "", createdAt: InventoryAppStoreDemoData.itemTimestamp, updatedAt: InventoryAppStoreDemoData.itemTimestamp))
            }
        }
        for definition in dataset.items {
            if let item = itemsByID[definition.id] {
                item.applyUserEdit(name: definition.name, category: definition.category, locationName: definition.locationName, containerName: definition.containerName, iconID: definition.iconID, quantity: definition.quantity, condition: definition.condition, tags: definition.tags, notes: definition.notes, updatedAt: InventoryAppStoreDemoData.itemTimestamp)
                item.createdAt = InventoryAppStoreDemoData.itemTimestamp
                item.updatedAt = InventoryAppStoreDemoData.itemTimestamp
            } else {
                context.insert(InventoryItem(id: definition.id, name: definition.name, category: definition.category, locationName: definition.locationName, containerName: definition.containerName, iconID: definition.iconID, quantity: definition.quantity, condition: definition.condition, tags: definition.tags, notes: definition.notes, createdAt: InventoryAppStoreDemoData.itemTimestamp, updatedAt: InventoryAppStoreDemoData.itemTimestamp))
            }
        }
        for definition in dataset.recentViews {
            if let event = eventsByID[definition.id] { event.itemID = definition.itemID; event.viewedAt = now.addingTimeInterval(definition.offset) }
            else { context.insert(InventoryItemViewEvent(id: definition.id, itemID: definition.itemID, viewedAt: now.addingTimeInterval(definition.offset))) }
        }
        try context.save()
    }
}
#endif
