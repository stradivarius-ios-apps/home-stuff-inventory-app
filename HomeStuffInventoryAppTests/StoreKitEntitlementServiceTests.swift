import Foundation
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct StoreKitEntitlementServiceTests {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test func coldLaunchWithoutCachedOrStoreOwnershipPublishesUnavailable() async {
        let harness = EntitlementClientHarness(entitlementResponses: [.success([])])
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)

        service.start()
        await eventually { service.lifecycleState == .unavailable }

        #expect(service.premiumAccess.entitlements == .free)
        #expect(await cache.removeCount == 1)
        service.stop()
    }

    @Test func offlineColdLaunchPreservesSeparatelyCachedVerifiedOwnership() async {
        let record = cachedRecord()
        let harness = EntitlementClientHarness(entitlementResponses: [.failure])
        let cache = LifetimeAccessCacheHarness(record: record)
        let service = makeService(harness: harness, cache: cache)

        service.start()
        await eventually { service.lifecycleState == .error(.entitlementRefreshFailed) }

        #expect(service.premiumAccess.entitlements.ownsLifetimePro)
        #expect(!service.premiumAccess.entitlements.hasActiveFamilySubscription)
        #expect(await cache.record == record)
        service.stop()
    }

    @Test func unsupportedCachedEvidenceNeverFabricatesOwnership() async throws {
        let data = try #require(
            """
            {
              "schemaVersion": 99,
              "productID": "unrelated.product",
              "transactionID": 999,
              "originalPurchaseDate": 0,
              "verifiedAt": 0
            }
            """.data(using: .utf8)
        )
        let unsupportedRecord = try JSONDecoder().decode(
            VerifiedLifetimeAccessRecord.self,
            from: data
        )
        let harness = EntitlementClientHarness(entitlementResponses: [.failure])
        let cache = LifetimeAccessCacheHarness(record: unsupportedRecord)
        let service = makeService(harness: harness, cache: cache)

        service.start()
        await eventually { service.lifecycleState == .error(.entitlementRefreshFailed) }

        #expect(!service.premiumAccess.entitlements.ownsLifetimePro)
        service.stop()
    }

    @Test func verifiedWarmReconciliationStoresEvidenceAndEnablesCentralPolicy() async {
        let transaction = activeTransaction(id: 10)
        let harness = EntitlementClientHarness(
            entitlementResponses: [.success([.verifiedLifetime(transaction)])]
        )
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)

        await service.refreshEntitlements()

        #expect(service.lifecycleState == .available(service.premiumAccess.entitlements))
        #expect(service.premiumAccess.availability(of: .roomSweep) == .available)
        #expect(service.premiumAccess.availability(of: .personalSync) == .unavailable)
        #expect(await cache.record?.transactionID == transaction.id)
    }

    @Test func transientAndUnverifiedRefreshesNeverRevokeVerifiedLocalAccess() async {
        let transaction = activeTransaction(id: 11)
        let harness = EntitlementClientHarness(
            entitlementResponses: [
                .success([.verifiedLifetime(transaction)]),
                .failure,
                .success([.unverifiedLifetime(transaction)])
            ]
        )
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)

        await service.refreshEntitlements()
        await service.refreshEntitlements()
        #expect(service.lifecycleState == .error(.entitlementRefreshFailed))
        #expect(service.premiumAccess.entitlements.ownsLifetimePro)

        await service.refreshEntitlements()
        #expect(service.lifecycleState == .error(.verificationFailed))
        #expect(service.premiumAccess.entitlements.ownsLifetimePro)
        #expect(await cache.removeCount == 0)
    }

    @Test func authoritativeAbsenceRevokesLifetimeButKeepsFamilyFactIndependent() async {
        let harness = EntitlementClientHarness(entitlementResponses: [.success([])])
        let cache = LifetimeAccessCacheHarness(record: cachedRecord())
        let premiumAccess = PremiumAccessState(
            entitlements: InventoryEntitlements(
                ownsLifetimePro: true,
                hasActiveFamilySubscription: true
            )
        )
        let service = makeService(
            harness: harness,
            cache: cache,
            premiumAccess: premiumAccess
        )

        await service.refreshEntitlements()

        #expect(!service.premiumAccess.entitlements.ownsLifetimePro)
        #expect(service.premiumAccess.entitlements.hasActiveFamilySubscription)
        #expect(service.lifecycleState == .available(service.premiumAccess.entitlements))
        #expect(service.premiumAccess.availability(of: .personalSync) == .available)
        #expect(await cache.record == nil)
    }

    @Test func purchaseUsesVerifiedClientOutcomeAndOnlyThenReturnsIntendedAction() async {
        let transaction = activeTransaction(id: 20)
        let action = PremiumIntendedAction(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            feature: .moveSelectedItems
        )
        let harness = EntitlementClientHarness(
            purchaseResponses: [.success(.purchased(transaction))]
        )
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)

        await service.purchaseLifetime(intendedAction: action)

        guard case let .purchased(resumableAction?) = service.operationState else {
            Issue.record("Expected a verified resumable action")
            return
        }
        #expect(resumableAction.id == action.id)
        #expect(resumableAction.feature == action.feature)
        #expect(service.premiumAccess.entitlements.ownsLifetimePro)
        #expect(await harness.purchaseCallCount == 1)
        #expect(await cache.record?.transactionID == transaction.id)
    }

    @Test func cacheWriteFailureCannotUndoAStoreVerifiedPurchase() async {
        let transaction = activeTransaction(id: 23)
        let harness = EntitlementClientHarness(
            purchaseResponses: [.success(.purchased(transaction))]
        )
        let cache = LifetimeAccessCacheHarness(storeFails: true)
        let service = makeService(harness: harness, cache: cache)

        await service.purchaseLifetime()

        #expect(service.operationState == .purchased(resumableAction: nil))
        #expect(service.lifecycleState == .error(.cacheUnavailable))
        #expect(service.premiumAccess.entitlements.ownsLifetimePro)
    }

    @Test(arguments: [
        PurchaseFixture.pending,
        .cancelled,
        .unverified,
        .productUnavailable,
        .failure
    ])
    func nonVerifiedPurchaseOutcomesNeverGrantOrExposeIntendedAction(
        fixture: PurchaseFixture
    ) async {
        let transaction = activeTransaction(id: 21)
        let response: EntitlementClientHarness.PurchaseResponse = switch fixture {
        case .pending: .success(.pending)
        case .cancelled: .success(.cancelled)
        case .unverified: .success(.unverified(transaction))
        case .productUnavailable: .productUnavailable
        case .failure: .failure
        }
        let harness = EntitlementClientHarness(purchaseResponses: [response])
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)
        let action = PremiumIntendedAction(feature: .roomSweep)

        await service.purchaseLifetime(intendedAction: action)

        #expect(!service.premiumAccess.entitlements.ownsLifetimePro)
        switch service.operationState {
        case .pending, .cancelled, .unverified, .failed:
            break
        case .purchased:
            Issue.record("A non-verified outcome exposed the intended action")
        default:
            Issue.record("Unexpected purchase state: \(service.operationState)")
        }
        #expect(await cache.record == nil)
    }

    @Test func pendingPurchaseResumesOnceAfterVerifiedUpdate() async {
        let transaction = activeTransaction(id: 22)
        let harness = EntitlementClientHarness(
            entitlementResponses: [.failure],
            purchaseResponses: [.success(.pending)]
        )
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)
        let action = PremiumIntendedAction(feature: .extendedMovementUndo)

        service.start()
        await eventually { await harness.updateStreamCount == 1 }
        await service.purchaseLifetime(intendedAction: action)
        #expect(service.operationState == .pending)

        await harness.sendUpdate(.verifiedLifetime(transaction))
        await eventually {
            guard case let .purchased(resumableAction?) = service.operationState else {
                return false
            }
            return resumableAction.id == action.id
                && resumableAction.feature == action.feature
        }
        await harness.sendUpdate(.verifiedLifetime(transaction))
        await Task.yield()

        #expect(await cache.storeCount == 1)
        service.stop()
    }

    @Test func verifiedRevocationDisablesNewProWorkWithoutTouchingFamilyState() async {
        let active = activeTransaction(id: 30)
        let revoked = StoreTransactionInfo(
            id: active.id,
            productID: active.productID,
            purchaseDate: active.purchaseDate,
            originalPurchaseDate: active.originalPurchaseDate,
            revocationDate: now,
            expirationDate: nil
        )
        let harness = EntitlementClientHarness(entitlementResponses: [.failure])
        let cache = LifetimeAccessCacheHarness(record: cachedRecord())
        let premiumAccess = PremiumAccessState(
            entitlements: InventoryEntitlements(
                ownsLifetimePro: true,
                hasActiveFamilySubscription: true
            )
        )
        let service = makeService(
            harness: harness,
            cache: cache,
            premiumAccess: premiumAccess
        )

        service.start()
        await eventually { await harness.updateStreamCount == 1 }
        await harness.sendUpdate(.verifiedLifetime(revoked))
        await eventually { !service.premiumAccess.entitlements.ownsLifetimePro }

        #expect(service.premiumAccess.entitlements.hasActiveFamilySubscription)
        #expect(service.premiumAccess.availability(of: .roomSweep) == .available)
        await eventually { await cache.record == nil }
        service.stop()
    }

    @Test func restorePublishesSuccessNoPurchaseAndFailureOutcomes() async {
        let transaction = activeTransaction(id: 40)

        let successHarness = EntitlementClientHarness(
            entitlementResponses: [.success([.verifiedLifetime(transaction)])]
        )
        let successService = makeService(
            harness: successHarness,
            cache: LifetimeAccessCacheHarness()
        )
        await successService.restorePurchases()
        #expect(successService.operationState == .restored)
        #expect(successService.premiumAccess.entitlements.ownsLifetimePro)
        #expect(await successHarness.synchronizeCallCount == 1)

        let emptyHarness = EntitlementClientHarness(
            entitlementResponses: [.success([])]
        )
        let emptyService = makeService(
            harness: emptyHarness,
            cache: LifetimeAccessCacheHarness()
        )
        await emptyService.restorePurchases()
        #expect(emptyService.operationState == .noPurchase)

        let syncFailureHarness = EntitlementClientHarness(syncFails: true)
        let syncFailureService = makeService(
            harness: syncFailureHarness,
            cache: LifetimeAccessCacheHarness(record: cachedRecord())
        )
        await syncFailureService.restorePurchases()
        #expect(syncFailureService.operationState == .failed(.restoreFailed))
        #expect(syncFailureService.premiumAccess.entitlements.ownsLifetimePro == false)

        let refreshFailureHarness = EntitlementClientHarness(
            entitlementResponses: [.failure]
        )
        let refreshFailureService = makeService(
            harness: refreshFailureHarness,
            cache: LifetimeAccessCacheHarness()
        )
        await refreshFailureService.restorePurchases()
        #expect(refreshFailureService.operationState == .failed(.restoreFailed))
    }

    @Test func lifecycleStartIsIdempotentAndStopAllowsOneCleanRestart() async {
        let harness = EntitlementClientHarness(
            entitlementResponses: [.success([]), .success([])]
        )
        let cache = LifetimeAccessCacheHarness()
        let service = makeService(harness: harness, cache: cache)

        service.start()
        service.start()
        await eventually { await harness.updateStreamCount == 1 }
        service.stop()
        await eventually { await harness.updateTerminationCount == 1 }

        service.start()
        service.start()
        await eventually { await harness.updateStreamCount == 2 }
        service.stop()

        #expect(await cache.loadCount == 1)
    }

    @Test func latestRefreshWinsWhenAnOlderRequestCompletesLater() async {
        let active = activeTransaction(id: 50)
        let sequencer = EntitlementRefreshSequencer(newerResult: [.verifiedLifetime(active)])
        let cache = LifetimeAccessCacheHarness()
        let service = StoreKitEntitlementService(
            client: StoreKitEntitlementClient(
                loadLifetimeProduct: { throw TestError.failed },
                purchaseLifetime: { throw TestError.failed },
                currentEntitlements: { try await sequencer.next() },
                transactionUpdates: { AsyncStream { $0.finish() } },
                synchronize: {}
            ),
            cache: cache.cache,
            now: { now }
        )

        let older = Task { @MainActor in await service.refreshEntitlements() }
        await eventually { await sequencer.waitingForOlderRequest }
        await service.refreshEntitlements()
        await sequencer.completeOlder(with: [])
        await older.value

        #expect(service.premiumAccess.entitlements.ownsLifetimePro)
        #expect(service.lifecycleState == .available(service.premiumAccess.entitlements))
        #expect(await cache.removeCount == 0)
    }

    @Test func productLoadingPublishesAvailableUnavailableAndErrorStates() async {
        let product = StoreProductInfo(
            id: StoreProductID.lifetimePro.rawValue,
            displayName: "Home Stuff Pro",
            description: "Advanced local workflows",
            displayPrice: "$19.99"
        )
        let availableHarness = EntitlementClientHarness(productResponse: .success(product))
        let available = makeService(
            harness: availableHarness,
            cache: LifetimeAccessCacheHarness()
        )
        await available.loadLifetimeProduct()
        #expect(available.productState == .available(product))

        let unavailableHarness = EntitlementClientHarness(productResponse: .unavailable)
        let unavailable = makeService(
            harness: unavailableHarness,
            cache: LifetimeAccessCacheHarness()
        )
        await unavailable.loadLifetimeProduct()
        #expect(unavailable.productState == .unavailable)

        let failedHarness = EntitlementClientHarness(productResponse: .failure)
        let failed = makeService(
            harness: failedHarness,
            cache: LifetimeAccessCacheHarness()
        )
        await failed.loadLifetimeProduct()
        #expect(failed.productState == .error(.productLoadFailed))
    }

    private func makeService(
        harness: EntitlementClientHarness,
        cache: LifetimeAccessCacheHarness,
        premiumAccess: PremiumAccessState = PremiumAccessState(entitlements: .free)
    ) -> StoreKitEntitlementService {
        StoreKitEntitlementService(
            premiumAccess: premiumAccess,
            client: harness.client,
            cache: cache.cache,
            now: { now }
        )
    }

    private func activeTransaction(id: UInt64) -> StoreTransactionInfo {
        StoreTransactionInfo(
            id: id,
            productID: StoreProductID.lifetimePro.rawValue,
            purchaseDate: now.addingTimeInterval(-100),
            originalPurchaseDate: now.addingTimeInterval(-100),
            revocationDate: nil,
            expirationDate: nil
        )
    }

    private func cachedRecord() -> VerifiedLifetimeAccessRecord {
        VerifiedLifetimeAccessRecord(
            transaction: activeTransaction(id: 1),
            verifiedAt: now
        )!
    }

    private func eventually(
        _ condition: @escaping () async -> Bool
    ) async {
        for _ in 0..<1_000 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        Issue.record("Timed out waiting for asynchronous state")
    }
}

