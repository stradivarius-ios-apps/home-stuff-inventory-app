import SwiftData
import SwiftUI

struct InventoryItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled

    private let item: InventoryItem?
    @State private var draft = InventoryItemDraft()
    @State private var workflow: InventoryItemFormWorkflow
    @State private var isShowingSaveError = false
    @State private var isShowingDiscardConfirmation = false
    @State private var placeReviewPrompt: InventoryStorageConsistencyReview.Prompt?
    @State private var hasBlurredNameField = false
    @State private var hasRequestedInitialFocus = false
    @FocusState private var focusedField: InventoryItemFormFocusedField?

    @Query(sort: \InventoryItem.name) private var items: [InventoryItem]
    @Query(sort: \InventoryCustomCategory.name) private var customCategories: [InventoryCustomCategory]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Query(sort: \InventoryPlace.name) private var places: [InventoryPlace]

    init(item: InventoryItem? = nil, createContext: InventoryItemCreateContext = .global) {
        self.item = item
        let initialDraft = item.map(InventoryItemDraft.init(item:))
            ?? InventoryItemDraft(createContext: createContext)
        _draft = State(initialValue: initialDraft)
        _workflow = State(initialValue: InventoryItemFormWorkflow(initialDraft: initialDraft))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("inventory.field.name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                        .inventoryFocusableFormRow(focusedField: $focusedField, equals: .name)
                        .accessibilityIdentifier("inventory.itemForm.nameField")
                } header: {
                    Text("inventory.section.item")
                } footer: {
                    if shouldShowNameValidation {
                        Text("inventory.form.nameRequiredFooter")
                            .inventoryValidationMessage()
                            .accessibilityIdentifier("inventory.itemForm.nameValidation")
                    }
                }
                .inventoryFormRowSurface()

                Section {
                    NavigationLink {
                        InventoryStandardizedValueSelectionView(
                            title: "inventory.field.location",
                            selection: $draft.locationName,
                            options: locationOptions,
                            emptySelectionTitle: "inventory.fallback.noLocation",
                            createPrompt: "inventory.selection.location.newPrompt",
                            createButtonTitle: "inventory.selection.location.addNew",
                            createSheetTitle: "inventory.selection.location.create",
                            resolveCreatedValue: resolveLocationName
                        )
                    } label: {
                        LabeledContent("inventory.field.location", value: selectedLocationDisplayName)
                    }
                    .accessibilityIdentifier("inventory.itemForm.locationPicker")
                    .tint(InventoryDesign.ContentRole.location.color)

                    NavigationLink {
                        InventoryItemPlaceSelectionView(
                            location: selectedStorageLocation,
                            places: places,
                            selection: $draft.placeID,
                            placeName: $draft.containerName,
                            createPlace: createPlace
                        )
                    } label: {
                        LabeledContent("inventory.field.container", value: selectedPlaceDisplayName)
                    }
                    .disabled(selectedStorageLocation == nil)
                    .accessibilityIdentifier("inventory.itemForm.containerPicker")
                } header: {
                    Text("inventory.section.whereIsIt")
                } footer: {
                    Text("inventory.form.storageFooter")
                        .inventoryHelperText()
                }
                .inventoryFormRowSurface()
                .tint(InventoryDesign.ContentRole.location.color)

                Section("inventory.section.itemKind") {
                    NavigationLink {
                        InventoryStandardizedValueSelectionView(
                            title: "inventory.field.category",
                            selection: $draft.category,
                            options: categoryOptions,
                            emptySelectionTitle: nil,
                            createPrompt: "inventory.selection.category.newPrompt",
                            createButtonTitle: "inventory.selection.category.addNew",
                            createSheetTitle: "inventory.selection.category.create",
                            resolveCreatedValue: resolveCategoryValue
                        )
                    } label: {
                        LabeledContent("inventory.field.category", value: selectedCategoryDisplayName)
                    }
                    .accessibilityIdentifier("inventory.itemForm.categoryPicker")

                    Stepper(value: $draft.quantity, in: 1...999) {
                        LabeledContent("inventory.field.quantity", value: draft.quantity.formatted())
                    }

                    Picker("inventory.field.condition", selection: $draft.condition) {
                        ForEach(InventoryCondition.allCases) { condition in
                            Text(condition.displayName).tag(condition.rawValue)
                        }
                    }

                    NavigationLink {
                        InventoryItemIconPickerView(selection: $draft.iconID)
                    } label: {
                        InventoryItemIconSelectionLabel(iconID: draft.iconID)
                    }
                    .accessibilityIdentifier("inventory.itemForm.iconPicker")
                }
                .inventoryFormRowSurface()

                Section {
                    TextField("inventory.field.tags.placeholder", text: $draft.tagsText)
                        .textInputAutocapitalization(.never)
                        .inventoryFocusableFormRow(focusedField: $focusedField, equals: .tags)
                        .accessibilityIdentifier("inventory.itemForm.tagsField")

                    if !draft.isTagsValid {
                        Text(tagValidationText)
                            .inventoryValidationMessage()
                            .accessibilityIdentifier("inventory.itemForm.tagsValidation")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("inventory.field.notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $draft.notes)
                            .focused($focusedField, equals: .notes)
                            .inventoryEditorTextStyle(minHeight: 120)
                            .inventoryEditorSurface(isFocused: focusedField == .notes)
                            .onTapGesture {
                                focusedField = .notes
                            }
                            .accessibilityLabel("inventory.field.notes")
                            .accessibilityIdentifier("inventory.itemForm.notesEditor")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("inventory.section.extraContext")
                } footer: {
                    Text("inventory.form.extraContextFooter")
                        .inventoryHelperText()
                }
                .inventoryFormRowSurface()
            }
            .accessibilityIdentifier("inventory.itemForm")
            .inventoryFormPresentation()
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isDirty)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                requestInitialNameFocusIfAppropriate()
            }
            .onDisappear {
                focusedField = nil
            }
            .onChange(of: focusedField) { previousField, currentField in
                if previousField == .name, currentField != .name {
                    hasBlurredNameField = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("inventory.action.cancel") {
                        cancel()
                    }
                    .accessibilityIdentifier("inventory.itemForm.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("inventory.action.save") {
                        save()
                    }
                    .inventoryPrimaryActionTint()
                    .disabled(!isSaveEnabled)
                    .accessibilityIdentifier("inventory.itemForm.saveButton")
                }
            }
            .onChange(of: draft.locationName) { _, nextLocationName in
                draft.placeID = nil
                draft.allowsLegacyPlaceResolution = false
                placeReviewPrompt = workflow.reviewPlaceAfterLocationChange(
                    locationName: nextLocationName,
                    placeName: draft.containerName
                )
            }
            .alert(saveErrorTitle, isPresented: $isShowingSaveError) {
                Button("inventory.action.ok", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .alert(discardAlertTitle, isPresented: $isShowingDiscardConfirmation) {
                Button("inventory.action.keepEditing", role: .cancel) { }
                    .accessibilityIdentifier("inventory.itemForm.keepEditingButton")
                Button("inventory.action.discard", role: .destructive) {
                    dismiss()
                }
                .accessibilityIdentifier("inventory.itemForm.discardButton")
            } message: {
                Text(discardAlertMessage)
            }
            .alert(placeReviewAlertTitle, isPresented: isShowingPlaceReviewPrompt) {
                Button("inventory.action.keepPlace", role: .cancel) {
                    placeReviewPrompt = nil
                }
                .accessibilityIdentifier("inventory.itemForm.keepPlaceButton")
                Button("inventory.action.clearPlace", role: .destructive) {
                    draft.containerName = ""
                    placeReviewPrompt = nil
                }
                .accessibilityIdentifier("inventory.itemForm.clearPlaceButton")
            } message: {
                Text(placeReviewAlertMessage)
            }
        }
    }

    private func cancel() {
        guard isDirty else {
            dismiss()
            return
        }

        isShowingDiscardConfirmation = true
    }

    private func requestInitialNameFocusIfAppropriate() {
        let initialField = InventoryItemFormFocusBehavior.initialField(
            isCreatingItem: item == nil,
            isVoiceOverEnabled: isVoiceOverEnabled,
            hasRequestedInitialFocus: hasRequestedInitialFocus,
            hasBlurredNameField: hasBlurredNameField,
            focusedField: focusedField
        )
        hasRequestedInitialFocus = true
        focusedField = initialField ?? focusedField
    }

    private func save() {
        guard isSaveEnabled else {
            return
        }

        switch InventoryItemFormPersistence.save(
            draft: draft,
            item: item,
            locations: locations,
            places: places,
            in: modelContext
        ) {
        case .saved:
            dismiss()
        case .invalidDraft:
            return
        case .saveFailed:
            isShowingSaveError = true
        }
    }

    private var navigationTitle: String {
        item == nil
            ? InventoryLocalization.string("inventory.form.newItem.title", defaultValue: "New Item")
            : InventoryLocalization.string("inventory.form.editItem.title", defaultValue: "Edit Item")
    }

    private var isSaveEnabled: Bool {
        workflow.isSaveEnabled(for: draft)
    }

    private var shouldShowNameValidation: Bool {
        hasBlurredNameField && !draft.isNameValid
    }

    private var isDirty: Bool {
        workflow.isDirty(draft)
    }

    private var tagValidationText: String {
        return InventoryLocalization.formatted(
            "inventory.form.tagsMaxLengthFooter",
            defaultValue: "Keep each tag to %d characters or fewer. “%@” is too long.",
            InventoryItemDraft.maximumTagLength,
            workflow.tagValidationTextArgument(for: draft) ?? ""
        )
    }

    private var saveErrorTitle: String {
        item == nil
            ? InventoryLocalization.string("inventory.alert.saveError.newTitle", defaultValue: "Item Not Saved")
            : InventoryLocalization.string("inventory.alert.saveError.editTitle", defaultValue: "Item Not Updated")
    }

    private var saveErrorMessage: String {
        InventoryLocalization.string(
            "inventory.alert.saveError.message",
            defaultValue: "Your changes could not be saved. Please try again."
        )
    }

    private var discardAlertTitle: String {
        InventoryLocalization.string(
            "inventory.alert.discardItemChanges.title",
            defaultValue: "Discard Changes?"
        )
    }

    private var discardAlertMessage: String {
        item == nil
            ? InventoryLocalization.string(
                "inventory.alert.discardItemChanges.newMessage",
                defaultValue: "Discard this new item? It will not be saved."
            )
            : InventoryLocalization.string(
                "inventory.alert.discardItemChanges.editMessage",
                defaultValue: "Discard your changes? The saved item will not be changed."
            )
    }

    private var isShowingPlaceReviewPrompt: Binding<Bool> {
        Binding(
            get: { placeReviewPrompt != nil },
            set: { isShowing in
                if !isShowing {
                    placeReviewPrompt = nil
                }
            }
        )
    }

    private var placeReviewAlertTitle: String {
        InventoryLocalization.string(
            "inventory.alert.reviewPlaceAfterLocationChange.title",
            defaultValue: "Review Storage Place"
        )
    }

    private var placeReviewAlertMessage: String {
        guard let placeReviewPrompt else {
            return ""
        }

        let locationName = placeReviewPrompt.locationName.isEmpty
            ? InventoryLocalization.noLocation
            : placeReviewPrompt.locationName
        return InventoryLocalization.formatted(
            "inventory.alert.reviewPlaceAfterLocationChange.message",
            defaultValue: "The Storage Place “%@” may belong to the previous Location. Keep it after changing Location to “%@”, or clear it and enter a new Storage Place.",
            placeReviewPrompt.placeName,
            locationName
        )
    }

    private var categoryOptions: [InventorySelectionOption] {
        InventorySelectionOptions.categories(from: items, customCategories: customCategories)
    }

    private var locationOptions: [InventorySelectionOption] {
        InventorySelectionOptions.locations(from: items, storageLocations: locations)
    }

    private var selectedCategoryDisplayName: String {
        categoryOptions.first { $0.storageValue == draft.category }?.displayName
            ?? InventoryCategory.displayName(forStoredValue: draft.category)
    }

    private var selectedLocationDisplayName: String {
        let trimmedLocationName = draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLocationName.isEmpty else {
            return InventoryLocalization.noLocation
        }

        return locationOptions.first {
            $0.storageValue.localizedCaseInsensitiveCompare(trimmedLocationName) == .orderedSame
                || $0.displayName.localizedCaseInsensitiveCompare(trimmedLocationName) == .orderedSame
        }?.displayName ?? trimmedLocationName
    }

    private var selectedStorageLocation: StorageLocation? {
        locations.first {
            InventoryNormalizedName.location($0.name) == InventoryNormalizedName.location(draft.locationName)
        }
    }

    private var selectedPlaceDisplayName: String {
        if let id = draft.placeID, let place = places.first(where: { $0.id == id }) {
            return place.name
        }
        let trimmed = draft.containerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? InventoryLocalization.noContainer : trimmed
    }

    private func createPlace(_ name: String, _ iconID: String?) -> InventoryValueCreationOutcome {
        guard let location = selectedStorageLocation else { return .failure(valueCreationSaveErrorMessage) }
        do {
            try InventoryListManagementPersistence.save(
                .addPlace(name: name, iconID: iconID, location: location),
                locations: locations,
                places: places,
                customCategories: customCategories,
                items: items,
                in: modelContext
            )
            let persistedPlaces = try modelContext.fetch(FetchDescriptor<InventoryPlace>())
            guard let place = persistedPlaces.first(where: {
                $0.locationID == location.id
                    && InventoryNormalizedName.place($0.name) == InventoryNormalizedName.place(name)
            }) else { return .failure(valueCreationSaveErrorMessage) }
            draft.placeID = place.id
            draft.containerName = place.name
            draft.allowsLegacyPlaceResolution = true
            return .success(place.name)
        } catch {
            return .failure(valueCreationSaveErrorMessage)
        }
    }

    private func resolveCategoryValue(_ value: String) -> InventoryValueCreationOutcome {
        do {
            guard let persistedValue = try InventorySelectionValueStore.persistedCategoryValue(
                value,
                items: items,
                customCategories: customCategories,
                modelContext: modelContext
            ) else {
                return .failure(valueCreationSaveErrorMessage)
            }

            return .success(persistedValue)
        } catch {
            return .failure(valueCreationSaveErrorMessage)
        }
    }

    private func resolveLocationName(_ value: String) -> InventoryValueCreationOutcome {
        do {
            guard let persistedValue = try InventorySelectionValueStore.persistedLocationName(
                value,
                items: items,
                storageLocations: locations,
                modelContext: modelContext
            ) else {
                return .failure(valueCreationSaveErrorMessage)
            }

            return .success(persistedValue)
        } catch {
            return .failure(valueCreationSaveErrorMessage)
        }
    }

    private var valueCreationSaveErrorMessage: String {
        InventoryLocalization.string(
            "inventory.selection.creation.error.message",
            defaultValue: "Couldn't save this value. Please try again."
        )
    }
}

