import Foundation
import SwiftData

/// Canonicalizes legacy built-in aliases and removes custom records that collide with them.
enum InventoryCategoryReconciler {
    static func reconcile(in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let customCategories = try context.fetch(FetchDescriptor<InventoryCustomCategory>())
        try reconcile(items: items, customCategories: customCategories, in: context)
    }

    static func reconcile(
        items: [InventoryItem],
        customCategories: [InventoryCustomCategory],
        in context: ModelContext
    ) throws {
        var didChange = false

        for customCategory in customCategories {
            guard let builtInCategory = InventoryCategory.resolveBuiltInCategory(from: customCategory.name) else {
                continue
            }

            for item in items where InventoryListManagement.categoryValuesMatch(item.category, customCategory.name) {
                guard item.category != builtInCategory.rawValue else {
                    continue
                }

                // This is a storage compatibility repair, not a user edit.
                item.category = builtInCategory.rawValue
                didChange = true
            }

            context.delete(customCategory)
            didChange = true
        }

        if didChange {
            try context.save()
        }
    }
}
