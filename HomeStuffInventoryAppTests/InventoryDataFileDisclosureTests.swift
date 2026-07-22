import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

struct InventoryDataFileDisclosureTests {
    @Test func plaintextFileDisclosureStringsKeepTheRequiredSecurityMeaningInBothLocales() throws {
        let catalog = try localizationTestCatalog(
            at: localizationTestRepositoryRootURL().appendingPathComponent("HomeStuffInventoryApp/Resources/Localizable.xcstrings")
        )

        for language in ["en", "uk"] {
            let export = try #require(catalog["settings.fileDisclosure.export.message"]?.localizedValue(for: language))
            let backup = try #require(catalog["settings.fileDisclosure.backup.message"]?.localizedValue(for: language))

            #expect(!export.isEmpty)
            #expect(!backup.isEmpty)
            #expect(export != backup)
        }

        let englishExport = try #require(catalog["settings.fileDisclosure.export.message"]?.localizedValue(for: "en"))
        let englishBackup = try #require(catalog["settings.fileDisclosure.backup.message"]?.localizedValue(for: "en"))
        let ukrainianExport = try #require(catalog["settings.fileDisclosure.export.message"]?.localizedValue(for: "uk"))
        let ukrainianBackup = try #require(catalog["settings.fileDisclosure.backup.message"]?.localizedValue(for: "uk"))

        #expect(englishExport.contains("does not encrypt or password-protect"))
        #expect(englishExport.contains("destination you choose"))
        #expect(englishBackup.contains("recent item-view history"))
        #expect(englishBackup.contains("does not encrypt or password-protect"))
        #expect(ukrainianExport.contains("не шифрує й не захищає паролем"))
        #expect(ukrainianExport.contains("місця призначення"))
        #expect(ukrainianBackup.contains("історію нещодавніх переглядів"))
        #expect(ukrainianBackup.contains("не шифрує й не захищає паролем"))
    }

    @MainActor
    @Test func transferWorkflowExportsCleansUpAndMapsShareFailures() throws {
        var cleanupCount = 0
        let artifact = InventoryReadableExportArtifact(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/inventory-export.txt"),
            cleanupAction: {}
        )
        let workflow = InventoryDataTransferWorkflow(
            readableExport: { _, _, _ in artifact },
            artifactCleanup: { _ in cleanupCount += 1 }
        )

        workflow.export(items: [], locations: [], customCategories: [])
        #expect(workflow.phase == .sharingReadableExport)
        #expect(workflow.exportArtifact === artifact)

        workflow.completeShare(.lowStorage)
        #expect(workflow.phase == .outcome(.readableExport(.lowStorage)))
        #expect(workflow.exportArtifact == nil)
        #expect(cleanupCount == 1)
        guard case .readableExport(.lowStorage)? = workflow.transferOutcome else {
            Issue.record("Expected the typed low-storage export outcome")
            return
        }
    }

    @MainActor
    @Test func transferWorkflowMapsUnknownExportAndImporterFailuresWithoutRawErrors() {
        let workflow = InventoryDataTransferWorkflow(
            readableExport: { _, _, _ in throw CocoaError(.fileWriteUnknown) }
        )

        workflow.export(items: [], locations: [], customCategories: [])
        guard case .readableExport(.generationFailed)? = workflow.transferOutcome else {
            Issue.record("Expected the typed generation failure")
            return
        }

        workflow.dismissOutcome()
        workflow.requestRestoreImport()
        workflow.handleRestoreSelection(.failure(NSError(domain: "test", code: 1)))
        guard case .restore(.unreadableFile)? = workflow.transferOutcome else {
            Issue.record("Expected the typed unreadable-file failure")
            return
        }
    }

    @MainActor
    @Test func transferWorkflowCoversEveryTypedLocalizedOutcome() {
        let readableExportErrors: [InventoryReadableExportError] = [
            .generationFailed,
            .lowStorage,
            .destinationWriteFailed,
            .unsupportedPortabilityLimits,
        ]
        let backupErrors: [InventoryBackupExportFailure] = [
            .encoding,
            .lowStorage,
            .destination,
            .unsupportedPortabilityLimits,
        ]
        let restoreErrors: [InventoryBackupRestoreError] = [
            .unreadableFile,
            .malformedFile,
            .wrongFileType,
            .unsupportedNewerVersion,
            .integrityMismatch,
            .invalidRelationships,
            .fileTooLarge,
            .backupTooComplex,
            .lowStorage,
            .recoverySnapshotFailed,
            .replacementFailed,
            .verificationFailed,
            .recoveryRequired,
        ]

        for outcome in readableExportErrors.map(InventoryDataTransferOutcome.readableExport)
            + backupErrors.map(InventoryDataTransferOutcome.backup)
            + restoreErrors.map(InventoryDataTransferOutcome.restore) {
            _ = outcome.id
            _ = outcome.titleKey
            _ = outcome.messageKey
        }
    }

