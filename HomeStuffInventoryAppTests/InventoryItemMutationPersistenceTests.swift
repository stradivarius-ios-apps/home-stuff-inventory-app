import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryItemMutationPersistenceTests {
    @Test func deletePersistsItemRemoval() throws {
        let context = try modelContext()
        let item = InventoryItem(name: "Cable", locationName: "Desk")
        context.insert(item)
        try context.save()

        try InventoryItemMutationPersistence.delete(item, in: context)

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).isEmpty)
    }

    @Test func failedDeleteRollsBackItemRemoval() throws {
        let context = try modelContext()
        let item = InventoryItem(name: "Cable", locationName: "Desk")
        context.insert(item)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryItemMutationPersistence.delete(
                item,
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).map(\.name) == ["Cable"])
    }

    @Test func deleteRemovesOnlyTargetItemViewEvents() throws {
        let context = try modelContext()
        let target = InventoryItem(name: "Cable", locationName: "Desk")
        let unrelated = InventoryItem(name: "Adapter", locationName: "Desk")
        let targetEvents = [
            InventoryItemViewEvent(itemID: target.id),
            InventoryItemViewEvent(itemID: target.id)
        ]
        let unrelatedEvent = InventoryItemViewEvent(itemID: unrelated.id)
        [target, unrelated].forEach(context.insert)
        (targetEvents + [unrelatedEvent]).forEach(context.insert)
        try context.save()

        try InventoryItemMutationPersistence.delete(target, in: context)

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).map(\.id) == [unrelated.id])
        #expect(try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).map(\.id) == [unrelatedEvent.id])
    }

    @Test func failedDeleteRollsBackTargetItemAndViewEvents() throws {
        let context = try modelContext()
        let item = InventoryItem(name: "Cable", locationName: "Desk")
        let events = [
            InventoryItemViewEvent(itemID: item.id),
            InventoryItemViewEvent(itemID: item.id)
        ]
        context.insert(item)
        events.forEach(context.insert)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryItemMutationPersistence.delete(
                item,
                in: context,
                persist: { throw PersistenceFailure.expected }
            )
        }

        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).map(\.id) == [item.id])
        #expect(Set(try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).map(\.id)) == Set(events.map(\.id)))
    }

    @Test func saveNotesPersistsNormalizedNotesAndTimestamp() throws {
        let originalTimestamp = Date(timeIntervalSince1970: 100)
        let updatedTimestamp = Date(timeIntervalSince1970: 200)
        let context = try modelContext()
        let item = InventoryItem(
            name: "Cable",
            locationName: "Desk",
            notes: "Original",
            createdAt: originalTimestamp
        )
        context.insert(item)
        try context.save()

        try InventoryItemMutationPersistence.saveNotes(
            " Updated notes \n",
            to: item,
            in: context,
            updatedAt: updatedTimestamp
        )

        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persistedItem.notes == "Updated notes")
        #expect(persistedItem.updatedAt == updatedTimestamp)
    }

    @Test func failedNotesSaveRollsBackNotesAndTimestamp() throws {
        let originalTimestamp = Date(timeIntervalSince1970: 100)
        let context = try modelContext()
        let item = InventoryItem(
            name: "Cable",
            locationName: "Desk",
            notes: "Original",
            createdAt: originalTimestamp
        )
        context.insert(item)
        try context.save()

        #expect(throws: PersistenceFailure.expected) {
            try InventoryItemMutationPersistence.saveNotes(
                "Updated notes",
                to: item,
                in: context,
                updatedAt: Date(timeIntervalSince1970: 200),
                persist: { throw PersistenceFailure.expected }
            )
        }

        let persistedItem = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        #expect(persistedItem.notes == "Original")
        #expect(persistedItem.updatedAt == originalTimestamp)
    }

    private func modelContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private enum PersistenceFailure: Error, Equatable {
        case expected
    }
}
