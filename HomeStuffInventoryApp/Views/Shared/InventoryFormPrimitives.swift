import SwiftUI

struct InventoryFocusableFormRowModifier<FocusValue: Hashable>: ViewModifier {
    @FocusState.Binding private var focusedField: FocusValue?
    private let focusValue: FocusValue

    init(focusedField: FocusState<FocusValue?>.Binding, focusValue: FocusValue) {
        _focusedField = focusedField
        self.focusValue = focusValue
    }

    func body(content: Content) -> some View {
        content
            .focused($focusedField, equals: focusValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = focusValue
            }
    }
}

struct InventoryEditorSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isFocused: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(InventoryDesign.Appearance.contentSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        strokeColor,
                        lineWidth: isFocused ? InventoryDesign.Stroke.editorFocused : InventoryDesign.Stroke.card
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: isFocused)
    }

    private var strokeColor: Color {
        if isFocused {
            InventoryDesign.Appearance.secondaryAccent.opacity(InventoryDesign.Opacity.editorFocusedStroke)
        } else {
            InventoryDesign.Appearance.contentStroke.opacity(InventoryDesign.Opacity.editorStroke)
        }
    }
}

struct InventoryEditorTextStyleModifier: ViewModifier {
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.body)
            .lineSpacing(2)
            .frame(minHeight: minHeight)
            .padding(.horizontal, InventoryDesign.editorHorizontalPadding)
            .padding(.vertical, InventoryDesign.editorVerticalPadding)
            .scrollContentBackground(.hidden)
    }
}

struct InventoryValidationMessageModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundStyle(Color(.systemRed))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct InventoryHelperTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct InventoryFormPresentationModifier: ViewModifier {
    let contentRole: InventoryDesign.ContentRole?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let contentRole {
            content
                .scrollContentBackground(.hidden)
                .inventoryScreenBackground(backgroundStyle(for: contentRole))
                .tint(contentRole.color)
        } else {
            content
                .scrollContentBackground(.hidden)
                .background(InventoryDesign.Appearance.groupedBackground)
                .tint(InventoryDesign.Appearance.secondaryAccent)
        }
    }

    private func backgroundStyle(for contentRole: InventoryDesign.ContentRole) -> InventoryScreenBackgroundStyle {
        switch contentRole {
        case .location:
            .locationAtmosphere
        case .item, .place:
            .grouped
        }
    }
}

struct InventoryFormRowSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(InventoryDesign.Appearance.contentSurface)
    }
}

extension View {
    func inventoryFocusableFormRow<FocusValue: Hashable>(
        focusedField: FocusState<FocusValue?>.Binding,
        equals focusValue: FocusValue
    ) -> some View {
        modifier(InventoryFocusableFormRowModifier(focusedField: focusedField, focusValue: focusValue))
    }

    func inventoryEditorSurface(
        isFocused: Bool,
        cornerRadius: CGFloat = InventoryDesign.compactCornerRadius
    ) -> some View {
        modifier(InventoryEditorSurfaceModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }

    func inventoryEditorTextStyle(minHeight: CGFloat) -> some View {
        modifier(InventoryEditorTextStyleModifier(minHeight: minHeight))
    }

    func inventoryValidationMessage() -> some View {
        modifier(InventoryValidationMessageModifier())
    }

    func inventoryHelperText() -> some View {
        modifier(InventoryHelperTextModifier())
    }

    func inventoryFormPresentation(contentRole: InventoryDesign.ContentRole? = nil) -> some View {
        modifier(InventoryFormPresentationModifier(contentRole: contentRole))
    }

    func inventoryFormRowSurface() -> some View {
        modifier(InventoryFormRowSurfaceModifier())
    }
}
