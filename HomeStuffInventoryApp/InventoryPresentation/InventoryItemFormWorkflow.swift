import Foundation

struct InventoryItemFormWorkflow: Equatable {
    private let initialDraft: InventoryItemDraft
    private var storageConsistencyReview: InventoryStorageConsistencyReview

    init(initialDraft: InventoryItemDraft) {
        self.initialDraft = initialDraft
        self.storageConsistencyReview = InventoryStorageConsistencyReview(initialLocationName: initialDraft.locationName)
    }

    func isSaveEnabled(for draft: InventoryItemDraft) -> Bool {
        draft.isNameValid && draft.isTagsValid
    }

    func isDirty(_ draft: InventoryItemDraft) -> Bool {
        draft.normalizedForComparison != initialDraft.normalizedForComparison
    }

    func tagValidationTextArgument(for draft: InventoryItemDraft) -> String? {
        draft.invalidTags.first
    }

    mutating func reviewPlaceAfterLocationChange(
        locationName: String,
        placeName: String
    ) -> InventoryStorageConsistencyReview.Prompt? {
        storageConsistencyReview.promptIfNeeded(
            nextLocationName: locationName,
            placeName: placeName
        )
    }
}

struct InventoryRoomSweepWorkflow: Equatable {
    var draft: InventoryItemDraft
    private(set) var savedCount = 0

    init(createContext: InventoryItemCreateContext = .global) {
        draft = InventoryItemDraft(createContext: createContext)
    }

    var isSaveEnabled: Bool {
        draft.isNameValid && draft.isTagsValid
    }

    mutating func didSaveItem() {
        let retainedContext = InventoryItemCreateContext(
            locationName: draft.locationName,
            placeName: draft.containerName,
            placeID: draft.placeID
        )
        draft = InventoryItemDraft(createContext: retainedContext)
        savedCount += 1
    }
}
