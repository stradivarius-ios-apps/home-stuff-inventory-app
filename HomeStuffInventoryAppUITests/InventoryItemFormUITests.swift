import XCTest

@MainActor
final class InventoryItemFormUITests: InventoryUITestCase {
    func testTagsGuidanceRemainsVisibleAcrossLengthValidationAndCorrection() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()
        let name = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("USB-C cable")
        let tags = app.textFields["inventory.itemForm.tagsField"]
        let validation = app.staticTexts["inventory.itemForm.tagsValidation"]
        let save = app.buttons["inventory.itemForm.saveButton"]
        revealDraftField(tags)
        assertTagsGuidance()
        XCTAssertEqual(tags.placeholderValue, "Adapters, tools, spare")
        XCTAssertFalse(validation.exists)
        XCTAssertTrue(save.isEnabled)

        tags.tap()
        XCTAssertTrue(waitForKeyboardFocus(tags, timeout: 3))
        tags.typeText("1234567890123456")
        assertTagsGuidance()
        XCTAssertFalse(validation.exists)
        XCTAssertTrue(save.isEnabled)
        tags.typeText("7")
        XCTAssertTrue(validation.waitForExistence(timeout: 3))
        revealDraftField(validation)
        XCTAssertTrue(validation.label.contains("12345678901234567"))
        XCTAssertFalse(save.isEnabled)
        assertTagsGuidance()

