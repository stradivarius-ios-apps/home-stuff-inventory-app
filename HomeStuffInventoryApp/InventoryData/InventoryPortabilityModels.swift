import Foundation

/// Safety ceilings for documents that cross the app's portability boundary.
struct InventoryPortabilityLimits: Sendable, Equatable {
    let maximumDocumentBytes: Int
    let maximumJSONNestingDepth: Int
    let maximumLocations: Int
    let maximumPlaces: Int
    let maximumCustomCategories: Int
    let maximumItems: Int
    let maximumRecentItemViewEvents: Int
    let maximumMovementRecords: Int
    let maximumTagsPerItem: Int
    let maximumUTF8BytesPerString: Int
    let maximumTotalRecords: Int

    init(
        maximumDocumentBytes: Int,
        maximumJSONNestingDepth: Int,
        maximumLocations: Int,
        maximumPlaces: Int = 50_000,
        maximumCustomCategories: Int,
        maximumItems: Int,
        maximumRecentItemViewEvents: Int,
        maximumMovementRecords: Int = 100_000,
        maximumTagsPerItem: Int,
        maximumUTF8BytesPerString: Int,
        maximumTotalRecords: Int
    ) {
        self.maximumDocumentBytes = maximumDocumentBytes
        self.maximumJSONNestingDepth = maximumJSONNestingDepth
        self.maximumLocations = maximumLocations
        self.maximumPlaces = maximumPlaces
        self.maximumCustomCategories = maximumCustomCategories
        self.maximumItems = maximumItems
        self.maximumRecentItemViewEvents = maximumRecentItemViewEvents
        self.maximumMovementRecords = maximumMovementRecords
        self.maximumTagsPerItem = maximumTagsPerItem
        self.maximumUTF8BytesPerString = maximumUTF8BytesPerString
        self.maximumTotalRecords = maximumTotalRecords
    }

    static let production = Self(
        maximumDocumentBytes: 16 * 1024 * 1024,
        maximumJSONNestingDepth: 32,
        maximumLocations: 10_000,
        maximumCustomCategories: 10_000,
        maximumItems: 50_000,
        maximumRecentItemViewEvents: 100_000,
        maximumMovementRecords: 100_000,
        maximumTagsPerItem: 1_000,
        maximumUTF8BytesPerString: 1 * 1024 * 1024,
        maximumTotalRecords: 150_000
    )
}

enum InventoryPortabilityArtifactType: String, Codable, Sendable {
    case readableExport
    case completeBackup
}

struct InventoryPortabilityIntegrityV1: Codable, Equatable, Sendable {
    let algorithm: String
    let canonicalization: String
    let digest: String

    init(digest: String) {
        algorithm = "SHA-256"
        canonicalization = "RFC8785"
        self.digest = digest
    }
}

struct InventoryPortabilityMetadataV1: Codable, Equatable, Sendable {
    let createdAt: String
    let appVersion: String
    let appBuild: String
    let platform: String

    init(
        createdAt: Date,
        appVersion: String,
        appBuild: String,
        platform: String = "iOS"
    ) {
        self.createdAt = InventoryPortabilityDate.string(from: createdAt)
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.platform = platform
    }
}

struct InventoryPortabilityLocationV1: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let iconID: String?
    let notes: String
    let createdAt: String
    let updatedAt: String
}

struct InventoryPortabilityCustomCategoryV1: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let createdAt: String
    let updatedAt: String
}

