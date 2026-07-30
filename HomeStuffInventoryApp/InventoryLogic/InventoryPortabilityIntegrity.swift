import CryptoKit
import Foundation

enum InventoryPortabilityCodecError: Error, Equatable, Sendable {
    case invalidEncoding
    case malformedJSON
    case wrongFormat
    case wrongArtifactType
    case unsupportedNewerVersion
    case invalidIntegrity
    case integrityMismatch
    case invalidSchema
    case invalidRelationships
    case resourceLimitExceeded
    case documentTooLarge
    case generationFailed
}

enum InventoryPortabilityEncoder {
    static let formatIdentifier = "com.stradivarius23.home-stuff-inventory.portability"
    static let schemaVersion = 3

    static func encode(
        snapshot: InventoryPortabilitySnapshotV1,
        metadata: InventoryPortabilityMetadataV1,
        artifactType: InventoryPortabilityArtifactType,
        prettyPrinted: Bool,
        limits: InventoryPortabilityLimits = .production
    ) throws -> Data {
        do {
            try InventoryPortabilityLimitValidator.validate(snapshot, limits: limits)
            try InventoryPortabilityValidator.validate(
                snapshot,
                artifactType: artifactType,
                schemaVersion: schemaVersion
            )
            var inventory = try jsonObject(snapshot) as! [String: Any]
            if artifactType == .readableExport {
                inventory.removeValue(forKey: "places")
            }
            let unsignedObject: [String: Any] = [
                "formatIdentifier": formatIdentifier,
                "artifactType": artifactType.rawValue,
                "schemaVersion": schemaVersion,
                "metadata": try jsonObject(metadata),
                "inventory": inventory
            ]
            let canonicalData = try InventoryRFC8785Canonicalizer.data(from: unsignedObject)
            let digest = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }.joined()
            try InventoryPortabilityLimitValidator.validateEnvelope(
                metadata: metadata,
                artifactType: artifactType,
                integrity: InventoryPortabilityIntegrityV1(digest: digest),
                limits: limits
            )

            var documentObject = unsignedObject
            documentObject["integrity"] = try jsonObject(InventoryPortabilityIntegrityV1(digest: digest))
            let options: JSONSerialization.WritingOptions = prettyPrinted
                ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                : [.sortedKeys, .withoutEscapingSlashes]
            var data = try JSONSerialization.data(withJSONObject: documentObject, options: options)
            data.append(0x0A)
            guard data.count <= limits.maximumDocumentBytes else { throw InventoryPortabilityCodecError.documentTooLarge }
            return data
        } catch let error as InventoryPortabilityCodecError {
            throw error
        } catch {
            throw InventoryPortabilityCodecError.generationFailed
        }
    }

    static func decodeAndVerify(_ data: Data, limits: InventoryPortabilityLimits = .production) throws -> InventoryPortabilityDocumentV1 {
        guard data.count <= limits.maximumDocumentBytes else { throw InventoryPortabilityCodecError.documentTooLarge }
        try InventoryPortabilityRawPreflight.validate(data, limits: limits)

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw InventoryPortabilityCodecError.malformedJSON
        }
        guard var root = object as? [String: Any] else {
            throw InventoryPortabilityCodecError.malformedJSON
        }
        let completeRoot = root
        guard root["formatIdentifier"] as? String == formatIdentifier else {
            throw InventoryPortabilityCodecError.wrongFormat
        }
        guard let artifactRawValue = root["artifactType"] as? String,
              InventoryPortabilityArtifactType(rawValue: artifactRawValue) != nil
        else {
            throw InventoryPortabilityCodecError.wrongArtifactType
        }
        guard let version = root["schemaVersion"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(),
              version.doubleValue.rounded() == version.doubleValue
        else {
            throw InventoryPortabilityCodecError.invalidSchema
        }
        if version.intValue > schemaVersion {
            throw InventoryPortabilityCodecError.unsupportedNewerVersion
        }
        guard [1, 2, schemaVersion].contains(version.intValue) else {
            throw InventoryPortabilityCodecError.invalidSchema
        }
        guard let integrity = root.removeValue(forKey: "integrity") as? [String: Any],
              integrity["algorithm"] as? String == "SHA-256",
              integrity["canonicalization"] as? String == "RFC8785",
              let digest = integrity["digest"] as? String,
              digest.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil
        else {
            throw InventoryPortabilityCodecError.invalidIntegrity
        }
        try InventoryPortabilityShapeValidator.validate(completeRoot, artifactType: artifactRawValue, schemaVersion: version.intValue)
        try InventoryPortabilityLimitValidator.validateRaw(completeRoot, limits: limits)

        let canonicalData: Data
        do {
            canonicalData = try InventoryRFC8785Canonicalizer.data(from: root)
        } catch {
            throw InventoryPortabilityCodecError.invalidSchema
        }
        let expectedDigest = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }.joined()
        guard digest == expectedDigest else {
            throw InventoryPortabilityCodecError.integrityMismatch
        }

        do {
            let document = try JSONDecoder().decode(InventoryPortabilityDocumentV1.self, from: data)
            try InventoryPortabilityValidator.validate(
                document.inventory,
                artifactType: document.artifactType,
                schemaVersion: document.schemaVersion,
                invalidError: .invalidRelationships
            )
            try InventoryPortabilityLimitValidator.validate(document.inventory, limits: limits)
            try InventoryPortabilityLimitValidator.validateEnvelope(
                metadata: document.metadata,
                artifactType: document.artifactType,
                integrity: document.integrity,
                limits: limits
            )
            return document
        } catch let error as InventoryPortabilityCodecError {
            throw error
        } catch {
            throw InventoryPortabilityCodecError.invalidSchema
        }
    }

    private static func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }
}
