import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupRecoveryTests: InventoryBackupRestoreTestCase {
    let support = InventoryBackupRestoreTestSupport()

    @Test func rejectedPlanningLeavesLivePendingEditsAndRecoveryPathsUntouched() async throws {
        let context = try makeTargetContext()
        context.autosaveEnabled = false
        context.insert(InventoryItem(name: "Pending Item", locationName: ""))
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let recoveryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("limits-recovery-\(UUID().uuidString)", isDirectory: true)
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 1, maximumJSONNestingDepth: 32,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10, maximumRecentItemViewEvents: 10,
            maximumTagsPerItem: 10, maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
        await #expect(throws: InventoryBackupRestoreError.fileTooLarge) {
            try await InventoryBackupRestorePlanner(limits: limits).plan(data: backupData(snapshot: unicodeSnapshot()))
        }
        #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
        #expect(context.hasChanges)
        #expect(!FileManager.default.fileExists(atPath: recoveryDirectory.path))
    }
    @Test func verifiedRestorePurgesAllTransientRecoveryArtifacts() async throws {
        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let store = try makeRecoveryStore()

        let recovery = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: unicodeSnapshot()),
            in: context,
            metadataSource: metadataSource,
            recoveryStore: store
        )

        let recoveryDocument = try InventoryPortabilityEncoder.decodeAndVerify(recovery.data)
        #expect(recoveryDocument.artifactType == .completeBackup)
        #expect(recoveryDocument.inventory == original)
        #expect(!FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.journalURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.directory.path))
    }
    @Test func successfulAutomaticRecoveryPurgesAllTransientRecoveryArtifacts() async throws {
        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let existing = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        context.insert(InventoryPlaceOpenRecord(placeIdentity: InventoryPlaceIdentity.make(for: existing).rawValue, openCount: 3, lastOpenedAt: date))
        try context.save()
        let store = try makeRecoveryStore()

        await #expect(throws: InventoryBackupRestoreError.verificationFailed) {
            try await InventoryBackupRestoreService().restore(
                try await makePlan(snapshot: unicodeSnapshot()),
                in: context,
                metadataSource: metadataSource,
                recoveryStore: store,
                stageObserver: { stage in
                    if stage == .reopenVerification {
                        throw InventoryBackupRestoreError.verificationFailed
                    }
                }
            )
        }

        let reopened = ModelContext(context.container)
        #expect(try InventoryBackupSnapshotter.capture(in: reopened) == original)
        let restoredRecord = try #require(reopened.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(restoredRecord.openCount == 3)
        #expect(!FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.journalURL.path))
    }
    @Test func failedAutomaticRecoveryRetainsArtifactsAndRequiresRecovery() async throws {
        let context = try makeTargetContext()
        let store = try makeRecoveryStore()

        await #expect(throws: InventoryBackupRestoreError.recoveryRequired) {
            try await InventoryBackupRestoreService().restore(
                try await makePlan(snapshot: unicodeSnapshot()),
                in: context,
                metadataSource: metadataSource,
                recoveryStore: store,
                stageObserver: { stage in
                    if stage == .reopenVerification {
                        throw InventoryBackupRestoreError.verificationFailed
                    }
                    if stage == .automaticRecovery {
                        throw InventoryBackupRestoreError.recoveryRequired
                    }
                }
            )
        }

        #expect(try store.journal()?.phase == .committedAwaitingVerification)
        #expect(FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(FileManager.default.fileExists(atPath: store.journalURL.path))
    }
    @Test func startupRecoverySelectsCandidateOnlyWhenPersistentStoreMatchesIt() async throws {
        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let candidate = unicodeSnapshot()
        let store = try makeRecoveryStore()
        let candidateData = try backupData(snapshot: candidate)
        let candidateDigest = try InventoryPortabilityEncoder.decodeAndVerify(candidateData).integrity.digest
        try store.prepare(
            safetyData: backupData(snapshot: original),
            candidateData: candidateData,
            digest: candidateDigest
        )
        try store.markCommitted(digest: candidateDigest)

        try InventoryBackupRecoveryCoordinator.recoverIfNeeded(
            container: context.container,
            store: store
        )

        #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(context.container)) == original)
        #expect(!FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.journalURL.path))

        let candidateContext = try makeTargetContext()
        try InventoryBackupRestoreService.replaceSnapshot(candidate, in: candidateContext)
        let matchingStore = try makeRecoveryStore()
        try matchingStore.prepare(
            safetyData: backupData(snapshot: original),
            candidateData: candidateData,
            digest: candidateDigest
        )
        try matchingStore.markCommitted(digest: candidateDigest)

        try InventoryBackupRecoveryCoordinator.recoverIfNeeded(
            container: candidateContext.container,
            store: matchingStore
        )

        #expect(!FileManager.default.fileExists(atPath: matchingStore.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: matchingStore.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: matchingStore.journalURL.path))
        #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(candidateContext.container)) == candidate)
    }
    @Test func startupSafetyRecoveryRestoresDurablePlaceOpenHistory() async throws {
        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let existing = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
        let history = InventoryBackupRecoveryPlaceOpenRecord(
            id: UUID(),
            placeIdentity: InventoryPlaceIdentity.make(for: existing).rawValue,
            placeID: nil,
            openCount: 7,
            lastOpenedAt: date
        )
        let candidate = unicodeSnapshot()
        let candidateData = try backupData(snapshot: candidate)
        let digest = try InventoryPortabilityEncoder.decodeAndVerify(candidateData).integrity.digest
        let store = try makeRecoveryStore()
        try store.prepare(
            safetyData: backupData(snapshot: original),
            candidateData: candidateData,
            digest: digest,
            placeOpenRecordsData: try JSONEncoder().encode([history])
        )
        try store.markCommitted(digest: digest)

        try InventoryBackupRecoveryCoordinator.recoverIfNeeded(container: context.container, store: store)

        let reopened = ModelContext(context.container)
        #expect(try InventoryBackupSnapshotter.capture(in: reopened) == original)
        let restoredHistory = try #require(reopened.fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
        #expect(restoredHistory.id == history.id)
        #expect(restoredHistory.openCount == 7)
        #expect(!FileManager.default.fileExists(atPath: store.placeOpenRecordsURL.path))
    }
    @Test func startupSafetyRecoveryRequiresPresentAndReadablePlaceOpenHistoryArtifact() async throws {
        for artifactState in ["missing", "corrupt"] {
            let context = try makeTargetContext()
            let existing = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first)
            let originalHistory = InventoryPlaceOpenRecord(
                placeIdentity: InventoryPlaceIdentity.make(for: existing).rawValue,
                openCount: 9,
                lastOpenedAt: date
            )
            context.insert(originalHistory)
            try context.save()
            let original = try InventoryBackupSnapshotter.capture(in: context)
            let candidate = unicodeSnapshot()
            let candidateData = try backupData(snapshot: candidate)
            let digest = try InventoryPortabilityEncoder.decodeAndVerify(candidateData).integrity.digest
            let store = try makeRecoveryStore()
            try store.prepare(
                safetyData: backupData(snapshot: original),
                candidateData: candidateData,
                digest: digest,
                placeOpenRecordsData: try JSONEncoder().encode([
                    InventoryBackupRecoveryPlaceOpenRecord(
                        id: originalHistory.id,
                        placeIdentity: originalHistory.placeIdentity,
                        placeID: originalHistory.placeID,
                        openCount: originalHistory.openCount,
                        lastOpenedAt: originalHistory.lastOpenedAt
                    )
                ])
            )
            try store.markCommitted(digest: digest)
            if artifactState == "missing" {
                try FileManager.default.removeItem(at: store.placeOpenRecordsURL)
            } else {
                try Data("not JSON".utf8).write(to: store.placeOpenRecordsURL, options: .atomic)
            }

            #expect(throws: InventoryBackupRestoreError.recoveryRequired) {
                try InventoryBackupRecoveryCoordinator.recoverIfNeeded(container: context.container, store: store)
            }

            #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(context.container)) == original)
            let preservedHistory = try #require(ModelContext(context.container).fetch(FetchDescriptor<InventoryPlaceOpenRecord>()).first)
            #expect(preservedHistory.id == originalHistory.id)
            #expect(try store.journal()?.phase == .committedAwaitingVerification)
            #expect(FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
            #expect(FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
            #expect(FileManager.default.fileExists(atPath: store.journalURL.path))
        }
    }
    @Test func cancellationAfterCommitMarkerIsDeferredUntilAutomaticRecoveryCompletes() async throws {
        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let store = try makeRecoveryStore()

        await #expect(throws: InventoryBackupRestoreError.verificationFailed) {
            try await InventoryBackupRestoreService().restore(
                try await makePlan(snapshot: unicodeSnapshot()),
                in: context,
                metadataSource: metadataSource,
                recoveryStore: store,
                stageObserver: { stage in
                    if stage == .reopenVerification { throw CancellationError() }
                }
            )
        }

        #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(context.container)) == original)
        #expect(!FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.journalURL.path))
    }
    @Test func preCommitStartupRecoveryRetainsSafetyUntilOriginalIsDurablyResolved() async throws {
        let context = try makeTargetContext()
        let original = try InventoryBackupSnapshotter.capture(in: context)
        let candidate = unicodeSnapshot()
        let store = try makeRecoveryStore()
        let candidateData = try backupData(snapshot: candidate)
        let digest = try InventoryPortabilityEncoder.decodeAndVerify(candidateData).integrity.digest
        try store.prepare(safetyData: backupData(snapshot: original), candidateData: candidateData, digest: digest)

        #expect(FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        try InventoryBackupRecoveryCoordinator.recoverIfNeeded(container: context.container, store: store)

        #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(context.container)) == original)
        #expect(!FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.journalURL.path))
    }
    @Test func terminalCleanupFailureKeepsVerifiedDatasetAndRetriesAtStartup() async throws {
        let context = try makeTargetContext()
        let candidate = unicodeSnapshot()
        let removalFailure = RecoveryArtifactRemovalFailure()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("inventory-restore-cleanup-retry-\(UUID().uuidString)", isDirectory: true)
        let store = InventoryBackupRecoveryStore(
            directory: directory,
            removeItem: { url in
                if url.lastPathComponent == "pre-restore-safety-backup.json", removalFailure.shouldFail {
                    throw CocoaError(.fileWriteNoPermission)
                }
                try FileManager.default.removeItem(at: url)
            }
        )

        _ = try await InventoryBackupRestoreService().restore(
            try await makePlan(snapshot: candidate),
            in: context,
            metadataSource: metadataSource,
            recoveryStore: store
        )

        #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(context.container)) == candidate)
        #expect(try store.journal()?.phase == .verified)
        #expect(FileManager.default.fileExists(atPath: store.safetyBackupURL.path))

        removalFailure.shouldFail = false
        try InventoryBackupRecoveryCoordinator.recoverIfNeeded(container: context.container, store: store)

        #expect(try InventoryBackupSnapshotter.capture(in: ModelContext(context.container)) == candidate)
        #expect(!FileManager.default.fileExists(atPath: store.safetyBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.candidateBackupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.journalURL.path))
    }
}
