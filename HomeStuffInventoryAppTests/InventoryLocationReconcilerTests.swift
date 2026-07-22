import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryLocationReconcilerTests {
    @Test func reconciliationInsertsOneMissingReusableLocation() throws {
        let context = try modelContext()
        let item = InventoryItem(name: "Cable", locationName: "Office")
        context.insert(item)
        try context.save()

        try InventoryLocationReconciler.reconcile(in: context)

        #expect(try locationNames(in: context) == ["Office"])
    }

    @Test func reconciliationGroupsEquivalentSpellingsAndChoosesMostFrequentSpelling() throws {
        let context = try modelContext()
        ["Office", " office ", "OFFICE", "Office"].forEach { name in
            context.insert(InventoryItem(name: UUID().uuidString, locationName: name))
        }
        try context.save()

        try InventoryLocationReconciler.reconcile(in: context)

        #expect(try locationNames(in: context) == ["Office"])
    }

    @Test func reconciliationUsesLocalizedThenNormalAlphabeticalTieBreak() throws {
        let context = try modelContext()
        ["office", "Office"].forEach { name in
            context.insert(InventoryItem(name: UUID().uuidString, locationName: name))
        }
        try context.save()

        try InventoryLocationReconciler.reconcile(in: context)

        #expect(try locationNames(in: context) == ["Office"])
    }

    @Test func reconciliationIsIdempotentAndPreservesExistingLocation() throws {
        let context = try modelContext()
        let existing = StorageLocation(name: "Office", iconID: "office")
        context.insert(existing)
        context.insert(InventoryItem(name: "Cable", locationName: " office "))
        context.insert(InventoryItem(name: "Tape", locationName: "Garage"))
        try context.save()

        try InventoryLocationReconciler.reconcile(in: context)
        try InventoryLocationReconciler.reconcile(in: context)

        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        #expect(locations.count == 2)
        #expect(locations.first { $0.name == "Office" }?.id == existing.id)
        #expect(locations.first { $0.name == "Office" }?.iconID == "office")
        #expect(locations.contains { $0.name == "Garage" })
    }

    @Test func reconciliationNeverCreatesLocationForBlankValues() throws {
        let context = try modelContext()
        context.insert(InventoryItem(name: "Cable", locationName: "  \n "))
        try context.save()

        try InventoryLocationReconciler.reconcile(in: context)

        #expect(try locationNames(in: context).isEmpty)
    }

    @Test func categoryReconciliationCanonicalizesCollisionsWithoutChangingUserEditDates() throws {
        let context = try modelContext()
        let timestamp = Date(timeIntervalSince1970: 100)
        let collidingName = ukrainianCategoryName(for: .tools)
        let colliding = InventoryCustomCategory(name: collidingName)
        let custom = InventoryCustomCategory(name: "Craft Supplies")
        let matching = InventoryItem(name: "Hammer", category: "Custom", locationName: "Garage", updatedAt: timestamp)
        matching.category = collidingName
        let unrelated = InventoryItem(name: "Glue", category: "Craft Supplies", locationName: "Desk", updatedAt: timestamp)
        context.insert(colliding)
        context.insert(custom)
        context.insert(matching)
        context.insert(unrelated)
        try context.save()

        try InventoryLocationReconciler.reconcile(in: context)
        try InventoryLocationReconciler.reconcile(in: context)

        #expect(matching.category == InventoryCategory.tools.rawValue)
        #expect(matching.updatedAt == timestamp)
        #expect(unrelated.category == "Craft Supplies")
        #expect(try context.fetch(FetchDescriptor<InventoryCustomCategory>()).map(\.name) == ["Craft Supplies"])
    }

    private func modelContext() throws -> ModelContext {
        ModelContext(try InventoryModelContainer.make(inMemory: true))
    }

    private func locationNames(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<StorageLocation>()).map(\.name).sorted()
    }
}
