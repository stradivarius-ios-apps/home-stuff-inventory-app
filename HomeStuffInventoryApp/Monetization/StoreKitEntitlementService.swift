import Foundation
import Observation
import Security

struct VerifiedLifetimeAccessRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let productID: String
    let transactionID: UInt64
    let originalPurchaseDate: Date
    let verifiedAt: Date

    init?(transaction: StoreTransactionInfo, verifiedAt: Date) {
        guard transaction.productID == StoreProductID.lifetimePro.rawValue,
              transaction.revocationDate == nil,
              transaction.expirationDate.map({ $0 > verifiedAt }) ?? true else {
            return nil
        }
        schemaVersion = 1
        productID = transaction.productID
        transactionID = transaction.id
        originalPurchaseDate = transaction.originalPurchaseDate
        self.verifiedAt = verifiedAt
    }

    var isSupportedLifetimeEvidence: Bool {
        schemaVersion == 1
            && productID == StoreProductID.lifetimePro.rawValue
            && transactionID > 0
    }
}

struct LifetimeAccessCache: Sendable {
    let load: @Sendable () async throws -> VerifiedLifetimeAccessRecord?
    let store: @Sendable (VerifiedLifetimeAccessRecord) async throws -> Void
    let remove: @Sendable () async throws -> Void

    static let live: LifetimeAccessCache = {
        let store = LifetimeAccessKeychainStore()
        return LifetimeAccessCache(
            load: { try store.load() },
            store: { try store.store($0) },
            remove: { try store.remove() }
        )
    }()
}

enum StoreKitEntitlementFailure: Equatable, Sendable {
    case cacheUnavailable
    case productLoadFailed
    case productUnavailable
    case entitlementRefreshFailed
    case verificationFailed
    case purchaseFailed
    case restoreFailed
}

enum StoreKitEntitlementLifecycleState: Equatable, Sendable {
    case loading(cachedLifetimeAccess: Bool)
    case available(InventoryEntitlements)
    case unavailable
    case error(StoreKitEntitlementFailure)
}

enum LifetimeProductLoadState: Equatable, Sendable {
    case idle
    case loading
    case available(StoreProductInfo)
    case unavailable
    case error(StoreKitEntitlementFailure)
}

struct PremiumIntendedAction: Equatable, Hashable, Sendable {
    let id: UUID
    let feature: PremiumFeature

    init(id: UUID = UUID(), feature: PremiumFeature) {
        self.id = id
        self.feature = feature
    }
}

struct PremiumResumableActionToken: Equatable, Hashable, Sendable {
    let id: UUID
    let feature: PremiumFeature

    fileprivate init(verifiedAction action: PremiumIntendedAction) {
        id = action.id
        feature = action.feature
    }
}

enum StoreKitEntitlementOperationState: Equatable, Sendable {
    case idle
    case purchasing
    case restoring
    case purchased(resumableAction: PremiumResumableActionToken?)
    case pending
    case cancelled
    case unverified
    case restored
    case noPurchase
    case failed(StoreKitEntitlementFailure)
}

struct StoreKitEntitlementClient: Sendable {
    let loadLifetimeProduct: @Sendable () async throws -> StoreProductInfo
    let purchaseLifetime: @Sendable () async throws -> StorePurchaseOutcome
    let currentEntitlements: @Sendable () async throws -> [StoreTransactionOutcome]
    let transactionUpdates: @Sendable () async -> AsyncStream<StoreTransactionOutcome>
    let synchronize: @Sendable () async throws -> Void

    static let live: StoreKitEntitlementClient = {
        let client = StoreKitClient.live
        return StoreKitEntitlementClient(
            loadLifetimeProduct: { try await client.loadLifetimeProduct() },
            purchaseLifetime: { try await client.purchaseLifetime() },
            currentEntitlements: { await client.currentEntitlements() },
            transactionUpdates: { await client.transactionUpdates() },
            synchronize: { try await client.synchronize() }
        )
    }()
}

@Observable
@MainActor
final class StoreKitEntitlementService {
    let premiumAccess: PremiumAccessState
    private(set) var lifecycleState: StoreKitEntitlementLifecycleState
    private(set) var productState: LifetimeProductLoadState = .idle
    private(set) var operationState: StoreKitEntitlementOperationState = .idle

