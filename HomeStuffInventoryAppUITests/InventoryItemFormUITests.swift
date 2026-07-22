import XCTest

@MainActor
final class InventoryItemFormUITests: InventoryUITestCase {
    func testNewItemFormInitiallyFocusesNameWhileEditFormDoesNotForceFocus() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()

        let newNameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(newNameField.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForKeyboardFocus(newNameField, timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["inventory.itemForm.cancelButton"].tap()

        openItem(named: "Precision screwdriver set")
        app.buttons["inventory.editItemButton"].tap()

        let editNameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 3))
        XCTAssertFalse(waitForKeyboardFocus(editNameField, timeout: 1))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    func testPreScopedNewItemFormInitiallyFocusesName() {
        launchApp()
        openPlaceDetail(location: "Office", place: "Desk drawer")
        app.buttons["locations.placeDetail.addItemButton"].tap()

        let nameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        XCTAssertTrue(waitForKeyboardFocus(nameField, timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office"))
        XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].label.contains("Desk drawer"))
    }

    func testReturningFromItemFormPickersDoesNotRestoreNameFocus() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()

        let nameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(waitForKeyboardFocus(nameField, timeout: 3))

        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.option.Office"].tap()
        XCTAssertFalse(waitForKeyboardFocus(nameField, timeout: 1))

        tapVisibleButton(identifier: "inventory.itemForm.containerPicker")
        tapBackButton()
        XCTAssertFalse(waitForKeyboardFocus(nameField, timeout: 1))

        tapVisibleButton(identifier: "inventory.itemForm.categoryPicker")
        tapBackButton()
        XCTAssertFalse(waitForKeyboardFocus(nameField, timeout: 1))

