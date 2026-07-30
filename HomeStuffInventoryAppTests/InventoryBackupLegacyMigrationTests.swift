import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryBackupLegacyMigrationTests: InventoryBackupRestoreTestCase {
    let support = InventoryBackupRestoreTestSupport()

    @Test func legacyVersionZeroFixtureMigratesInMemoryAndRestoresAsVersionTwo() async throws {
        let data = try Data(contentsOf: fixtureURL("legacy-compatible-backup-v0.json"))
        let plan = try await InventoryBackupRestorePlanner().plan(data: data, currentAppVersion: "1.0")
        let context = try makeTargetContext()

        _ = try await InventoryBackupRestoreService().restore(
            plan,
            in: context,
            metadataSource: metadataSource,
            recoveryStore: try makeRecoveryStore()
        )

        #expect(try InventoryBackupSnapshotter.capture(in: context) == plan.document.inventory)
        #expect(plan.schemaVersion == 4)
        #expect(plan.document.inventory.items.first { $0.name == "Legacy drill" }?.categoryStorageValue == "tools")
        #expect(plan.document.inventory.items.first { $0.name == "Legacy drill" }?.conditionStorageValue == "good")
        #expect(plan.document.inventory.items.first { $0.name == "Legacy unlabeled place" }?.placeName == "   ")
        #expect(plan.document.inventory.recentItemViewEvents == [])
        #expect(plan.document.inventory.places.map(\.name) == ["Tool cabinet"])
        #expect(plan.document.inventory.places.allSatisfy { $0.iconID == PlaceIconCatalog.defaultIconID })
        #expect(plan.document.inventory.items.first { $0.name == "Legacy drill" }?.placeID == plan.document.inventory.places.first?.id)

        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var inventory = try #require(root["inventory"] as? [String: Any])
        var items = try #require(inventory["items"] as? [[String: Any]])
        items[1]["category"] = "  Legacy category  "
        items[1]["condition"] = "  Legacy condition  "
        inventory["items"] = items
        root["inventory"] = inventory
        let unknownValuePlan = try await InventoryBackupRestorePlanner().plan(
            data: JSONSerialization.data(withJSONObject: root)
        )
        let unknownValueItem = unknownValuePlan.document.inventory.items.first {
            $0.name == "Legacy unlabeled place"
        }
        #expect(unknownValueItem?.categoryStorageValue == "  Legacy category  ")
        #expect(unknownValueItem?.conditionStorageValue == "  Legacy condition  ")
    }

    @Test func versionOneFixtureRestoresSynthesizedPlacesAndItemLinks() async throws {
        let plan = try await InventoryBackupRestorePlanner().plan(
            data: Data(contentsOf: fixtureURL("ordinary-complete-backup-v1.json")),
            currentAppVersion: "1.0"
        )
        let context = try makeTargetContext()

        _ = try await InventoryBackupRestoreService().restore(
            plan,
            in: context,
            metadataSource: metadataSource,
            recoveryStore: try makeRecoveryStore()
        )

        #expect(try InventoryBackupSnapshotter.capture(in: context) == plan.document.inventory)
        #expect(try context.fetch(FetchDescriptor<InventoryPlace>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).allSatisfy { $0.placeID != nil })
    }
}
