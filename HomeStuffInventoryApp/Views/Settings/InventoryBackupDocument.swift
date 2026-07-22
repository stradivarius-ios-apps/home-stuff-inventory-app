import SwiftUI
import UniformTypeIdentifiers

struct InventoryBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum InventoryBackupExportFailure: String, Identifiable, Equatable {
    case encoding
    case lowStorage
    case destination
    case unsupportedPortabilityLimits

    var id: String { rawValue }

    static func fromPreparation(_ error: any Error) -> Self? {
        if error is CancellationError || isUserCancellation(error) {
            return nil
        }

        if let error = error as? InventoryPortabilityCodecError,
           error == .resourceLimitExceeded || error == .documentTooLarge {
            return .unsupportedPortabilityLimits
        }
        return .encoding
    }

    static func fromDestination(_ error: any Error) -> Self? {
        if error is CancellationError || contains(error, matching: isUserCancellation) {
            return nil
        }

        if contains(error, matching: isOutOfSpace) {
            return .lowStorage
        }

        return .destination
    }

    private static func contains(
        _ error: any Error,
        matching predicate: (any Error) -> Bool
    ) -> Bool {
        if predicate(error) {
            return true
        }

        let nsError = error as NSError
        guard let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? any Error,
              (underlyingError as NSError) !== nsError
        else {
            return false
        }

        return contains(underlyingError, matching: predicate)
    }

    private static func isUserCancellation(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.userCancelled.rawValue
    }

    private static func isOutOfSpace(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return (nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.fileWriteOutOfSpace.rawValue)
            || (nsError.domain == NSPOSIXErrorDomain
                && nsError.code == Int(POSIXErrorCode.ENOSPC.rawValue))
    }
}
