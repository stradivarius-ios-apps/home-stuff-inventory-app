import Foundation
import SwiftData

enum InventoryLocationReconciler {
    static func reconcile(in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        try reconcile(items: items, storageLocations: locations, in: context)
        try InventoryCategoryReconciler.reconcile(in: context)
    }

    static func reconcile(
        items: [InventoryItem],
        storageLocations: [StorageLocation],
        in context: ModelContext
    ) throws {
        let existingNames = Set(storageLocations.compactMap { location -> InventoryNormalizedName? in
            let normalizedName = InventoryNormalizedName.location(location.name)
            return normalizedName.isMissing ? nil : normalizedName
        })
        let itemNames = Dictionary(grouping: items.compactMap { item -> InventoryNormalizedName? in
            let normalizedName = InventoryNormalizedName.location(item.locationName)
            return normalizedName.isMissing ? nil : normalizedName
        }, by: { $0 })

        let missingNames = itemNames.keys
            .filter { !existingNames.contains($0) }
            .sorted(by: sortedNames)

        for name in missingNames {
            let spellings = items.compactMap { item -> String? in
                let normalizedName = InventoryNormalizedName.location(item.locationName)
                guard normalizedName == name else {
                    return nil
                }

                return normalizedName.displayName
            }
            context.insert(StorageLocation(name: preferredSpelling(from: spellings)))
        }

        if !missingNames.isEmpty {
            try context.save()
        }
    }

    private static func preferredSpelling(from spellings: [String]) -> String {
        Dictionary(grouping: spellings, by: { $0 })
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count {
                    return lhs.value.count > rhs.value.count
                }

                let localizedComparison = lhs.key.localizedCaseInsensitiveCompare(rhs.key)
                if localizedComparison != .orderedSame {
                    return localizedComparison == .orderedAscending
                }

                return lhs.key < rhs.key
            }
            .first!.key
    }

    private static func sortedNames(_ lhs: InventoryNormalizedName, _ rhs: InventoryNormalizedName) -> Bool {
        let localizedComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if localizedComparison != .orderedSame {
            return localizedComparison == .orderedAscending
        }

        return lhs.displayName < rhs.displayName
    }
}