#if DEBUG
#Preview("Item Capture Form - New") {
    InventoryItemFormView()
        .modelContainer(try! InventoryModelContainer.makeSample())
}

#Preview("Item Capture Form - Accessibility Ukrainian") {
    InventoryItemFormView()
        .modelContainer(try! InventoryModelContainer.makeSample())
        .environment(\.locale, Locale(identifier: "uk"))
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Item Capture Form - Edit Long Item") {
    InventoryItemFormView(item: .previewFormLongItem)
        .modelContainer(try! InventoryModelContainer.makeSample())
        .preferredColorScheme(.dark)
}

private extension InventoryItem {
    static var previewFormLongItem: InventoryItem {
        InventoryItem(
            id: UUID(uuidString: "8B763B0E-C1EA-40BE-8269-A7D765E3D901")!,
            name: "Набір запасних зарядних кабелів для гостей і подорожей",
            category: InventoryCategory.householdSupplies.rawValue,
            locationName: "Шафа у передпокої з довгою назвою місця зберігання",
            containerName: "Прозорий контейнер на верхній полиці біля дорожніх сумок",
            iconID: "power-plug",
            quantity: 8,
            condition: InventoryCondition.new.rawValue,
            tags: ["зарядні кабелі", "подорожі", "гості", "USB-C"],
            notes: "Підходить для перевірки довгих українських підписів, нотаток і перенесення тексту у великих розмірах Dynamic Type.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_704_320_000)
        )
    }
}
#endif