        tags.typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertTrue(validation.waitForNonExistence(timeout: 3))
        XCTAssertTrue(save.isEnabled)
        XCTAssertTrue(waitForKeyboardFocus(tags, timeout: 3))
        XCTAssertEqual(tags.value as? String, "1234567890123456")
        assertTagsGuidance()
    }

    func testEditingTagsKeepsStoredValueAfterCancel() {
        launchApp()
        openItem(named: "Precision screwdriver set")
        app.buttons["inventory.editItemButton"].tap()
        let tags = app.textFields["inventory.itemForm.tagsField"]
        revealDraftField(tags)
        assertTagsGuidance()
        let storedTags = tags.value as? String
        XCTAssertFalse(storedTags?.isEmpty ?? true)
        tags.tap()
        tags.typeText(", temporary")
        app.buttons["inventory.itemForm.cancelButton"].tap()
        tapAlertButton(identifier: "inventory.itemForm.discardButton")
        XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
        app.buttons["inventory.editItemButton"].tap()
        revealDraftField(tags)
        XCTAssertEqual(tags.value as? String, storedTags)
        assertTagsGuidance()
        app.buttons["inventory.itemForm.cancelButton"].tap()
        XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["inventory.itemForm.discardButton"].exists)
    }

    private func assertTagsGuidance(file: StaticString = #filePath, line: UInt = #line) {
        let tags = app.textFields["inventory.itemForm.tagsField"]
        XCTAssertEqual(app.textFields.matching(identifier: "inventory.itemForm.tagsField").count, 1, file: file, line: line)
        XCTAssertEqual(tags.label, "Tags", file: file, line: line)
        XCTAssertTrue(staticText(labeled: "Tags").exists, file: file, line: line)
        XCTAssertTrue(staticText(labeled: "Separate tags with commas. Maximum 16 characters per tag.").exists, file: file, line: line)
    }

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
        let itemName = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(itemName.waitForExistence(timeout: 3))
        itemName.tap(); itemName.typeText("Кабель USB-C")
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
        assertReturnedToUnsavedForm(name: "Кабель USB-C")
        XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].label.contains("Нова шухляда"))
        XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office"))
        tapVisibleButton(identifier: "inventory.itemForm.containerPicker")
        app.buttons["inventory.placeSelection.createButton"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        app.navigationBars.buttons["Скасувати"].tap()
        XCTAssertTrue(app.buttons["inventory.placeSelection.createButton"].waitForExistence(timeout: 3))
        tapBackButton()
        assertReturnedToUnsavedForm(name: "Кабель USB-C")
        assertSelectedPlace(named: "Нова шухляда")
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
        launchApp()
        app.buttons["inventory.addItemButton"].tap()
        let nameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap(); nameField.typeText("USB-C cable")
        let quantity = app.steppers.firstMatch
        revealDraftField(quantity)
        quantity.buttons["Increment"].tap()
        XCTAssertEqual(quantity.value as? String, "2")
        let tags = app.textFields["inventory.itemForm.tagsField"]
        revealDraftField(tags); tags.tap(); tags.typeText("usb, cable")
        let notes = app.textViews["inventory.itemForm.notesEditor"]
        revealDraftField(notes); notes.tap(); notes.typeText("Original draft note")

        for (kind, value) in [("location", "Workshop"), ("category", "Cables and adapters")] {
            openStandardizedCreation(kind: kind)
            submitStandardizedValue(value)
            assertReturnedToUnsavedForm(name: "USB-C cable")
            let picker = app.buttons["inventory.itemForm.\(kind)Picker"]
            XCTAssertTrue(picker.label.contains(value))
            XCTAssertFalse(waitForKeyboardFocus(nameField, timeout: 1))
            revealDraftField(quantity)
            XCTAssertEqual(quantity.value as? String, "2")
            XCTAssertEqual(tags.value as? String, "usb, cable")
            XCTAssertEqual(notes.value as? String, "Original draft note")

            // A later canceled creation must not reuse the previous success.
            openStandardizedCreation(kind: kind)
            app.buttons["inventory.selection.cancelCreateButton"].tap()
            XCTAssertTrue(app.buttons["inventory.selection.createButton"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["inventory.itemForm.saveButton"].isHittable)
            tapBackButton()
            assertReturnedToUnsavedForm(name: "USB-C cable")
            XCTAssertTrue(picker.label.contains(value))
        }
        app.buttons["inventory.itemForm.cancelButton"].tap()
        XCTAssertTrue(app.buttons["inventory.itemForm.discardButton"].waitForExistence(timeout: 3))
        tapAlertButton(identifier: "inventory.itemForm.discardButton")
        XCTAssertFalse(nameField.waitForExistence(timeout: 1))
        XCTAssertFalse(row(named: "USB-C cable").exists)
    }

    func testCanceledAndSwipedCreationsPreserveSelectorQueryAndSelection() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()
        let name = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("Unsaved cable")
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.option.Office"].tap()

        for kind in ["location", "category", "container"] {
            let picker = app.buttons["inventory.itemForm.\(kind)Picker"]
            let previousSelection = picker.label
            tapVisibleButton(identifier: picker.identifier)
            let isPlace = kind == "container"
            let createID = isPlace ? "inventory.placeSelection.createButton" : "inventory.selection.createButton"
            let fieldID = isPlace ? "inventory.placeSelection.nameField" : "inventory.selection.newValueField"
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 3))
            search.tap(); search.typeText("zzzz")
            let create = app.buttons[createID]
            scrollToElement(create); create.tap()
            XCTAssertTrue(app.textFields[fieldID].waitForExistence(timeout: 3))
            if isPlace { app.navigationBars.buttons["Cancel"].tap() }
            else { app.buttons["inventory.selection.cancelCreateButton"].tap() }
            XCTAssertTrue(create.waitForExistence(timeout: 3))
            XCTAssertEqual(search.value as? String, "zzzz")
            XCTAssertFalse(app.buttons["inventory.itemForm.saveButton"].isHittable)

            create.tap()
            XCTAssertTrue(app.textFields[fieldID].waitForExistence(timeout: 3))
            let cancelID = isPlace ? "Cancel" : "inventory.selection.cancelCreateButton"
            let bar = app.navigationBars.containing(.button, identifier: cancelID).firstMatch
            XCTAssertTrue(bar.waitForExistence(timeout: 3))
            bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            XCTAssertTrue(app.textFields[fieldID].waitForNonExistence(timeout: 3))
            XCTAssertTrue(create.waitForExistence(timeout: 3))
            XCTAssertEqual(search.value as? String, "zzzz")
            // End search after verifying its query, so the native Back action is visible.
            let closeSearch = app.buttons["close"].firstMatch
            XCTAssertTrue(closeSearch.waitForExistence(timeout: 3))
            closeSearch.tap()
            XCTAssertTrue(app.navigationBars.buttons["BackButton"].firstMatch.waitForExistence(timeout: 3))
            tapBackButton()
            assertReturnedToUnsavedForm(name: "Unsaved cable")
            XCTAssertEqual(picker.label, previousSelection)
        }
    }

    func testExistingAndEmptySelectionsReturnToSameItemForm() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()
        let name = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("Unsaved cable")
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.option.Office"].tap()
        assertReturnedToUnsavedForm(name: "Unsaved cable")
        selectPlace(named: "Desk drawer")
        assertReturnedToUnsavedForm(name: "Unsaved cable")
        assertSelectedPlace(named: "Desk drawer")
        clearSelectedPlace()
        assertReturnedToUnsavedForm(name: "Unsaved cable")
        assertPlacePickerDoesNotShow("Desk drawer")
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.empty"].tap()
        assertReturnedToUnsavedForm(name: "Unsaved cable")
        XCTAssertFalse(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office"))

        // Resolving an existing canonical name completes creation in the same way.
        openStandardizedCreation(kind: "location")
        submitStandardizedValue(" office ")
        assertReturnedToUnsavedForm(name: "Unsaved cable")
        XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office"))
    }

    func testCreatedLocationDefersPlaceReviewUntilFormReturns() {
        for keepPlace in [true, false] {
            launchApp()
            openItem(named: "Precision screwdriver set")
            app.buttons["inventory.editItemButton"].tap()
            assertSelectedPlace(named: "Small tool box")
            openStandardizedCreation(kind: "location")
            XCTAssertFalse(app.buttons["inventory.itemForm.keepPlaceButton"].exists)
            submitStandardizedValue("Workshop")
            let reviewButton = app.buttons[keepPlace ? "inventory.itemForm.keepPlaceButton" : "inventory.itemForm.clearPlaceButton"].firstMatch
            XCTAssertTrue(reviewButton.waitForExistence(timeout: 3))
            XCTAssertTrue(app.textFields["inventory.selection.newValueField"].waitForNonExistence(timeout: 3))
            XCTAssertFalse(app.buttons["inventory.selection.createButton"].exists)
            XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].exists)
            reviewButton.tap()
            assertReturnedToUnsavedForm(name: "Precision screwdriver set")
            if keepPlace { assertSelectedPlace(named: "Small tool box") }
            else { assertPlacePickerDoesNotShow("Small tool box") }
            XCTAssertTrue(reviewButton.waitForNonExistence(timeout: 1))

            tapVisibleButton(identifier: "inventory.itemForm.categoryPicker")
            tapBackButton()
            XCTAssertFalse(reviewButton.waitForExistence(timeout: 1))
            app.buttons["inventory.itemForm.saveButton"].tap()
            XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
            app.buttons["inventory.editItemButton"].tap()
            XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Workshop"))
            if keepPlace { assertSelectedPlace(named: "Small tool box") }
            else { assertPlacePickerDoesNotShow("Small tool box") }
            app.terminate()
        }
    }

    private func revealDraftField(_ field: XCUIElement) {
        for _ in 0..<8 {
            let keyboard = app.keyboards.firstMatch
            if field.exists, field.isHittable,
               !keyboard.exists || field.frame.maxY <= keyboard.frame.minY { return }
            scrollVisibleForm(up: true)
        }
        XCTFail("Could not reveal draft field \(field.identifier) above the keyboard")
    }

    private func scrollVisibleForm(up: Bool) {
        let form = element(identifier: "inventory.itemForm")
        XCTAssertTrue(form.waitForExistence(timeout: 3))
        let keyboard = app.keyboards.firstMatch
        let bottom = keyboard.exists ? min(form.frame.maxY, keyboard.frame.minY) : form.frame.maxY
        print("Visible Form gesture: form=\(form.frame), keyboard=\(keyboard.exists ? keyboard.frame : .zero)")
        let navigationBottom = app.navigationBars.allElementsBoundByIndex.map { $0.frame.maxY }.max() ?? form.frame.minY
        let visibleTop = max(form.frame.minY, navigationBottom) + 24
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let topPoint = origin.withOffset(CGVector(dx: form.frame.midX, dy: visibleTop))
        let bottomPoint = origin.withOffset(CGVector(dx: form.frame.midX, dy: visibleTop + (bottom - visibleTop) * 0.6))
        (up ? bottomPoint : topPoint).press(forDuration: 0.1, thenDragTo: up ? topPoint : bottomPoint)
    }

    private func openStandardizedCreation(kind: String) {
        let picker = app.buttons["inventory.itemForm.\(kind)Picker"]
        let form = element(identifier: "inventory.itemForm")
        let navigationBar = app.navigationBars.containing(.button, identifier: "inventory.itemForm.cancelButton").firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 3))
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 3))
        func visibleContentBounds() -> CGRect {
            let frame = form.frame
            let keyboard = app.keyboards.firstMatch
            let top = max(frame.minY, navigationBar.frame.maxY)
            let bottom = keyboard.exists ? min(frame.maxY, keyboard.frame.minY) : frame.maxY
            return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
        }
        for _ in 0..<8 {
            if !picker.exists {
                // These picker rows precede the lower draft fields in the lazy Form.
                scrollVisibleForm(up: false)
                continue
            }
            let bounds = visibleContentBounds()
            if bounds.contains(picker.frame) { break }
            scrollVisibleForm(up: picker.frame.maxY > bounds.maxY)
        }
        XCTAssertTrue(picker.exists)
        let bounds = visibleContentBounds()
        print("Picker pre-tap: id=\(picker.identifier), picker=\(picker.frame), visibleContent=\(bounds), navigationBar=\(navigationBar.frame)")
        XCTAssertTrue(bounds.contains(picker.frame), "Picker must be fully within visible form content before tapping")
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        let selector = element(identifier: "inventory.selection")
        XCTAssertTrue(selector.waitForExistence(timeout: 3))
        let create = app.buttons["inventory.selection.createButton"]
        scrollToElement(create, in: selector)
        create.tap()
        XCTAssertTrue(app.textFields["inventory.selection.newValueField"].waitForExistence(timeout: 3))
    }

    private func submitStandardizedValue(_ value: String) {
        let field = app.textFields["inventory.selection.newValueField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap(); field.typeText(value)
        app.buttons["inventory.selection.confirmCreateButton"].tap()
    }

    private func assertReturnedToUnsavedForm(name: String, file: StaticString = #filePath, line: UInt = #line) {
        let nameField = app.textFields["inventory.itemForm.nameField"]
        scrollVisibleForm(up: false)
        scrollVisibleForm(up: false)
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertEqual(nameField.value as? String, name, file: file, line: line)
        XCTAssertTrue(app.buttons["inventory.itemForm.saveButton"].isHittable, file: file, line: line)
        XCTAssertFalse(app.textFields["inventory.selection.newValueField"].exists, file: file, line: line)
        XCTAssertFalse(app.textFields["inventory.placeSelection.nameField"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["inventory.selection.createButton"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["inventory.placeSelection.createButton"].exists, file: file, line: line)
    }

    func testAddItemFormTextFieldsFocusFromExpandedRows() {
        launchApp()
        app.buttons["inventory.addItemButton"].tap()
        assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.itemForm.nameField"], textParts: ["NameTop", "NameMid", "NameLow"])
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.option.Office"].tap()
        createPlace(named: "Focus place \(uniqueTestSuffix())")
        XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].waitForExistence(timeout: 3))
        let tags = app.textFields["inventory.itemForm.tagsField"]
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists { returnKey.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        revealDraftField(tags)
        assertFieldAcceptsTextAfterRowTaps(tags, textParts: ["TagTop", "TagMid", "TagLow"])
        app.buttons["inventory.itemForm.cancelButton"].tap()
        tapAlertButton(identifier: "inventory.itemForm.discardButton")

        app.buttons["inventory.addItemButton"].tap()
        tapVisibleButton(identifier: "inventory.itemForm.locationPicker")
        app.buttons["inventory.selection.createButton"].tap()
        assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.selection.newValueField"], textParts: ["LocationTop", "LocationMid", "LocationLow"])
        app.buttons["inventory.selection.cancelCreateButton"].tap()
        tapBackButton()
        app.buttons["inventory.itemForm.categoryPicker"].tap()
        app.buttons["inventory.selection.createButton"].tap()
        assertFieldAcceptsTextAfterRowTaps(app.textFields["inventory.selection.newValueField"], textParts: ["CategoryTop", "CategoryMid", "CategoryLow"])
        app.buttons["inventory.selection.cancelCreateButton"].tap()
        tapBackButton()
        app.buttons["inventory.itemForm.cancelButton"].tap()
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