    @MainActor
    @Test func transferWorkflowMapsShareCompletionsAndRejectsStaleCallbacks() {
        let artifact = InventoryReadableExportArtifact(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/inventory-export.txt"),
            cleanupAction: {}
        )
        let workflow = InventoryDataTransferWorkflow(
            readableExport: { _, _, _ in artifact }
        )

        workflow.export(items: [], locations: [], customCategories: [])
        workflow.completeShare(.completed)
        #expect(workflow.transferOutcome == nil)

        workflow.export(items: [], locations: [], customCategories: [])
        workflow.completeShare(.failed)
        guard case .readableExport(.destinationWriteFailed)? = workflow.transferOutcome else {
            Issue.record("Expected the typed share destination failure")
            return
        }

        workflow.dismissOutcome()
        workflow.completeShare(.failed)
        #expect(workflow.transferOutcome == nil)
        workflow.completeBackupExport(.failure(CocoaError(.userCancelled)))
        #expect(workflow.transferOutcome == nil)
        workflow.completeRestore(.failure(.verificationFailed))
        #expect(workflow.transferOutcome == nil)
        workflow.completeRestore(.success(()))
        #expect(!workflow.restoreSucceeded)
    }

    @MainActor
    @Test func transferWorkflowPreventsCompetingDisclosureAndBackupOperations() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let workflow = InventoryDataTransferWorkflow(
            backupPreparation: { _ in
                try await Task.sleep(for: .seconds(30))
                return InventoryPreparedBackup(data: Data(), suggestedFilename: "backup.json")
            }
        )

        workflow.prepareBackup(in: context)
        #expect(workflow.isPreparingBackup)
        workflow.requestDisclosure(for: .readableExport)
        #expect(workflow.pendingDisclosureAction == nil)
        workflow.export(items: [], locations: [], customCategories: [])
        workflow.requestRestoreImport()
        #expect(workflow.phase == .preparingBackup)
        #expect(workflow.exportArtifact == nil)
        #expect(!workflow.isRestoreImporterPresented)

