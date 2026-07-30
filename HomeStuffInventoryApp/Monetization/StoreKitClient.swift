import Foundation
import StoreKit

struct StoreProductInfo: Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
}

struct StoreTransactionInfo: Equatable, Sendable {
    let id: UInt64
    let productID: String
    let purchaseDate: Date
    let originalPurchaseDate: Date
    let revocationDate: Date?
    let expirationDate: Date?
}

enum StoreTransactionOutcome: Equatable, Sendable {
    case verifiedLifetime(StoreTransactionInfo)
    case unverifiedLifetime(StoreTransactionInfo)
    case ignoredProduct(StoreTransactionInfo)
}

enum StorePurchaseOutcome: Equatable, Sendable {
    case purchased(StoreTransactionInfo)
    case pending
    case cancelled
    case unverified(StoreTransactionInfo)
    case ignoredProduct(StoreTransactionInfo)
}

enum StoreKitClientError: Error, Equatable {
    case productUnavailable(StoreProductID)
    case unsupportedPurchaseResult
}

struct StoreKitClient: Sendable {
    private let backend: StoreKitBackend

    static let live = StoreKitClient(backend: .storeKit2())

    init(backend: StoreKitBackend) {
        self.backend = backend
    }

    func loadLifetimeProduct() async throws -> StoreProductInfo {
        let productID = StoreProductID.lifetimePro
        let products = try await backend.loadProducts([productID.rawValue])
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            throw StoreKitClientError.productUnavailable(productID)
        }
        return product
    }

    func purchaseLifetime() async throws -> StorePurchaseOutcome {
        let result = try await backend.purchase(StoreProductID.lifetimePro.rawValue)

        switch result {
        case let .success(verification):
            switch transactionOutcome(for: verification) {
            case let .verifiedLifetime(transaction):
                await backend.finish(transaction.id)
                return .purchased(transaction)
            case let .unverifiedLifetime(transaction):
                return .unverified(transaction)
            case let .ignoredProduct(transaction):
                return .ignoredProduct(transaction)
            }
        case .pending:
            return .pending
        case .cancelled:
            return .cancelled
        }
    }

    func currentEntitlements() async -> [StoreTransactionOutcome] {
        let stream = await backend.currentEntitlements()
        var outcomes: [StoreTransactionOutcome] = []
        for await verification in stream {
            outcomes.append(transactionOutcome(for: verification))
        }
        return outcomes
    }

    func transactionUpdates() async -> AsyncStream<StoreTransactionOutcome> {
        let source = await backend.transactionUpdates()
        return AsyncStream { continuation in
            let task = Task {
                for await verification in source {
                    guard !Task.isCancelled else { break }
                    let outcome = transactionOutcome(for: verification)
                    if case let .verifiedLifetime(transaction) = outcome {
                        await backend.finish(transaction.id)
                    }
                    continuation.yield(outcome)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func transactionOutcome(
        for verification: StoreKitTransactionVerification
    ) -> StoreTransactionOutcome {
        let transaction = verification.transaction
        guard transaction.productID == StoreProductID.lifetimePro.rawValue else {
            return .ignoredProduct(transaction)
        }

        switch verification {
        case .verified:
            return .verifiedLifetime(transaction)
        case .unverified:
            return .unverifiedLifetime(transaction)
        }
    }
}

enum StoreKitTransactionVerification: Equatable, Sendable {
    case verified(StoreTransactionInfo)
    case unverified(StoreTransactionInfo)

    var transaction: StoreTransactionInfo {
        switch self {
        case let .verified(transaction), let .unverified(transaction):
            transaction
        }
    }
}

enum StoreKitBackendPurchaseResult: Equatable, Sendable {
    case success(StoreKitTransactionVerification)
    case pending
    case cancelled
}

struct StoreKitBackend: Sendable {
    let loadProducts: @Sendable (Set<String>) async throws -> [StoreProductInfo]
    let purchase: @Sendable (String) async throws -> StoreKitBackendPurchaseResult
    let currentEntitlements: @Sendable () async -> AsyncStream<StoreKitTransactionVerification>
    let transactionUpdates: @Sendable () async -> AsyncStream<StoreKitTransactionVerification>
    let finish: @Sendable (UInt64) async -> Void

    static func storeKit2() -> StoreKitBackend {
        let bridge = StoreKit2Bridge()
        return StoreKitBackend(
            loadProducts: { try await bridge.loadProducts($0) },
            purchase: { try await bridge.purchase(productID: $0) },
            currentEntitlements: { await bridge.currentEntitlements() },
            transactionUpdates: { await bridge.transactionUpdates() },
            finish: { await bridge.finish(transactionID: $0) }
        )
    }
}

private actor StoreKit2Bridge {
    private var productsByID: [String: Product] = [:]
    private var transactionsByID: [UInt64: Transaction] = [:]

    func loadProducts(_ identifiers: Set<String>) async throws -> [StoreProductInfo] {
        let products = try await Product.products(for: identifiers)
        for product in products {
            productsByID[product.id] = product
        }
        return products.map {
            StoreProductInfo(
                id: $0.id,
                displayName: $0.displayName,
                description: $0.description,
                displayPrice: $0.displayPrice
            )
        }
    }

    func purchase(productID: String) async throws -> StoreKitBackendPurchaseResult {
        let product: Product
        if let cachedProduct = productsByID[productID] {
            product = cachedProduct
        } else {
            let loadedProducts = try await Product.products(for: [productID])
            guard let loadedProduct = loadedProducts.first(where: { $0.id == productID }) else {
                throw StoreKitClientError.productUnavailable(.lifetimePro)
            }
            productsByID[productID] = loadedProduct
            product = loadedProduct
        }

        switch try await product.purchase() {
        case let .success(result):
            return .success(capture(result, retainHandledTransaction: true))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw StoreKitClientError.unsupportedPurchaseResult
        }
    }

    func currentEntitlements() -> AsyncStream<StoreKitTransactionVerification> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.currentEntitlements {
                    guard !Task.isCancelled else { break }
                    continuation.yield(capture(result, retainHandledTransaction: false))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func transactionUpdates() -> AsyncStream<StoreKitTransactionVerification> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    continuation.yield(capture(result, retainHandledTransaction: true))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func finish(transactionID: UInt64) async {
        guard let transaction = transactionsByID.removeValue(forKey: transactionID) else {
            return
        }
        await transaction.finish()
    }

    private func capture(
        _ result: VerificationResult<Transaction>,
        retainHandledTransaction: Bool
    ) -> StoreKitTransactionVerification {
        switch result {
        case let .verified(transaction):
            if retainHandledTransaction,
               transaction.productID == StoreProductID.lifetimePro.rawValue {
                transactionsByID[transaction.id] = transaction
            }
            return .verified(snapshot(of: transaction))
        case let .unverified(transaction, _):
            return .unverified(snapshot(of: transaction))
        }
    }

    private func snapshot(of transaction: Transaction) -> StoreTransactionInfo {
        StoreTransactionInfo(
            id: transaction.id,
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            originalPurchaseDate: transaction.originalPurchaseDate,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )
    }
}