struct InventoryPortabilityItemV1: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let categoryStorageValue: String
    let customCategoryID: String?
    let locationName: String
    let locationID: String?
    let placeName: String?
    let placeID: String?
    let iconID: String?
    let quantity: Int
    let conditionStorageValue: String
    let tags: [String]
    let notes: String
    let createdAt: String
    let updatedAt: String

    init(
        id: String, name: String, categoryStorageValue: String, customCategoryID: String?,
        locationName: String, locationID: String?, placeName: String?, placeID: String? = nil,
        iconID: String?, quantity: Int, conditionStorageValue: String, tags: [String], notes: String,
        createdAt: String, updatedAt: String
    ) {
        self.id = id
        self.name = name
        self.categoryStorageValue = categoryStorageValue
        self.customCategoryID = customCategoryID
        self.locationName = locationName
        self.locationID = locationID
        self.placeName = placeName
        self.placeID = placeID
        self.iconID = iconID
        self.quantity = quantity
        self.conditionStorageValue = conditionStorageValue
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct InventoryPortabilityPlaceV1: Codable, Equatable, Sendable {
    let id: String
    let locationID: String
    let name: String
    let iconID: String
    let createdAt: String
    let updatedAt: String
}

struct InventoryPortabilityRecentItemViewEventV1: Codable, Equatable, Sendable {
    let id: String
    let itemID: String
    let viewedAt: String
}

struct InventoryPortabilityMovementRecordV1: Codable, Equatable, Sendable {
    let id: String
    let operationID: String
    let itemID: String
    let occurredAt: String
    let originStorageValue: String
    let reversedOperationID: String?
    let sourceLocationID: String?
    let sourceLocationName: String
    let sourcePlaceID: String?
    let sourcePlaceName: String?
    let destinationLocationID: String?
    let destinationLocationName: String
    let destinationPlaceID: String?
    let destinationPlaceName: String?
}

struct InventoryPortabilitySnapshotV1: Codable, Equatable, Sendable {
    let locations: [InventoryPortabilityLocationV1]
    let customCategories: [InventoryPortabilityCustomCategoryV1]
    let items: [InventoryPortabilityItemV1]
    let places: [InventoryPortabilityPlaceV1]
    let recentItemViewEvents: [InventoryPortabilityRecentItemViewEventV1]?
    let movementRecords: [InventoryPortabilityMovementRecordV1]?

    init(
        locations: [InventoryPortabilityLocationV1],
        customCategories: [InventoryPortabilityCustomCategoryV1],
        items: [InventoryPortabilityItemV1],
        places: [InventoryPortabilityPlaceV1] = [],
        recentItemViewEvents: [InventoryPortabilityRecentItemViewEventV1]? = nil,
        movementRecords: [InventoryPortabilityMovementRecordV1]? = []
    ) {
        self.locations = locations.sorted { $0.id < $1.id }
        self.customCategories = customCategories.sorted { $0.id < $1.id }
        self.items = items.sorted { $0.id < $1.id }
        self.places = places.sorted { $0.id < $1.id }
        self.recentItemViewEvents = recentItemViewEvents?.sorted {
            ($0.viewedAt, $0.id) < ($1.viewedAt, $1.id)
        }
        self.movementRecords = movementRecords?.sorted {
            ($0.occurredAt, $0.operationID, $0.itemID, $0.id)
                < ($1.occurredAt, $1.operationID, $1.itemID, $1.id)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case locations, customCategories, items, places, recentItemViewEvents, movementRecords
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            locations: try values.decode([InventoryPortabilityLocationV1].self, forKey: .locations),
            customCategories: try values.decode([InventoryPortabilityCustomCategoryV1].self, forKey: .customCategories),
            items: try values.decode([InventoryPortabilityItemV1].self, forKey: .items),
            places: try values.decodeIfPresent([InventoryPortabilityPlaceV1].self, forKey: .places) ?? [],
            recentItemViewEvents: try values.decodeIfPresent([InventoryPortabilityRecentItemViewEventV1].self, forKey: .recentItemViewEvents),
            movementRecords: try values.decodeIfPresent([InventoryPortabilityMovementRecordV1].self, forKey: .movementRecords)
        )
    }
}

struct InventoryPortabilityDocumentV1: Codable, Equatable, Sendable {
    let formatIdentifier: String
    let artifactType: InventoryPortabilityArtifactType
    let schemaVersion: Int
    let integrity: InventoryPortabilityIntegrityV1
    let metadata: InventoryPortabilityMetadataV1
    let inventory: InventoryPortabilitySnapshotV1
}

enum InventoryPortabilityDate {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }
}

extension UUID {
    var inventoryPortabilityString: String {
        uuidString.lowercased()
    }
}