        workflow.cancelOutstandingWork()
        await waitUntil { !workflow.isPreparingBackup }
        #expect(workflow.phase == .idle)
    }

    @MainActor
    @Test func transferWorkflowBlocksPairwiseOverlapsAcrossNativePresentations() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let artifact = InventoryReadableExportArtifact(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/inventory-export.txt"),
            cleanupAction: {}
        )
        let workflow = InventoryDataTransferWorkflow(
            readableExport: { _, _, _ in artifact },
            backupPreparation: { _ in
                InventoryPreparedBackup(data: Data([0x7B, 0x7D]), suggestedFilename: "backup.json")
            }
        )

        workflow.requestDisclosure(for: .readableExport)
        workflow.requestDisclosure(for: .completeBackup)
        workflow.requestRestoreImport()
        #expect(workflow.phase == .disclosure(.readableExport))
        #expect(!workflow.isRestoreImporterPresented)
        workflow.cancelDisclosure()

        workflow.export(items: [], locations: [], customCategories: [])
        #expect(workflow.phase == .sharingReadableExport)
        workflow.prepareBackup(in: context)
        workflow.requestRestoreImport()
        #expect(workflow.phase == .sharingReadableExport)
        #expect(!workflow.isRestoreImporterPresented)
        workflow.cleanupExportArtifact()

        workflow.prepareBackup(in: context)
        await waitUntil { workflow.phase == .exportingBackup }
        workflow.export(items: [], locations: [], customCategories: [])
        workflow.requestRestoreImport()
        #expect(workflow.phase == .exportingBackup)
        #expect(workflow.exportArtifact == nil)
        #expect(!workflow.isRestoreImporterPresented)
        workflow.discardPreparedBackup()

        workflow.requestRestoreImport()
        workflow.export(items: [], locations: [], customCategories: [])
        workflow.prepareBackup(in: context)
        #expect(workflow.phase == .importingRestore)
        #expect(workflow.exportArtifact == nil)
        #expect(workflow.backupDocument == nil)
        workflow.handleRestoreSelection(.failure(CocoaError(.userCancelled)))
        #expect(workflow.phase == .idle)
    }

    @MainActor
    @Test func transferWorkflowBlocksNewOperationsDuringRestoreConfirmationAndOutcome() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let plan = restorePlanFixture()
        let workflow = InventoryDataTransferWorkflow(
            readableExport: { _, _, _ in throw InventoryReadableExportError.generationFailed },
            backupPreparation: { _ in
                InventoryPreparedBackup(data: Data(), suggestedFilename: "backup.json")
            },
            backupFileRead: { _ in Data() },
            restorePlanning: { _ in plan }
        )

        workflow.planRestore(from: URL(fileURLWithPath: "/tmp/backup.json"))
        await waitUntil { workflow.phase == .confirmingRestore }
        workflow.requestDisclosure(for: .readableExport)
        workflow.prepareBackup(in: context)
        #expect(workflow.phase == .confirmingRestore)
        workflow.completeRestore(.failure(.verificationFailed))
        #expect(workflow.phase == .outcome(.restore(.verificationFailed)))

        workflow.requestDisclosure(for: .completeBackup)
        workflow.requestRestoreImport()
        workflow.export(items: [], locations: [], customCategories: [])
        #expect(workflow.phase == .outcome(.restore(.verificationFailed)))
        #expect(!workflow.isRestoreImporterPresented)
        workflow.dismissOutcome()
        #expect(workflow.canRequestDataTransfer)
    }

    @MainActor
    @Test func cancelledAsyncCompletionCannotOverwriteANewerOperation() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let artifact = InventoryReadableExportArtifact(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/inventory-export.txt"),
            cleanupAction: {}
        )
        let workflow = InventoryDataTransferWorkflow(
            readableExport: { _, _, _ in artifact },
            backupPreparation: { _ in
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    // Simulate a dependency that finishes despite cooperative cancellation.
                }
                return InventoryPreparedBackup(data: Data([0x7B, 0x7D]), suggestedFilename: "stale.json")
            }
        )

        workflow.prepareBackup(in: context)
        workflow.cancelOutstandingWork()
        workflow.export(items: [], locations: [], customCategories: [])
        try await Task.sleep(for: .milliseconds(100))

        #expect(workflow.phase == .sharingReadableExport)
        #expect(workflow.exportArtifact === artifact)
        #expect(workflow.backupDocument == nil)
        #expect(!workflow.isBackupExporterPresented)
    }

    @MainActor
    @Test func transferWorkflowPreparesBackupAndMapsPreparationFailure() async throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let successfulWorkflow = InventoryDataTransferWorkflow(
            backupPreparation: { _ in
                InventoryPreparedBackup(data: Data([0x7B, 0x7D]), suggestedFilename: "inventory-backup.json")
            }
        )

        successfulWorkflow.prepareBackup(in: context)
        await waitUntil { !successfulWorkflow.isPreparingBackup }
        #expect(successfulWorkflow.isBackupExporterPresented)
        #expect(successfulWorkflow.backupDocument != nil)
        #expect(successfulWorkflow.backupFilename == "inventory-backup.json")
        successfulWorkflow.completeBackupExport(.failure(CocoaError(.fileWriteOutOfSpace)))
        #expect(successfulWorkflow.phase == .outcome(.backup(.lowStorage)))

        let failingWorkflow = InventoryDataTransferWorkflow(
            backupPreparation: { _ in throw InventoryPortabilityCodecError.resourceLimitExceeded }
        )
        failingWorkflow.prepareBackup(in: context)
        await waitUntil { !failingWorkflow.isPreparingBackup }
        guard case .backup(.unsupportedPortabilityLimits)? = failingWorkflow.transferOutcome else {
            Issue.record("Expected the typed backup preparation failure")
            return
        }
    }

    @MainActor
    @Test func transferWorkflowMapsRestorePlanningFailure() async {
        let workflow = InventoryDataTransferWorkflow(
            backupFileRead: { _ in Data([0x7B, 0x7D]) },
            restorePlanning: { _ in throw InventoryBackupRestoreError.integrityMismatch }
        )

        workflow.planRestore(from: URL(fileURLWithPath: "/tmp/inventory-backup.json"))
        await waitUntil { !workflow.isPlanningRestore }
        guard case .restore(.integrityMismatch)? = workflow.transferOutcome else {
            Issue.record("Expected the typed restore planning failure")
            return
        }
    }

    @MainActor
    @Test func transferWorkflowTreatsImporterCancellationAsSilent() {
        let workflow = InventoryDataTransferWorkflow()
        workflow.requestRestoreImport()
        workflow.handleRestoreSelection(.failure(CocoaError(.userCancelled)))
        #expect(workflow.transferOutcome == nil)
        #expect(workflow.phase == .idle)
        workflow.requestRestoreImport()
        workflow.handleRestoreSelection(.success([]))
        #expect(workflow.transferOutcome == nil)
        #expect(workflow.restorePlan == nil)
        #expect(workflow.phase == .idle)
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
        #expect(condition())
    }

    private func restorePlanFixture() -> InventoryBackupRestorePlan {
        let date = Date(timeIntervalSince1970: 1_752_000_000)
        let snapshot = InventoryPortabilitySnapshotV1(
            locations: [],
            customCategories: [],
            items: []
        )
        let document = InventoryPortabilityDocumentV1(
            formatIdentifier: "com.stradivarius23.home-stuff-inventory.portability",
            artifactType: .completeBackup,
            schemaVersion: 2,
            integrity: InventoryPortabilityIntegrityV1(digest: "test"),
            metadata: InventoryPortabilityMetadataV1(
                createdAt: date,
                appVersion: "1.0",
                appBuild: "1"
            ),
            inventory: snapshot
        )
        return InventoryBackupRestorePlan(
            document: document,
            backupDate: date,
            counts: InventoryBackupRestoreCounts(
                items: 0,
                locations: 0,
                places: 0,
                customCategories: 0,
                recentItemViews: 0
            ),
            compatibilityWarnings: []
        )
    }
}
