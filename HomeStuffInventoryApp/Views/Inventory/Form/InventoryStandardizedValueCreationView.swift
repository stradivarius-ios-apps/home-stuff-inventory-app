import SwiftUI

enum InventoryValueCreationOutcome: Equatable {
    case success(String)
    case failure(String)
}

struct InventoryValueCreationState: Equatable {
    var value = ""
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !trimmedValue.isEmpty && !isSubmitting
    }

    mutating func beginSubmit() -> String? {
        guard canSubmit else {
            return nil
        }

        isSubmitting = true
        errorMessage = nil
        return trimmedValue
    }

    mutating func apply(_ outcome: InventoryValueCreationOutcome) {
        isSubmitting = false

        if case let .failure(message) = outcome {
            errorMessage = message
        }
    }

    mutating func clearError() {
        errorMessage = nil
    }
}

struct InventoryStandardizedValueCreationView: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    let onAdd: (String) -> InventoryValueCreationOutcome

    @Environment(\.dismiss) private var dismiss
    @State private var creationState = InventoryValueCreationState()
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            Form {
                TextField(prompt, text: $creationState.value)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(addValue)
                    .inventoryFocusableFormRow(focusedField: $focusedField, equals: .value)
                    .accessibilityIdentifier("inventory.selection.newValueField")
                    .inventoryFormRowSurface()
            }
            .inventoryFormPresentation()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.action.cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("inventory.selection.cancelCreateButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addValue()
                    } label: {
                        Text("inventory.action.add")
                    }
                    .disabled(!creationState.canSubmit)
                    .inventoryPrimaryActionTint()
                    .accessibilityIdentifier("inventory.selection.confirmCreateButton")
                }
            }
            .alert("inventory.selection.creation.error.title", isPresented: errorAlertBinding) {
                Button("inventory.action.ok", role: .cancel) { }
            } message: {
                Text(creationState.errorMessage ?? "")
            }
        }
    }

    private func addValue() {
        guard let value = creationState.beginSubmit() else {
            return
        }

        let outcome = onAdd(value)
        creationState.apply(outcome)

        if case .success = outcome {
            dismiss()
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { creationState.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    creationState.clearError()
                }
            }
        )
    }

    private enum FocusedField: Hashable {
        case value
    }
}
