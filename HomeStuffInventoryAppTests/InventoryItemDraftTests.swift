import Foundation
import Testing
@testable import HomeStuffInventoryApp

struct InventoryItemDraftTests {
    @Test func newItemFormRequestsNameFocusOnlyOnItsFirstUninterruptedPresentation() {
        #expect(InventoryItemFormFocusBehavior.initialField(
            isCreatingItem: true,
            isVoiceOverEnabled: false,
            hasRequestedInitialFocus: false,
            hasBlurredNameField: false,
            focusedField: nil
        ) == .name)

        #expect(InventoryItemFormFocusBehavior.initialField(
            isCreatingItem: true,
            isVoiceOverEnabled: false,
            hasRequestedInitialFocus: true,
            hasBlurredNameField: false,
            focusedField: nil
        ) == nil)
    }

    @Test func itemFormInitialFocusPreservesEditAccessibilityValidationAndExistingFocus() {
        let blockedContexts: [(isCreatingItem: Bool, isVoiceOverEnabled: Bool, hasBlurredNameField: Bool, focusedField: InventoryItemFormFocusedField?)] = [
            (false, false, false, nil),
            (true, true, false, nil),
            (true, false, true, nil),
            (true, false, false, .tags)
        ]

        for context in blockedContexts {
            #expect(InventoryItemFormFocusBehavior.initialField(
                isCreatingItem: context.isCreatingItem,
                isVoiceOverEnabled: context.isVoiceOverEnabled,
                hasRequestedInitialFocus: false,
                hasBlurredNameField: context.hasBlurredNameField,
                focusedField: context.focusedField
            ) == nil)
        }
    }

    @Test func emptyNameCannotCreateItem() {
        var draft = InventoryItemDraft()
        draft.name = "  \n  "
        draft.locationName = "Desk drawer"

        #expect(!draft.isNameValid)
        #expect(draft.makeInventoryItem() == nil)
    }

    @Test func createdItemUsesDefaultsAndNormalizesInput() throws {
        var draft = InventoryItemDraft()
        draft.name = "  USB-C Adapter  "
        draft.locationName = "  Desk drawer  "
        draft.containerName = "  Cable pouch  "
        draft.quantity = 0
        draft.tagsText = " adapters, , usb-c "
        draft.notes = "  For presentations  "
        let createdAt = Date(timeIntervalSince1970: 50)

        let item = try #require(draft.makeInventoryItem(createdAt: createdAt))

        #expect(item.name == "USB-C Adapter")
        #expect(item.locationName == "Desk drawer")
        #expect(item.containerName == "Cable pouch")
        #expect(item.category == InventoryCategory.miscellaneous.rawValue)
        #expect(item.iconID == nil)
        #expect(item.quantity == 1)
        #expect(item.condition == InventoryCondition.unknown.rawValue)
        #expect(item.tags == ["adapters", "usb-c"])
        #expect(item.notes == "For presentations")
        #expect(item.createdAt == createdAt)
        #expect(item.updatedAt == createdAt)
    }

    @Test func createContextPrefillsLocationAndPlace() throws {
        var draft = InventoryItemDraft(
            createContext: InventoryItemCreateContext(
                locationName: "Hall closet",
                placeName: "Top shelf"
            )
        )
        draft.name = "Packing tape"

        let item = try #require(draft.makeInventoryItem())

        #expect(draft.locationName == "Hall closet")
        #expect(draft.containerName == "Top shelf")
        #expect(item.locationName == "Hall closet")
        #expect(item.containerName == "Top shelf")
    }

    @Test func storageConsistencyReviewPromptsForMeaningfulLocationChanges() {
        var namedToNamed = InventoryStorageConsistencyReview(initialLocationName: "Office")
        #expect(namedToNamed.promptIfNeeded(nextLocationName: "Garage", placeName: "Desk drawer") == .init(locationName: "Garage", placeName: "Desk drawer"))

        var namedToMissing = InventoryStorageConsistencyReview(initialLocationName: "Office")
        #expect(namedToMissing.promptIfNeeded(nextLocationName: "  ", placeName: "Desk drawer") == .init(locationName: "", placeName: "Desk drawer"))

        var missingToNamed = InventoryStorageConsistencyReview(initialLocationName: "")
        #expect(missingToNamed.promptIfNeeded(nextLocationName: "Garage", placeName: "Desk drawer") == .init(locationName: "Garage", placeName: "Desk drawer"))
    }

    @Test func storageConsistencyReviewSkipsInitializationEquivalentLocationsAndEmptyPlaces() {
        var review = InventoryStorageConsistencyReview(initialLocationName: " Office ")

        #expect(review.promptIfNeeded(nextLocationName: "office", placeName: "Desk drawer") == nil)
        #expect(review.promptIfNeeded(nextLocationName: "Garage", placeName: " \n ") == nil)

        let item = InventoryItem(name: "Cable", locationName: "Office", containerName: "Desk drawer")
        let editDraft = InventoryItemDraft(item: item)
        #expect(InventoryStorageConsistencyReview(initialLocationName: editDraft.locationName) == InventoryStorageConsistencyReview(initialLocationName: "Office"))
    }

    @Test func storageConsistencyReviewDoesNotRepeatAnAcceptedChangeAndReevaluatesLaterChanges() {
        var review = InventoryStorageConsistencyReview(initialLocationName: "Office")

        #expect(review.promptIfNeeded(nextLocationName: "Garage", placeName: "  Desk drawer  ")?.placeName == "  Desk drawer  ")
        #expect(review.promptIfNeeded(nextLocationName: "Garage", placeName: "Desk drawer") == nil)
        #expect(review.promptIfNeeded(nextLocationName: "Kitchen", placeName: "Desk drawer") != nil)
    }

    @Test func globalCreateContextKeepsLocationAndPlaceEditableButBlank() {
        var draft = InventoryItemDraft(createContext: .global)

        #expect(draft.locationName.isEmpty)
        #expect(draft.containerName.isEmpty)

        draft.locationName = "Kitchen"
        draft.containerName = "Utility drawer"

        #expect(draft.locationName == "Kitchen")
        #expect(draft.containerName == "Utility drawer")
    }

    @Test func formWorkflowDerivesSaveAndDirtyStateFromPersistedMeaning() {
        let initialDraft = InventoryItemDraft(createContext: .global)
        let workflow = InventoryItemFormWorkflow(initialDraft: initialDraft)

        #expect(!workflow.isSaveEnabled(for: initialDraft))
        #expect(!workflow.isDirty(initialDraft))

        var changedDraft = initialDraft
        changedDraft.name = "  USB-C adapter  "
        #expect(workflow.isSaveEnabled(for: changedDraft))
        #expect(workflow.isDirty(changedDraft))

        changedDraft.name = " \n "
        #expect(!workflow.isSaveEnabled(for: changedDraft))
    }

    @Test func formWorkflowReviewsAndClearsPlaceDeterministically() {
        var initialDraft = InventoryItemDraft()
        initialDraft.locationName = "Office"
        initialDraft.containerName = "Desk drawer"
        var workflow = InventoryItemFormWorkflow(initialDraft: initialDraft)

        #expect(workflow.reviewPlaceAfterLocationChange(locationName: "Garage", placeName: "Desk drawer") == .init(locationName: "Garage", placeName: "Desk drawer"))
        #expect(workflow.reviewPlaceAfterLocationChange(locationName: "Garage", placeName: "Desk drawer") == nil)
    }

    @Test func tagsAllowSixteenCharacters() throws {
        var draft = InventoryItemDraft()
        draft.name = "USB-C Adapter"
        draft.locationName = "Desk drawer"
        draft.tagsText = "1234567890123456"

        let item = try #require(draft.makeInventoryItem())

        #expect(draft.isTagsValid)
        #expect(draft.invalidTags.isEmpty)
        #expect(item.tags == ["1234567890123456"])
    }

    @Test func tagsLongerThanSixteenCharactersAreInvalid() {
        var draft = InventoryItemDraft()
        draft.name = "USB-C Adapter"
        draft.locationName = "Desk drawer"
        draft.tagsText = "short, 12345678901234567"

        #expect(!draft.isTagsValid)
        #expect(draft.invalidTags == ["12345678901234567"])
        #expect(draft.makeInventoryItem() == nil)
    }

    @Test func draftUsesTheSameTagNormalizationAsTheModel() {
        var draft = InventoryItemDraft()
        draft.tagsText = " USB-C , usb-c, café, CAFE, tool box, tool  box, , Travel "

        let normalizedTags = ["USB-C", "café", "tool box", "tool  box", "Travel"]
        let item = InventoryItem(
            name: "Adapter",
            locationName: "Desk",
            tags: [" USB-C ", "usb-c", "café", "CAFE", "tool box", "tool  box", "", "Travel"]
        )

        #expect(draft.normalizedTags == normalizedTags)
        #expect(item.tags == normalizedTags)
    }

    @Test func duplicateLongTagsProduceOneValidationMessage() {
        var draft = InventoryItemDraft()
        draft.tagsText = "12345678901234567, 12345678901234567"

        #expect(!draft.isTagsValid)
        #expect(draft.invalidTags == ["12345678901234567"])
    }

    @Test func firstLongTagRemainsInvalidWhenLaterEquivalentTagIsShorter() {
        var draft = InventoryItemDraft()
        let longFirstTag = "AAAAAAAAAASTRASSE"
        let shorterEquivalentTag = "aaaaaaaaaastraße"
        draft.tagsText = "\(longFirstTag), \(shorterEquivalentTag)"

        #expect(longFirstTag.count == InventoryItemDraft.maximumTagLength + 1)
        #expect(shorterEquivalentTag.count == InventoryItemDraft.maximumTagLength)
        #expect(!draft.isTagsValid)
        #expect(draft.normalizedTags == [longFirstTag])
        #expect(draft.makeInventoryItem() == nil)
    }

    @Test func blankOptionalFieldsStayBlankOrNil() throws {
        var draft = InventoryItemDraft()
        draft.name = "Hammer"
        draft.locationName = "  "
        draft.containerName = "  "

        let item = try #require(draft.makeInventoryItem())

        #expect(item.locationName.isEmpty)
        #expect(item.containerName == nil)
    }

    @Test func draftCanBeCreatedFromExistingItem() {
        let item = InventoryItem(
            name: "HDMI cable",
            category: InventoryCategory.cablesAndAdapters.rawValue,
            locationName: "Living room cabinet",
            containerName: "Cable box",
            iconID: "cable",
            quantity: 2,
            condition: InventoryCondition.good.rawValue,
            tags: ["video", "adapter"],
            notes: "For the TV"
        )

        let draft = InventoryItemDraft(item: item)

        #expect(draft.name == "HDMI cable")
        #expect(draft.category == InventoryCategory.cablesAndAdapters.rawValue)
        #expect(draft.iconID == "cable")
        #expect(draft.locationName == "Living room cabinet")
        #expect(draft.containerName == "Cable box")
        #expect(draft.quantity == 2)
        #expect(draft.condition == InventoryCondition.good.rawValue)
        #expect(draft.tagsText == "video, adapter")
        #expect(draft.notes == "For the TV")
    }

    @Test func draftMapsLegacyDisplayValuesToStoredIdentifiers() {
        let item = InventoryItem(
            name: "Legacy item",
            category: "Spare Parts",
            locationName: "Garage",
            condition: "Needs Repair"
        )
        item.category = "Spare Parts"
        item.condition = "Needs Repair"

        let draft = InventoryItemDraft(item: item)

        #expect(draft.category == InventoryCategory.spareParts.rawValue)
        #expect(draft.condition == InventoryCondition.needsRepair.rawValue)
    }

    @Test func draftAppliesNormalizedEditToExistingItem() {
        let item = InventoryItem(
            name: "Old adapter",
            locationName: "Desk",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        var draft = InventoryItemDraft(item: item)
        draft.name = "  USB-C Adapter  "
        draft.locationName = "  Hall drawer  "
        draft.containerName = "  Cable pouch  "
        draft.category = InventoryCategory.cablesAndAdapters.rawValue
        draft.iconID = "cable"
        draft.quantity = 0
        draft.condition = InventoryCondition.worn.rawValue
        draft.tagsText = " usb-c, , video "
        draft.notes = "  Works with monitor  "
        let updatedAt = Date(timeIntervalSince1970: 200)

        draft.apply(to: item, updatedAt: updatedAt)

        #expect(item.name == "USB-C Adapter")
        #expect(item.locationName == "Hall drawer")
        #expect(item.containerName == "Cable pouch")
        #expect(item.category == InventoryCategory.cablesAndAdapters.rawValue)
        #expect(item.iconID == "cable")
        #expect(item.quantity == 1)
        #expect(item.condition == InventoryCondition.worn.rawValue)
        #expect(item.tags == ["usb-c", "video"])
        #expect(item.notes == "Works with monitor")
        #expect(item.updatedAt == updatedAt)
    }

    @Test func contextualCreateDraftMatchesItsInitialComparisonSnapshot() {
        let initialDraft = InventoryItemDraft(
            createContext: .init(locationName: "Hall closet", placeName: "Top shelf")
        )

        #expect(initialDraft.normalizedForComparison == initialDraft.normalizedForComparison)
        #expect(initialDraft.normalizedForComparison.locationName == "Hall closet")
        #expect(initialDraft.normalizedForComparison.containerName == "Top shelf")
    }

    @Test func persistedItemDraftMatchesItsInitialComparisonSnapshot() {
        let item = InventoryItem(
            name: "HDMI cable",
            category: "Cables & Adapters",
            locationName: "TV stand",
            containerName: "Cable box",
            iconID: "cable",
            quantity: 2,
            condition: "Good",
            tags: ["video"],
            notes: "For the TV"
        )
        let draft = InventoryItemDraft(item: item)

        #expect(draft.normalizedForComparison.name == item.name)
        #expect(draft.normalizedForComparison.category == InventoryCategory.cablesAndAdapters.rawValue)
        #expect(draft.normalizedForComparison.condition == InventoryCondition.good.rawValue)
    }

    @Test func changingEachDraftFieldChangesItsComparisonRepresentation() {
        let initialDraft = InventoryItemDraft(
            item: InventoryItem(
                name: "Adapter",
                category: InventoryCategory.tools.rawValue,
                locationName: "Office",
                containerName: "Desk drawer",
                iconID: "cable",
                quantity: 2,
                condition: InventoryCondition.good.rawValue,
                tags: ["video"],
                notes: "For the monitor"
            )
        )
        let changes: [(inout InventoryItemDraft) -> Void] = [
            { $0.name = "Charger" },
            { $0.iconID = "hammer" },
            { $0.locationName = "Hall" },
            { $0.containerName = "Top shelf" },
            { $0.category = InventoryCategory.electronics.rawValue },
            { $0.quantity = 3 },
            { $0.condition = InventoryCondition.worn.rawValue },
            { $0.tagsText = "adapter" },
            { $0.notes = "For travel" }
        ]

        for change in changes {
            var draft = initialDraft
            change(&draft)
            #expect(draft.normalizedForComparison != initialDraft.normalizedForComparison)
        }
    }

    @Test func revertingAChangedDraftRestoresItsComparisonRepresentation() {
        var draft = InventoryItemDraft(
            item: InventoryItem(name: "Adapter", locationName: "Office", tags: ["video"])
        )
        let initialComparison = draft.normalizedForComparison
        draft.name = "Charger"
        draft.tagsText = "travel"
        draft.name = "Adapter"
        draft.tagsText = "video"

        #expect(draft.normalizedForComparison == initialComparison)
    }

    @Test func comparisonIgnoresInputThatSavesToTheOriginalValue() {
        let initialDraft = InventoryItemDraft(
            item: InventoryItem(
                name: "Adapter",
                locationName: "Office",
                containerName: nil,
                quantity: 1,
                tags: ["USB-C", "café"],
                notes: "For travel"
            )
        )
        var draft = initialDraft
        draft.name = "  Adapter  "
        draft.locationName = " Office\n"
        draft.containerName = "  "
        draft.quantity = 0
        draft.category = " Miscellaneous "
        draft.condition = " Unknown "
        draft.tagsText = " usb-c, CAFE, café "
        draft.notes = "  For travel\n"

        #expect(draft.normalizedForComparison == initialDraft.normalizedForComparison)
    }

    @Test func comparisonUsesTheSharedCaseAndDiacriticInsensitiveTagContract() {
        var initialDraft = InventoryItemDraft()
        initialDraft.tagsText = "USB-C, café"
        var equivalentDraft = initialDraft
        equivalentDraft.tagsText = "usb-c, CAFE, café"

        #expect(equivalentDraft.normalizedForComparison == initialDraft.normalizedForComparison)
    }
}
