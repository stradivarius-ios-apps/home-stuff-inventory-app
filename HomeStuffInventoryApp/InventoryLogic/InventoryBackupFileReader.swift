import Foundation

actor InventoryBackupFileReader {
    private let limits: InventoryPortabilityLimits
    private let metadata: @Sendable (URL) throws -> InventoryBackupFileMetadata
    private let load: @Sendable (URL) throws -> Data
    init(
        limits: InventoryPortabilityLimits = .production,
        metadata: @escaping @Sendable (URL) throws -> InventoryBackupFileMetadata = { url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey])
            return InventoryBackupFileMetadata(
                fileSize: values.fileSize,
                isRegularFile: values.isRegularFile,
                isDirectory: values.isDirectory
            )
        },
        load: @escaping @Sendable (URL) throws -> Data = { try Data(contentsOf: $0, options: [.mappedIfSafe]) }
    ) {
        self.limits = limits
        self.metadata = metadata
        self.load = load
    }
    func read(_ url: URL) throws -> Data {
        try Task.checkCancellation()
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let metadata = try metadata(url)
            guard metadata.isDirectory != true, metadata.isRegularFile != false else { throw InventoryBackupRestoreError.unreadableFile }
            if let size = metadata.fileSize, size > limits.maximumDocumentBytes { throw InventoryBackupRestoreError.fileTooLarge }
            let data = try load(url)
            try Task.checkCancellation()
            guard data.count <= limits.maximumDocumentBytes else { throw InventoryBackupRestoreError.fileTooLarge }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as InventoryBackupRestoreError {
            throw error
        } catch {
            throw InventoryBackupRestoreError.unreadableFile
        }
    }
}
