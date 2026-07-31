import Foundation
import Observation

enum PremiumUpgradeContext: Equatable, Hashable, Identifiable, Sendable {
    case settings
    case roomSweep
    case selectedItemMovement
    case placeContentsMovement
    case extendedMovementUndo
    case nestedStoragePlaceCreation
    case nestedStoragePlaceRestructure

    var id: String {
        switch self {
        case .settings: "settings"
        case .roomSweep: "roomSweep"
        case .selectedItemMovement: "selectedItemMovement"
        case .placeContentsMovement: "placeContentsMovement"
        case .extendedMovementUndo: "extendedMovementUndo"
        case .nestedStoragePlaceCreation: "nestedStoragePlaceCreation"
        case .nestedStoragePlaceRestructure: "nestedStoragePlaceRestructure"
        }
    }

    var requiredFeature: PremiumFeature? {
        switch self {
        case .settings: nil
        case .roomSweep: .roomSweep
        case .selectedItemMovement: .moveSelectedItems
        case .placeContentsMovement: .movePlaceContents
        case .extendedMovementUndo: .extendedMovementUndo
        case .nestedStoragePlaceCreation, .nestedStoragePlaceRestructure: .storageHierarchyEditing
        }
    }

    var titleKey: String {
        switch self {
        case .settings: "premium.context.settings.title"
        case .roomSweep: "premium.context.roomSweep.title"
        case .selectedItemMovement: "premium.context.selectedItems.title"
        case .placeContentsMovement: "premium.context.placeContents.title"
        case .extendedMovementUndo: "premium.context.undo.title"
        case .nestedStoragePlaceCreation: "premium.context.nestedCreate.title"
        case .nestedStoragePlaceRestructure: "premium.context.nestedRestructure.title"
        }
    }

    var messageKey: String {
        switch self {
        case .settings: "premium.context.settings.message"
        case .roomSweep: "premium.context.roomSweep.message"
        case .selectedItemMovement: "premium.context.selectedItems.message"
        case .placeContentsMovement: "premium.context.placeContents.message"
        case .extendedMovementUndo: "premium.context.undo.message"
        case .nestedStoragePlaceCreation: "premium.context.nestedCreate.message"
        case .nestedStoragePlaceRestructure: "premium.context.nestedRestructure.message"
        }
    }
}

enum PremiumBundleCapability: String, CaseIterable, Sendable {
    case roomSweep
    case selectedItemMovement
    case placeContentsMovement
    case extendedMovementUndo
    case nestedStoragePlaces

    var titleKey: String { "premium.bundle.\(rawValue)" }
}

enum PremiumUpgradeOutcome: Equatable, Sendable {
    case none
    case pending
    case failure
    case offline
    case productUnavailable
    case restoreNoPurchase
    case restored
}

enum PremiumUpgradePresentationHost: Equatable, Sendable {
    case root
    case movementHistory
}

@Observable
@MainActor
final class PremiumUpgradeCoordinator {
    private(set) var presentedContext: PremiumUpgradeContext?
    private(set) var presentationHost: PremiumUpgradePresentationHost = .root
    private(set) var outcome: PremiumUpgradeOutcome = .none

    @ObservationIgnored private let service: StoreKitEntitlementService
    @ObservationIgnored private var pendingAction: PremiumIntendedAction?
    @ObservationIgnored private var resumeAction: (() -> Void)?
    @ObservationIgnored private var consumedActionIDs: Set<UUID> = []

    init(service: StoreKitEntitlementService) {
        self.service = service
    }

    var premiumAccess: PremiumAccessState { service.premiumAccess }
    var productState: LifetimeProductLoadState { service.productState }
    var operationState: StoreKitEntitlementOperationState { service.operationState }

    func request(
        _ context: PremiumUpgradeContext,
        presentationHost: PremiumUpgradePresentationHost = .root,
        resume: (() -> Void)? = nil
    ) {
        if let feature = context.requiredFeature,
           premiumAccess.availability(of: feature) == .available {
            resume?()
            return
        }

        pendingAction = context.requiredFeature.map { PremiumIntendedAction(feature: $0) }
        resumeAction = resume
        outcome = .none
        self.presentationHost = presentationHost
        presentedContext = context
    }

    func presentedContext(
        for host: PremiumUpgradePresentationHost
    ) -> PremiumUpgradeContext? {
        presentationHost == host ? presentedContext : nil
    }

    func dismiss() {
        presentedContext = nil
        presentationHost = .root
        outcome = .none
        pendingAction = nil
        resumeAction = nil
    }

    func loadProductIfNeeded() async {
        guard case .idle = service.productState else { return }
        await service.loadLifetimeProduct()
    }

    func reloadProduct() async {
        await service.loadLifetimeProduct()
    }

    func purchase() async {
        outcome = .none
        await service.purchaseLifetime(intendedAction: pendingAction)
        handle(service.operationState)
    }

    func restore() async {
        outcome = .none
        await service.restorePurchases()
        handle(service.operationState)
    }

    func handle(_ state: StoreKitEntitlementOperationState) {
        switch state {
        case let .purchased(token):
            guard let token else {
                completeWithoutResume()
                return
            }
            complete(resumableActionID: token.id)
        case .restored:
            outcome = .restored
            if let feature = presentedContext?.requiredFeature,
               premiumAccess.availability(of: feature) == .available {
                complete(resumableActionID: pendingAction?.id)
            }
        case .pending:
            outcome = .pending
        case .cancelled:
            // Keep the context and let the system cancellation remain calm.
            outcome = .none
        case .noPurchase:
            outcome = .restoreNoPurchase
        case let .failed(failure):
            outcome = failure == .productUnavailable ? .productUnavailable : .failure
        case .unverified:
            outcome = .failure
        case .idle, .purchasing, .restoring:
            break
        }
    }

    private func complete(resumableActionID: UUID?) {
        guard let actionID = resumableActionID,
              consumedActionIDs.insert(actionID).inserted else {
            return
        }
        let resume = resumeAction
        dismiss()
        resume?()
    }

    private func completeWithoutResume() {
        dismiss()
    }
}
