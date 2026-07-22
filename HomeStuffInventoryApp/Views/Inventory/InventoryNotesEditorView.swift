import SwiftData
import SwiftUI

struct InventoryNotesEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: InventoryItem

    @State private var editorState: InventoryNotesEditorState
    @State private var isShowingDiscardConfirmation = false
    @State private var mutationFailure: InventoryItemMutationFailure?
    @State private var hasRequestedInitialFocus = false
    @FocusState private var isNotesEditorFocused: Bool

    init(item: InventoryItem) {
        self.item = item
        _editorState = State(initialValue: InventoryNotesEditorState(persistedNotes: item.notes))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: draftBinding)
                    .focused($isNotesEditorFocused)
                    .inventoryEditorTextStyle(minHeight: 220)
                    .accessibilityLabel("inventory.field.notes")
                    .accessibilityIdentifier("inventory.notesEditor.editor")

                if editorState.draftNotes.isEmpty {
                    Text(InventoryLocalization.notesPlaceholder)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .padding(.horizontal, InventoryDesign.editorHorizontalPadding + 6)
                        .padding(.vertical, InventoryDesign.editorVerticalPadding + 8)
                        .allowsHitTesting(false)
                }
            }
            .inventoryEditorSurface(isFocused: isNotesEditorFocused)
            .padding(InventoryDesign.screenPadding)
            .navigationTitle("inventory.notes.editor.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.action.cancel") {
                        cancelEditing()
                    }
                    .accessibilityIdentifier("inventory.notesEditor.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("inventory.action.save") {
                        save()
                    }
                    .inventoryPrimaryActionTint()
                    .accessibilityIdentifier("inventory.notesEditor.saveButton")
                }
            }
            .alert("inventory.notes.discard.title", isPresented: $isShowingDiscardConfirmation) {
                Button("inventory.action.discard", role: .destructive) {
                    dismiss()
                }
                .accessibilityIdentifier("inventory.notesEditor.confirmDiscardButton")

                Button("inventory.action.cancel", role: .cancel) { }
            } message: {
                Text("inventory.notes.discard.message")
            }
            .alert(mutationFailure?.title ?? "", isPresented: isShowingMutationFailure) {
                Button("inventory.action.ok", role: .cancel) { }
            } message: {
                Text(mutationFailure?.message ?? "")
            }
        }
        .interactiveDismissDisabled(editorState.hasChanges)
        .onAppear {
            guard !hasRequestedInitialFocus else {
                return
            }

            hasRequestedInitialFocus = true
            isNotesEditorFocused = true
        }
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { editorState.draftNotes },
            set: { editorState.draftNotes = $0 }
        )
    }

    private var isShowingMutationFailure: Binding<Bool> {
        Binding(
            get: { mutationFailure != nil },
            set: { isShowing in
                if !isShowing {
                    mutationFailure = nil
                }
            }
        )
    }

    private func cancelEditing() {
        if editorState.hasChanges {
            isShowingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            try InventoryItemMutationPersistence.saveNotes(
                editorState.normalizedDraft,
                to: item,
                in: modelContext
            )
            dismiss()
        } catch {
            mutationFailure = .saveNotes
        }
    }
}
