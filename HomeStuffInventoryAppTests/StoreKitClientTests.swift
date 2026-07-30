import Foundation
import StoreKitTest
import Testing
@testable import HomeStuffInventoryApp

struct StoreKitClientTests {
    @Test
    func checkedInConfigurationLoadsTheLifetimeProduct() throws {
        let session = try SKTestSession(configurationFileNamed: "HomeStuffInventory")
        session.disableDialogs = true
        session.resetToDefaultState()
        session.clearTransactions()

        let configurationURL = try #require(
            Bundle(for: StoreKitConfigurationBundleMarker.self).url(
                forResource: "HomeStuffInventory",
                withExtension: "storekit"
            )
        )
        let data = try Data(contentsOf: configurationURL)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let products = try #require(root["products"] as? [[String: Any]])
        let product = try #require(products.first)

        #expect(products.count == 1)
        #expect(product["productID"] as? String == StoreProductID.lifetimePro.rawValue)
        #expect(product["type"] as? String == "NonConsumable")
    }

    @Test func lifetimeProductUsesTheCentralizedIdentifier() async throws {
        let recorder = StoreKitBackendRecorder(
            products: [
                StoreProductInfo(
                    id: StoreProductID.lifetimePro.rawValue,
                    displayName: "Home Stuff Pro",
                    description: "Advanced local inventory workflows.",
                    displayPrice: "$19.99"
                )
            ]
        )

        let product = try await recorder.client.loadLifetimeProduct()

        #expect(product.id == "com.stradivarius23.HomeStuffInventoryApp.pro.lifetime")
        #expect(await recorder.requestedProductIDs == [StoreProductID.lifetimePro.rawValue])
    }

    @Test func missingLifetimeProductReturnsAStableError() async {
        let recorder = StoreKitBackendRecorder(products: [])

        await #expect(throws: StoreKitClientError.productUnavailable(.lifetimePro)) {
            try await recorder.client.loadLifetimeProduct()
        }
    }

    @Test func verifiedLifetimePurchaseFinishesAndReturnsTheTransaction() async throws {
        let transaction = transaction(id: 101)
        let recorder = StoreKitBackendRecorder(
            purchaseResult: .success(.verified(transaction))
        )

        let outcome = try await recorder.client.purchaseLifetime()

        #expect(outcome == .purchased(transaction))
        #expect(await recorder.finishedTransactionIDs == [transaction.id])
    }

    @Test func unverifiedPurchaseNeverFinishesOrGrantsOwnership() async throws {
        let transaction = transaction(id: 102)
        let recorder = StoreKitBackendRecorder(
            purchaseResult: .success(.unverified(transaction))
        )

        let outcome = try await recorder.client.purchaseLifetime()

        #expect(outcome == .unverified(transaction))
        #expect(await recorder.finishedTransactionIDs.isEmpty)
    }

    @Test(arguments: [
        StoreKitBackendPurchaseResult.pending,
        .cancelled
    ])
    func transientPurchaseOutcomesStayDistinctAndDoNotFinish(
        result: StoreKitBackendPurchaseResult
    ) async throws {
        let recorder = StoreKitBackendRecorder(purchaseResult: result)

        let outcome = try await recorder.client.purchaseLifetime()

        switch result {
        case .pending:
            #expect(outcome == .pending)
        case .cancelled:
            #expect(outcome == .cancelled)
        case .success:
            Issue.record("Unexpected fixture")
        }
        #expect(await recorder.finishedTransactionIDs.isEmpty)
    }

    @Test func verifiedUnknownProductIsIgnoredAndNeverFinished() async throws {
        let transaction = transaction(id: 103, productID: "unrelated.product")
        let recorder = StoreKitBackendRecorder(
            purchaseResult: .success(.verified(transaction))
        )

        let outcome = try await recorder.client.purchaseLifetime()

        #expect(outcome == .ignoredProduct(transaction))
        #expect(await recorder.finishedTransactionIDs.isEmpty)
    }

    @Test func currentEntitlementsParseVerifiedUnverifiedAndUnrelatedTransactions() async {
        let verified = transaction(id: 201)
        let unverified = transaction(id: 202)
        let unrelated = transaction(id: 203, productID: "unrelated.product")
        let recorder = StoreKitBackendRecorder(
            currentEntitlements: [
                .verified(verified),
                .unverified(unverified),
                .verified(unrelated)
            ]
        )

        let outcomes = await recorder.client.currentEntitlements()

        #expect(outcomes == [
            .verifiedLifetime(verified),
            .unverifiedLifetime(unverified),
            .ignoredProduct(unrelated)
        ])
        #expect(await recorder.finishedTransactionIDs.isEmpty)
    }

    @Test func updateStreamFinishesOnlyHandledVerifiedLifetimeTransactions() async {
        let verified = transaction(id: 301)
        let unverified = transaction(id: 302)
        let unrelated = transaction(id: 303, productID: "unrelated.product")
        let recorder = StoreKitBackendRecorder(
            updates: [
                .verified(verified),
                .unverified(unverified),
                .verified(unrelated)
            ]
        )

        var outcomes: [StoreTransactionOutcome] = []
        for await outcome in await recorder.client.transactionUpdates() {
            outcomes.append(outcome)
        }

        #expect(outcomes == [
            .verifiedLifetime(verified),
            .unverifiedLifetime(unverified),
            .ignoredProduct(unrelated)
        ])
        #expect(await recorder.finishedTransactionIDs == [verified.id])
    }

    private func transaction(
        id: UInt64,
        productID: String = StoreProductID.lifetimePro.rawValue
    ) -> StoreTransactionInfo {
        StoreTransactionInfo(
            id: id,
            productID: productID,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            originalPurchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            revocationDate: nil,
            expirationDate: nil
        )
    }
}

