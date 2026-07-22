import Foundation
import SwiftData

enum InventoryBackupRecoveryPhase: String, Codable, Sendable {
    case safetyCopyReady
    case committedAwaitingVerification
    case verified
    case recoveredOriginal
}

struct InventoryBackupRecoveryJournal: Codable, Equatable, Sendable {
    let phase: InventoryBackupRecoveryPhase
    let candidateDigest: String
    let updatedAt: String
}

struct InventoryBackupRecoveryPlaceOpenRecord: Codable, Equatable, Sendable {
    let id: UUID
    let placeIdentity: String
    let placeID: UUID?
    let openCount: Int
    let lastOpenedAt: Date
}

struct InventoryBackupRecoveryStore: Sendable {
    typealias DurableWrite = @Sendable (Data, URL) throws -> Void
    typealias AvailableCapacity = @Sendable (URL) throws -> Int64?
    typealias ApplyFileProtection = @Sendable (URL, FileProtectionType) throws -> Void
    typealias ExcludeFromBackup = @Sendable (URL) throws -> Void
    typealias RemoveItem = @Sendable (URL) throws -> Void

    let directory: URL
    private let durableWrite: DurableWrite
    private let availableCapacity: AvailableCapacity
    private let applyFileProtection: ApplyFileProtection
    private let excludeFromBackup: ExcludeFromBackup
    private let removeItem: RemoveItem

    init(
        directory: URL,
        durableWrite: @escaping DurableWrite = Self.writeDurably,
        availableCapacity: @escaping AvailableCapacity = Self.availableCapacity,
        applyFileProtection: @escaping ApplyFileProtection = Self.applyFileProtection,
        excludeFromBackup: @escaping ExcludeFromBackup = Self.excludeFromBackup,
        removeItem: @escaping RemoveItem = Self.removeItem
    ) {
        self.directory = directory
        self.durableWrite = durableWrite
        self.availableCapacity = availableCapacity
        self.applyFileProtection = applyFileProtection
        self.excludeFromBackup = excludeFromBackup
        self.removeItem = removeItem
    }

    static func live(fileManager: FileManager = .default) throws -> Self {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return Self(directory: base.appendingPathComponent("InventoryRestoreRecovery", isDirectory: true))
    }

    var safetyBackupURL: URL { directory.appendingPathComponent("pre-restore-safety-backup.json") }
    var candidateBackupURL: URL { directory.appendingPathComponent("restore-candidate.json") }
    var journalURL: URL { directory.appendingPathComponent("restore-journal.json") }
    var placeOpenRecordsURL: URL { directory.appendingPathComponent("pre-restore-place-open-records.json") }

