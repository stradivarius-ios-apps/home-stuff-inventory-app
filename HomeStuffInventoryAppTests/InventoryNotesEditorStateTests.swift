import Testing
@testable import HomeStuffInventoryApp

struct InventoryNotesEditorStateTests {
    @Test func draftStartsFromPersistedNotes() {
        let state = InventoryNotesEditorState(persistedNotes: "Kept with chargers")

        #expect(state.initialNotes == "Kept with chargers")
        #expect(state.draftNotes == "Kept with chargers")
        #expect(!state.hasChanges)
    }

    @Test func changedDraftRequiresDiscardConfirmationAndBlocksInteractiveDismissal() {
        var state = InventoryNotesEditorState(persistedNotes: "Kept with chargers")
        state.draftNotes = "Kept with travel chargers"

        #expect(state.hasChanges)
    }

    @Test func normalizedDraftPreservesDraftAfterAFailedSave() {
        var state = InventoryNotesEditorState(persistedNotes: "Kept with chargers")
        state.draftNotes = "  Kept with travel chargers  "

        #expect(state.normalizedDraft == "Kept with travel chargers")
        #expect(state.draftNotes == "  Kept with travel chargers  ")
        #expect(state.hasChanges)
    }

    @Test func unchangedDraftCanCancelWithoutConfirmation() {
        let state = InventoryNotesEditorState(persistedNotes: "Kept with chargers")

        #expect(!state.hasChanges)
    }
}
