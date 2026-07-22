import CryptoKit
import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryPortabilityCodecTests {
    @Test func mergedVersionOneFixturesMatchGoldenRFC8785Digests() throws {
        for fixture in [
            "empty-readable-export-v1.json",
            "unicode-readable-export-v1.json",
            "ordinary-complete-backup-v1.json"
        ] {
            let data = try Data(contentsOf: fixtureURL(fixture))
            let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            let integrity = try #require(root["integrity"] as? [String: Any])
            let storedDigest = try #require(integrity["digest"] as? String)
            var unsigned = root
            unsigned.removeValue(forKey: "integrity")
            let canonical = try InventoryRFC8785Canonicalizer.data(from: unsigned)
            let computedDigest = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()

            #expect(computedDigest == storedDigest, "Golden digest mismatch for \(fixture)")
            #expect(try InventoryPortabilityEncoder.decodeAndVerify(data).schemaVersion == 1)
        }
    }

    @Test func canonicalizerUsesRFC8785StringEscapesUTF16KeyOrderAndSchemaIntegers() throws {
        let object: [String: Any] = [
            "\u{FFFD}": NSNull(),
            "\u{1F600}": true,
            "z": -2,
            "a": "€\n\"\\/\u{0001}"
        ]

        let canonical = try InventoryRFC8785Canonicalizer.data(from: object)
        #expect(
            String(decoding: canonical, as: UTF8.self)
                == #"{"a":"€\n\"\\/\u0001","z":-2,"😀":true,"�":null}"#
        )
    }

    @Test func canonicalizerRejectsFloatingNumericRepresentationsOutsideVersionOneSchema() {
        #expect(throws: InventoryPortabilityCodecError.invalidSchema) {
            try InventoryRFC8785Canonicalizer.data(from: ["quantity": NSNumber(value: 1.0)])
        }
    }

    @Test func rawPreflightHonorsDepthAndStringEscapesBeforeFoundationParsing() throws {
        let limits = testLimits(depth: 2)
        try InventoryPortabilityRawPreflight.validate(Data(#"{"a":["{ [ \\\" ] }"]}"#.utf8), limits: limits)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityRawPreflight.validate(Data(#"{"a":{"b":{"c":1}}}"#.utf8), limits: limits)
        }
        #expect(throws: InventoryPortabilityCodecError.malformedJSON) {
            try InventoryPortabilityRawPreflight.validate(Data(#"{"a":[}"#.utf8), limits: limits)
        }
    }

    @Test func decoderClassifiesResourceLimitsBeforeIntegrityAndCanonicalization() throws {
        let fixture = try Data(contentsOf: fixtureURL("empty-readable-export-v1.json"))
        let overBytes = InventoryPortabilityLimits(
            maximumDocumentBytes: fixture.count - 1, maximumJSONNestingDepth: 32, maximumLocations: 10,
            maximumCustomCategories: 10, maximumItems: 10, maximumRecentItemViewEvents: 10,
            maximumTagsPerItem: 10, maximumUTF8BytesPerString: 100, maximumTotalRecords: 10
        )
        #expect(throws: InventoryPortabilityCodecError.documentTooLarge) {
            try InventoryPortabilityEncoder.decodeAndVerify(fixture, limits: overBytes)
        }
    }

    @Test func rawStringAndCollectionLimitsRejectResealedDocuments() throws {
        let fixture = try Data(contentsOf: fixtureURL("empty-readable-export-v1.json"))
        let stringLimited = try resealed(fixture) { root in
            var metadata = root["metadata"] as! [String: Any]
            metadata["futureInformationalValue"] = "🇺🇦😀"
            root["metadata"] = metadata
        }
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 0, maximumCustomCategories: 0, maximumItems: 0,
            maximumRecentItemViewEvents: 0, maximumTagsPerItem: 0,
            maximumUTF8BytesPerString: 7, maximumTotalRecords: 0)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityEncoder.decodeAndVerify(stringLimited, limits: limits)
        }
        let oneLocation = try resealed(fixture) { root in
            var inventory = root["inventory"] as! [String: Any]
            inventory["locations"] = [["id": "10000000-0000-0000-0000-000000000001", "name": "A", "iconID": NSNull(), "notes": "", "createdAt": "2025-01-01T00:00:00.000Z", "updatedAt": "2025-01-01T00:00:00.000Z"]]
            root["inventory"] = inventory
        }
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityEncoder.decodeAndVerify(oneLocation, limits: limits)
        }
    }

    @Test func typedPortabilityLimitsAcceptBoundaryAndRejectOneOverForEveryRecordAndFieldCeiling() throws {
        let base = InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 1, maximumCustomCategories: 1, maximumItems: 1,
            maximumRecentItemViewEvents: 1, maximumTagsPerItem: 1,
            maximumUTF8BytesPerString: 36, maximumTotalRecords: 4)
        for snapshot in [limitSnapshot(locations: 1), limitSnapshot(categories: 1), limitSnapshot(items: 1), limitSnapshot(events: 1)] {
            try InventoryPortabilityLimitValidator.validate(snapshot, limits: base)
        }
        let overLocation = limitSnapshot(locations: 2)
        let overCategory = limitSnapshot(categories: 2)
        let overItem = limitSnapshot(items: 2)
        let overEvent = limitSnapshot(events: 2)
        for snapshot in [overLocation, overCategory, overItem, overEvent] {
            #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) { try InventoryPortabilityLimitValidator.validate(snapshot, limits: base) }
        }
        try InventoryPortabilityLimitValidator.validate(limitSnapshot(items: 1, tags: [String(repeating: "😀", count: 9)]), limits: base)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityLimitValidator.validate(limitSnapshot(items: 1, tags: ["a", "b"]), limits: base)
        }
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityLimitValidator.validate(limitSnapshot(items: 1, name: String(repeating: "😀", count: 10)), limits: base)
        }
        let totalLimit = InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 2, maximumCustomCategories: 2, maximumItems: 2, maximumRecentItemViewEvents: 2,
            maximumTagsPerItem: 2, maximumUTF8BytesPerString: 100, maximumTotalRecords: 1)
        try InventoryPortabilityLimitValidator.validate(limitSnapshot(locations: 1), limits: totalLimit)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityLimitValidator.validate(limitSnapshot(locations: 1, categories: 1), limits: totalLimit)
        }
    }

    @Test func overLimitClassificationPrecedesBothValidAndInvalidIntegrityDigests() throws {
        let fixture = try Data(contentsOf: fixtureURL("empty-readable-export-v1.json"))
        let overLimit = try resealed(fixture) { root in
            var inventory = root["inventory"] as! [String: Any]
            inventory["locations"] = [["id": "10000000-0000-0000-0000-000000000001", "name": "A", "iconID": NSNull(), "notes": "", "createdAt": "2025-01-01T00:00:00.000Z", "updatedAt": "2025-01-01T00:00:00.000Z"]]
            root["inventory"] = inventory
        }
        let limits = InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 0, maximumCustomCategories: 1, maximumItems: 1, maximumRecentItemViewEvents: 1,
            maximumTagsPerItem: 1, maximumUTF8BytesPerString: 100, maximumTotalRecords: 1)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) { try InventoryPortabilityEncoder.decodeAndVerify(overLimit, limits: limits) }
        var tampered = try #require(try JSONSerialization.jsonObject(with: overLimit) as? [String: Any])
        var integrity = tampered["integrity"] as! [String: Any]
        integrity["digest"] = String(repeating: "0", count: 64)
        tampered["integrity"] = integrity
        let invalidDigest = try JSONSerialization.data(withJSONObject: tampered)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) { try InventoryPortabilityEncoder.decodeAndVerify(invalidDigest, limits: limits) }
    }

    @Test func envelopeStringLimitsCoverMetadataAndIntegrityDuringGenerationAndDefenseInDepth() throws {
        let metadata = InventoryPortabilityMetadataV1(createdAt: Date(timeIntervalSince1970: 1_752_000_000), appVersion: "1", appBuild: "1")
        let integrity = InventoryPortabilityIntegrityV1(digest: String(repeating: "a", count: 64))
        let atBoundary = InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 1, maximumCustomCategories: 1, maximumItems: 1, maximumRecentItemViewEvents: 1,
            maximumTagsPerItem: 1, maximumUTF8BytesPerString: 64, maximumTotalRecords: 1)
        try InventoryPortabilityLimitValidator.validateEnvelope(metadata: metadata, artifactType: .readableExport, integrity: integrity, limits: atBoundary)
        let oneOver = InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: 32,
            maximumLocations: 1, maximumCustomCategories: 1, maximumItems: 1, maximumRecentItemViewEvents: 1,
            maximumTagsPerItem: 1, maximumUTF8BytesPerString: 63, maximumTotalRecords: 1)
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityLimitValidator.validateEnvelope(metadata: metadata, artifactType: .readableExport, integrity: integrity, limits: oneOver)
        }
        #expect(throws: InventoryPortabilityCodecError.resourceLimitExceeded) {
            try InventoryPortabilityEncoder.encode(
                snapshot: InventoryPortabilitySnapshotV1(locations: [], customCategories: [], items: []),
                metadata: metadata,
                artifactType: .readableExport,
                prettyPrinted: false,
                limits: oneOver
            )
        }
    }

    private func testLimits(depth: Int) -> InventoryPortabilityLimits {
        InventoryPortabilityLimits(maximumDocumentBytes: 10_000, maximumJSONNestingDepth: depth,
            maximumLocations: 10, maximumCustomCategories: 10, maximumItems: 10,
            maximumRecentItemViewEvents: 10, maximumTagsPerItem: 10,
            maximumUTF8BytesPerString: 100, maximumTotalRecords: 10)
    }

    private func limitSnapshot(locations: Int = 0, categories: Int = 0, items: Int = 0, events: Int = 0, tags: [String] = [], name: String = "A") -> InventoryPortabilitySnapshotV1 {
        let timestamp = "2025-01-01T00:00:00.000Z"
        return InventoryPortabilitySnapshotV1(
            locations: (0..<locations).map { InventoryPortabilityLocationV1(id: "10000000-0000-0000-0000-00000000000\($0)", name: name, iconID: nil, notes: "", createdAt: timestamp, updatedAt: timestamp) },
            customCategories: (0..<categories).map { InventoryPortabilityCustomCategoryV1(id: "20000000-0000-0000-0000-00000000000\($0)", name: name, createdAt: timestamp, updatedAt: timestamp) },
            items: (0..<items).map { InventoryPortabilityItemV1(id: "30000000-0000-0000-0000-00000000000\($0)", name: name, categoryStorageValue: "", customCategoryID: nil, locationName: "", locationID: nil, placeName: nil, iconID: nil, quantity: 1, conditionStorageValue: "", tags: tags, notes: "", createdAt: timestamp, updatedAt: timestamp) },
            recentItemViewEvents: (0..<events).map { InventoryPortabilityRecentItemViewEventV1(id: "40000000-0000-0000-0000-00000000000\($0)", itemID: "30000000-0000-0000-0000-000000000000", viewedAt: timestamp) }
        )
    }

    @Test func decoderRejectsUnknownRootIntegrityInventoryAndRecordMembersAfterIntegrity() throws {
        let fixture = try Data(contentsOf: fixtureURL("unicode-readable-export-v1.json"))

        try expectInvalidSchema(fixture) { root in
            root["futureRoot"] = "value"
        }
        try expectInvalidSchema(fixture) { root in
            var integrity = root["integrity"] as! [String: Any]
            integrity["futureDescriptor"] = "value"
            root["integrity"] = integrity
        }
        try expectInvalidSchema(fixture) { root in
            var inventory = root["inventory"] as! [String: Any]
            inventory["futureRecords"] = []
            root["inventory"] = inventory
        }
        try expectInvalidSchema(fixture) { root in
            var inventory = root["inventory"] as! [String: Any]
            var items = inventory["items"] as! [[String: Any]]
            items[0]["futureUserField"] = "must not be discarded"
            inventory["items"] = items
            root["inventory"] = inventory
        }
    }

    @Test func metadataMayContainUnknownInformationalMembers() throws {
        let fixture = try Data(contentsOf: fixtureURL("empty-readable-export-v1.json"))
        let data = try resealed(fixture) { root in
            var metadata = root["metadata"] as! [String: Any]
            metadata["futureInformationalValue"] = "allowed"
            root["metadata"] = metadata
        }

        #expect(try InventoryPortabilityEncoder.decodeAndVerify(data).artifactType == .readableExport)
    }

    @Test func shareCompletionClassifiesSuccessCancellationCapacityAndOtherFailures() {
        #expect(InventoryActivityShareResult.classify(completed: true, error: nil) == .completed)
        #expect(InventoryActivityShareResult.classify(completed: false, error: nil) == .cancelled)
        #expect(
            InventoryActivityShareResult.classify(
                completed: false,
                error: CocoaError(.fileWriteOutOfSpace)
            ) == .lowStorage
        )
        #expect(
            InventoryActivityShareResult.classify(
                completed: false,
                error: CocoaError(.fileWriteUnknown)
            ) == .failed
        )
    }

    private func expectInvalidSchema(
        _ data: Data,
        mutation: (inout [String: Any]) -> Void
    ) throws {
        let data = try resealed(data, mutation: mutation)
        #expect(throws: InventoryPortabilityCodecError.invalidSchema) {
            try InventoryPortabilityEncoder.decodeAndVerify(data)
        }
    }

    private func resealed(
        _ data: Data,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        var root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        mutation(&root)
        var unsigned = root
        unsigned.removeValue(forKey: "integrity")
        let canonical = try InventoryRFC8785Canonicalizer.data(from: unsigned)
        let digest = SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
        var integrity = root["integrity"] as! [String: Any]
        integrity["digest"] = digest
        root["integrity"] = integrity
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    private func fixtureURL(_ name: String) throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            url.deleteLastPathComponent()
            let fixture = url
                .appendingPathComponent("docs/data/portability-recovery-v1", isDirectory: true)
                .appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fixture.path) {
                return fixture
            }
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
