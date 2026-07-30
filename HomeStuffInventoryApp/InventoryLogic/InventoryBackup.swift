import Foundation
import SwiftData

struct InventoryBackupMetadataSource: Sendable {
    let appVersion: String
    let appBuild: String

    static func current(bundle: Bundle = .main) throws -> Self {
        guard let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !appVersion.isEmpty,
              let appBuild = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !appBuild.isEmpty
        else {
            throw InventoryPortabilityCodecError.generationFailed
        }

        return Self(appVersion: appVersion, appBuild: appBuild)
    }
}

struct InventoryPreparedBackup: Sendable {
    let data: Data
    let suggestedFilename: String
}

enum InventoryBackupSnapshotter {
    /// Captures every record visible to the context without yielding the main actor, so UI edits cannot
    /// interleave collections. Avoid `ModelContext.transaction` here because it commits pending edits.
    @MainActor
    static func capture(in context: ModelContext) throws -> InventoryPortabilitySnapshotV1 {
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let customCategories = try context.fetch(FetchDescriptor<InventoryCustomCategory>())
        let items = try context.fetch(FetchDescriptor<InventoryItem>())
        let places = try context.fetch(FetchDescriptor<InventoryPlace>())
        let viewEvents = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
        let movementRecords = try context.fetch(FetchDescriptor<InventoryMovementRecord>())

        return makeSnapshot(
            locations: locations,
            customCategories: customCategories,
            items: items,
            places: places,
            viewEvents: viewEvents,
            movementRecords: movementRecords
        )
    }

    @MainActor
    static func makeSnapshot(
        locations: [StorageLocation],
        customCategories: [InventoryCustomCategory],
        items: [InventoryItem],
        places: [InventoryPlace],
        viewEvents: [InventoryItemViewEvent],
        movementRecords: [InventoryMovementRecord] = []
    ) -> InventoryPortabilitySnapshotV1 {
        let locationRecords = locations.map { location in
            InventoryPortabilityLocationV1(
                id: location.id.inventoryPortabilityString,
                name: location.name,
                iconID: location.iconID,
                notes: location.notes,
                createdAt: InventoryPortabilityDate.string(from: location.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: location.updatedAt)
            )
        }
        let customCategoryRecords = customCategories.map { category in
            InventoryPortabilityCustomCategoryV1(
                id: category.id.inventoryPortabilityString,
                name: category.name,
                createdAt: InventoryPortabilityDate.string(from: category.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: category.updatedAt)
            )
        }

        let itemRecords = items.map { item in
            InventoryPortabilityItemV1(
                id: item.id.inventoryPortabilityString,
                name: item.name,
                categoryStorageValue: item.category,
                customCategoryID: customCategoryID(for: item, in: customCategories),
                locationName: item.locationName,
                locationID: locationID(for: item, in: locations),
                placeName: item.containerName,
                placeID: item.placeID?.inventoryPortabilityString,
                iconID: item.iconID,
                quantity: item.quantity,
                conditionStorageValue: item.condition,
                tags: item.tags,
                notes: item.notes,
                createdAt: InventoryPortabilityDate.string(from: item.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: item.updatedAt)
            )
        }
        let placeRecords = places.map { place in
            InventoryPortabilityPlaceV1(
                id: place.id.inventoryPortabilityString,
                locationID: place.locationID.inventoryPortabilityString,
                name: place.name,
                iconID: PlaceIconCatalog.normalizedIconID(place.iconID),
                createdAt: InventoryPortabilityDate.string(from: place.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: place.updatedAt)
            )
        }
        let viewEventRecords = viewEvents.map { event in
            InventoryPortabilityRecentItemViewEventV1(
                id: event.id.inventoryPortabilityString,
                itemID: event.itemID.inventoryPortabilityString,
                viewedAt: InventoryPortabilityDate.string(from: event.viewedAt)
            )
        }
        let movementPortabilityRecords = movementRecords.map { record in
            InventoryPortabilityMovementRecordV1(
                id: record.id.inventoryPortabilityString,
                operationID: record.operationID.inventoryPortabilityString,
                itemID: record.itemID.inventoryPortabilityString,
                occurredAt: InventoryPortabilityDate.string(from: record.occurredAt),
                originStorageValue: record.originStorageValue,
                reversedOperationID: record.reversedOperationID?.inventoryPortabilityString,
                sourceLocationID: record.sourceLocationID?.inventoryPortabilityString,
                sourceLocationName: record.sourceLocationName,
                sourcePlaceID: record.sourcePlaceID?.inventoryPortabilityString,
                sourcePlaceName: record.sourcePlaceName,
                destinationLocationID: record.destinationLocationID?.inventoryPortabilityString,
                destinationLocationName: record.destinationLocationName,
                destinationPlaceID: record.destinationPlaceID?.inventoryPortabilityString,
                destinationPlaceName: record.destinationPlaceName
            )
        }

        return InventoryPortabilitySnapshotV1(
            locations: locationRecords,
            customCategories: customCategoryRecords,
            items: itemRecords,
            places: placeRecords,
            recentItemViewEvents: viewEventRecords,
            movementRecords: movementPortabilityRecords
        )
    }

