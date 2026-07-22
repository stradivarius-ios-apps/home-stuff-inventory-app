import Foundation
import CryptoKit

private struct InventoryLegacyBackupV0: Decodable {
    let formatIdentifier: String
    let artifactType: String
    let schemaVersion: Int
    let metadata: InventoryPortabilityMetadataV1
    let inventory: InventoryLegacySnapshotV0
}

private struct InventoryLegacySnapshotV0: Decodable {
    let locations: [InventoryPortabilityLocationV1]
    let customCategories: [InventoryPortabilityCustomCategoryV1]
    let items: [InventoryLegacyItemV0]
}

private struct InventoryLegacyItemV0: Decodable {
    let id: String
    let name: String
    let category: String
    let locationName: String
    let containerName: String?
    let iconID: String?
    let quantity: Int
    let condition: String
    let tags: [String]
    let notes: String
    let createdAt: String
    let updatedAt: String
}

enum InventoryBackupLegacyMigration {
    static func migratePlaces(in document: InventoryPortabilityDocumentV1) throws -> InventoryPortabilityDocumentV1 {
        guard document.schemaVersion == 1 else { return document }
        var placesByScope: [String: InventoryPortabilityPlaceV1] = [:]
        let locationIDs = Set(document.inventory.locations.map(\.id))
        let items = document.inventory.items.map { item -> InventoryPortabilityItemV1 in
            guard let locationID = item.locationID, locationIDs.contains(locationID),
                  let rawPlace = item.placeName,
                  !InventoryNormalizedName.place(rawPlace).isMissing
            else { return item }
            let normalized = InventoryNormalizedName.place(rawPlace)
            let scope = "\(locationID)\u{1F}\(normalized.comparisonKey)"
            let place = placesByScope[scope] ?? InventoryPortabilityPlaceV1(
                id: stablePlaceID(for: scope), locationID: locationID, name: normalized.displayName,
                iconID: PlaceIconCatalog.defaultIconID, createdAt: item.createdAt, updatedAt: item.updatedAt
            )
            placesByScope[scope] = place
            return InventoryPortabilityItemV1(
                id: item.id, name: item.name, categoryStorageValue: item.categoryStorageValue,
                customCategoryID: item.customCategoryID, locationName: item.locationName, locationID: item.locationID,
                placeName: item.placeName, placeID: place.id, iconID: item.iconID, quantity: item.quantity,
                conditionStorageValue: item.conditionStorageValue, tags: item.tags, notes: item.notes,
                createdAt: item.createdAt, updatedAt: item.updatedAt
            )
        }
        let snapshot = InventoryPortabilitySnapshotV1(
            locations: document.inventory.locations, customCategories: document.inventory.customCategories,
            items: items, places: Array(placesByScope.values), recentItemViewEvents: document.inventory.recentItemViewEvents
        )
        try InventoryPortabilityValidator.validate(snapshot, artifactType: document.artifactType, invalidError: .invalidRelationships)
        let data = try InventoryPortabilityEncoder.encode(
            snapshot: snapshot, metadata: document.metadata, artifactType: document.artifactType, prettyPrinted: false
        )
        return try InventoryPortabilityEncoder.decodeAndVerify(data)
    }

