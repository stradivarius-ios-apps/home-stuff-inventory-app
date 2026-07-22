import Foundation
import SwiftData

struct InventoryBackupRestoreService: Sendable {
    typealias StageObserver = @Sendable (InventoryBackupRestoreStage) throws -> Void

    @MainActor
    func restore(
        _ plan: InventoryBackupRestorePlan,
        in context: ModelContext,
        metadataSource: InventoryBackupMetadataSource? = nil,
        recoveryStore: InventoryBackupRecoveryStore? = nil,
        stageObserver: StageObserver? = nil
    ) async throws -> InventoryBackupRecoverySnapshot {
        try Task.checkCancellation()
        try stageObserver?(.recoverySnapshot)

        let originalSnapshot: InventoryPortabilitySnapshotV1
        let originalPlaceOpenRecords: [InventoryBackupRecoveryPlaceOpenRecord]
        let recoveryData: Data
        do {
            originalSnapshot = try InventoryBackupSnapshotter.capture(in: context)
            originalPlaceOpenRecords = try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).map {
                InventoryBackupRecoveryPlaceOpenRecord(id: $0.id, placeIdentity: $0.placeIdentity, placeID: $0.placeID, openCount: $0.openCount, lastOpenedAt: $0.lastOpenedAt)
            }
            let source = try metadataSource ?? .current()
            recoveryData = try await InventoryBackupEncoderService().encode(
                snapshot: originalSnapshot,
                metadata: InventoryPortabilityMetadataV1(
                    createdAt: .now,
                    appVersion: source.appVersion,
                    appBuild: source.appBuild
                )
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw InventoryBackupRestoreError.recoverySnapshotFailed
        }

        try Task.checkCancellation()
        try stageObserver?(.beforeReplacement)

        let candidateData = try InventoryPortabilityEncoder.encode(
            snapshot: plan.document.inventory,
            metadata: plan.document.metadata,
            artifactType: .completeBackup,
            prettyPrinted: false
        )
        let recoveryStore = try recoveryStore ?? .live()
        try recoveryStore.prepare(
            safetyData: recoveryData,
            candidateData: candidateData,
            digest: plan.document.integrity.digest,
            placeOpenRecordsData: try JSONEncoder().encode(originalPlaceOpenRecords)
        )

        // Isolate destructive staging from the live UI context. A failed transaction can then be
        // discarded without rolling back pending edits that existed before restore started.
        let stagingContext = ModelContext(context.container)
        stagingContext.autosaveEnabled = false

        do {
            try stagingContext.transaction {
                try Task.checkCancellation()
                try stageObserver?(.replacing)
                try Self.deletePersonalDataset(in: stagingContext)
                try Self.insert(plan.document.inventory, in: stagingContext)

                try Task.checkCancellation()
                try stageObserver?(.verification)
                let applied = try InventoryBackupSnapshotter.capture(in: stagingContext)
                guard applied == plan.document.inventory else {
                    throw InventoryBackupRestoreError.verificationFailed
                }
                // The durable marker is written immediately before transaction commit. If the app
                // stops between marker and commit, startup selects the verified safety copy.
                try recoveryStore.markCommitted(digest: plan.document.integrity.digest)
            }
        } catch is CancellationError {
            stagingContext.rollback()
            throw CancellationError()
        } catch let error as InventoryBackupRestoreError {
            stagingContext.rollback()
            throw error
        } catch {
            stagingContext.rollback()
            throw InventoryBackupRestoreError.replacementFailed
        }

        do {
            try stageObserver?(.reopenVerification)
            let reopenedContext = ModelContext(context.container)
            let reopened = try InventoryBackupSnapshotter.capture(in: reopenedContext)
            guard reopened == plan.document.inventory else {
                throw InventoryBackupRestoreError.verificationFailed
            }
            try recoveryStore.markVerified(digest: plan.document.integrity.digest)
            context.rollback()
        } catch {
            do {
                try stageObserver?(.automaticRecovery)
                let safety = try recoveryStore.safetyDocument()
                let recoveryContext = ModelContext(context.container)
                try Self.replaceSnapshot(safety.inventory, in: recoveryContext)
                try Self.restorePlaceOpenRecords(originalPlaceOpenRecords, in: recoveryContext)
                let recoveredContext = ModelContext(context.container)
                guard try InventoryBackupSnapshotter.capture(in: recoveredContext) == safety.inventory else {
                    throw InventoryBackupRestoreError.recoveryRequired
                }
                try recoveryStore.markRecoveredOriginal(digest: plan.document.integrity.digest)
                context.rollback()
                throw InventoryBackupRestoreError.verificationFailed
            } catch let restoreError as InventoryBackupRestoreError
                where restoreError == .verificationFailed {
                throw restoreError
            } catch {
                throw InventoryBackupRestoreError.recoveryRequired
            }
        }

        return InventoryBackupRecoverySnapshot(data: recoveryData)
    }