private final class StoreKitConfigurationBundleMarker: NSObject {}

private actor StoreKitBackendRecorder {
    private let products: [StoreProductInfo]
    private let purchaseResult: StoreKitBackendPurchaseResult
    private let entitlementResults: [StoreKitTransactionVerification]
    private let updateResults: [StoreKitTransactionVerification]

    private(set) var requestedProductIDs: Set<String> = []
    private(set) var finishedTransactionIDs: [UInt64] = []

    init(
        products: [StoreProductInfo] = [],
        purchaseResult: StoreKitBackendPurchaseResult = .cancelled,
        currentEntitlements: [StoreKitTransactionVerification] = [],
        updates: [StoreKitTransactionVerification] = []
    ) {
        self.products = products
        self.purchaseResult = purchaseResult
        entitlementResults = currentEntitlements
        updateResults = updates
    }

    nonisolated var client: StoreKitClient {
        StoreKitClient(
            backend: StoreKitBackend(
                loadProducts: { [weak self] identifiers in
                    guard let self else { return [] }
                    return await self.loadProducts(identifiers)
                },
                purchase: { [weak self] productID in
                    guard let self else { return .cancelled }
                    return await self.purchase(productID: productID)
                },
                currentEntitlements: { [weak self] in
                    guard let self else { return AsyncStream { $0.finish() } }
                    return await self.entitlements()
                },
                transactionUpdates: { [weak self] in
                    guard let self else { return AsyncStream { $0.finish() } }
                    return await self.updates()
                },
                finish: { [weak self] transactionID in
                    await self?.finish(transactionID: transactionID)
                }
            )
        )
    }

    private func loadProducts(_ identifiers: Set<String>) -> [StoreProductInfo] {
        requestedProductIDs = identifiers
        return products.filter { identifiers.contains($0.id) }
    }

    private func purchase(productID: String) -> StoreKitBackendPurchaseResult {
        purchaseResult
    }

    private func entitlements() -> AsyncStream<StoreKitTransactionVerification> {
        stream(from: entitlementResults)
    }

    private func updates() -> AsyncStream<StoreKitTransactionVerification> {
        stream(from: updateResults)
    }

    private func finish(transactionID: UInt64) {
        finishedTransactionIDs.append(transactionID)
    }

    private func stream(
        from results: [StoreKitTransactionVerification]
    ) -> AsyncStream<StoreKitTransactionVerification> {
        AsyncStream { continuation in
            for result in results {
                continuation.yield(result)
            }
            continuation.finish()
        }
    }
}