    private static func stablePlaceID(for scope: String) -> String {
        var bytes = Array(SHA256.hash(data: Data(scope.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])).inventoryPortabilityString
    }
    static func migrateIfVersionZero(_ data: Data, limits: InventoryPortabilityLimits = .production) throws -> Data? {
        guard data.count <= limits.maximumDocumentBytes else { throw InventoryBackupRestoreError.fileTooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = root["schemaVersion"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(version),
              version.intValue == 0,
              version.doubleValue == 0
        else { return nil }

        try validateShape(root)
        try InventoryPortabilityLimitValidator.validateRaw(root, limits: limits)
        let legacy: InventoryLegacyBackupV0
        do {
            legacy = try JSONDecoder().decode(InventoryLegacyBackupV0.self, from: data)
        } catch {
            throw InventoryBackupRestoreError.malformedFile
        }
        guard legacy.formatIdentifier == InventoryPortabilityEncoder.formatIdentifier,
              legacy.artifactType == InventoryPortabilityArtifactType.completeBackup.rawValue,
              legacy.schemaVersion == 0
        else { throw InventoryBackupRestoreError.wrongFileType }

        let locationsByName = try uniqueNameIndex(
            legacy.inventory.locations.map { ($0.name, $0.id) }
        )
        let categoriesByName = try uniqueNameIndex(
            legacy.inventory.customCategories.map { ($0.name, $0.id) }
        )
        let items = legacy.inventory.items.map { item in
            let category = InventoryCategory.resolveBuiltInCategory(from: item.category)?.rawValue
                ?? item.category
            return InventoryPortabilityItemV1(
                id: item.id,
                name: item.name,
                categoryStorageValue: category,
                customCategoryID: InventoryCategory.resolveBuiltInCategory(from: category) == nil
                    ? categoriesByName[nameKey(category)]
                    : nil,
                locationName: item.locationName,
                locationID: locationsByName[nameKey(item.locationName)],
                placeName: item.containerName,
                iconID: item.iconID,
                quantity: item.quantity,
                conditionStorageValue: InventoryCondition(storedValue: item.condition)?.rawValue
                    ?? item.condition,
                tags: item.tags,
                notes: item.notes,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
        }
        let snapshot = InventoryPortabilitySnapshotV1(
            locations: legacy.inventory.locations,
            customCategories: legacy.inventory.customCategories,
            items: items,
            recentItemViewEvents: []
        )
        do {
            let enriched = try migratePlaces(in: InventoryPortabilityDocumentV1(
                formatIdentifier: InventoryPortabilityEncoder.formatIdentifier,
                artifactType: .completeBackup,
                schemaVersion: 1,
                integrity: InventoryPortabilityIntegrityV1(digest: ""),
                metadata: legacy.metadata,
                inventory: snapshot
            ))
            return try InventoryPortabilityEncoder.encode(
                snapshot: enriched.inventory,
                metadata: legacy.metadata,
                artifactType: .completeBackup,
                prettyPrinted: false
            )
        } catch {
            throw InventoryBackupRestoreError.invalidRelationships
        }
    }

    private static func validateShape(_ root: [String: Any]) throws {
        guard Set(root.keys) == ["formatIdentifier", "artifactType", "schemaVersion", "metadata", "inventory"],
              let metadata = root["metadata"] as? [String: Any],
              Set(metadata.keys) == ["createdAt", "appVersion", "appBuild", "platform"],
              let inventory = root["inventory"] as? [String: Any],
              Set(inventory.keys) == ["locations", "customCategories", "items"],
              let locations = inventory["locations"] as? [[String: Any]],
              let categories = inventory["customCategories"] as? [[String: Any]],
              let items = inventory["items"] as? [[String: Any]]
        else { throw InventoryBackupRestoreError.malformedFile }

        guard locations.allSatisfy({
            hasKeys(
                $0,
                required: ["id", "name", "notes", "createdAt", "updatedAt"],
                optional: ["iconID"]
            )
        }), categories.allSatisfy({
            hasKeys($0, required: ["id", "name", "createdAt", "updatedAt"])
        }), items.allSatisfy({
            hasKeys(
                $0,
                required: [
                    "id", "name", "category", "locationName", "quantity", "condition",
                    "tags", "notes", "createdAt", "updatedAt"
                ],
                optional: ["containerName", "iconID"]
            )
        }) else {
            throw InventoryBackupRestoreError.malformedFile
        }
    }

    private static func hasKeys(
        _ object: [String: Any],
        required: Set<String>,
        optional: Set<String> = []
    ) -> Bool {
        let keys = Set(object.keys)
        return required.isSubset(of: keys) && keys.isSubset(of: required.union(optional))
    }

    private static func uniqueNameIndex(_ entries: [(String, String)]) throws -> [String: String] {
        var result: [String: String] = [:]
        for (name, id) in entries {
            let key = nameKey(name)
            guard result.updateValue(id, forKey: key) == nil else {
                throw InventoryBackupRestoreError.invalidRelationships
            }
        }
        return result
    }

    private static func nameKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
