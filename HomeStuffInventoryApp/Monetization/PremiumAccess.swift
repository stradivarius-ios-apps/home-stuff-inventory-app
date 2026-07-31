import Observation

struct InventoryEntitlements: Equatable, Sendable {
    let ownsLifetimePro: Bool
    let hasActiveFamilySubscription: Bool

    var hasLocalProFeatures: Bool {
        ownsLifetimePro || hasActiveFamilySubscription
    }

    var hasSyncAndSharing: Bool {
        hasActiveFamilySubscription
    }

    static let free = InventoryEntitlements(
        ownsLifetimePro: false,
        hasActiveFamilySubscription: false
    )

    init(ownsLifetimePro: Bool, hasActiveFamilySubscription: Bool) {
        self.ownsLifetimePro = ownsLifetimePro
        self.hasActiveFamilySubscription = hasActiveFamilySubscription
    }

    init(state: InventoryEntitlementState) {
        switch state {
        case .free, .expiredFamilySubscription:
            self = .free
        case .lifetimePro, .lifetimeProWithExpiredFamilySubscription:
            self.init(ownsLifetimePro: true, hasActiveFamilySubscription: false)
        case .activeFamilySubscription:
            self.init(ownsLifetimePro: false, hasActiveFamilySubscription: true)
        case .lifetimeProWithActiveFamilySubscription:
            self.init(ownsLifetimePro: true, hasActiveFamilySubscription: true)
        }
    }
}

enum PremiumFeature: CaseIterable, Hashable, Sendable {
    case roomSweep
    case moveSelectedItems
    case movePlaceContents
    case extendedMovementUndo
    case storageHierarchyEditing

    // Policy placeholders only. They do not activate or expose a production feature.
    case personalSync
    case householdSharing
}

struct PremiumAccessPolicy: Sendable {
    func availability(
        of feature: PremiumFeature,
        entitlements: InventoryEntitlements
    ) -> InventoryCapabilityAvailability {
        switch feature {
        case .roomSweep,
             .moveSelectedItems,
             .movePlaceContents,
             .extendedMovementUndo,
             .storageHierarchyEditing:
            entitlements.hasLocalProFeatures ? .available : .unavailable
        case .personalSync, .householdSharing:
            entitlements.hasSyncAndSharing ? .available : .unavailable
        }
    }

    func freeAvailability(
        of capability: InventoryFreeCapability,
        entitlementState: InventoryEntitlementState?
    ) -> InventoryCapabilityAvailability {
        InventoryFreeAccessPolicy().availability(
            of: capability,
            entitlementState: entitlementState
        )
    }
}

enum InventoryEntitlementResolution: Equatable, Sendable {
    case verified(InventoryEntitlements)
    case pending
    case cancelled
    case failed
}

@MainActor
protocol PremiumAccessProviding: AnyObject {
    var entitlements: InventoryEntitlements { get }

    func availability(of feature: PremiumFeature) -> InventoryCapabilityAvailability
}

@Observable
@MainActor
final class PremiumAccessState: PremiumAccessProviding {
    private(set) var entitlements: InventoryEntitlements
    @ObservationIgnored private let policy: PremiumAccessPolicy

    init(
        entitlements: InventoryEntitlements,
        policy: PremiumAccessPolicy = PremiumAccessPolicy()
    ) {
        self.entitlements = entitlements
        self.policy = policy
    }

    func apply(_ resolution: InventoryEntitlementResolution) {
        // Transient StoreKit outcomes never fabricate or revoke last verified access.
        guard case let .verified(entitlements) = resolution else { return }
        self.entitlements = entitlements
    }

    func availability(of feature: PremiumFeature) -> InventoryCapabilityAvailability {
        policy.availability(of: feature, entitlements: entitlements)
    }
}

#if DEBUG
enum InventoryEntitlementPreset: CaseIterable, Sendable {
    case free
    case lifetimePro
    case activeFamilySubscription
    case lifetimeProWithActiveFamilySubscription
    case expiredFamilySubscription
    case lifetimeProWithExpiredFamilySubscription

    var entitlements: InventoryEntitlements {
        InventoryEntitlements(state: entitlementState)
    }

    var entitlementState: InventoryEntitlementState {
        switch self {
        case .free: .free
        case .lifetimePro: .lifetimePro
        case .activeFamilySubscription: .activeFamilySubscription
        case .lifetimeProWithActiveFamilySubscription: .lifetimeProWithActiveFamilySubscription
        case .expiredFamilySubscription: .expiredFamilySubscription
        case .lifetimeProWithExpiredFamilySubscription: .lifetimeProWithExpiredFamilySubscription
        }
    }
}

extension PremiumAccessState {
    convenience init(
        debugPreset: InventoryEntitlementPreset,
        policy: PremiumAccessPolicy = PremiumAccessPolicy()
    ) {
        self.init(entitlements: debugPreset.entitlements, policy: policy)
    }
}
#endif
