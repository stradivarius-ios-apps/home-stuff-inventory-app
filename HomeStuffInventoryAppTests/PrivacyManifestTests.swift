import Foundation
import Testing

struct PrivacyManifestTests {
    @Test func sourceManifestDeclaresOnlyTheAuditedDiskSpaceReason() throws {
        let manifest = try sourceManifest()

        #expect(try PrivacyManifestContract.validate(manifest) == [
            "NSPrivacyAccessedAPICategoryDiskSpace": ["E174.1"]
        ])
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
    }

    @Test func contractRejectsDuplicateCategoriesAndReasons() {
        #expect(throws: PrivacyManifestContract.Error.duplicateCategory) {
            try PrivacyManifestContract.validate(manifest(entries: [diskSpaceEntry(), diskSpaceEntry()]))
        }
        #expect(throws: PrivacyManifestContract.Error.duplicateReason) {
            try PrivacyManifestContract.validate(manifest(entries: [
                diskSpaceEntry(reasons: ["E174.1", "E174.1"])
            ]))
        }
    }

    @Test func contractRejectsUnsupportedCategoriesAndReasons() {
        #expect(throws: PrivacyManifestContract.Error.unsupportedCategory) {
            try PrivacyManifestContract.validate(manifest(entries: [[
                "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]
            ]]))
        }
        #expect(throws: PrivacyManifestContract.Error.unsupportedReason) {
            try PrivacyManifestContract.validate(manifest(entries: [diskSpaceEntry(reasons: ["85F4.1"])]))
        }
    }

    private func sourceManifest() throws -> [String: Any] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("HomeStuffInventoryApp")
            .appendingPathComponent("Resources")
            .appendingPathComponent("PrivacyInfo.xcprivacy")
        let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(value as? [String: Any])
    }

    private func manifest(entries: [[String: Any]]) -> [String: Any] {
        ["NSPrivacyAccessedAPITypes": entries]
    }

    private func diskSpaceEntry(reasons: [String] = ["E174.1"]) -> [String: Any] {
        [
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryDiskSpace",
            "NSPrivacyAccessedAPITypeReasons": reasons
        ]
    }
}

private enum PrivacyManifestContract {
    enum Error: Swift.Error {
        case malformedEntry
        case duplicateCategory
        case duplicateReason
        case unsupportedCategory
        case unsupportedReason
    }

    static func validate(_ manifest: [String: Any]) throws -> [String: [String]] {
        let allowed = ["NSPrivacyAccessedAPICategoryDiskSpace": Set(["E174.1"])]
        guard let entries = manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]] else {
            throw Error.malformedEntry
        }

        var result: [String: [String]] = [:]
        for entry in entries {
            guard let category = entry["NSPrivacyAccessedAPIType"] as? String,
                  let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String]
            else { throw Error.malformedEntry }
            guard result[category] == nil else { throw Error.duplicateCategory }
            guard Set(reasons).count == reasons.count else { throw Error.duplicateReason }
            guard let allowedReasons = allowed[category] else { throw Error.unsupportedCategory }
            guard !reasons.isEmpty, Set(reasons).isSubset(of: allowedReasons) else {
                throw Error.unsupportedReason
            }
            result[category] = reasons
        }
        return result
    }
}