    @MainActor
    static func replaceSnapshot(
        _ snapshot: InventoryPortabilitySnapshotV1,
        in context: ModelContext
    ) throws {
        context.autosaveEnabled = false
        do {
            try context.transaction {
                try deletePersonalDataset(in: context)
                try insert(snapshot, in: context)
                guard try InventoryBackupSnapshotter.capture(in: context) == snapshot else {
                    throw InventoryBackupRestoreError.verificationFailed
                }
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    static func restorePlaceOpenRecords(
        _ records: [InventoryBackupRecoveryPlaceOpenRecord],
        in context: ModelContext
    ) throws {
        for record in records {
            context.insert(InventoryPlaceOpenRecord(
                id: record.id,
                placeIdentity: record.placeIdentity,
                placeID: record.placeID,
                openCount: record.openCount,
                lastOpenedAt: record.lastOpenedAt
            ))
        }
        try context.save()
    }

    @MainActor
    private static func deletePersonalDataset(in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()) {
            context.delete(record)
        }
        for place in try context.fetch(FetchDescriptor<InventoryPlace>()) {
            context.delete(place)
        }
        for event in try context.fetch(FetchDescriptor<InventoryItemViewEvent>()) {
            context.delete(event)
        }
        for item in try context.fetch(FetchDescriptor<InventoryItem>()) {
            context.delete(item)
        }
        for category in try context.fetch(FetchDescriptor<InventoryCustomCategory>()) {
            context.delete(category)
        }
        for location in try context.fetch(FetchDescriptor<StorageLocation>()) {
            context.delete(location)
        }
    }

    @MainActor
    private static func insert(
        _ snapshot: InventoryPortabilitySnapshotV1,
        in context: ModelContext
    ) throws {
        for record in snapshot.locations {
            guard let id = UUID(uuidString: record.id),
                  let createdAt = InventoryPortabilityDate.date(from: record.createdAt),
                  let updatedAt = InventoryPortabilityDate.date(from: record.updatedAt)
            else { throw InventoryBackupRestoreError.invalidRelationships }
            let location = StorageLocation(
                id: id,
                name: record.name,
                iconID: record.iconID,
                notes: record.notes,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
            location.iconID = record.iconID
            context.insert(location)
        }

        for record in snapshot.customCategories {
            guard let id = UUID(uuidString: record.id),
                  let createdAt = InventoryPortabilityDate.date(from: record.createdAt),
                  let updatedAt = InventoryPortabilityDate.date(from: record.updatedAt)
            else { throw InventoryBackupRestoreError.invalidRelationships }
            context.insert(
                InventoryCustomCategory(
                    id: id,
                    name: record.name,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            )
        }

        for record in snapshot.places {
            guard let id = UUID(uuidString: record.id),
                  let locationID = UUID(uuidString: record.locationID),
                  let createdAt = InventoryPortabilityDate.date(from: record.createdAt),
                  let updatedAt = InventoryPortabilityDate.date(from: record.updatedAt)
            else { throw InventoryBackupRestoreError.invalidRelationships }
            context.insert(InventoryPlace(
                id: id,
                locationID: locationID,
                name: record.name,
                iconID: record.iconID,
                createdAt: createdAt,
                updatedAt: updatedAt
            ))
        }

        for record in snapshot.items {
            guard let id = UUID(uuidString: record.id),
                  let createdAt = InventoryPortabilityDate.date(from: record.createdAt),
                  let updatedAt = InventoryPortabilityDate.date(from: record.updatedAt)
            else { throw InventoryBackupRestoreError.invalidRelationships }
            let item = InventoryItem(
                id: id,
                name: record.name,
                category: record.categoryStorageValue,
                locationName: record.locationName,
                containerName: record.placeName,
                iconID: record.iconID,
                quantity: record.quantity,
                condition: record.conditionStorageValue,
                tags: record.tags,
                notes: record.notes,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
            // The backup is machine-restorable, so preserve persisted storage values exactly.
            item.category = record.categoryStorageValue
            item.containerName = record.placeName
            item.iconID = record.iconID
            item.condition = record.conditionStorageValue
            item.tags = record.tags
            item.notes = record.notes
            item.placeID = record.placeID.flatMap(UUID.init(uuidString:))
            context.insert(item)
        }

        for record in snapshot.recentItemViewEvents ?? [] {
            guard let id = UUID(uuidString: record.id),
                  let itemID = UUID(uuidString: record.itemID),
                  let viewedAt = InventoryPortabilityDate.date(from: record.viewedAt)
            else { throw InventoryBackupRestoreError.invalidRelationships }
            context.insert(InventoryItemViewEvent(id: id, itemID: itemID, viewedAt: viewedAt))
        }
    }
}
