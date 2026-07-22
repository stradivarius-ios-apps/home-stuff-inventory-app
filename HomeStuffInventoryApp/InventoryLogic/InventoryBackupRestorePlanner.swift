import Foundation

actor InventoryBackupRestorePlanner {
    private let limits: InventoryPortabilityLimits
    init(limits: InventoryPortabilityLimits = .production) { self.limits = limits }
    func plan(
        data: Data,
        currentAppVersion: String? = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
        stageObserver: (@Sendable (InventoryBackupRestoreStage) throws -> Void)? = nil
    ) throws -> InventoryBackupRestorePlan {
        try Task.checkCancellation()
        try stageObserver?(.decoding)

        let document: InventoryPortabilityDocumentV1
        do {
            guard data.count <= limits.maximumDocumentBytes else {
                throw InventoryBackupRestoreError.fileTooLarge
            }
            try InventoryPortabilityRawPreflight.validate(data, limits: limits)
            let supportedData = try InventoryBackupLegacyMigration.migrateIfVersionZero(data, limits: limits) ?? data
            document = try InventoryBackupLegacyMigration.migratePlaces(
                in: InventoryPortabilityEncoder.decodeAndVerify(supportedData, limits: limits)
            )
        } catch let error as InventoryPortabilityCodecError {
            throw Self.restoreError(for: error)
        } catch let error as InventoryBackupRestoreError {
            throw error
        } catch {
            throw InventoryBackupRestoreError.malformedFile
        }

        guard document.artifactType == .completeBackup else {
            throw InventoryBackupRestoreError.wrongFileType
        }
        guard let backupDate = InventoryPortabilityDate.date(from: document.metadata.createdAt) else {
            throw InventoryBackupRestoreError.malformedFile
        }

        let places = document.inventory.places.count
        let warnings: [InventoryBackupRestoreWarning]
        if let currentAppVersion,
           currentAppVersion.compare(document.metadata.appVersion, options: .numeric) == .orderedAscending {
            warnings = [.olderAppVersion]
        } else {
            warnings = []
        }

        try Task.checkCancellation()
        return InventoryBackupRestorePlan(
            document: document,
            backupDate: backupDate,
            counts: InventoryBackupRestoreCounts(
                items: document.inventory.items.count,
                locations: document.inventory.locations.count,
                places: places,
                customCategories: document.inventory.customCategories.count,
                recentItemViews: document.inventory.recentItemViewEvents?.count ?? 0
            ),
            compatibilityWarnings: warnings
        )
    }

    private static func restoreError(
        for error: InventoryPortabilityCodecError
    ) -> InventoryBackupRestoreError {
        switch error {
        case .invalidEncoding:
            .unreadableFile
        case .malformedJSON, .invalidSchema:
            .malformedFile
        case .wrongFormat, .wrongArtifactType:
            .wrongFileType
        case .unsupportedNewerVersion:
            .unsupportedNewerVersion
        case .invalidIntegrity, .integrityMismatch:
            .integrityMismatch
        case .invalidRelationships:
            .invalidRelationships
        case .documentTooLarge:
            .fileTooLarge
        case .resourceLimitExceeded:
            .backupTooComplex
        case .generationFailed:
            .malformedFile
        }
    }
}