    @MainActor
    private static func locationID(
        for item: InventoryItem,
        in locations: [StorageLocation]
    ) -> String? {
        let itemLocation = InventoryNormalizedName.location(item.locationName)
        guard !itemLocation.isMissing else {
            return nil
        }

        let matchingLocations = locations.filter {
            InventoryNormalizedName.location($0.name) == itemLocation
        }
        guard matchingLocations.count == 1 else {
            return nil
        }

        return matchingLocations[0].id.inventoryPortabilityString
    }

    @MainActor
    private static func customCategoryID(
        for item: InventoryItem,
        in customCategories: [InventoryCustomCategory]
    ) -> String? {
        guard InventoryCategory.resolveBuiltInCategory(from: item.category) == nil else {
            return nil
        }

        let matchingCategories = customCategories.filter {
            InventoryListManagement.categoryValuesMatch($0.name, item.category)
        }
        guard matchingCategories.count == 1 else {
            return nil
        }

        return matchingCategories[0].id.inventoryPortabilityString
    }
}

actor InventoryBackupEncoderService {
    private let limits: InventoryPortabilityLimits
    init(limits: InventoryPortabilityLimits = .production) { self.limits = limits }
    func encode(
        snapshot: InventoryPortabilitySnapshotV1,
        metadata: InventoryPortabilityMetadataV1
    ) throws -> Data {
        try Task.checkCancellation()
        let data = try InventoryPortabilityEncoder.encode(
            snapshot: snapshot,
            metadata: metadata,
            artifactType: .completeBackup,
            prettyPrinted: false,
            limits: limits
        )
        try Task.checkCancellation()

        let decoded = try InventoryPortabilityEncoder.decodeAndVerify(data, limits: limits)
        guard decoded.artifactType == .completeBackup,
              decoded.inventory == snapshot
        else {
            throw InventoryPortabilityCodecError.generationFailed
        }

        return data
    }
}

struct InventoryBackupService: Sendable {
    private let encoder: InventoryBackupEncoderService

    init(encoder: InventoryBackupEncoderService = InventoryBackupEncoderService()) {
        self.encoder = encoder
    }

    @MainActor
    func prepareBackup(
        in context: ModelContext,
        createdAt: Date = .now,
        metadataSource: InventoryBackupMetadataSource? = nil
    ) async throws -> InventoryPreparedBackup {
        try Task.checkCancellation()
        let snapshot = try InventoryBackupSnapshotter.capture(in: context)
        let metadataSource = try metadataSource ?? .current()
        let metadata = InventoryPortabilityMetadataV1(
            createdAt: createdAt,
            appVersion: metadataSource.appVersion,
            appBuild: metadataSource.appBuild
        )
        let data = try await encoder.encode(snapshot: snapshot, metadata: metadata)

        return InventoryPreparedBackup(
            data: data,
            suggestedFilename: InventoryBackupFilename.suggested(for: createdAt)
        )
    }
}

enum InventoryBackupFilename {
    static func suggested(for date: Date) -> String {
        "Home-Stuff-Inventory-Backup-\(InventoryPortabilityDate.string(from: date).replacingOccurrences(of: ":", with: "-"))"
    }
}
