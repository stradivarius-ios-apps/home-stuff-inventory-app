import Testing
@testable import HomeStuffInventoryApp

struct PremiumAccessTests {
    private let localFeatures: Set<PremiumFeature> = [
        .roomSweep,
        .moveSelectedItems,
        .movePlaceContents,
        .extendedMovementUndo,
        .inventoryInboxBatchCleanup
    ]

    private let subscriptionFeatures: Set<PremiumFeature> = [
        .personalSync,
        .householdSharing
    ]

    @Test func featureSetContainsOnlyTheApprovedLaunchBundleAndPlaceholders() {
        #expect(PremiumFeature.allCases.count == 7)
        #expect(Set(PremiumFeature.allCases) == localFeatures.union(subscriptionFeatures))
    }

    @Test(arguments: [false, true], [false, true])
    func independentFactsDeriveAccess(
        ownsLifetimePro: Bool,
        hasActiveFamilySubscription: Bool
    ) {
        let entitlements = InventoryEntitlements(
            ownsLifetimePro: ownsLifetimePro,
            hasActiveFamilySubscription: hasActiveFamilySubscription
        )

        #expect(entitlements.hasLocalProFeatures == (ownsLifetimePro || hasActiveFamilySubscription))
        #expect(entitlements.hasSyncAndSharing == hasActiveFamilySubscription)
    }

    @Test func everyFeatureUsesItsSingleCentralRequirement() {
        let policy = PremiumAccessPolicy()
        let fixtures: [(InventoryEntitlements, Bool, Bool)] = [
            (.free, false, false),
            (.init(ownsLifetimePro: true, hasActiveFamilySubscription: false), true, false),
            (.init(ownsLifetimePro: false, hasActiveFamilySubscription: true), true, true),
            (.init(ownsLifetimePro: true, hasActiveFamilySubscription: true), true, true)
        ]

        for (entitlements, localAccess, subscriptionAccess) in fixtures {
            for feature in localFeatures {
                #expect(
                    policy.availability(of: feature, entitlements: entitlements)
                        == (localAccess ? .available : .unavailable)
                )
            }
            for feature in subscriptionFeatures {
                #expect(
                    policy.availability(of: feature, entitlements: entitlements)
                        == (subscriptionAccess ? .available : .unavailable)
                )
            }
        }
    }

    @Test func allSixApprovedStatesResolveTheExpectedMatrix() {
        let policy = PremiumAccessPolicy()
        let fixtures: [(InventoryEntitlementState, Bool, Bool)] = [
            (.free, false, false),
            (.lifetimePro, true, false),
            (.activeFamilySubscription, true, true),
            (.lifetimeProWithActiveFamilySubscription, true, true),
            (.expiredFamilySubscription, false, false),
            (.lifetimeProWithExpiredFamilySubscription, true, false)
        ]

        #expect(fixtures.count == InventoryEntitlementState.allCases.count)
        #expect(Set(fixtures.map(\.0)) == Set(InventoryEntitlementState.allCases))

        for (state, localAccess, subscriptionAccess) in fixtures {
            let entitlements = InventoryEntitlements(state: state)
            for feature in localFeatures {
                #expect(
                    policy.availability(of: feature, entitlements: entitlements)
                        == (localAccess ? .available : .unavailable)
                )
            }
            for feature in subscriptionFeatures {
                #expect(
                    policy.availability(of: feature, entitlements: entitlements)
                        == (subscriptionAccess ? .available : .unavailable)
                )
            }
        }
    }

    @Test @MainActor func observableStateReflectsInjectedEntitlementChanges() {
        let state = PremiumAccessState(entitlements: .free)

        #expect(state.availability(of: .roomSweep) == .unavailable)
        #expect(state.availability(of: .personalSync) == .unavailable)

        state.apply(
            .verified(.init(
                ownsLifetimePro: true,
                hasActiveFamilySubscription: false
            ))
        )
        #expect(state.availability(of: .roomSweep) == .available)
        #expect(state.availability(of: .personalSync) == .unavailable)

        state.apply(
            .verified(.init(
                ownsLifetimePro: false,
                hasActiveFamilySubscription: true
            ))
        )
        #expect(state.availability(of: .roomSweep) == .available)
        #expect(state.availability(of: .personalSync) == .available)

        state.apply(.verified(.free))
        #expect(state.availability(of: .roomSweep) == .unavailable)
    }

    @Test @MainActor func transientOutcomesPreserveLastVerifiedOfflineAccess() {
        let verifiedLifetime = InventoryEntitlements(
            ownsLifetimePro: true,
            hasActiveFamilySubscription: false
        )
        let state = PremiumAccessState(entitlements: verifiedLifetime)

        for resolution in [
            InventoryEntitlementResolution.pending,
            .cancelled,
            .failed
        ] {
            state.apply(resolution)
            #expect(state.entitlements == verifiedLifetime)
            #expect(state.availability(of: .roomSweep) == .available)
        }

        // A verified recomputation is the only path for refunds, revocations, and restores.
        state.apply(.verified(.free))
        #expect(state.availability(of: .roomSweep) == .unavailable)
        state.apply(.verified(verifiedLifetime))
        #expect(state.availability(of: .roomSweep) == .available)
    }

    @Test func everyProtectedFreeCapabilityStaysAvailableInEveryState() {
        let policy = PremiumAccessPolicy()
        let states: [InventoryEntitlementState?] = [nil] + InventoryEntitlementState.allCases.map(Optional.some)

        #expect(InventoryFreeCapability.allCases.count == 24)
        #expect(InventoryFreeCapability.allCases.contains(.filterByPlace))
        for state in states {
            for capability in InventoryFreeCapability.allCases {
                #expect(policy.freeAvailability(of: capability, entitlementState: state) == .available)
            }
        }
    }

    #if DEBUG
    @Test func debugPresetsCoverAllSixApprovedStatesWithoutProductionUI() {
        #expect(InventoryEntitlementPreset.allCases.count == 6)
        #expect(
            Set(InventoryEntitlementPreset.allCases.map(\.entitlementState))
                == Set(InventoryEntitlementState.allCases)
        )
    }

    @Test @MainActor func everyDebugPresetInjectsDeterministicState() {
        for preset in InventoryEntitlementPreset.allCases {
            let state = PremiumAccessState(debugPreset: preset)
            #expect(state.entitlements == preset.entitlements)
        }
    }
    #endif
}
