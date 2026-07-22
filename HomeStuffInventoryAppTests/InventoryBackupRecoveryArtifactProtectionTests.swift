import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupRecoveryArtifactProtectionTests: InventoryBackupRestoreTestCase {
    let support = InventoryBackupRestoreTestSupport()

    @Test func recoveryArtifactsUseCompleteProtectionAndAreExcludedFromBackup() throws {
        let store = try makeRecoveryStore()
        let data = try backupData(snapshot: unicodeSnapshot())
        let digest = try InventoryPortabilityEncoder.decodeAndVerify(data).integrity.digest
        try store.prepare(safetyData: data, candidateData: data, digest: digest)

        for url in [store.safetyBackupURL, store.candidateBackupURL, store.placeOpenRecordsURL, store.journalURL] {
            let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
            #expect(values.isExcludedFromBackup == true)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            // Simulator filesystems may not report the protection attribute even after setting it.
            if let protection = attributes[.protectionKey] as? FileProtectionType {
                #expect(protection == .complete)
            }
        }
        let directoryValues = try store.directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(directoryValues.isExcludedFromBackup == true)
    }
    @Test func everyRecoveryArtifactWriteRequestsCompleteProtectionAndBackupExclusion() throws {
        let recorder = RecoveryArtifactConfigurationRecorder()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("inventory-restore-protection-requests-\(UUID().uuidString)", isDirectory: true)
        let store = InventoryBackupRecoveryStore(
            directory: directory,
            applyFileProtection: { url, protection in
                recorder.protectionRequests.append((url, protection))
            },
            excludeFromBackup: { url in
                recorder.backupExclusionRequests.append(url)
            }
        )
        let data = try backupData(snapshot: unicodeSnapshot())
        let digest = try InventoryPortabilityEncoder.decodeAndVerify(data).integrity.digest

        try store.prepare(safetyData: data, candidateData: data, digest: digest)
        try store.markCommitted(digest: digest)
        try store.markVerified(digest: digest)

        let expectedArtifactWrites = [
            store.safetyBackupURL,
            store.candidateBackupURL,
            store.placeOpenRecordsURL,
            store.journalURL,
            store.journalURL,
            store.journalURL
        ]
        #expect(recorder.protectionRequests.map(\.0) == expectedArtifactWrites)
        #expect(recorder.protectionRequests.allSatisfy { $0.1 == .complete })
        #expect(recorder.backupExclusionRequests == [store.directory] + expectedArtifactWrites)
    }
    @Test func artifactProtectionOrBackupExclusionFailurePreventsDestructiveReplacement() async throws {
        for failedConfiguration in ["protection", "backup exclusion"] {
            let context = try makeTargetContext()
            let original = try InventoryBackupSnapshotter.capture(in: context)
            let store = InventoryBackupRecoveryStore(
                directory: FileManager.default.temporaryDirectory
                    .appendingPathComponent("inventory-restore-configuration-failure-\(UUID().uuidString)"),
                applyFileProtection: { _, _ in
                    guard failedConfiguration != "protection" else {
                        throw CocoaError(.fileWriteNoPermission)
                    }
                },
                excludeFromBackup: { _ in
                    guard failedConfiguration != "backup exclusion" else {
                        throw CocoaError(.fileWriteNoPermission)
                    }
                }
            )

            await #expect(throws: InventoryBackupRestoreError.recoverySnapshotFailed) {
                try await InventoryBackupRestoreService().restore(
                    try await makePlan(snapshot: unicodeSnapshot()),
                    in: context,
                    metadataSource: metadataSource,
                    recoveryStore: store
                )
            }
            #expect(try InventoryBackupSnapshotter.capture(in: context) == original)
        }
    }
}