    func prepare(
        safetyData: Data,
        candidateData: Data,
        digest: String,
        placeOpenRecordsData: Data = Data("[]".utf8)
    ) throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try excludeFromBackup(directory)
            let payloadBytes = Int64(safetyData.count) + Int64(candidateData.count) + Int64(placeOpenRecordsData.count)
            // Allow one additional payload-sized staging copy plus filesystem/SQLite overhead.
            let requiredCapacity = payloadBytes.multipliedReportingOverflow(by: 2)
            guard !requiredCapacity.overflow,
                  try availableCapacity(directory).map({ $0 >= requiredCapacity.partialValue + 1_048_576 }) != false
            else { throw InventoryBackupRestoreError.lowStorage }
            try durableWrite(safetyData, safetyBackupURL)
            try configureArtifact(safetyBackupURL)
            _ = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: safetyBackupURL))
            try durableWrite(candidateData, candidateBackupURL)
            try configureArtifact(candidateBackupURL)
            _ = try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: candidateBackupURL))
            try durableWrite(placeOpenRecordsData, placeOpenRecordsURL)
            try configureArtifact(placeOpenRecordsURL)
            _ = try JSONDecoder().decode([InventoryBackupRecoveryPlaceOpenRecord].self, from: Data(contentsOf: placeOpenRecordsURL))
            try writeJournal(.safetyCopyReady, digest: digest)
        } catch {
            throw classifySafetyCopy(error)
        }
    }

    func markCommitted(digest: String) throws {
        try writeJournal(.committedAwaitingVerification, digest: digest)
    }

    func markVerified(digest: String) throws {
        try writeJournal(.verified, digest: digest)
        finalizeTerminalArtifacts()
    }

    func markRecoveredOriginal(digest: String) throws {
        try writeJournal(.recoveredOriginal, digest: digest)
        finalizeTerminalArtifacts()
    }

    /// Removes only artifacts from a durably terminal recovery transaction. Failures retain the
    /// journal so the next launch can retry without treating the transaction as unfinished.
    func finalizeTerminalArtifacts() {
        guard let journal = try? journal(),
              journal.phase == .verified || journal.phase == .recoveredOriginal
        else { return }

        // Keep the terminal journal until both data-bearing files are gone. This makes partial
        // cleanup retryable and prevents startup from interpreting it as a recovery replay.
        guard removeIfPresent(safetyBackupURL), removeIfPresent(candidateBackupURL), removeIfPresent(placeOpenRecordsURL) else { return }
        guard removeIfPresent(journalURL) else { return }
        removeEmptyDirectory()
    }

    func removeEmptyDirectory() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ), contents.isEmpty
        else { return }
        try? removeItem(directory)
    }

    func journal() throws -> InventoryBackupRecoveryJournal? {
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return nil }
        return try JSONDecoder().decode(
            InventoryBackupRecoveryJournal.self,
            from: Data(contentsOf: journalURL)
        )
    }

    func safetyDocument() throws -> InventoryPortabilityDocumentV1 {
        try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: safetyBackupURL))
    }

    func candidateDocument() throws -> InventoryPortabilityDocumentV1 {
        try InventoryPortabilityEncoder.decodeAndVerify(Data(contentsOf: candidateBackupURL))
    }

    func originalPlaceOpenRecords() throws -> [InventoryBackupRecoveryPlaceOpenRecord] {
        guard FileManager.default.fileExists(atPath: placeOpenRecordsURL.path) else {
            throw InventoryBackupRestoreError.recoveryRequired
        }
        return try JSONDecoder().decode(
            [InventoryBackupRecoveryPlaceOpenRecord].self,
            from: Data(contentsOf: placeOpenRecordsURL)
        )
    }

    private func writeJournal(_ phase: InventoryBackupRecoveryPhase, digest: String) throws {
        let journal = InventoryBackupRecoveryJournal(
            phase: phase,
            candidateDigest: digest,
            updatedAt: InventoryPortabilityDate.string(from: .now)
        )
        try durableWrite(try JSONEncoder().encode(journal), journalURL)
        try configureArtifact(journalURL)
    }

    private func configureArtifact(_ url: URL) throws {
        try applyFileProtection(url, .complete)
        try excludeFromBackup(url)
    }

    private func removeIfPresent(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        do {
            try removeItem(url)
            return true
        } catch {
            return false
        }
    }

    private func classifySafetyCopy(_ error: any Error) -> InventoryBackupRestoreError {
        if let restoreError = error as? InventoryBackupRestoreError {
            return restoreError
        }
        let nsError = error as NSError
        if (nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.fileWriteOutOfSpace.rawValue)
            || (nsError.domain == NSPOSIXErrorDomain
                && nsError.code == Int(POSIXErrorCode.ENOSPC.rawValue)) {
            return .lowStorage
        }
        return .recoverySnapshotFailed
    }

    private static func writeDurably(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    private static func applyFileProtection(_ url: URL, _ protection: FileProtectionType) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
    }

    private static func removeItem(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private static func availableCapacity(at url: URL) throws -> Int64? {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage
    }
}

enum InventoryBackupRecoveryCoordinator {
    @MainActor
    static func recoverIfNeeded(
        container: ModelContainer,
        store: InventoryBackupRecoveryStore? = nil
    ) throws {
        let store = try store ?? .live()
        guard let journal = try store.journal() else {
            store.removeEmptyDirectory()
            return
        }

        switch journal.phase {
        case .verified, .recoveredOriginal:
            store.finalizeTerminalArtifacts()
            return
        case .safetyCopyReady:
            try store.markRecoveredOriginal(digest: journal.candidateDigest)
            return
        case .committedAwaitingVerification:
            let context = ModelContext(container)
            context.autosaveEnabled = false
            if let candidate = try? store.candidateDocument(),
               candidate.integrity.digest == journal.candidateDigest,
               (try? InventoryBackupSnapshotter.capture(in: context)) == candidate.inventory {
                try store.markVerified(digest: journal.candidateDigest)
                return
            }
            do {
                let safety = try store.safetyDocument()
                let originalPlaceOpenRecords = try store.originalPlaceOpenRecords()
                try InventoryBackupRestoreService.replaceSnapshot(safety.inventory, in: context)
                try InventoryBackupRestoreService.restorePlaceOpenRecords(
                    originalPlaceOpenRecords,
                    in: context
                )
                let reopened = ModelContext(container)
                guard try InventoryBackupSnapshotter.capture(in: reopened) == safety.inventory else {
                    throw InventoryBackupRestoreError.recoveryRequired
                }
                try store.markRecoveredOriginal(digest: journal.candidateDigest)
            } catch {
                throw InventoryBackupRestoreError.recoveryRequired
            }
        }
    }
}
