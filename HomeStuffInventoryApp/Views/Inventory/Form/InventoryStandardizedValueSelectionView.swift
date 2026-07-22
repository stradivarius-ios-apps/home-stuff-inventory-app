import SwiftUI

struct InventoryStandardizedValueSelectionView: View {
    let title: LocalizedStringKey
    @Binding var selection: String
    let options: [InventorySelectionOption]
    let emptySelectionTitle: LocalizedStringKey?
    let createPrompt: LocalizedStringKey
    let createButtonTitle: LocalizedStringKey
    let createSheetTitle: LocalizedStringKey
    let resolveCreatedValue: (String) -> InventoryValueCreationOutcome

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCreateSheet = false
    @State private var searchText = ""

    private var displayedOptions: [InventorySelectionOption] {
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        var displayedOptions = options

        if !trimmedSelection.isEmpty,
           !displayedOptions.contains(where: { isSelected($0) }) {
            displayedOptions.append(
                InventorySelectionOption(
                    displayName: trimmedSelection,
                    storageValue: trimmedSelection
                )
            )
        }

        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSearchText.isEmpty else {
            return displayedOptions
        }

        return displayedOptions.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var body: some View {
        List {
            if let emptySelectionTitle {
                Section {
                    Button {
                        selection = ""
                        dismiss()
                    } label: {
                        selectionRow(
                            title: emptySelectionTitle,
                            isSelected: selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("inventory.selection.empty")
                }
                .inventoryFormRowSurface()
            }

            if !displayedOptions.isEmpty {
                Section("inventory.selection.existing") {
                    ForEach(displayedOptions) { option in
                        Button {
                            selection = option.storageValue
                            dismiss()
                        } label: {
                            optionRow(option)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("inventory.selection.option.\(option.storageValue)")
                    }
                }
                .inventoryFormRowSurface()
            }

            Section {
                Button {
                    isShowingCreateSheet = true
                } label: {
                    InventoryAddNewRow(createButtonTitle)
                }
                .inventoryPrimaryActionTint()
                .accessibilityIdentifier("inventory.selection.createButton")
            }
            .inventoryFormRowSurface()
        }
        .inventoryFormPresentation()
        .accessibilityIdentifier("inventory.selection")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .sheet(isPresented: $isShowingCreateSheet) {
            InventoryStandardizedValueCreationView(
                title: createSheetTitle,
                prompt: createPrompt
            ) { value in
                createValue(value)
            }
        }
    }

    private func selectionRow(title: LocalizedStringKey, isSelected: Bool) -> some View {
        InventorySelectionRow(title, isSelected: isSelected)
    }

    private func optionRow(_ option: InventorySelectionOption) -> some View {
        InventorySelectionRow(verbatim: option.displayName, isSelected: isSelected(option))
    }

    private func isSelected(_ option: InventorySelectionOption) -> Bool {
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines)

        return option.storageValue.localizedCaseInsensitiveCompare(trimmedSelection) == .orderedSame
            || option.displayName.localizedCaseInsensitiveCompare(trimmedSelection) == .orderedSame
    }

    private func createValue(_ value: String) -> InventoryValueCreationOutcome {
        let outcome = resolveCreatedValue(value)

        if case let .success(resolvedValue) = outcome {
            selection = resolvedValue
            isShowingCreateSheet = false
        }

        return outcome
    }
}

#if DEBUG
#Preview("Location Selection - Light") {
    InventoryStandardizedValueSelectionPreview()
        .preferredColorScheme(.light)
}

#Preview("Category Selection - Dark") {
    InventoryStandardizedValueSelectionPreview(
        title: "inventory.field.category",
        selection: "spareParts",
        options: [
            InventorySelectionOption(displayName: "Cables & Adapters", storageValue: "cablesAndAdapters"),
            InventorySelectionOption(
                displayName: "Дуже довга назва категорії для перевірки контрасту",
                storageValue: "Дуже довга назва категорії для перевірки контрасту"
            ),
            InventorySelectionOption(displayName: "Spare Parts", storageValue: "spareParts")
        ],
        emptySelectionTitle: nil,
        createPrompt: "inventory.selection.category.newPrompt",
        createButtonTitle: "inventory.selection.category.addNew",
        createSheetTitle: "inventory.selection.category.create"
    )
    .preferredColorScheme(.dark)
}

private struct InventoryStandardizedValueSelectionPreview: View {
    let title: LocalizedStringKey
    let options: [InventorySelectionOption]
    let emptySelectionTitle: LocalizedStringKey?
    let createPrompt: LocalizedStringKey
    let createButtonTitle: LocalizedStringKey
    let createSheetTitle: LocalizedStringKey

    @State private var selection: String

    init(
        title: LocalizedStringKey = "inventory.field.location",
        selection: String = "Garage",
        options: [InventorySelectionOption] = [
            InventorySelectionOption(displayName: "Garage", storageValue: "Garage"),
            InventorySelectionOption(
                displayName: "Kitchen drawer with extra long label",
                storageValue: "Kitchen drawer with extra long label"
            ),
            InventorySelectionOption(displayName: "Шафа у передпокої", storageValue: "Шафа у передпокої")
        ],
        emptySelectionTitle: LocalizedStringKey? = "inventory.fallback.noLocation",
        createPrompt: LocalizedStringKey = "inventory.selection.location.newPrompt",
        createButtonTitle: LocalizedStringKey = "inventory.selection.location.addNew",
        createSheetTitle: LocalizedStringKey = "inventory.selection.location.create"
    ) {
        self.title = title
        self.options = options
        self.emptySelectionTitle = emptySelectionTitle
        self.createPrompt = createPrompt
        self.createButtonTitle = createButtonTitle
        self.createSheetTitle = createSheetTitle
        _selection = State(initialValue: selection)
    }

    var body: some View {
        NavigationStack {
            InventoryStandardizedValueSelectionView(
                title: title,
                selection: $selection,
                options: options,
                emptySelectionTitle: emptySelectionTitle,
                createPrompt: createPrompt,
                createButtonTitle: createButtonTitle,
                createSheetTitle: createSheetTitle
            ) { value in
                .success(value)
            }
        }
    }
}
#endif
