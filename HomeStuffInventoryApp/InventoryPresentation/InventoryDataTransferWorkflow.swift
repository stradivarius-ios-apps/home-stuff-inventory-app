import Observation
import SwiftData
import SwiftUI

private enum InventoryDataTransferLiveDependencies {
    static func readBackupFile(_ url: URL) async throws -> Data {
        try await InventoryBackupFileReader().read(url)
    }

    static func planRestore(_ data: Data) async throws -> InventoryBackupRestorePlan {
        try await InventoryBackupRestorePlanner().plan(data: data)
    }
}

enum InventoryDataFileAction: Identifiable {
    case readableExport
    case completeBackup

    var id: Self { self }

    var messageKey: LocalizedStringKey {
        switch self {
        case .readableExport: "settings.fileDisclosure.export.message"
        case .completeBackup: "settings.fileDisclosure.backup.message"
        }
    }

    var continueKey: LocalizedStringKey {
        switch self {
        case .readableExport: "settings.fileDisclosure.export.continue"
        case .completeBackup: "settings.fileDisclosure.backup.continue"
        }
    }
}

enum InventoryDataTransferOutcome: Identifiable, Equatable {
    case readableExport(InventoryReadableExportError)
    case backup(InventoryBackupExportFailure)
    case restore(InventoryBackupRestoreError)

    var id: String { String(describing: self) }

    var titleKey: LocalizedStringKey {
        switch self {
        case let .readableExport(error):
            switch error {
            case .generationFailed: "settings.export.failure.generation.title"
            case .lowStorage: "settings.export.failure.storage.title"
            case .destinationWriteFailed: "settings.export.failure.write.title"
            case .unsupportedPortabilityLimits: "settings.portability.failure.title"
            }
        case let .backup(error):
            switch error {
            case .encoding: "settings.backup.error.encoding.title"
            case .lowStorage: "settings.backup.error.lowStorage.title"
            case .destination: "settings.backup.error.destination.title"
            case .unsupportedPortabilityLimits: "settings.portability.failure.title"
            }
        case let .restore(error):
            switch error {
            case .unreadableFile: "settings.restore.error.unreadable.title"
            case .malformedFile: "settings.restore.error.malformed.title"
            case .wrongFileType: "settings.restore.error.wrongType.title"
            case .unsupportedNewerVersion: "settings.restore.error.newerVersion.title"
            case .integrityMismatch: "settings.restore.error.integrity.title"
            case .invalidRelationships: "settings.restore.error.relationships.title"
            case .fileTooLarge: "settings.restore.error.fileTooLarge.title"
            case .backupTooComplex: "settings.restore.error.tooComplex.title"
            case .lowStorage: "settings.restore.error.lowStorage.title"
            case .recoverySnapshotFailed: "settings.restore.error.recovery.title"
            case .replacementFailed: "settings.restore.error.replacement.title"
            case .verificationFailed: "settings.restore.error.verification.title"
            case .recoveryRequired: "settings.restore.error.recoveryRequired.title"
            }
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case let .readableExport(error):
            switch error {
            case .generationFailed: "settings.export.failure.generation.message"
            case .lowStorage: "settings.export.failure.storage.message"
            case .destinationWriteFailed: "settings.export.failure.write.message"
            case .unsupportedPortabilityLimits: "settings.portability.failure.message"
            }
        case let .backup(error):
            switch error {
            case .encoding: "settings.backup.error.encoding.message"
            case .lowStorage: "settings.backup.error.lowStorage.message"
            case .destination: "settings.backup.error.destination.message"
            case .unsupportedPortabilityLimits: "settings.portability.failure.message"
            }
        case let .restore(error):
            switch error {
            case .unreadableFile: "settings.restore.error.unreadable.message"
            case .malformedFile: "settings.restore.error.malformed.message"
            case .wrongFileType: "settings.restore.error.wrongType.message"
            case .unsupportedNewerVersion: "settings.restore.error.newerVersion.message"
            case .integrityMismatch: "settings.restore.error.integrity.message"
            case .invalidRelationships: "settings.restore.error.relationships.message"
            case .fileTooLarge: "settings.restore.error.fileTooLarge.message"
            case .backupTooComplex: "settings.restore.error.tooComplex.message"
            case .lowStorage: "settings.restore.error.lowStorage.message"
            case .recoverySnapshotFailed: "settings.restore.error.recovery.message"
            case .replacementFailed: "settings.restore.error.replacement.message"
            case .verificationFailed: "settings.restore.error.verification.message"
            case .recoveryRequired: "settings.restore.error.recoveryRequired.message"
            }
        }
    }
}

enum InventoryDataTransferPhase: Equatable {
    case idle
    case disclosure(InventoryDataFileAction)
    case generatingReadableExport
    case sharingReadableExport
    case preparingBackup
    case exportingBackup
    case importingRestore
    case planningRestore
    case confirmingRestore
    case outcome(InventoryDataTransferOutcome)
    case restoreSucceeded
}

