import Foundation

enum InventoryPortabilityRawPreflight {
    static func validate(_ data: Data, limits: InventoryPortabilityLimits) throws {
        guard String(data: data, encoding: .utf8) != nil else { throw InventoryPortabilityCodecError.invalidEncoding }
        var containers: [UInt8] = [], inString = false, escaped = false
        for byte in data {
            if inString {
                if escaped { escaped = false }
                else if byte == 0x5C { escaped = true }
                else if byte == 0x22 { inString = false }
                continue
            }
            if byte == 0x22 { inString = true; continue }
            if byte == 0x7B || byte == 0x5B {
                containers.append(byte)
                if containers.count > limits.maximumJSONNestingDepth { throw InventoryPortabilityCodecError.resourceLimitExceeded }
            } else if byte == 0x7D || byte == 0x5D {
                guard let opening = containers.popLast(), (opening == 0x7B && byte == 0x7D) || (opening == 0x5B && byte == 0x5D) else {
                    throw InventoryPortabilityCodecError.malformedJSON
                }
            }
        }
        if inString || !containers.isEmpty { throw InventoryPortabilityCodecError.malformedJSON }
    }
}

enum InventoryPortabilityLimitValidator {
    static func validateEnvelope(
        metadata: InventoryPortabilityMetadataV1,
        artifactType: InventoryPortabilityArtifactType,
        integrity: InventoryPortabilityIntegrityV1,
        limits: InventoryPortabilityLimits
    ) throws {
        let strings = [
            InventoryPortabilityEncoder.formatIdentifier,
            artifactType.rawValue,
            metadata.createdAt,
            metadata.appVersion,
            metadata.appBuild,
            metadata.platform,
            integrity.algorithm,
            integrity.canonicalization,
            integrity.digest
        ]
        for string in strings where string.lengthOfBytes(using: .utf8) > limits.maximumUTF8BytesPerString {
            throw InventoryPortabilityCodecError.resourceLimitExceeded
        }
    }

    static func validateRaw(_ root: [String: Any], limits: InventoryPortabilityLimits) throws {
        try validateStrings(root, limits: limits)
        guard let inventory = root["inventory"] as? [String: Any],
              let locations = inventory["locations"] as? [Any],
              let categories = inventory["customCategories"] as? [Any],
              let items = inventory["items"] as? [Any]
        else { throw InventoryPortabilityCodecError.invalidSchema }
        let places = inventory["places"] as? [Any] ?? []
        let events = inventory["recentItemViewEvents"] as? [Any] ?? []
        let movements = inventory["movementRecords"] as? [Any] ?? []
        try validateCounts(locations: locations.count, places: places.count, categories: categories.count, items: items.count, events: events.count, movements: movements.count, limits: limits)
        for item in items {
            guard let tags = (item as? [String: Any])?["tags"] as? [Any] else { throw InventoryPortabilityCodecError.invalidSchema }
            guard tags.count <= limits.maximumTagsPerItem else { throw InventoryPortabilityCodecError.resourceLimitExceeded }
        }
    }

    static func validate(_ snapshot: InventoryPortabilitySnapshotV1, limits: InventoryPortabilityLimits) throws {
        let events = snapshot.recentItemViewEvents ?? []
        let movements = snapshot.movementRecords ?? []
        try validateCounts(locations: snapshot.locations.count, places: snapshot.places.count, categories: snapshot.customCategories.count, items: snapshot.items.count, events: events.count, movements: movements.count, limits: limits)
        var strings: [String?] = []
        strings += snapshot.locations.flatMap { [$0.id, $0.name, $0.iconID, $0.notes, $0.createdAt, $0.updatedAt] }
        strings += snapshot.customCategories.flatMap { [$0.id, $0.name, $0.createdAt, $0.updatedAt] }
        strings += snapshot.places.flatMap { [$0.id, $0.locationID, $0.name, $0.iconID, $0.createdAt, $0.updatedAt] }
        for item in snapshot.items {
            strings += [item.id, item.name, item.categoryStorageValue, item.customCategoryID, item.locationName, item.locationID, item.placeName, item.placeID, item.iconID, item.conditionStorageValue, item.notes, item.createdAt, item.updatedAt]
            strings += item.tags
        }
        strings += events.flatMap { [$0.id, $0.itemID, $0.viewedAt] }
        strings += movements.flatMap {
            [
                $0.id, $0.operationID, $0.itemID, $0.occurredAt, $0.originStorageValue,
                $0.reversedOperationID, $0.sourceLocationID, $0.sourceLocationName,
                $0.sourcePlaceID, $0.sourcePlaceName, $0.destinationLocationID,
                $0.destinationLocationName, $0.destinationPlaceID, $0.destinationPlaceName
            ]
        }
        for value in strings where (value?.lengthOfBytes(using: .utf8) ?? 0) > limits.maximumUTF8BytesPerString { throw InventoryPortabilityCodecError.resourceLimitExceeded }
        for item in snapshot.items where item.tags.count > limits.maximumTagsPerItem { throw InventoryPortabilityCodecError.resourceLimitExceeded }
    }

    private static func validateCounts(locations: Int, places: Int, categories: Int, items: Int, events: Int, movements: Int, limits: InventoryPortabilityLimits) throws {
        guard locations <= limits.maximumLocations, places <= limits.maximumPlaces,
              categories <= limits.maximumCustomCategories, items <= limits.maximumItems,
              events <= limits.maximumRecentItemViewEvents,
              movements <= limits.maximumMovementRecords,
              locations + places + categories + items + events + movements <= limits.maximumTotalRecords
        else { throw InventoryPortabilityCodecError.resourceLimitExceeded }
    }

    private static func validateStrings(_ value: Any, limits: InventoryPortabilityLimits) throws {
        if let string = value as? String {
            guard string.lengthOfBytes(using: .utf8) <= limits.maximumUTF8BytesPerString else { throw InventoryPortabilityCodecError.resourceLimitExceeded }; return
        }
        if let values = value as? [Any] { for value in values { try validateStrings(value, limits: limits) }; return }
        if let values = value as? [String: Any] { for value in values.values { try validateStrings(value, limits: limits) } }
    }
}