        tapVisibleButton(identifier: "inventory.itemForm.iconPicker")
        tapBackButton()
        XCTAssertFalse(waitForKeyboardFocus(nameField, timeout: 1))
    }

    func testAddNewPlaceUsesLocalizedScopedPickerAndDefaultIcon() {
        launchStartupApp(arguments: ["--use-sample-inventory-data"], locale: "uk")
        resetToInventoryList()
        app.buttons["inventory.addItemButton"].tap()
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.option.Office"].tap()
        tapVisibleButton(identifier: "inventory.itemForm.containerPicker")
        XCTAssertTrue(app.buttons["inventory.placeSelection.createButton"].waitForExistence(timeout: 3))
        app.buttons["inventory.placeSelection.createButton"].tap()
        let field = app.textFields["inventory.placeSelection.nameField"]
        let iconPicker = element(identifier: "inventory.placeSelection.iconPicker")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertTrue(iconPicker.waitForExistence(timeout: 3))
        XCTAssertFalse(iconPicker.label.isEmpty)
        field.tap(); field.typeText("Нова шухляда")
        XCTAssertTrue(app.buttons["inventory.placeSelection.saveButton"].isEnabled)
        app.buttons["inventory.placeSelection.saveButton"].tap()
        XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].label.contains("Нова шухляда"))
    }
    func testPrimaryActionCreationMatrixRendersInDarkHighContrastAccessibility() {
        launchStartupApp(
            arguments: ["--use-sample-inventory-data", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "uk"
        )
        app.tabBars.buttons["Інвентар"].tap()

        let inventoryAdd = app.buttons["inventory.addItemButton"]
        XCTAssertTrue(inventoryAdd.waitForExistence(timeout: 3))
        add(attachment(named: "primary-action-inventory-toolbar-uk-dark-high-contrast-reduce-transparency-accessibility"))
        inventoryAdd.tap()
        XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["inventory.itemForm.saveButton"].isEnabled)
        add(attachment(named: "primary-action-item-form-save-disabled-uk-dark-high-contrast-reduce-transparency-accessibility"))

        app.buttons["inventory.itemForm.cancelButton"].tap()

        let locationsTab = app.tabBars.buttons["Локації"]
        XCTAssertTrue(locationsTab.waitForExistence(timeout: 3))
        locationsTab.tap()
        let locationsAdd = app.buttons["locations.addItemButton"]
        XCTAssertTrue(locationsAdd.waitForExistence(timeout: 3))
        add(attachment(named: "primary-action-locations-toolbar-uk-dark-high-contrast-reduce-transparency-accessibility"))
        let locationRow = app.buttons["locations.locationRow.Office"]
        scrollToElement(locationRow, in: element(identifier: "locations.list"))
        locationRow.tap()
        XCTAssertTrue(app.buttons["locations.locationDetail.addItemButton"].waitForExistence(timeout: 3))
        add(attachment(named: "primary-action-location-detail-toolbar-uk-dark-high-contrast-reduce-transparency-accessibility"))
        let placeRow = app.buttons["locations.placeRow.Desk drawer"]
        scrollToElement(placeRow, in: element(identifier: "locations.locationDetail"))
        placeRow.tap()
        XCTAssertTrue(app.buttons["locations.placeDetail.addItemButton"].waitForExistence(timeout: 3))
        add(attachment(named: "primary-action-place-detail-toolbar-uk-dark-high-contrast-reduce-transparency-accessibility"))
    }

    func testAddLocationCreationSurfaceRendersAtAccessibilitySize() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"], contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL", locale: "uk")
        app.tabBars.buttons["Інвентар"].tap()
        app.buttons["inventory.addItemButton"].tap()
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")

        let addLocation = app.buttons["inventory.selection.createButton"]
        scrollToElement(addLocation, in: element(identifier: "inventory.selection"))
        add(attachment(named: "primary-action-add-location-row-uk-dark-high-contrast-reduce-transparency-accessibility"))
        addLocation.tap()
        XCTAssertTrue(app.textFields["inventory.selection.newValueField"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["inventory.selection.confirmCreateButton"].isEnabled)
        add(attachment(named: "primary-action-standardized-add-disabled-uk-dark-high-contrast-reduce-transparency-accessibility"))
    }

    func testAddCategoryCreationSurfaceRendersAtAccessibilitySize() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"], contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL", locale: "uk")
        app.tabBars.buttons["Інвентар"].tap()
        app.buttons["inventory.addItemButton"].tap()
        tapVisibleButton(identifier: "inventory.itemForm.categoryPicker")

        let addCategory = app.buttons["inventory.selection.createButton"]
        scrollToElement(addCategory, in: element(identifier: "inventory.selection"))
        add(attachment(named: "primary-action-add-category-row-uk-dark-high-contrast-reduce-transparency-accessibility"))
    }

    func testItemFormDiscardProtectionForNewContextualAndEditFlows() {
        launchApp(); app.buttons["inventory.addItemButton"].tap(); XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].waitForExistence(timeout: 3))
        app.buttons["inventory.itemForm.cancelButton"].tap(); XCTAssertFalse(app.buttons["inventory.itemForm.keepEditingButton"].waitForExistence(timeout: 1))
        app.buttons["inventory.addItemButton"].tap(); let nameField = app.textFields["inventory.itemForm.nameField"]; nameField.tap(); nameField.typeText("Unsaved item"); app.buttons["inventory.itemForm.cancelButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.keepEditingButton"].waitForExistence(timeout: 3)); tapAlertButton(identifier: "inventory.itemForm.keepEditingButton"); XCTAssertTrue(nameField.exists); app.buttons["inventory.itemForm.cancelButton"].tap(); tapAlertButton(identifier: "inventory.itemForm.discardButton"); XCTAssertFalse(nameField.waitForExistence(timeout: 3))
        app.tabBars.buttons["Inventory"].tap(); openPlaceDetail(location: "Office", place: "Desk drawer"); app.buttons["locations.placeDetail.addItemButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].waitForExistence(timeout: 3)); app.buttons["inventory.itemForm.cancelButton"].tap(); XCTAssertFalse(app.buttons["inventory.itemForm.keepEditingButton"].waitForExistence(timeout: 1)); tapBackButton()
        app.tabBars.buttons["Inventory"].tap(); openItem(named: "Precision screwdriver set"); app.buttons["inventory.editItemButton"].tap(); let editNameField = app.textFields["inventory.itemForm.nameField"]; XCTAssertTrue(editNameField.waitForExistence(timeout: 3)); editNameField.tap(); editNameField.typeText(" Unsaved"); app.buttons["inventory.itemForm.cancelButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.keepEditingButton"].waitForExistence(timeout: 3)); tapAlertButton(identifier: "inventory.itemForm.discardButton"); XCTAssertFalse(editNameField.waitForExistence(timeout: 3))
    }

    func testEditingLocationReviewsExistingPlaceBeforeSaving() {
        launchApp(); openItem(named: "Precision screwdriver set"); app.buttons["inventory.editItemButton"].tap(); tapVisibleButton(identifier: "inventory.itemForm.locationPicker"); app.buttons["inventory.selection.option.Kitchen"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.keepPlaceButton"].waitForExistence(timeout: 3)); tapAlertButton(identifier: "inventory.itemForm.keepPlaceButton"); assertSelectedPlace(named: "Small tool box")
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker"); app.buttons["inventory.selection.option.Office"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.clearPlaceButton"].waitForExistence(timeout: 3)); tapAlertButton(identifier: "inventory.itemForm.clearPlaceButton"); assertPlacePickerDoesNotShow("Small tool box"); app.buttons["inventory.itemForm.saveButton"].tap(); XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
    }

    func testPlacePickerCanClearASelectedPlace() {
        launchApp()
        openItem(named: "Precision screwdriver set")
        app.buttons["inventory.editItemButton"].tap()
        assertSelectedPlace(named: "Small tool box")
        clearSelectedPlace()
        assertPlacePickerDoesNotShow("Small tool box")
    }

    func testCreatingLocationAndCategoryFromItemFormSelectsPersistedValues() {
        launchApp(); app.buttons["inventory.addItemButton"].tap(); let location = "Laundry room (uniqueTestSuffix())"; tapVisibleButton(identifier: "inventory.itemForm.locationPicker"); app.buttons["inventory.selection.createButton"].tap(); let locationField = app.textFields["inventory.selection.newValueField"]; XCTAssertTrue(locationField.waitForExistence(timeout: 3)); locationField.tap(); locationField.typeText(location); app.buttons["inventory.selection.confirmCreateButton"].tap(); XCTAssertTrue(app.buttons["inventory.selection.option.\(location)"].waitForExistence(timeout: 3)); tapBackButton(); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains(location))
        let category = "Cleaning (uniqueTestSuffix())"; app.buttons["inventory.itemForm.categoryPicker"].tap(); app.buttons["inventory.selection.createButton"].tap(); let categoryField = app.textFields["inventory.selection.newValueField"]; XCTAssertTrue(categoryField.waitForExistence(timeout: 3)); categoryField.tap(); categoryField.typeText(category); app.buttons["inventory.selection.confirmCreateButton"].tap(); XCTAssertTrue(app.buttons["inventory.selection.option.\(category)"].waitForExistence(timeout: 3)); tapBackButton(); XCTAssertTrue(app.buttons["inventory.itemForm.categoryPicker"].label.contains(category)); app.buttons["inventory.itemForm.cancelButton"].tap()
    }

    func testAddItemFormTextFieldsFocusFromExpandedRows() {
        launchApp(); app.buttons["inventory.addItemButton"].tap(); assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.itemForm.nameField"], textParts: ["NameTop", "NameMid", "NameLow"]); tapVisibleButton(identifier: "inventory.itemForm.locationPicker"); app.buttons["inventory.selection.option.Office"].tap(); createPlace(named: "Focus place \(uniqueTestSuffix())"); XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].waitForExistence(timeout: 3)); app.swipeUp(); assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.itemForm.tagsField"], textParts: ["TagTop", "TagMid", "TagLow"]); app.buttons["inventory.itemForm.cancelButton"].tap()
        app.buttons["inventory.addItemButton"].tap(); app.swipeDown(); app.buttons["inventory.itemForm.locationPicker"].tap(); app.buttons["inventory.selection.createButton"].tap(); assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.selection.newValueField"], textParts: ["LocationTop", "LocationMid", "LocationLow"]); app.buttons["inventory.selection.cancelCreateButton"].tap(); tapBackButton(); app.buttons["inventory.itemForm.categoryPicker"].tap(); app.buttons["inventory.selection.createButton"].tap(); assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.selection.newValueField"], textParts: ["CategoryTop", "CategoryMid", "CategoryLow"]); app.buttons["inventory.selection.cancelCreateButton"].tap(); tapBackButton(); app.buttons["inventory.itemForm.cancelButton"].tap()
    }

    func testNameValidationAppearsOnlyAfterNameFieldLosesFocus() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()

        let nameField = app.textFields["inventory.itemForm.nameField"]
        let locationPicker = app.buttons["inventory.itemForm.locationPicker"]
        let validation = app.staticTexts["inventory.itemForm.nameValidation"]
        let saveButton = app.buttons["inventory.itemForm.saveButton"]

        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        XCTAssertTrue(locationPicker.waitForExistence(timeout: 3))
        XCTAssertFalse(validation.exists)
        XCTAssertFalse(saveButton.isEnabled)

        nameField.tap()
        XCTAssertFalse(validation.exists)

        locationPicker.tap()
        tapBackButton()
        XCTAssertTrue(validation.waitForExistence(timeout: 3))

        nameField.tap()
        nameField.typeText("Name \(uniqueTestSuffix())")
        XCTAssertTrue(validation.waitForNonExistence(timeout: 3))
        XCTAssertTrue(saveButton.isEnabled)
    }

    func testEditingExistingItem() {
        launchApp(); openItem(named: "Precision screwdriver set"); app.buttons["inventory.editItemButton"].tap(); let nameField = app.textFields["inventory.itemForm.nameField"]; XCTAssertTrue(nameField.waitForExistence(timeout: 3)); nameField.tap(); nameField.typeText(" Mini"); app.buttons["inventory.itemForm.saveButton"].tap(); let editedName = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Mini")).firstMatch; XCTAssertTrue(editedName.waitForExistence(timeout: 3))
    }

    func testDeletingItemWithConfirmation() {
        launchApp(); openItem(named: "Old router"); tapVisibleButton(identifier: "inventory.deleteItemButton"); let deleteButton = app.buttons["inventory.confirmDeleteButton"].firstMatch; XCTAssertTrue(deleteButton.waitForExistence(timeout: 3)); deleteButton.tap(); XCTAssertTrue(row(named: "Old router").waitForNonExistence(timeout: 3))
    }
}