@MainActor
@Observable
final class InventoryDataTransferWorkflow {
    typealias ReadableExport = (
        [InventoryItem],
        [StorageLocation],
        [InventoryCustomCategory],
        [InventoryMovementRecord]
    ) throws -> InventoryReadableExportArtifact
    typealias BackupPreparation = @MainActor (ModelContext) async throws -> InventoryPreparedBackup
    typealias BackupFileRead = (URL) async throws -> Data
    typealias RestorePlanning = (Data) async throws -> InventoryBackupRestorePlan
    typealias ArtifactCleanup = (InventoryReadableExportArtifact) -> Void

    private(set) var phase: InventoryDataTransferPhase = .idle
    var exportArtifact: InventoryReadableExportArtifact?
    var backupDocument: InventoryBackupDocument?
    var backupFilename = ""
    var isBackupExporterPresented = false
    var isRestoreImporterPresented = false
    var restorePlan: InventoryBackupRestorePlan?

    var canRequestDataTransfer: Bool { phase == .idle }
    var pendingDisclosureAction: InventoryDataFileAction? {
        guard case let .disclosure(action) = phase else { return nil }
        return action
    }
    var transferOutcome: InventoryDataTransferOutcome? {
        guard case let .outcome(outcome) = phase else { return nil }
        return outcome
    }
    var isPreparingBackup: Bool { phase == .preparingBackup }
    var isPlanningRestore: Bool { phase == .planningRestore }
    var restoreSucceeded: Bool { phase == .restoreSucceeded }

    private let readableExport: ReadableExport
    private let backupPreparation: BackupPreparation
    private let backupFileRead: BackupFileRead
    private let restorePlanning: RestorePlanning
    private let artifactCleanup: ArtifactCleanup
    private var backupPreparationTask: Task<Void, Never>?
    private var restorePlanningTask: Task<Void, Never>?
    private var operationID: UUID?

    init(
        readableExport: @escaping ReadableExport = { items, locations, categories, movementRecords in
            try InventoryReadableExportService().export(
                items: items,
                locations: locations,
                customCategories: categories,
                movementRecords: movementRecords
            )
        },
        backupPreparation: @escaping BackupPreparation = { context in
            try await InventoryBackupService().prepareBackup(in: context)
        },
        backupFileRead: @escaping BackupFileRead = InventoryDataTransferLiveDependencies.readBackupFile,
        restorePlanning: @escaping RestorePlanning = InventoryDataTransferLiveDependencies.planRestore,
        artifactCleanup: @escaping ArtifactCleanup = { $0.cleanup() }
    ) {
        self.readableExport = readableExport
        self.backupPreparation = backupPreparation
        self.backupFileRead = backupFileRead
        self.restorePlanning = restorePlanning
        self.artifactCleanup = artifactCleanup
    }

    func requestDisclosure(for action: InventoryDataFileAction) {
        guard canRequestDataTransfer else { return }
        phase = .disclosure(action)
    }

    func cancelDisclosure() {
        guard case .disclosure = phase else { return }
        phase = .idle
    }

    func confirmDisclosure(
        _ action: InventoryDataFileAction,
        items: [InventoryItem],
        locations: [StorageLocation],
        customCategories: [InventoryCustomCategory],
        movementRecords: [InventoryMovementRecord] = [],
        context: ModelContext
    ) {
        guard phase == .disclosure(action) else { return }
        switch action {
        case .readableExport:
            export(
                items: items,
                locations: locations,
                customCategories: customCategories,
                movementRecords: movementRecords
            )
        case .completeBackup:
            prepareBackup(in: context)
        }
    }

    func export(
        items: [InventoryItem],
        locations: [StorageLocation],
        customCategories: [InventoryCustomCategory],
        movementRecords: [InventoryMovementRecord] = []
    ) {
        guard phase == .idle
                || phase == .disclosure(.readableExport)
                || isReadableExportOutcome
        else { return }
        phase = .generatingReadableExport
        do {
            exportArtifact = try readableExport(items, locations, customCategories, movementRecords)
            phase = .sharingReadableExport
        } catch let error as InventoryReadableExportError {
            phase = .outcome(.readableExport(error))
        } catch {
            phase = .outcome(.readableExport(.generationFailed))
        }
    }

    func completeShare(_ result: InventoryActivityShareResult) {
        guard phase == .sharingReadableExport else { return }
        cleanupExportArtifactStorage()
        switch result {
        case .completed, .cancelled:
            phase = .idle
        case .lowStorage:
            phase = .outcome(.readableExport(.lowStorage))
        case .failed:
            phase = .outcome(.readableExport(.destinationWriteFailed))
        }
    }

    func cleanupExportArtifact() {
        guard phase == .sharingReadableExport else { return }
        cleanupExportArtifactStorage()
        phase = .idle
    }

