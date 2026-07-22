import Foundation
import Testing
@testable import HomeStuffInventoryApp

@MainActor
struct InventoryItemDetailViewModelTests {
    @Test func viewModelPrioritizesLocationAndContainerText() {
        let item = InventoryItem(
            name: "Precision screwdriver set",
            category: InventoryCategory.tools.rawValue,
            locationName: "Hall closet",
            containerName: "Small tool box",
            iconID: "toolkit",
            quantity: 1,
            condition: InventoryCondition.good.rawValue,
            tags: ["tools", "repair"],
            notes: "Tiny bits for laptop repairs.",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.name == "Precision screwdriver set")
        #expect(viewModel.iconID == "toolkit")
        #expect(viewModel.iconSymbolName == "wrench.and.screwdriver")
        #expect(viewModel.locationName == "Hall closet")
        #expect(viewModel.containerName == "Small tool box")
        #expect(viewModel.category == "Tools")
        #expect(viewModel.quantityBadgeText == "1 item")
        #expect(viewModel.condition == "Good")
        #expect(viewModel.tagsText == "tools, repair")
        #expect(viewModel.notesText == "Tiny bits for laptop repairs.")
    }

    @Test func viewModelUsesNeutralItemFallbackIcon() {
        let item = InventoryItem(
            name: "Mystery cable",
            locationName: "  "
        )

        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.iconID == nil)
        #expect(viewModel.iconSymbolName == ItemIconCatalog.fallbackSymbolName)
        #expect(viewModel.iconSymbolName != "mappin.and.ellipse")
        #expect(viewModel.iconSymbolName != "mappin.slash")
    }

    @Test func viewModelDisplaysLegacyCategoryAndConditionText() {
        let item = InventoryItem(
            name: "Legacy screwdriver",
            locationName: "Hall closet",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        item.category = "Tools"
        item.condition = "Needs Repair"

        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.category == "Tools")
        #expect(viewModel.condition == "Needs Repair")
    }

    @Test func viewModelHandlesMissingOptionalFieldsGracefully() {
        let item = InventoryItem(
            name: "Mystery cable",
            locationName: "  ",
            containerName: nil,
            tags: [],
            notes: " \n ",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.locationName == "No location")
        #expect(viewModel.containerName == "No Storage Place")
        #expect(viewModel.tagsText == nil)
        #expect(viewModel.notesText == "No notes")
        #expect(!viewModel.hasNotes)
    }

    @Test func viewModelPreservesMultiLineNotesText() {
        let notes = "First shelf near the charger.\nIncludes spare USB-C tips."
        let item = InventoryItem(
            name: "Travel adapter",
            locationName: "Hall closet",
            notes: notes,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.notesText == notes)
        #expect(viewModel.hasNotes)
    }

    @Test func viewModelFormatsLastUpdatedDate() {
        let createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let item = InventoryItem(
            name: "Cable ties",
            locationName: "Storage room",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.createdText(formatter: formatter) == "2020-09-13 12:26")
        #expect(viewModel.lastUpdatedText(formatter: formatter) == "2023-11-14 22:13")
    }

    @Test func viewModelUsesRefreshedLastUpdatedValueAfterNotesSave() {
        let item = InventoryItem(
            name: "Cable ties",
            locationName: "Storage room",
            notes: "Small bag",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let editTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        item.applyNotesEdit("Kept beside the tool bag", updatedAt: editTimestamp)
        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.notesText == "Kept beside the tool bag")
        #expect(viewModel.lastUpdatedText(formatter: formatter) == "2023-11-14 22:13")
    }

    @Test(arguments: [0, 1, 3])
    func collapsedTagPresentationDoesNotAddOverflowAtOrBelowLimit(tagCount: Int) {
        let tags = (0..<tagCount).map { "tag-\($0)" }
        let presentation = InventoryDetailTagsPresentation(tags: tags, isExpanded: false)

        #expect(presentation.visibleTags == tags)
        #expect(presentation.overflowCount == 0)
        #expect(!presentation.canExpand)
        #expect(!presentation.canCollapse)
    }

    @Test(arguments: [4, 12])
    func collapsedTagPresentationKeepsFirstThreeInDeterministicOrder(tagCount: Int) {
        let tags = (0..<tagCount).map { "tag-\($0)" }
        let presentation = InventoryDetailTagsPresentation(tags: tags, isExpanded: false)

        #expect(presentation.visibleTags == ["tag-0", "tag-1", "tag-2"])
        #expect(presentation.overflowCount == tagCount - 3)
        #expect(presentation.canExpand)
        #expect(!presentation.canCollapse)
    }

    @Test func expandedTagPresentationShowsAllTagsInOrderAndCanCollapse() {
        let tags = [
            "зарядні кабелі для тривалих подорожей",
            "гостьовий адаптер",
            "презентації",
            "запасний монітор",
            "робочий стіл"
        ]
        let presentation = InventoryDetailTagsPresentation(tags: tags, isExpanded: true)

        #expect(presentation.visibleTags == tags)
        #expect(presentation.overflowCount == 2)
        #expect(!presentation.canExpand)
        #expect(presentation.canCollapse)
    }
}
