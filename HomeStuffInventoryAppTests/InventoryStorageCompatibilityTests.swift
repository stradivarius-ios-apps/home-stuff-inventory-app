import Testing
@testable import HomeStuffInventoryApp

struct InventoryStorageCompatibilityTests {
    @Test func categoryAndConditionStorageValuesStayLocaleIndependent() {
        #expect(InventoryCategory.tools.rawValue == "tools")
        #expect(InventoryCondition.needsRepair.rawValue == "needsRepair")
        #expect(InventoryCategory.storageValue(from: "Tools") == "tools")
        #expect(InventoryCondition.storageValue(from: "Needs Repair") == "needsRepair")
    }
}
