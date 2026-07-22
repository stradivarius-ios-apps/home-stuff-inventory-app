import Testing
@testable import HomeStuffInventoryApp

struct InventoryFreeAccessPolicyTests {
    private let protectedCapabilities: [InventoryFreeCapability] = [
        .unlimitedItems,
        .createItem,
        .viewItem,
        .editItem,
        .deleteItem,
        .manageLocations,
        .managePlaces,
        .relocateSingleItem,
        .searchSupportedFields,
        .filterByCategory,
        .filterByLocation,
        .filterByPlace,
        .browseLocationPlaceItem,
        .editNotes,
        .editTags,
        .editQuantity,
        .editCondition,
        .manageReusableValues,
        .guideMissingLocation,
        .guideMissingPlace,
        .viewExistingRecords,
        .exportInventory,
        .backUpInventory,
        .restoreInventory
    ]

    private let entitlementFixtures: [InventoryEntitlementState?] = [
        nil,
        .free,
        .lifetimePro,
        .activeFamilySubscription,
        .lifetimeProWithActiveFamilySubscription,
        .expiredFamilySubscription,
        .lifetimeProWithExpiredFamilySubscription
    ]

    @Test func fixtureEnumeratesTheCanonicalProtectedCapabilities() {
        #expect(protectedCapabilities.count == 24)
        #expect(Set(protectedCapabilities) == Set(InventoryFreeCapability.allCases))
    }

    @Test func fixtureEnumeratesNoStateAndEveryCanonicalEntitlementState() {
        #expect(entitlementFixtures.count == 7)
        #expect(entitlementFixtures[0] == nil)
        #expect(Set(entitlementFixtures.compactMap { $0 }) == Set(InventoryEntitlementState.allCases))
    }

    @Test func everyProtectedCapabilityIsAvailableForEveryEntitlementState() {
        let policy = InventoryFreeAccessPolicy()

        for entitlementState in entitlementFixtures {
            for capability in protectedCapabilities {
                #expect(
                    policy.availability(
                        of: capability,
                        entitlementState: entitlementState
                    ) == .available
                )
            }
        }
    }

    @Test func entitlementTransitionsCannotRevokeProtectedCapabilities() {
        let policy = InventoryFreeAccessPolicy()

        for previousState in entitlementFixtures {
            for nextState in entitlementFixtures where previousState != nextState {
                for capability in protectedCapabilities {
                    #expect(policy.availability(of: capability, entitlementState: previousState) == .available)
                    #expect(policy.availability(of: capability, entitlementState: nextState) == .available)
                }
            }
        }
    }
}
