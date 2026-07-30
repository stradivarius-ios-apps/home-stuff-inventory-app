import Foundation
import SwiftData

enum InventoryItemMutationPersistence {
    static func delete(
        _ item: InventoryItem,
        in modelContext: ModelContext,
        persist: (() throws -> Void)? = nil
    ) throws {
        do {
            let itemID = item.id
            let events = try modelContext.fetch(
                FetchDescriptor<InventoryItemViewEvent>(
                    predicate: #Predicate<InventoryItemViewEvent> { event in
                        event.itemID == itemID
                    }
                )
            )
            for event in events {
                modelContext.delete(event)
            }
            let movementRecords = try modelContext.fetch(
                FetchDescriptor<InventoryMovementRecord>(
                    predicate: #Predicate<InventoryMovementRecord> { record in
                        record.itemID == itemID
                    }
                )
            )
            for record in movementRecords {
                modelContext.delete(record)
            }
            modelContext.delete(item)
            try (persist ?? modelContext.save)()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func saveNotes(
        _ notes: String,
        to item: InventoryItem,
        in modelContext: ModelContext,
        updatedAt timestamp: Date = .now,
        persist: (() throws -> Void)? = nil
    ) throws {
        do {
            item.applyNotesEdit(notes, updatedAt: timestamp)
            try (persist ?? modelContext.save)()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