enum PurchaseFixture: Sendable {
    case pending
    case cancelled
    case unverified
    case productUnavailable
    case failure
}

private enum TestError: Error {
    case failed
}

private actor LifetimeAccessCacheHarness {
    private(set) var record: VerifiedLifetimeAccessRecord?
    private(set) var loadCount = 0
    private(set) var storeCount = 0
    private(set) var removeCount = 0
    private let storeFails: Bool

    init(
        record: VerifiedLifetimeAccessRecord? = nil,
        storeFails: Bool = false
    ) {
        self.record = record
        self.storeFails = storeFails
    }

    nonisolated var cache: LifetimeAccessCache {
        LifetimeAccessCache(
            load: { [self] in
                return await self.load()
            },
            store: { [self] record in
                try await self.store(record)
            },
            remove: { [self] in
                await self.remove()
            }
        )
    }

    private func load() -> VerifiedLifetimeAccessRecord? {
        loadCount += 1
        return record
    }

    private func store(_ record: VerifiedLifetimeAccessRecord) throws {
        storeCount += 1
        if storeFails {
            throw TestError.failed
        }
        self.record = record
    }

    private func remove() {
        removeCount += 1
        record = nil
    }
}

private actor EntitlementClientHarness {
    enum ProductResponse: Sendable {
        case success(StoreProductInfo)
        case unavailable
        case failure
    }

    enum EntitlementResponse: Sendable {
        case success([StoreTransactionOutcome])
        case failure
    }

    enum PurchaseResponse: Sendable {
        case success(StorePurchaseOutcome)
        case productUnavailable
        case failure
    }

    private var entitlementResponses: [EntitlementResponse]
    private var purchaseResponses: [PurchaseResponse]
    private let productResponse: ProductResponse
    private let syncFails: Bool
    private var updateContinuations: [UUID: AsyncStream<StoreTransactionOutcome>.Continuation] = [:]

    private(set) var purchaseCallCount = 0
    private(set) var synchronizeCallCount = 0
    private(set) var updateStreamCount = 0
    private(set) var updateTerminationCount = 0

    init(
        productResponse: ProductResponse = .failure,
        entitlementResponses: [EntitlementResponse] = [],
        purchaseResponses: [PurchaseResponse] = [],
        syncFails: Bool = false
    ) {
        self.productResponse = productResponse
        self.entitlementResponses = entitlementResponses
        self.purchaseResponses = purchaseResponses
        self.syncFails = syncFails
    }

    nonisolated var client: StoreKitEntitlementClient {
        StoreKitEntitlementClient(
            loadLifetimeProduct: { [self] in
                return try await self.loadProduct()
            },
            purchaseLifetime: { [self] in
                return try await self.purchase()
            },
            currentEntitlements: { [self] in
                return try await self.entitlements()
            },
            transactionUpdates: { [self] in
                return await self.updates()
            },
            synchronize: { [self] in
                try await self.synchronize()
            }
        )
    }

    func sendUpdate(_ update: StoreTransactionOutcome) {
        updateContinuations.values.forEach { $0.yield(update) }
    }

    private func loadProduct() throws -> StoreProductInfo {
        switch productResponse {
        case let .success(product):
            return product
        case .unavailable:
            throw StoreKitClientError.productUnavailable(.lifetimePro)
        case .failure:
            throw TestError.failed
        }
    }

    private func purchase() throws -> StorePurchaseOutcome {
        purchaseCallCount += 1
        guard !purchaseResponses.isEmpty else { throw TestError.failed }
        switch purchaseResponses.removeFirst() {
        case let .success(outcome):
            return outcome
        case .productUnavailable:
            throw StoreKitClientError.productUnavailable(.lifetimePro)
        case .failure:
            throw TestError.failed
        }
    }

    private func entitlements() throws -> [StoreTransactionOutcome] {
        guard !entitlementResponses.isEmpty else { throw TestError.failed }
        switch entitlementResponses.removeFirst() {
        case let .success(outcomes):
            return outcomes
        case .failure:
            throw TestError.failed
        }
    }

    private func updates() -> AsyncStream<StoreTransactionOutcome> {
        updateStreamCount += 1
        let id = UUID()
        return AsyncStream { continuation in
            updateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.didTerminateUpdateStream(id: id)
                }
            }
        }
    }

    private func didTerminateUpdateStream(id: UUID) {
        updateContinuations[id] = nil
        updateTerminationCount += 1
    }

    private func synchronize() throws {
        synchronizeCallCount += 1
        if syncFails {
            throw TestError.failed
        }
    }
}

private actor EntitlementRefreshSequencer {
    private let newerResult: [StoreTransactionOutcome]
    private var callCount = 0
    private var olderContinuation: CheckedContinuation<[StoreTransactionOutcome], Error>?

    init(newerResult: [StoreTransactionOutcome]) {
        self.newerResult = newerResult
    }

    var waitingForOlderRequest: Bool {
        olderContinuation != nil
    }

    func next() async throws -> [StoreTransactionOutcome] {
        callCount += 1
        if callCount == 1 {
            return try await withCheckedThrowingContinuation { continuation in
                olderContinuation = continuation
            }
        }
        return newerResult
    }

    func completeOlder(with result: [StoreTransactionOutcome]) {
        olderContinuation?.resume(returning: result)
        olderContinuation = nil
    }
}
