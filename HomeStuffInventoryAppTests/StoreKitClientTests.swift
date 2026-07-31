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
        let localizations = try #require(product["localizations"] as? [[String: Any]])

        #expect(products.count == 1)
        #expect(product["productID"] as? String == StoreProductID.lifetimePro.rawValue)
        #expect(product["referenceName"] as? String == "Home Stuff Pro Lifetime")
        #expect(product["type"] as? String == "NonConsumable")
        #expect(product["familyShareable"] as? Bool == false)
        #expect(Set(localizations.compactMap { $0["locale"] as? String }) == ["en_US", "uk_UA"])
        #expect(
            localizations.contains {
                $0["locale"] as? String == "en_US"
                    && $0["displayName"] as? String == "Home Stuff Pro"
                    && $0["description"] as? String
                        == "Advanced local inventory workflows."
            }
        )
        #expect(
            localizations.contains {
                $0["locale"] as? String == "uk_UA"
                    && $0["displayName"] as? String == "Home Stuff Pro"
                    && $0["description"] as? String
                        == "Розширені локальні робочі процеси інвентарю."
            }
        )
        #expect((root["subscriptionGroups"] as? [Any])?.isEmpty == true)
        #expect((root["nonRenewingSubscriptions"] as? [Any])?.isEmpty == true)
    }

    @Test func sharedSchemeResolvesTheStoreKitFixtureFromTestAndLaunchActions() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let schemeURL = repositoryRoot
            .appendingPathComponent("HomeStuffInventoryApp.xcodeproj")
            .appendingPathComponent("xcshareddata")
            .appendingPathComponent("xcschemes")
            .appendingPathComponent("HomeStuffInventoryApp.xcscheme")
        let scheme = try String(contentsOf: schemeURL, encoding: .utf8)
        let reference =
            "../../../HomeStuffInventoryApp/Resources/HomeStuffInventory.storekit"
        let resolvedFixtureURL = schemeURL
            .deletingLastPathComponent()
            .appendingPathComponent(reference)
            .standardizedFileURL
        let canonicalFixtureURL = repositoryRoot
            .appendingPathComponent("HomeStuffInventoryApp")
            .appendingPathComponent("Resources")
            .appendingPathComponent("HomeStuffInventory.storekit")
            .standardizedFileURL

        #expect(scheme.components(separatedBy: reference).count - 1 == 2)
        #expect(resolvedFixtureURL == canonicalFixtureURL)
        #expect(FileManager.default.fileExists(atPath: resolvedFixtureURL.path))
    }

#if DEBUG
    @Test func qaProductFixtureRequiresExplicitNamePriceAndEnableArguments() {
        #expect(InventoryQAStoreProductFixture.product(arguments: []) == nil)
        #expect(
            InventoryQAStoreProductFixture.product(
                arguments: ["--qa-storekit-product-fixture"]
            ) == nil
        )

        let product = InventoryQAStoreProductFixture.product(arguments: [
            "--qa-storekit-product-fixture",
            "--qa-storekit-product-name",
            "Injected Product",
            "--qa-storekit-product-price",
            "Injected Price"
        ])
        #expect(product?.id == StoreProductID.lifetimePro.rawValue)
        #expect(product?.displayName == "Injected Product")
        #expect(product?.displayPrice == "Injected Price")
    }
#endif

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

    @Test func productionSwiftSourcesDoNotHardcodeTheFixturePrice() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = repositoryRoot.appendingPathComponent("HomeStuffInventoryApp")
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        )

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(!source.contains("19.99"), "Hardcoded fixture price in \(url.lastPathComponent)")
            #expect(!source.contains("$19.99"), "Hardcoded fixture price in \(url.lastPathComponent)")
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

    @Test func synchronizeDelegatesToTheInjectableBackend() async throws {
        let recorder = StoreKitBackendRecorder()

        try await recorder.client.synchronize()

        #expect(await recorder.synchronizeCallCount == 1)
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
    private(set) var synchronizeCallCount = 0

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
                synchronize: { [weak self] in
                    await self?.synchronize()
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

    private func synchronize() {
        synchronizeCallCount += 1
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
