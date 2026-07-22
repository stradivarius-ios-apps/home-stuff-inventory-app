import Foundation
import SwiftData

struct InventoryBackupRestoreCounts: Equatable, Sendable {
    let items: Int
    let locations: Int
    let places: Int
    let customCategories: Int
    let recentItemViews: Int
}

struct InventoryBackupRestorePlan: Identifiable, Equatable, Sendable {
    let id = UUID()
    let document: InventoryPortabilityDocumentV1
    let backupDate: Date
    let counts: InventoryBackupRestoreCounts
    let compatibilityWarnings: [InventoryBackupRestoreWarning]

    var schemaVersion: Int { document.schemaVersion }
    var appVersion: String { document.metadata.appVersion }
}

enum InventoryBackupRestoreWarning: String, Equatable, Sendable {
    case olderAppVersion
}

enum InventoryBackupRestoreError: Error, Equatable, Sendable {
    case unreadableFile
    case malformedFile
    case wrongFileType
    case unsupportedNewerVersion
    case integrityMismatch
    case invalidRelationships
    case fileTooLarge
    case backupTooComplex
    case lowStorage
    case recoverySnapshotFailed
    case replacementFailed
    case verificationFailed
    case recoveryRequired
}

enum InventoryBackupRestoreStage: Equatable, Sendable {
    case decoding
    case recoverySnapshot
    case beforeReplacement
    case replacing
    case verification
    case reopenVerification
    case automaticRecovery
}

struct InventoryBackupRecoverySnapshot: Equatable, Sendable {
    let data: Data
}

struct InventoryBackupFileMetadata: Sendable {
    let fileSize: Int?
    let isRegularFile: Bool?
    let isDirectory: Bool?
}
