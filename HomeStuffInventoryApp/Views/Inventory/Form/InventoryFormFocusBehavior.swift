enum InventoryItemFormFocusedField: Hashable {
    case name
    case container
    case tags
    case notes
}

enum InventoryItemFormFocusBehavior {
    static func initialField(
        isCreatingItem: Bool,
        isVoiceOverEnabled: Bool,
        hasRequestedInitialFocus: Bool,
        hasBlurredNameField: Bool,
        focusedField: InventoryItemFormFocusedField?
    ) -> InventoryItemFormFocusedField? {
        guard isCreatingItem,
              !isVoiceOverEnabled,
              !hasRequestedInitialFocus,
              !hasBlurredNameField,
              focusedField == nil else {
            return nil
        }

        return .name
    }
}
