import Foundation
import Testing
@testable import HomeStuffInventoryApp

private func premiumTestTransaction() -> StoreTransactionInfo {
    StoreTransactionInfo(
        id: 42,
        productID: StoreProductID.lifetimePro.rawValue,
        purchaseDate: Date(timeIntervalSince1970: 1_750_000_000),
        originalPurchaseDate: Date(timeIntervalSince1970: 1_750_000_000),
        revocationDate: nil,
        expirationDate: nil
    )
}

@MainActor
struct PremiumUpgradeCoordinatorTests {
    @Test func launchBundleIsExactlyTheFivePresentedCapabilities() {
        #expect(PremiumBundleCapability.allCases == [
            .roomSweep,
            .selectedItemMovement,
            .placeContentsMovement,
            .extendedMovementUndo,
            .nestedStoragePlaces
        ])
        #expect(PremiumBundleCapability.allCases.count == 5)
        #expect(!PremiumBundleCapability.allCases.map(\.rawValue).contains { $0.localizedCaseInsensitiveContains("inbox") })
    }

    @Test func everyContextMapsToTheExpectedCentralPolicyFeature() {
        let fixtures: [(PremiumUpgradeContext, PremiumFeature?)] = [
            (.settings, nil),
            (.roomSweep, .roomSweep),
            (.selectedItemMovement, .moveSelectedItems),
            (.placeContentsMovement, .movePlaceContents),
            (.extendedMovementUndo, .extendedMovementUndo),
            (.nestedStoragePlaceCreation, .storageHierarchyEditing),
            (.nestedStoragePlaceRestructure, .storageHierarchyEditing)
        ]

        for (context, feature) in fixtures {
            #expect(context.requiredFeature == feature)
            #expect(!context.titleKey.isEmpty)
            #expect(!context.messageKey.isEmpty)
        }
    }

    @Test func firstLaunchAndUnprotectedWorkflowsNeverPresentAnUpgrade() {
        let coordinator = makeCoordinator()

        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.outcome == .none)
    }

    @Test(arguments: [
        InventoryEntitlements(ownsLifetimePro: true, hasActiveFamilySubscription: false),
        InventoryEntitlements(ownsLifetimePro: false, hasActiveFamilySubscription: true),
        InventoryEntitlements(ownsLifetimePro: true, hasActiveFamilySubscription: true)
    ])
    func existingAccessResumesProtectedWorkflowWithoutPresenting(
        entitlements: InventoryEntitlements
    ) {
        let coordinator = makeCoordinator(entitlements: entitlements)
        var resumeCount = 0

        coordinator.request(.roomSweep) {
            resumeCount += 1
        }

        #expect(resumeCount == 1)
        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.premiumAccess.entitlements == entitlements)
    }

    @Test func freeContextPresentsAndCancelRetainsTheExactIntent() {
        let coordinator = makeCoordinator()

        coordinator.request(.selectedItemMovement)
        coordinator.handle(.cancelled)

        #expect(coordinator.presentedContext == .selectedItemMovement)
        #expect(coordinator.outcome == .none)
    }

    @Test func verifiedPurchaseDismissesAndResumesExactlyOnce() async {
        let verifiedTransaction = premiumTestTransaction()
        let coordinator = makeCoordinator(purchase: .purchased(verifiedTransaction))
        var resumeCount = 0

        coordinator.request(.nestedStoragePlaceCreation) {
            resumeCount += 1
        }
        await coordinator.purchase()
        let state = coordinator.operationState
        coordinator.handle(state)

        #expect(resumeCount == 1)
        #expect(coordinator.presentedContext == nil)
        #expect(coordinator.premiumAccess.entitlements.ownsLifetimePro)
    }

    @Test(arguments: [
        StorePurchaseOutcome.pending,
        .cancelled,
        .unverified(premiumTestTransaction())
    ])
    func nonSuccessPurchaseNeverResumes(
        outcome: StorePurchaseOutcome
    ) async {
        let coordinator = makeCoordinator(purchase: outcome)
        var resumeCount = 0
        coordinator.request(.placeContentsMovement) {
            resumeCount += 1
        }

        await coordinator.purchase()

        #expect(resumeCount == 0)
        #expect(coordinator.presentedContext == .placeContentsMovement)
        if outcome == .pending {
            #expect(coordinator.outcome == .pending)
        } else if case .cancelled = outcome {
            #expect(coordinator.outcome == .none)
        } else {
            #expect(coordinator.outcome == .failure)
        }
    }

    @Test func productUsesStoreProvidedLocalizedNameAndPrice() async {
        let product = StoreProductInfo(
            id: StoreProductID.lifetimePro.rawValue,
            displayName: "Localized Pro",
            description: "Localized description",
            displayPrice: "₴799.00"
        )
        let coordinator = makeCoordinator(product: .success(product))

        await coordinator.loadProductIfNeeded()

        #expect(coordinator.productState == .available(product))
    }

    @Test func missingAndOfflineProductStatesRemainExplicit() async {
        let missing = makeCoordinator(product: .productUnavailable)
        await missing.loadProductIfNeeded()
        #expect(missing.productState == .unavailable)

        let offline = makeCoordinator(product: .failure)
        await offline.loadProductIfNeeded()
        #expect(offline.productState == .error(.productLoadFailed))
    }

    @Test func restoreNoPurchaseAndRestoreFailureAreExplicit() async {
        let noPurchase = makeCoordinator(entitlementsResponse: .success([]))
        noPurchase.request(.settings)
        await noPurchase.restore()
        #expect(noPurchase.outcome == .restoreNoPurchase)

        let failure = makeCoordinator(synchronizeFails: true)
        failure.request(.settings)
        await failure.restore()
        #expect(failure.outcome == .failure)
    }

    private enum ProductFixture {
        case success(StoreProductInfo)
        case productUnavailable
        case failure
    }

    private enum EntitlementsFixture {
        case success([StoreTransactionOutcome])
        case failure
    }

    private func makeCoordinator(
        entitlements: InventoryEntitlements = .free,
        product: ProductFixture = .success(
            StoreProductInfo(
                id: StoreProductID.lifetimePro.rawValue,
                displayName: "Home Stuff Pro",
                description: "Five capabilities",
                displayPrice: "$19.99"
            )
        ),
        purchase: StorePurchaseOutcome = .cancelled,
        entitlementsResponse: EntitlementsFixture = .success([]),
        synchronizeFails: Bool = false
    ) -> PremiumUpgradeCoordinator {
        let client = StoreKitEntitlementClient(
            loadLifetimeProduct: {
                switch product {
                case let .success(info): info
                case .productUnavailable: throw StoreKitClientError.productUnavailable(.lifetimePro)
                case .failure: throw TestFailure()
                }
            },
            purchaseLifetime: { purchase },
            currentEntitlements: {
                switch entitlementsResponse {
                case let .success(outcomes): outcomes
                case .failure: throw TestFailure()
                }
            },
            transactionUpdates: { AsyncStream { $0.finish() } },
            synchronize: {
                if synchronizeFails {
                    throw TestFailure()
                }
            }
        )
        let cache = LifetimeAccessCache(
            load: { nil },
            store: { _ in },
            remove: {}
        )
        let service = StoreKitEntitlementService(
            premiumAccess: PremiumAccessState(entitlements: entitlements),
            client: client,
            cache: cache,
            now: { Date(timeIntervalSince1970: 1_750_000_100) }
        )
        return PremiumUpgradeCoordinator(service: service)
    }

    private struct TestFailure: Error {}
}