    @ObservationIgnored private let client: StoreKitEntitlementClient
    @ObservationIgnored private let cache: LifetimeAccessCache
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingIntendedAction: PremiumIntendedAction?
    @ObservationIgnored private var processedUpdates: Set<TransactionUpdateIdentity> = []
    @ObservationIgnored private var reconciliationGeneration = 0
    @ObservationIgnored private var hasLoadedCache = false

    static func live() -> StoreKitEntitlementService {
        StoreKitEntitlementService(
            client: .live,
            cache: .live
        )
    }

    init(
        premiumAccess: PremiumAccessState = PremiumAccessState(entitlements: .free),
        client: StoreKitEntitlementClient,
        cache: LifetimeAccessCache,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.premiumAccess = premiumAccess
        self.client = client
        self.cache = cache
        self.now = now
        lifecycleState = .loading(cachedLifetimeAccess: premiumAccess.entitlements.ownsLifetimePro)
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        guard observationTask == nil else { return }

        observationTask = Task { [weak self, client] in
            await self?.loadCachedAccessIfNeeded()
            guard !Task.isCancelled else { return }

            // Opening the stream first lets StoreKit buffer updates that race bootstrap.
            let updates = await client.transactionUpdates()
            await self?.refreshEntitlements()

            for await update in updates {
                guard !Task.isCancelled else { break }
                await self?.handle(update)
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        reconciliationGeneration += 1
    }

    func loadLifetimeProduct() async {
        productState = .loading
        do {
            productState = .available(try await client.loadLifetimeProduct())
        } catch StoreKitClientError.productUnavailable {
            productState = .unavailable
        } catch {
            productState = .error(.productLoadFailed)
        }
    }

    func purchaseLifetime(
        intendedAction: PremiumIntendedAction? = nil
    ) async {
        guard !operationState.isInProgress else { return }
        operationState = .purchasing
        pendingIntendedAction = intendedAction

        do {
            switch try await client.purchaseLifetime() {
            case let .purchased(transaction):
                guard await applyVerifiedLifetime(transaction) else {
                    pendingIntendedAction = nil
                    operationState = .unverified
                    return
                }
                publishPurchasedOutcome()
            case .pending:
                operationState = .pending
            case .cancelled:
                pendingIntendedAction = nil
                operationState = .cancelled
            case .unverified:
                pendingIntendedAction = nil
                operationState = .unverified
                lifecycleState = .error(.verificationFailed)
            case .ignoredProduct:
                pendingIntendedAction = nil
                operationState = .failed(.purchaseFailed)
            }
        } catch StoreKitClientError.productUnavailable {
            pendingIntendedAction = nil
            productState = .unavailable
            operationState = .failed(.productUnavailable)
        } catch {
            pendingIntendedAction = nil
            operationState = .failed(.purchaseFailed)
        }
    }

    func restorePurchases() async {
        guard !operationState.isInProgress else { return }
        operationState = .restoring

        do {
            try await client.synchronize()
        } catch {
            operationState = .failed(.restoreFailed)
            return
        }

        switch await reconcileCurrentEntitlements() {
        case .available:
            operationState = .restored
        case .unavailable:
            operationState = .noPurchase
        case .failed:
            operationState = .failed(.restoreFailed)
        case .superseded:
            break
        }
    }

    func refreshEntitlements() async {
        _ = await reconcileCurrentEntitlements()
    }

    private func loadCachedAccessIfNeeded() async {
        guard !hasLoadedCache else { return }

        do {
            let record = try await cache.load()
            guard !Task.isCancelled else { return }
            hasLoadedCache = true
            let hasCachedAccess = record?.isSupportedLifetimeEvidence == true
            if hasCachedAccess {
                applyLifetimeOwnership(true)
            }
            lifecycleState = .loading(cachedLifetimeAccess: hasCachedAccess)
        } catch {
            guard !Task.isCancelled else { return }
            hasLoadedCache = true
            lifecycleState = .error(.cacheUnavailable)
        }
    }

    private func reconcileCurrentEntitlements() async -> ReconciliationResult {
        reconciliationGeneration += 1
        let generation = reconciliationGeneration

        do {
            let outcomes = try await client.currentEntitlements()
            guard !Task.isCancelled, generation == reconciliationGeneration else {
                return .superseded
            }

            let verified = outcomes.compactMap { outcome -> StoreTransactionInfo? in
                guard case let .verifiedLifetime(transaction) = outcome else { return nil }
                return transaction
            }
            if let active = verified
                .filter(isActiveLifetimeTransaction)
                .max(by: { $0.originalPurchaseDate < $1.originalPurchaseDate }) {
                return await applyVerifiedLifetime(active) ? .available : .failed
            }

            let hasUnverifiedLifetime = outcomes.contains {
                if case .unverifiedLifetime = $0 { true } else { false }
            }
            guard !hasUnverifiedLifetime else {
                lifecycleState = .error(.verificationFailed)
                return .failed
            }

            applyLifetimeOwnership(false)
            do {
                try await cache.remove()
                publishLifecycleState()
                return .unavailable
            } catch {
                lifecycleState = .error(.cacheUnavailable)
                return .failed
            }
        } catch {
            guard generation == reconciliationGeneration else { return .superseded }
            lifecycleState = .error(.entitlementRefreshFailed)
            return .failed
        }
    }

    private func handle(_ update: StoreTransactionOutcome) async {
        switch update {
        case let .verifiedLifetime(transaction):
            let identity = TransactionUpdateIdentity(transaction: transaction)
            guard processedUpdates.insert(identity).inserted else { return }

            if isActiveLifetimeTransaction(transaction) {
                if await applyVerifiedLifetime(transaction),
                   pendingIntendedAction != nil {
                    publishPurchasedOutcome()
                }
            } else {
                applyLifetimeOwnership(false)
                do {
                    try await cache.remove()
                    publishLifecycleState()
                } catch {
                    lifecycleState = .error(.cacheUnavailable)
                }
                pendingIntendedAction = nil
            }
        case .unverifiedLifetime:
            lifecycleState = .error(.verificationFailed)
        case .ignoredProduct:
            break
        }
    }

    private func applyVerifiedLifetime(_ transaction: StoreTransactionInfo) async -> Bool {
        let timestamp = now()
        guard let record = VerifiedLifetimeAccessRecord(
            transaction: transaction,
            verifiedAt: timestamp
        ) else {
            return false
        }

        applyLifetimeOwnership(true)
        do {
            try await cache.store(record)
            publishLifecycleState()
        } catch {
            lifecycleState = .error(.cacheUnavailable)
        }
        return true
    }

    private func applyLifetimeOwnership(_ ownsLifetimePro: Bool) {
        premiumAccess.apply(
            .verified(
                InventoryEntitlements(
                    ownsLifetimePro: ownsLifetimePro,
                    hasActiveFamilySubscription: premiumAccess.entitlements.hasActiveFamilySubscription
                )
            )
        )
    }

    private func publishLifecycleState() {
        let entitlements = premiumAccess.entitlements
        lifecycleState = entitlements.hasLocalProFeatures
            ? .available(entitlements)
            : .unavailable
    }

    private func publishPurchasedOutcome() {
        let action = pendingIntendedAction.map(PremiumResumableActionToken.init(verifiedAction:))
        pendingIntendedAction = nil
        operationState = .purchased(resumableAction: action)
    }

    private func isActiveLifetimeTransaction(_ transaction: StoreTransactionInfo) -> Bool {
        transaction.productID == StoreProductID.lifetimePro.rawValue
            && transaction.revocationDate == nil
            && (transaction.expirationDate.map { $0 > now() } ?? true)
    }
}

private extension StoreKitEntitlementOperationState {
    var isInProgress: Bool {
        switch self {
        case .purchasing, .restoring:
            true
        default:
            false
        }
    }
}

private extension StoreKitEntitlementService {
    enum ReconciliationResult {
        case available
        case unavailable
        case failed
        case superseded
    }

    struct TransactionUpdateIdentity: Hashable {
        let id: UInt64
        let revocationDate: Date?
        let expirationDate: Date?

        init(transaction: StoreTransactionInfo) {
            id = transaction.id
            revocationDate = transaction.revocationDate
            expirationDate = transaction.expirationDate
        }
    }
}

private final class LifetimeAccessKeychainStore: @unchecked Sendable {
    private let service = "com.stradivarius23.HomeStuffInventoryApp.entitlements"
    private let account = "verified-lifetime-pro"

    func load() throws -> VerifiedLifetimeAccessRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(VerifiedLifetimeAccessRecord.self, from: data)
    }

    func store(_ record: VerifiedLifetimeAccessRecord) throws {
        let data = try JSONEncoder().encode(record)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        var addQuery = baseQuery
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    func remove() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private struct KeychainError: Error {
        let status: OSStatus
    }
}
