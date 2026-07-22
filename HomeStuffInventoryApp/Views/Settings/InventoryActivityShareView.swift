import SwiftUI
import UIKit

enum InventoryActivityShareResult: Equatable {
    case completed
    case cancelled
    case lowStorage
    case failed

    static func classify(completed: Bool, error: Error?) -> Self {
        if let error {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain,
               error.code == CocoaError.fileWriteOutOfSpace.rawValue {
                return .lowStorage
            }
            return .failed
        }
        return completed ? .completed : .cancelled
    }
}

struct InventoryActivityShareView: UIViewControllerRepresentable {
    let url: URL
    let completion: (InventoryActivityShareResult) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            completion(.classify(completed: completed, error: error))
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
