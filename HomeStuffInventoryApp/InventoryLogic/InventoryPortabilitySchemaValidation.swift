import Foundation

enum InventoryPortabilityShapeValidator {
    private static let rootKeys: Set<String> = [
        "formatIdentifier", "artifactType", "schemaVersion", "integrity", "metadata", "inventory"
    ]
    private static let integrityKeys: Set<String> = ["algorithm", "canonicalization", "digest"]
    private static let locationKeys: Set<String> = [
        "id", "name", "iconID", "notes", "createdAt", "updatedAt"
    ]
    private static let categoryKeys: Set<String> = ["id", "name", "createdAt", "updatedAt"]
    private static let itemKeys: Set<String> = [
        "id", "name", "categoryStorageValue", "customCategoryID", "locationName", "locationID",
        "placeName", "placeID", "iconID", "quantity", "conditionStorageValue", "tags", "notes", "createdAt", "updatedAt"
    ]
    private static let placeKeys: Set<String> = ["id", "locationID", "name", "iconID", "createdAt", "updatedAt"]
    private static let eventKeys: Set<String> = ["id", "itemID", "viewedAt"]
    private static let movementKeys: Set<String> = [
        "id", "operationID", "itemID", "occurredAt", "originStorageValue", "reversedOperationID",
        "sourceLocationID", "sourceLocationName", "sourcePlaceID", "sourcePlaceName",
        "destinationLocationID", "destinationLocationName", "destinationPlaceID", "destinationPlaceName"
    ]

    static func validate(_ root: [String: Any], artifactType: String, schemaVersion: Int) throws {
        try requireOnly(root, keys: rootKeys)
        guard let integrity = root["integrity"] as? [String: Any],
              let inventory = root["inventory"] as? [String: Any]
        else { throw invalid }
        try requireOnly(integrity, keys: integrityKeys)

        var inventoryKeys: Set<String> = ["locations", "customCategories", "items"]
        if schemaVersion >= 2 && artifactType == InventoryPortabilityArtifactType.completeBackup.rawValue {
            inventoryKeys.insert("places")
        }
        if artifactType == InventoryPortabilityArtifactType.completeBackup.rawValue {
            inventoryKeys.insert("recentItemViewEvents")
        }
        if schemaVersion >= 3 {
            inventoryKeys.insert("movementRecords")
        }
        try requireOnly(inventory, keys: inventoryKeys)
        try validateRecords(inventory["locations"], keys: locationKeys)
        try validateRecords(inventory["customCategories"], keys: categoryKeys)
        try validateRecords(inventory["items"], keys: schemaVersion >= 2 ? itemKeys : itemKeys.subtracting(["placeID"]))
        if schemaVersion >= 2 && artifactType == InventoryPortabilityArtifactType.completeBackup.rawValue {
            try validateRecords(inventory["places"], keys: placeKeys)
        }
        if artifactType == InventoryPortabilityArtifactType.completeBackup.rawValue {
            try validateRecords(inventory["recentItemViewEvents"], keys: eventKeys)
        }
        if schemaVersion >= 3 {
            try validateRecords(inventory["movementRecords"], keys: movementKeys)
        }
    }

    private static var invalid: InventoryPortabilityCodecError { .invalidSchema }

    private static func requireOnly(_ object: [String: Any], keys: Set<String>) throws {
        guard Set(object.keys).isSubset(of: keys) else { throw invalid }
    }

    private static func validateRecords(_ value: Any?, keys: Set<String>) throws {
        guard let records = value as? [Any] else { throw invalid }
        for record in records {
            guard let object = record as? [String: Any] else { throw invalid }
            try requireOnly(object, keys: keys)
        }
    }
}

