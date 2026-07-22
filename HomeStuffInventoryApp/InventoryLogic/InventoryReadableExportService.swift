import Foundation

enum InventoryReadableExportError: Error, Equatable {
    case generationFailed
    case lowStorage
    case destinationWriteFailed
    case unsupportedPortabilityLimits
}

final class InventoryReadableExportArtifact: Identifiable {
    let id: UUID
    let url: URL
    private let cleanupAction: () -> Void
    private var isCleanedUp = false

    init(id: UUID, url: URL, cleanupAction: @escaping () -> Void) {
        self.id = id
        self.url = url
        self.cleanupAction = cleanupAction
    }

    func cleanup() {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        cleanupAction()
    }

    deinit {
        cleanup()
    }
}

struct InventoryReadableExportFileSystem {
    var temporaryDirectory: () -> URL = { FileManager.default.temporaryDirectory }
    var createDirectory: (URL) throws -> Void = {
        try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
    }
    var write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    var read: (URL) throws -> Data = { try Data(contentsOf: $0) }
    var remove: (URL) -> Void = { try? FileManager.default.removeItem(at: $0) }
}

struct InventoryReadableExportService {
    private let fileSystem: InventoryReadableExportFileSystem
    private let bundle: Bundle
    private let limits: InventoryPortabilityLimits

    init(
        fileSystem: InventoryReadableExportFileSystem = InventoryReadableExportFileSystem(),
        bundle: Bundle = .main,
        limits: InventoryPortabilityLimits = .production
    ) {
        self.fileSystem = fileSystem
        self.bundle = bundle
        self.limits = limits
    }

    func export(
        items: [InventoryItem],
        locations: [StorageLocation],
        customCategories: [InventoryCustomCategory],
        createdAt: Date = .now,
        artifactID: UUID = UUID()
    ) throws -> InventoryReadableExportArtifact {
        let snapshot = makeSnapshot(
            items: items,
            locations: locations,
            customCategories: customCategories
        )
        let metadata = InventoryPortabilityMetadataV1(
            createdAt: createdAt,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
        let data: Data
        do {
            data = try InventoryPortabilityEncoder.encode(
                snapshot: snapshot,
                metadata: metadata,
                artifactType: .readableExport,
                prettyPrinted: true,
                limits: limits
            )
        } catch let error as InventoryPortabilityCodecError {
            if error == .resourceLimitExceeded || error == .documentTooLarge { throw InventoryReadableExportError.unsupportedPortabilityLimits }
            throw InventoryReadableExportError.generationFailed
        } catch {
            throw InventoryReadableExportError.generationFailed
        }

        let directory = fileSystem.temporaryDirectory()
            .appendingPathComponent("HomeStuffInventoryExports", isDirectory: true)
            .appendingPathComponent(artifactID.inventoryPortabilityString, isDirectory: true)
        let fileURL = directory.appendingPathComponent(fileName(for: createdAt))
        do {
            try fileSystem.createDirectory(directory)
            try fileSystem.write(data, fileURL)
            let writtenData = try fileSystem.read(fileURL)
            let writtenDocument = try InventoryPortabilityEncoder.decodeAndVerify(writtenData, limits: limits)
            guard writtenDocument.artifactType == .readableExport else {
                throw InventoryReadableExportError.destinationWriteFailed
            }
        } catch {
            fileSystem.remove(directory)
            if isCapacityError(error) {
                throw InventoryReadableExportError.lowStorage
            }
            throw InventoryReadableExportError.destinationWriteFailed
        }

        return InventoryReadableExportArtifact(id: artifactID, url: fileURL) {
            fileSystem.remove(directory)
        }
    }

    func makeSnapshot(
        items: [InventoryItem],
        locations: [StorageLocation],
        customCategories: [InventoryCustomCategory]
    ) -> InventoryPortabilitySnapshotV1 {
        let locationRecords = locations.map {
            InventoryPortabilityLocationV1(
                id: $0.id.inventoryPortabilityString,
                name: $0.name,
                iconID: $0.iconID,
                notes: $0.notes,
                createdAt: InventoryPortabilityDate.string(from: $0.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: $0.updatedAt)
            )
        }
        let categoryRecords = customCategories.map {
            InventoryPortabilityCustomCategoryV1(
                id: $0.id.inventoryPortabilityString,
                name: $0.name,
                createdAt: InventoryPortabilityDate.string(from: $0.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: $0.updatedAt)
            )
        }
        let locationsByName = locationRecords.reduce(into: [String: String]()) {
            $0[nameKey($1.name)] = $1.id
        }
        let categoriesByName = categoryRecords.reduce(into: [String: String]()) {
            $0[nameKey($1.name)] = $1.id
        }
        let itemRecords = items.map { item in
            let trimmedPlace = item.containerName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return InventoryPortabilityItemV1(
                id: item.id.inventoryPortabilityString,
                name: item.name,
                categoryStorageValue: item.category,
                customCategoryID: categoriesByName[nameKey(item.category)],
                locationName: item.locationName,
                locationID: locationsByName[nameKey(item.locationName)],
                placeName: trimmedPlace?.isEmpty == false ? trimmedPlace : nil,
                placeID: nil,
                iconID: item.iconID,
                quantity: item.quantity,
                conditionStorageValue: item.condition,
                tags: item.tags,
                notes: item.notes,
                createdAt: InventoryPortabilityDate.string(from: item.createdAt),
                updatedAt: InventoryPortabilityDate.string(from: item.updatedAt)
            )
        }

        return InventoryPortabilitySnapshotV1(
            locations: locationRecords,
            customCategories: categoryRecords,
            items: itemRecords
        )
    }

    private func fileName(for date: Date) -> String {
        let day = InventoryPortabilityDate.string(from: date).prefix(10)
        return "Home-Stuff-Inventory-\(day).json"
    }

    private func nameKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isCapacityError(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == CocoaError.fileWriteOutOfSpace.rawValue
    }
}
