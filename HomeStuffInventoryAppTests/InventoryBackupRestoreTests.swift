import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

final class RecoveryArtifactRemovalFailure: @unchecked Sendable {
    var shouldFail = true
}

final class FileReaderProbe: @unchecked Sendable {
    var metadata = InventoryBackupFileMetadata(fileSize: nil, isRegularFile: nil, isDirectory: nil)
    var readCount = 0
}

final class RecoveryArtifactConfigurationRecorder: @unchecked Sendable {
    var protectionRequests: [(URL, FileProtectionType)] = []
    var backupExclusionRequests: [URL] = []
}

@MainActor
struct InventoryBackupRestoreTestSupport {
    let date = Date(timeIntervalSince1970: 1_752_000_000)
    let metadataSource = InventoryBackupMetadataSource(appVersion: "1.0", appBuild: "1")


    func makePlan(snapshot: InventoryPortabilitySnapshotV1) async throws -> InventoryBackupRestorePlan {
        try await InventoryBackupRestorePlanner().plan(
            data: backupData(snapshot: snapshot),
            currentAppVersion: "1.0"
        )
    }

    func makeRecoveryStore() throws -> InventoryBackupRecoveryStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("inventory-restore-tests-\(UUID().uuidString)", isDirectory: true)
        return InventoryBackupRecoveryStore(directory: directory)
    }

    func backupData(
        snapshot: InventoryPortabilitySnapshotV1,
        appVersion: String = "1.0"
    ) throws -> Data {
        try InventoryPortabilityEncoder.encode(
            snapshot: snapshot,
            metadata: InventoryPortabilityMetadataV1(
                createdAt: date,
                appVersion: appVersion,
                appBuild: "1"
            ),
            artifactType: .completeBackup,
            prettyPrinted: false
        )
    }

    func unicodeSnapshot() -> InventoryPortabilitySnapshotV1 {
        let locationID = "10000000-0000-0000-0000-000000000001"
        let categoryID = "20000000-0000-0000-0000-000000000001"
        let itemID = "30000000-0000-0000-0000-000000000001"
        let placeID = "50000000-0000-0000-0000-000000000001"
        let timestamp = InventoryPortabilityDate.string(from: date)
        return InventoryPortabilitySnapshotV1(
            locations: [
                InventoryPortabilityLocationV1(
                    id: locationID,
                    name: "Майстерня 🛠️",
                    iconID: "hammer",
                    notes: "Локально — приватно",
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ],
            customCategories: [
                InventoryPortabilityCustomCategoryV1(
                    id: categoryID,
                    name: "Électronique для хобі",
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ],
            items: [
                InventoryPortabilityItemV1(
                    id: itemID,
                    name: "Паяльник 🔧",
                    categoryStorageValue: "Électronique для хобі",
                    customCategoryID: categoryID,
                    locationName: "Майстерня 🛠️",
                locationID: locationID,
                placeName: "  Шухляда 📦  ",
                placeID: placeID,
                    iconID: "wrench.and.screwdriver",
                    quantity: 2,
                    conditionStorageValue: "good",
                    tags: ["Кабелі", "naïve 🧰"],
                    notes: "350 °C\nОбережно",
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ],
            places: [
                InventoryPortabilityPlaceV1(
                    id: placeID,
                    locationID: locationID,
                    name: "Шухляда 📦",
                    iconID: PlaceIconCatalog.defaultIconID,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
            ],
            recentItemViewEvents: [
                InventoryPortabilityRecentItemViewEventV1(
                    id: "40000000-0000-0000-0000-000000000001",
                    itemID: itemID,
                    viewedAt: timestamp
                )
            ]
        )
    }

    func makeTargetContext() throws -> ModelContext {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(
            StorageLocation(
                id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
                name: "Existing Location",
                createdAt: date,
                updatedAt: date
            )
        )
        context.insert(
            InventoryItem(
                id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
                name: "Existing Item",
                locationName: "Existing Location",
                createdAt: date,
                updatedAt: date
            )
        )
        try context.save()
        return context
    }

    func mutate(
        _ data: Data,
        reseal: Bool,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        mutation(&root)
        if reseal {
            var unsigned = root
            unsigned.removeValue(forKey: "integrity")
            let canonical = try InventoryRFC8785Canonicalizer.data(from: unsigned)
            let digest = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
            var integrity = root["integrity"] as! [String: Any]
            integrity["digest"] = digest
            root["integrity"] = integrity
        }
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    func fixtureURL(_ name: String) throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url.deleteLastPathComponent()
            let fixture = url
                .appendingPathComponent("docs/data/portability-recovery-v1", isDirectory: true)
                .appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fixture.path) { return fixture }
        }
        throw CocoaError(.fileNoSuchFile)
    }
}

@MainActor
protocol InventoryBackupRestoreTestCase {
    var support: InventoryBackupRestoreTestSupport { get }
}

extension InventoryBackupRestoreTestCase {
    var date: Date { support.date }
    var metadataSource: InventoryBackupMetadataSource { support.metadataSource }
    func makePlan(snapshot: InventoryPortabilitySnapshotV1) async throws -> InventoryBackupRestorePlan { try await support.makePlan(snapshot: snapshot) }
    func makeRecoveryStore() throws -> InventoryBackupRecoveryStore { try support.makeRecoveryStore() }
    func backupData(snapshot: InventoryPortabilitySnapshotV1, appVersion: String = "1.0") throws -> Data { try support.backupData(snapshot: snapshot, appVersion: appVersion) }
    func unicodeSnapshot() -> InventoryPortabilitySnapshotV1 { support.unicodeSnapshot() }
    func makeTargetContext() throws -> ModelContext { try support.makeTargetContext() }
    func mutate(_ data: Data, reseal: Bool, mutation: (inout [String: Any]) -> Void) throws -> Data { try support.mutate(data, reseal: reseal, mutation: mutation) }
    func fixtureURL(_ name: String) throws -> URL { try support.fixtureURL(name) }
}