enum InventoryPortabilityValidator {
    static func validate(
        _ snapshot: InventoryPortabilitySnapshotV1,
        artifactType: InventoryPortabilityArtifactType,
        schemaVersion: Int = InventoryPortabilityEncoder.schemaVersion,
        invalidError: InventoryPortabilityCodecError = .invalidSchema
    ) throws {
        switch artifactType {
        case .readableExport:
            guard snapshot.recentItemViewEvents == nil, snapshot.places.isEmpty,
                  snapshot.items.allSatisfy({ $0.placeID == nil }) else { throw invalidError }
        case .completeBackup:
            guard snapshot.recentItemViewEvents != nil else { throw invalidError }
        }
        if schemaVersion >= 3 {
            guard snapshot.movementRecords != nil else { throw invalidError }
        } else if snapshot.movementRecords != nil {
            throw invalidError
        }

        var allIDs = Set<String>()
        let locationsByName = try uniqueNameIndex(
            snapshot.locations,
            name: \InventoryPortabilityLocationV1.name,
            invalidError: invalidError
        )
        let categoriesByName = try uniqueNameIndex(
            snapshot.customCategories,
            name: \InventoryPortabilityCustomCategoryV1.name,
            invalidError: invalidError
        )
        let locationIDs = try validatedIDs(
            snapshot.locations.map(\.id),
            allIDs: &allIDs,
            invalidError: invalidError
        )
        let placeIDs = try validatedIDs(snapshot.places.map(\.id), allIDs: &allIDs, invalidError: invalidError)
        let categoryIDs = try validatedIDs(
            snapshot.customCategories.map(\.id),
            allIDs: &allIDs,
            invalidError: invalidError
        )
        let itemIDs = try validatedIDs(
            snapshot.items.map(\.id),
            allIDs: &allIDs,
            invalidError: invalidError
        )

        for location in snapshot.locations {
            try validateRequiredName(location.name, invalidError: invalidError)
            try validateDates(createdAt: location.createdAt, updatedAt: location.updatedAt, invalidError: invalidError)
        }
        for category in snapshot.customCategories {
            try validateRequiredName(category.name, invalidError: invalidError)
            try validateDates(createdAt: category.createdAt, updatedAt: category.updatedAt, invalidError: invalidError)
        }
        var placeScopes = Set<String>()
        let placesByID = Dictionary(uniqueKeysWithValues: snapshot.places.map { ($0.id, $0) })
        for place in snapshot.places {
            guard locationIDs.contains(place.locationID),
                  PlaceIconCatalog.normalizedIconID(place.iconID) == place.iconID
            else { throw invalidError }
            try validateRequiredName(place.name, invalidError: invalidError)
            try validateDates(createdAt: place.createdAt, updatedAt: place.updatedAt, invalidError: invalidError)
            let scope = "\(place.locationID)\u{1F}\(InventoryNormalizedName.place(place.name).comparisonKey)"
            guard placeScopes.insert(scope).inserted else { throw invalidError }
        }
        for item in snapshot.items {
            try validateRequiredName(item.name, invalidError: invalidError)
            try validateDates(createdAt: item.createdAt, updatedAt: item.updatedAt, invalidError: invalidError)
            guard item.quantity >= 1 else { throw invalidError }
            guard InventoryTagNormalization.normalizedTags(from: item.tags) == item.tags else { throw invalidError }

            let categoryMatch = categoriesByName[nameKey(item.categoryStorageValue)]
            if let categoryMatch {
                guard item.customCategoryID == categoryMatch.id,
                      categoryIDs.contains(categoryMatch.id)
                else { throw invalidError }
            } else if item.customCategoryID != nil {
                throw invalidError
            }

            let trimmedLocationName = item.locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            let locationMatch = locationsByName[nameKey(trimmedLocationName)]
            if let locationMatch {
                guard item.locationID == locationMatch.id,
                      locationIDs.contains(locationMatch.id)
                else { throw invalidError }
            } else if item.locationID != nil {
                throw invalidError
            }
            if let placeID = item.placeID {
                guard placeIDs.contains(placeID), let place = placesByID[placeID],
                      item.locationID == place.locationID,
                      InventoryNormalizedName.place(item.placeName) == InventoryNormalizedName.place(place.name)
                else { throw invalidError }
            }
        }

        for event in snapshot.recentItemViewEvents ?? [] {
            _ = try validatedIDs([event.id], allIDs: &allIDs, invalidError: invalidError)
            guard canonicalUUID(event.itemID), itemIDs.contains(event.itemID) else { throw invalidError }
            _ = try date(event.viewedAt, invalidError: invalidError)
        }

        var operationFacts: [String: (occurredAt: String, origin: String, reversed: String?, itemIDs: Set<String>)] = [:]
        for record in snapshot.movementRecords ?? [] {
            _ = try validatedIDs([record.id], allIDs: &allIDs, invalidError: invalidError)
            guard canonicalUUID(record.operationID),
                  canonicalUUID(record.itemID),
                  itemIDs.contains(record.itemID),
                  !record.originStorageValue.isEmpty
            else { throw invalidError }
            if let reversedOperationID = record.reversedOperationID,
               !canonicalUUID(reversedOperationID) {
                throw invalidError
            }
            for snapshotID in [
                record.sourceLocationID,
                record.sourcePlaceID,
                record.destinationLocationID,
                record.destinationPlaceID
            ] {
                if let snapshotID, !canonicalUUID(snapshotID) {
                    throw invalidError
                }
            }
            _ = try date(record.occurredAt, invalidError: invalidError)

            if var facts = operationFacts[record.operationID] {
                guard facts.occurredAt == record.occurredAt,
                      facts.origin == record.originStorageValue,
                      facts.reversed == record.reversedOperationID,
                      facts.itemIDs.insert(record.itemID).inserted
                else { throw invalidError }
                operationFacts[record.operationID] = facts
            } else {
                operationFacts[record.operationID] = (
                    record.occurredAt,
                    record.originStorageValue,
                    record.reversedOperationID,
                    [record.itemID]
                )
            }
        }
    }

    private static func validatedIDs(
        _ ids: [String],
        allIDs: inout Set<String>,
        invalidError: InventoryPortabilityCodecError
    ) throws -> Set<String> {
        for id in ids {
            guard canonicalUUID(id), allIDs.insert(id).inserted else { throw invalidError }
        }
        return Set(ids)
    }

    private static func canonicalUUID(_ value: String) -> Bool {
        guard value == value.lowercased(), let uuid = UUID(uuidString: value) else { return false }
        return uuid.inventoryPortabilityString == value
    }

    private static func validateRequiredName(
        _ name: String,
        invalidError: InventoryPortabilityCodecError
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw invalidError }
    }

    private static func validateDates(
        createdAt: String,
        updatedAt: String,
        invalidError: InventoryPortabilityCodecError
    ) throws {
        let created = try date(createdAt, invalidError: invalidError)
        let updated = try date(updatedAt, invalidError: invalidError)
        guard updated >= created else { throw invalidError }
    }

    private static func date(
        _ value: String,
        invalidError: InventoryPortabilityCodecError
    ) throws -> Date {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#, options: .regularExpression) != nil
        else { throw invalidError }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: value) else { throw invalidError }
        return date
    }

    private static func uniqueNameIndex<T>(
        _ values: [T],
        name: KeyPath<T, String>,
        invalidError: InventoryPortabilityCodecError
    ) throws -> [String: T] {
        var result: [String: T] = [:]
        for value in values {
            let key = nameKey(value[keyPath: name])
            guard result.updateValue(value, forKey: key) == nil else { throw invalidError }
        }
        return result
    }

    private static func nameKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
