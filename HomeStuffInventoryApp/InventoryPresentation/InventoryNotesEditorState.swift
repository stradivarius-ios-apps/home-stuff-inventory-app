import Foundation

struct InventoryNotesEditorState: Equatable {
    let initialNotes: String
    var draftNotes: String

    init(persistedNotes: String) {
        initialNotes = persistedNotes
        draftNotes = persistedNotes
    }

    var hasChanges: Bool {
        draftNotes != initialNotes
    }

    var normalizedDraft: String {
        InventoryItem.normalizedNotes(from: draftNotes)
    }
}
