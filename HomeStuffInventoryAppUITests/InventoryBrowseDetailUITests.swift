import XCTest

@MainActor
final class InventoryBrowseDetailUITests: InventoryUITestCase {
    func testCompactInventoryRowPreservesRetrievalOrderAndTapTarget() {
        launchApp()

        let row = app.buttons["inventory.itemRow.USB-C to HDMI adapter"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertEqual(
            row.label,
            "USB-C to HDMI adapter, Office, Desk drawer, Cables & Adapters, Quantity 1"
        )
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
    }

    func testPrimaryEditAndNotesSaveKeepDestructiveAndContextControlsAsNegativeControls() {
        launchStartupApp(
            arguments: ["--use-sample-inventory-data", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "en"
        )
        app.tabBars.buttons["Inventory"].tap()
        openItem(named: "USB-C to HDMI adapter")
        XCTAssertTrue(app.buttons["inventory.editItemButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.deleteItemButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Inventory"].exists)
        add(attachment(named: "primary-action-edit-destructive-tab-negative-controls-en-dark-high-contrast-reduce-transparency-accessibility"))

        let notesCard = app.buttons["inventory.detail.notesCard"]
        scrollToElement(notesCard)
        notesCard.tap()
        let editor = app.textViews["inventory.notesEditor.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.notesEditor.saveButton"].exists)
        add(attachment(named: "primary-action-notes-save-en-dark-high-contrast-reduce-transparency-accessibility"))
    }

    func testPlaceFilterNarrowsInventoryAndCanBeCleared() {
        launchApp()
        XCTAssertTrue(element(identifier: "inventory.list").waitForExistence(timeout: 3))
        let filterMenu = app.buttons["inventory.filter.menu"]
        XCTAssertTrue(filterMenu.waitForExistence(timeout: 3))
        filterMenu.tap()
        let deskDrawer = app.buttons["Desk drawer"]
        XCTAssertTrue(waitForHittableElement(deskDrawer, in: nil))
        deskDrawer.tap()
        XCTAssertTrue(waitForVisibleRow(named: "USB-C to HDMI adapter"))
        XCTAssertFalse(row(named: "Cable ties").exists)
        let clearButton = app.buttons["inventory.filterContext.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3))
        XCTAssertEqual(clearButton.label, "Clear Filters")
        clearButton.tap()
        XCTAssertTrue(waitForVisibleRow(named: "Cable ties"))
    }

    func testSearchingByItemNameLocationAndPlace() { launchApp(); assertSearch(query: "router", shows: "Old router", hides: "Bike pump"); assertSearch(query: "Living room", shows: "Ethernet cable 5m", hides: "Precision screwdriver set"); assertSearch(query: "Desk drawer", shows: "USB-C to HDMI adapter", hides: "Bike pump") }
    func testInventorySearchAndEmptyStateSurfaces() {
        launchApp()
        openSearch()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("2032\n")
        XCTAssertTrue(waitForVisibleRow(named: "CR2032 batteries"))

        let clearButton = app.buttons["inventory.filterContext.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3))
        XCTAssertEqual(clearButton.label, "Clear Search")
        XCTAssertGreaterThanOrEqual(clearButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(clearButton.frame.height, 44)
        clearButton.tap()
        XCTAssertFalse(clearButton.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("no matching household item\n")
        XCTAssertTrue(app.staticTexts["No Matching Items"].waitForExistence(timeout: 3))
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3))
        XCTAssertEqual(clearButton.label, "Clear Search")
        clearButton.tap()
        XCTAssertTrue(waitForVisibleRow(named: "USB-C to HDMI adapter"))
    }
    func testLocationAndPlaceDetailContextualAddAndHeroQA() {
        launchApp(); openItem(named: "USB-C to HDMI adapter"); tapBackButton(); openPlaceDetail(location: "Office", place: "Desk drawer"); XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3)); XCTAssertTrue(app.tabBars.buttons["Search inventory"].exists); let placeHero = element(identifier: "locations.placeDetailHero"); XCTAssertTrue(placeHero.waitForExistence(timeout: 3)); XCTAssertTrue(placeHero.label.contains("Desk drawer")); XCTAssertTrue(placeHero.label.contains("Location: Office")); XCTAssertTrue(placeHero.label.contains("1 item")); let parentLocation = element(identifier: "locations.placeDetailHero.parentLocation"); XCTAssertTrue(parentLocation.waitForExistence(timeout: 3)); XCTAssertTrue(parentLocation.label.contains("Office")); XCTAssertFalse(element(identifier: "locations.placeRecentItems").exists); XCTAssertFalse(app.staticTexts["All items"].exists); XCTAssertFalse(app.buttons["All items"].exists); app.buttons["locations.placeDetail.addItemButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office")); assertSelectedPlace(named: "Desk drawer"); app.buttons["inventory.itemForm.cancelButton"].tap(); tapBackButton(); app.buttons["locations.locationDetail.addItemButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office")); app.buttons["inventory.itemForm.cancelButton"].tap()
    }
    func testDeletingLastPlaceItemKeepsEmptyPlaceContext() {
        launchApp(); openPlaceDetail(location: "Balcony cabinet", place: "Red organizer"); let itemRow = app.buttons["locations.placeDetail.itemRow.Drill bits"]; XCTAssertTrue(itemRow.waitForExistence(timeout: 3)); itemRow.tap(); tapVisibleButton(identifier: "inventory.deleteItemButton"); let confirmDeleteButton = app.buttons["inventory.confirmDeleteButton"].firstMatch; XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 3)); confirmDeleteButton.tap(); let placeHero = element(identifier: "locations.placeDetailHero"); XCTAssertTrue(placeHero.waitForExistence(timeout: 3)); XCTAssertTrue(placeHero.label.contains("Red organizer")); XCTAssertTrue(placeHero.label.contains("Location: Balcony cabinet")); XCTAssertTrue(placeHero.label.contains("0 items")); XCTAssertTrue(app.staticTexts["No Items in This Storage Place"].waitForExistence(timeout: 3))
    }
    func testOpeningItemDetailKeepsHeroAndRevealsNavigationTitleAfterScroll() {
        launchApp(); openItemFromSearch(named: "USB-C to HDMI adapter"); let detail = element(identifier: "inventory.itemDetail"); XCTAssertTrue(detail.waitForExistence(timeout: 3)); let hero = element(identifier: "inventory.itemDetail.hero"); XCTAssertTrue(hero.waitForExistence(timeout: 3)); XCTAssertTrue(hero.label.contains("USB-C to HDMI adapter")); XCTAssertTrue(hero.label.contains("Category: Cables & Adapters")); XCTAssertFalse(hero.label.contains("Last updated")); XCTAssertFalse(hero.label.contains("Office")); XCTAssertFalse(hero.label.contains("Desk drawer")); let title = element(identifier: "inventory.itemDetail.title"); XCTAssertTrue(title.waitForExistence(timeout: 3)); XCTAssertEqual(title.label, "USB-C to HDMI adapter"); let storage = element(identifier: "inventory.itemDetail.storage"); XCTAssertTrue(storage.waitForExistence(timeout: 3)); let location = element(identifier: "inventory.itemDetail.location"); XCTAssertTrue(location.waitForExistence(timeout: 3)); XCTAssertTrue(location.label.contains("Office")); let place = element(identifier: "inventory.itemDetail.place"); XCTAssertTrue(place.waitForExistence(timeout: 3)); XCTAssertTrue(place.label.contains("Desk drawer")); let quantity = element(identifier: "inventory.itemDetail.quantity"); XCTAssertTrue(quantity.waitForExistence(timeout: 3)); XCTAssertTrue(quantity.label.contains("Quantity")); let condition = element(identifier: "inventory.itemDetail.condition"); XCTAssertTrue(condition.waitForExistence(timeout: 3)); XCTAssertTrue(condition.label.contains("Condition")); XCTAssertTrue(condition.label.contains("Good")); XCTAssertNotEqual(detail.value as? String, "USB-C to HDMI adapter"); XCTAssertTrue(hero.isHittable); XCTAssertTrue(waitForDetailNavigationTitleValue("USB-C to HDMI adapter"))
    }

    func testItemDetailBoundsAndExpandsManyTagsAfterNotes() {
        launchApp()
        openItem(named: "USB-C to HDMI adapter")

        let notes = app.buttons["inventory.detail.notesCard"]
        let tags = element(identifier: "inventory.itemDetail.tags")
        let showMore = app.buttons["inventory.itemDetail.tags.showMore"]
        scrollToElement(showMore)

        XCTAssertTrue(notes.exists)
        XCTAssertTrue(tags.exists)
        XCTAssertLessThan(notes.frame.minY, tags.frame.minY)
        XCTAssertTrue(element(identifier: "inventory.itemDetail.tag.0").exists)
        XCTAssertTrue(element(identifier: "inventory.itemDetail.tag.1").exists)
        XCTAssertTrue(element(identifier: "inventory.itemDetail.tag.2").exists)
        XCTAssertFalse(element(identifier: "inventory.itemDetail.tag.3").exists)
        XCTAssertEqual(showMore.label, "Show 9 more tags")
        XCTAssertGreaterThanOrEqual(showMore.frame.width, 44)
        XCTAssertGreaterThanOrEqual(showMore.frame.height, 44)

        showMore.tap()

        let fourthTag = element(identifier: "inventory.itemDetail.tag.3")
        XCTAssertTrue(fourthTag.waitForExistence(timeout: 3))
        let collapse = app.buttons["inventory.itemDetail.tags.collapse"]
        scrollToElement(collapse)
        XCTAssertEqual(collapse.label, "Show fewer tags")
        XCTAssertGreaterThanOrEqual(collapse.frame.height, 44)
        collapse.tap()
        XCTAssertFalse(fourthTag.waitForExistence(timeout: 1))
        XCTAssertTrue(showMore.waitForExistence(timeout: 3))
    }

    func testItemDetailPlacesLabeledDatesAfterNotesAndTags() {
        launchApp()
        openItem(named: "USB-C to HDMI adapter")

        let notes = app.buttons["inventory.detail.notesCard"]
        let tags = element(identifier: "inventory.itemDetail.tags")
        let dates = element(identifier: "inventory.itemDetail.dates")
        scrollToElement(dates)

        XCTAssertTrue(notes.exists)
        XCTAssertTrue(tags.exists)
        XCTAssertLessThan(notes.frame.minY, tags.frame.minY)
        XCTAssertLessThan(tags.frame.minY, dates.frame.minY)
        XCTAssertTrue(element(identifier: "inventory.itemDetail.created").label.contains("Created"))
        XCTAssertTrue(element(identifier: "inventory.itemDetail.updated").label.contains("Updated"))
        XCTAssertLessThan(dates.frame.minY, app.buttons["inventory.deleteItemButton"].frame.minY)
    }
    func testItemDetailStorageFitsUkrainianAccessibilityWithReducedTransparency() {
        launchStartupApp(
            arguments: ["--use-sample-inventory-data", "--qa-reduce-transparency"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "uk"
        )
        XCTAssertTrue(element(identifier: "qa.accessibility.reduceTransparency").waitForExistence(timeout: 3))
        app.tabBars.buttons["Шукати в інвентарі"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("USB-C to HDMI adapter")
        openItem(named: "USB-C to HDMI adapter")

        let hero = element(identifier: "inventory.itemDetail.hero")
        let storage = element(identifier: "inventory.itemDetail.storage")
        let location = element(identifier: "inventory.itemDetail.location")
        let place = element(identifier: "inventory.itemDetail.place")

        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(storage.waitForExistence(timeout: 3))
        XCTAssertTrue(location.exists)
        XCTAssertTrue(place.exists)
        XCTAssertLessThan(hero.frame.maxY, storage.frame.minY)
        XCTAssertLessThan(location.frame.maxY, place.frame.minY)
        XCTAssertGreaterThanOrEqual(location.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(location.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(place.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(place.frame.maxX, app.frame.maxX)
    }
    func testExistingNotesEditorLifecycleSupportsDismissDiscardAndSave() {
        launchApp(); openItem(named: "USB-C to HDMI adapter"); let notesCard = app.buttons["inventory.detail.notesCard"]; scrollToElement(notesCard); XCTAssertTrue(notesCard.isHittable); XCTAssertFalse(app.buttons["inventory.detail.editNotesButton"].exists)
        notesCard.tap(); let notesEditor = app.textViews["inventory.notesEditor.editor"]; XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); dismissNotesEditorInteractively(); XCTAssertFalse(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
        notesCard.tap(); XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); XCTAssertFalse(element(identifier: "inventory.itemForm").exists); notesEditor.tap(); notesEditor.typeText(" Updated"); let keyboard = app.keyboards.firstMatch; XCTAssertTrue(keyboard.waitForExistence(timeout: 3)); XCTAssertTrue(waitForElementAboveKeyboard(notesEditor, keyboard: keyboard, timeout: 3), "Expected detail notes editor to stay above keyboard; editor frame: \(notesEditor.frame), keyboard frame: \(keyboard.frame)"); dismissNotesEditorInteractively(); XCTAssertTrue(notesEditor.exists, "Dirty Notes editor should block interactive dismissal"); app.buttons["inventory.notesEditor.cancelButton"].tap(); XCTAssertTrue(app.buttons["inventory.notesEditor.confirmDiscardButton"].waitForExistence(timeout: 3)); tapAlertButton(identifier: "inventory.notesEditor.confirmDiscardButton"); XCTAssertFalse(notesEditor.waitForExistence(timeout: 1))
        notesCard.tap(); XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); notesEditor.tap(); notesEditor.typeText(" Saved"); app.buttons["inventory.notesEditor.saveButton"].tap(); XCTAssertFalse(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved")).firstMatch.waitForExistence(timeout: 3))
    }
    func testEmptyNotesCardOpensNotesEditor() { launchApp(); let itemName = "Empty Notes \(uniqueTestSuffix())"; app.buttons["inventory.addItemButton"].tap(); let nameField = app.textFields["inventory.itemForm.nameField"]; XCTAssertTrue(nameField.waitForExistence(timeout: 3)); nameField.tap(); nameField.typeText(itemName); app.buttons["inventory.itemForm.saveButton"].tap(); resetToInventoryList(); openSearch(); let searchField = app.searchFields.firstMatch; XCTAssertTrue(searchField.waitForExistence(timeout: 3)); searchField.tap(); searchField.typeText(itemName); openItem(named: itemName); let detail = element(identifier: "inventory.itemDetail"); XCTAssertTrue(detail.waitForExistence(timeout: 3)); let notesCard = app.buttons["inventory.detail.notesCard"]; scrollToElement(notesCard); XCTAssertEqual(notesCard.label, "Notes: No notes"); XCTAssertTrue(notesCard.isHittable); notesCard.tap(); let notesEditor = app.textViews["inventory.notesEditor.editor"]; XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); XCTAssertFalse(element(identifier: "inventory.itemForm").exists); let savedNotes = "Saved empty Notes \(uniqueTestSuffix())"; notesEditor.tap(); notesEditor.typeText(savedNotes); app.buttons["inventory.notesEditor.saveButton"].tap(); XCTAssertFalse(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(detail.exists); XCTAssertTrue(notesCard.waitForExistence(timeout: 3)); XCTAssertTrue(notesCard.isHittable); XCTAssertTrue(notesCard.label.contains(savedNotes)) }
}
