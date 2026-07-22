import Foundation
import SwiftData
import Testing
@testable import HomeStuffInventoryApp

#if DEBUG
@MainActor
struct InventoryAppStoreDemoDataTests {
    @Test func configurationRequiresExplicitFlagAndValidLocale() {
        #expect(!AppStoreDemoDataConfiguration.isEnabled(arguments: []))
        #expect(AppStoreDemoDataConfiguration.isEnabled(arguments: [AppStoreDemoDataConfiguration.launchArgument]))
        #expect(AppStoreDemoDataConfiguration.requestedLocale(arguments: [AppStoreDemoDataConfiguration.localeArgument, "en"]) == .en)
        #expect(AppStoreDemoDataConfiguration.requestedLocale(arguments: [AppStoreDemoDataConfiguration.localeArgument, "uk"]) == .uk)
        #expect(AppStoreDemoDataConfiguration.requestedLocale(arguments: [AppStoreDemoDataConfiguration.localeArgument]) == nil)
        #expect(AppStoreDemoDataConfiguration.requestedLocale(arguments: [AppStoreDemoDataConfiguration.localeArgument, "de"]) == nil)
        #expect(AppStoreDemoDataConfiguration.requestedLocale(arguments: ["--unrelated", "value"]) == nil)
    }

    @Test func invalidAppStoreDemoLocaleFailsBeforeOpeningPersistentStorage() {
        var persistentStoreWasOpened = false
        let result = InventoryModelContainer.loadLive(
            makePersistentContainer: {
                persistentStoreWasOpened = true
                return try InventoryModelContainer.make(inMemory: true)
            },
            arguments: [AppStoreDemoDataConfiguration.launchArgument, AppStoreDemoDataConfiguration.localeArgument, "de"]
        )
        if case let .failure(error) = result {
            #expect((error.underlyingError as? AppStoreDemoDataConfigurationError) == .invalidLocale)
        } else {
            Issue.record("Invalid App Store demo locale must fail startup")
        }
        #expect(!persistentStoreWasOpened)
    }

    @Test func datasetsHaveStableCompleteLocalizedDefinitions() {
        let english = InventoryAppStoreDemoData.dataset(for: .en)
        let ukrainian = InventoryAppStoreDemoData.dataset(for: .uk)
        for dataset in [english, ukrainian] {
            #expect(dataset.locations.count == 4)
            #expect(dataset.items.count == 14)
            #expect(dataset.recentViews.count == 3)
            #expect(Set(dataset.locations.map(\.id)).count == 4)
            #expect(Set(dataset.items.map(\.id)).count == 14)
            #expect(Set(dataset.recentViews.map(\.id)).count == 3)
            #expect(dataset.locations.allSatisfy { LocationIconCatalog.normalizedIconID($0.iconID) != nil })
            #expect(dataset.items.allSatisfy { ItemIconCatalog.normalizedIconID($0.iconID) != nil && !$0.name.isEmpty && !$0.locationName.isEmpty && !$0.containerName.isEmpty && !$0.category.isEmpty && !$0.condition.isEmpty && !$0.notes.isEmpty && (1...3).contains($0.tags.count) && $0.quantity > 0 })
        }
        #expect(english.locations.map(\.id) == ukrainian.locations.map(\.id))
        #expect(english.items.map(\.id) == ukrainian.items.map(\.id))
        #expect(english.recentViews.map(\.id) == ukrainian.recentViews.map(\.id))
        #expect(InventoryAppStoreDemoData.itemTimestamp == Date(timeIntervalSince1970: 1_784_140_200))
        let warranty = english.items[3]
        #expect(warranty.category == InventoryCategory.documents.rawValue)
        #expect(warranty.iconID == "document")
        #expect(warranty.name == "Electronics warranty folder")
    }

    @Test func seedingIsLocalizedIdempotentAndSearchable() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try InventoryAppStoreDemoDataSeeder.seed(in: context, locale: .en, now: now)
        try InventoryAppStoreDemoDataSeeder.seed(in: context, locale: .en, now: now)
        var items = try context.fetch(FetchDescriptor<InventoryItem>())
        var locations = try context.fetch(FetchDescriptor<StorageLocation>())
        var events = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
        #expect(items.count == 14)
        #expect(locations.count == 4)
        #expect(events.count == 3)
        let counts = Dictionary(grouping: items, by: { item in
            "\(item.locationName) → \(item.containerName ?? "")"
        }).mapValues(\.count)
        #expect(counts == [
            "Home Office → Top desk drawer": 4, "Home Office → Cable box": 2,
            "Hall Closet → Tool box": 2, "Hall Closet → Top shelf": 1,
            "Kitchen → Utility drawer": 2, "Kitchen → Pantry top shelf": 1,
            "Entryway → Shoe cabinet": 1, "Entryway → Key tray": 1
        ])
        let results = InventorySearch.matchingResults(in: items, query: "HDMI", filters: .init(), vocabulary: .localized)
        #expect(results.map(\.item.name).sorted() == ["HDMI cable, 2 m", "USB-C display adapter"])
        #expect(results.first(where: { $0.item.name == "USB-C display adapter" })?.matchContext == .init(matchedTag: "HDMI", matchedInNotes: false))
        #expect(InventoryRecentItemViews.topItems(from: items, events: events, now: now).map(\.name) == ["USB-C display adapter", "Presentation clicker", "65W USB-C charger"])

        try InventoryAppStoreDemoDataSeeder.seed(in: context, locale: .uk, now: now)
        items = try context.fetch(FetchDescriptor<InventoryItem>())
        locations = try context.fetch(FetchDescriptor<StorageLocation>())
        events = try context.fetch(FetchDescriptor<InventoryItemViewEvent>())
        #expect(items.count == 14 && locations.count == 4 && events.count == 3)
        #expect(items.contains { $0.name == "Відеоадаптер USB-C" && $0.locationName == "Домашній кабінет" && $0.containerName == "Верхня шухляда столу" })
    }

    @Test func reseedingRestoresFixtureTimestamps() throws {
        let container = try InventoryModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let fixtureID = InventoryAppStoreDemoData.dataset(for: .en).items[0].id
        try InventoryAppStoreDemoDataSeeder.seed(in: context, locale: .en)
        let item = try #require(context.fetch(FetchDescriptor<InventoryItem>()).first { $0.id == fixtureID })
        item.createdAt = .distantPast
        item.updatedAt = .distantFuture
        try context.save()

        try InventoryAppStoreDemoDataSeeder.seed(in: context, locale: .en)
        #expect(item.createdAt == InventoryAppStoreDemoData.itemTimestamp)
        #expect(item.updatedAt == InventoryAppStoreDemoData.itemTimestamp)
    }

    @Test func factoryRunsMaintenanceWithoutChangingFixtureCounts() throws {
        let container = try InventoryModelContainer.makeAppStoreDemo(locale: .en, now: Date(timeIntervalSince1970: 1_800_000_000))
        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<StorageLocation>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<InventoryItem>()).count == 14)
        #expect(try context.fetch(FetchDescriptor<InventoryItemViewEvent>()).count == 3)
    }
}
#endif
