import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupFileReaderTests: InventoryBackupRestoreTestCase {
    let support = InventoryBackupRestoreTestSupport()

    @Test func fileReaderRejectsMetadataAndPostReadByteOverages() async throws {
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 4, maximumJSONNestingDepth: 2,
            maximumLocations: 1, maximumCustomCategories: 1, maximumItems: 1,
            maximumRecentItemViewEvents: 1, maximumTagsPerItem: 1, maximumUTF8BytesPerString: 10, maximumTotalRecords: 1)
        let probe = FileReaderProbe()
        probe.metadata = InventoryBackupFileMetadata(fileSize: 5, isRegularFile: true, isDirectory: false)
        let reader = InventoryBackupFileReader(limits: limits, metadata: { _ in probe.metadata }, load: { _ in probe.readCount += 1; return Data("12345".utf8) })
        await #expect(throws: InventoryBackupRestoreError.fileTooLarge) { try await reader.read(URL(fileURLWithPath: "/tmp/test")) }
        #expect(probe.readCount == 0)
        probe.metadata = InventoryBackupFileMetadata(fileSize: 4, isRegularFile: true, isDirectory: false)
        await #expect(throws: InventoryBackupRestoreError.fileTooLarge) { try await reader.read(URL(fileURLWithPath: "/tmp/test")) }
        #expect(probe.readCount == 1)
    }
}