    func prepareBackup(in context: ModelContext) {
        guard phase == .idle || phase == .disclosure(.completeBackup) else { return }
        phase = .preparingBackup
        let operationID = UUID()
        self.operationID = operationID
        backupPreparationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.operationID == operationID {
                    self.backupPreparationTask = nil
                    self.operationID = nil
                }
            }
            do {
                let prepared = try await self.backupPreparation(context)
                try Task.checkCancellation()
                guard self.operationID == operationID, self.phase == .preparingBackup else { return }
                self.backupDocument = InventoryBackupDocument(data: prepared.data)
                self.backupFilename = prepared.suggestedFilename
                self.isBackupExporterPresented = true
                self.phase = .exportingBackup
            } catch is CancellationError {
                if self.operationID == operationID, self.phase == .preparingBackup {
                    self.phase = .idle
                }
                return
            } catch {
                guard self.operationID == operationID, self.phase == .preparingBackup else { return }
                if let failure = InventoryBackupExportFailure.fromPreparation(error) {
                    self.phase = .outcome(.backup(failure))
                } else {
                    self.phase = .idle
                }
            }
        }
    }

    func completeBackupExport(_ result: Result<URL, any Error>) {
        guard phase == .exportingBackup else { return }
        clearPreparedBackup()
        if case let .failure(error) = result,
           let failure = InventoryBackupExportFailure.fromDestination(error) {
            phase = .outcome(.backup(failure))
        } else {
            phase = .idle
        }
    }

    func discardPreparedBackup() {
        guard phase == .exportingBackup else { return }
        clearPreparedBackup()
        phase = .idle
    }

    func requestRestoreImport() {
        guard canRequestDataTransfer else { return }
        phase = .importingRestore
        isRestoreImporterPresented = true
    }

    func handleRestoreSelection(_ result: Result<[URL], any Error>) {
        guard phase == .importingRestore else { return }
        isRestoreImporterPresented = false
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                phase = .idle
                return
            }
            planRestore(from: url)
        case let .failure(error):
            let nsError = error as NSError
            guard nsError.domain != NSCocoaErrorDomain || nsError.code != CocoaError.Code.userCancelled.rawValue else {
                phase = .idle
                return
            }
            phase = .outcome(.restore(.unreadableFile))
        }
    }

    func planRestore(from url: URL) {
        guard phase == .idle || phase == .importingRestore else { return }
        phase = .planningRestore
        let operationID = UUID()
        self.operationID = operationID
        restorePlanningTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.operationID == operationID {
                    self.restorePlanningTask = nil
                    self.operationID = nil
                }
            }
            do {
                let data = try await self.backupFileRead(url)
                let plan = try await self.restorePlanning(data)
                try Task.checkCancellation()
                guard self.operationID == operationID, self.phase == .planningRestore else { return }
                self.restorePlan = plan
                self.phase = .confirmingRestore
            } catch is CancellationError {
                if self.operationID == operationID, self.phase == .planningRestore {
                    self.phase = .idle
                }
                return
            } catch let error as InventoryBackupRestoreError {
                guard self.operationID == operationID, self.phase == .planningRestore else { return }
                self.phase = .outcome(.restore(error))
            } catch {
                guard self.operationID == operationID, self.phase == .planningRestore else { return }
                self.phase = .outcome(.restore(.unreadableFile))
            }
        }
    }

    func completeRestore(_ result: Result<Void, InventoryBackupRestoreError>) {
        guard phase == .confirmingRestore else { return }
        restorePlan = nil
        switch result {
        case .success:
            phase = .restoreSucceeded
        case let .failure(error):
            phase = .outcome(.restore(error))
        }
    }

    func cancelRestoreConfirmation() {
        guard phase == .confirmingRestore else { return }
        restorePlan = nil
        phase = .idle
    }

    func dismissOutcome() {
        guard case .outcome = phase else { return }
        phase = .idle
    }

    func dismissRestoreSuccess() {
        guard phase == .restoreSucceeded else { return }
        phase = .idle
    }

    func cancelOutstandingWork() {
        operationID = nil
        backupPreparationTask?.cancel()
        backupPreparationTask = nil
        restorePlanningTask?.cancel()
        restorePlanningTask = nil
        cleanupExportArtifactStorage()
        clearPreparedBackup()
        isRestoreImporterPresented = false
        restorePlan = nil
        phase = .idle
    }

    private var isReadableExportOutcome: Bool {
        guard case .outcome(.readableExport) = phase else { return false }
        return true
    }

    private func cleanupExportArtifactStorage() {
        if let exportArtifact { artifactCleanup(exportArtifact) }
        exportArtifact = nil
    }

    private func clearPreparedBackup() {
        isBackupExporterPresented = false
        backupDocument = nil
        backupFilename = ""
    }
}
