import XCTest

@MainActor
class InventoryUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launchApp(contentSizeCategory: String? = nil) {
        launchStartupApp(arguments: ["--use-sample-inventory-data"], contentSizeCategory: contentSizeCategory)
        resetToInventoryList()
    }

    func launchStartupApp(arguments: [String] = [], contentSizeCategory: String? = nil, locale: String = "en") {
        app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "uk" ? "uk_UA" : "en_US"]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
    }

    func attachment(named name: String) -> XCTAttachment {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess
        return attachment
    }

    func fillItemForm(name: String, location: String, container: String, tags: String, notes: String) {
        XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].waitForExistence(timeout: 3))
        app.textFields["inventory.itemForm.nameField"].tap()
        app.textFields["inventory.itemForm.nameField"].typeText(name)
        app.buttons["inventory.itemForm.locationPicker"].tap()
        app.buttons["inventory.selection.createButton"].tap()
        let locationField = app.textFields["inventory.selection.newValueField"]
        XCTAssertTrue(locationField.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["inventory.selection.confirmCreateButton"].isEnabled)
        locationField.tap()
        locationField.typeText(location)
        app.buttons["inventory.selection.confirmCreateButton"].tap()
        XCTAssertTrue(app.buttons["inventory.selection.option.\(location)"].waitForExistence(timeout: 3))
        tapBackButton()
        selectPlace(named: container)
        let tagsField = app.textFields["inventory.itemForm.tagsField"]
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(tagsField.waitForExistence(timeout: 3))
        for _ in 0..<4 where !waitForElementAboveKeyboard(tagsField, keyboard: keyboard, timeout: 0.5) { app.swipeUp() }
        XCTAssertTrue(waitForElementAboveKeyboard(tagsField, keyboard: keyboard, timeout: 3))
        tagsField.tap()
        XCTAssertTrue(waitForKeyboardFocus(tagsField, timeout: 3))
        tagsField.typeText(tags)
        let notesEditor = app.textViews["inventory.itemForm.notesEditor"]
        XCTAssertTrue(notesEditor.waitForExistence(timeout: 3))
        notesEditor.tap()
        notesEditor.typeText(notes)
    }

    func assertSearch(query: String, shows expectedItem: String, hides hiddenItem: String) {
        openSearch()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        let clearButton = app.buttons["inventory.filterContext.clearButton"]
        if clearButton.exists { clearButton.tap() }
        searchField.tap()
        searchField.typeText(query)
        XCTAssertTrue(waitForVisibleRow(named: expectedItem))
        XCTAssertFalse(
            row(named: hiddenItem).isHittable,
            "Expected search for \(query) to hide \(hiddenItem) from the visible Inventory results."
        )
    }

    func openSearch() {
        if app.searchFields.firstMatch.waitForExistence(timeout: 1) { return }
        let searchTab = app.tabBars.buttons["Search inventory"]
        if searchTab.waitForExistence(timeout: 2) { searchTab.tap() }
    }

    func openManagedLocations() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.lists.locationsLink"].tap()
    }

    func openPlaceDetail(location: String, place: String) {
        app.tabBars.buttons["Locations"].tap()
        let locationRow = app.buttons["locations.locationRow.\(location)"]
        scrollToElement(locationRow, in: element(identifier: "locations.list"))
        locationRow.tap()
        let placeRow = app.buttons["locations.placeRow.\(place)"]
        scrollToElement(placeRow, in: element(identifier: "locations.locationDetail"))
        placeRow.tap()
    }

    func element(identifier: String) -> XCUIElement { app.descendants(matching: .any)[identifier] }
    func staticText(labeled label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    func openItem(named name: String) { XCTAssertTrue(waitForVisibleRow(named: name)); row(named: name).tap() }
    func openItemFromSearch(named name: String) {
        openSearch()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText(name)
        openItem(named: name)
    }

    func resetToInventoryList() {
        let inventoryTab = app.tabBars.buttons
            .matching(NSPredicate(format: "label IN %@", ["Inventory", "Інвентар"]))
            .firstMatch
        if inventoryTab.waitForExistence(timeout: 1) { inventoryTab.tap() }
        var remainingBackSteps = 3
        while let backButton = hittableNavigationBackButton(), remainingBackSteps > 0 {
            backButton.tap()
            remainingBackSteps -= 1
        }
        app.swipeDown()
        app.swipeDown()
    }

    func waitForVisibleRow(named name: String) -> Bool { waitForHittableElement(row(named: name), in: element(identifier: "inventory.list")) }

    func tapVisibleButton(identifier: String) {
        let button = app.buttons[identifier].firstMatch
        if button.waitForExistence(timeout: 1) { button.tap(); return }
        for _ in 0..<8 { app.swipeUp(); if button.waitForExistence(timeout: 1) { button.tap(); return } }
        XCTFail("Could not find button with identifier \(identifier)")
    }

    func selectPlace(named name: String) {
        tapVisibleButton(identifier: "inventory.itemForm.containerPicker")
        let option = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        XCTAssertTrue(waitForHittableElement(option, in: nil), "Expected Place option named \(name)")
        option.tap()
    }

    func clearSelectedPlace() {
        tapVisibleButton(identifier: "inventory.itemForm.containerPicker")
        let emptyPlace = app.buttons["inventory.placeSelection.empty"]
        XCTAssertTrue(waitForHittableElement(emptyPlace, in: nil), "Expected the clear Place option")
        emptyPlace.tap()
    }

    func createPlace(named name: String) {
        tapVisibleButton(identifier: "inventory.itemForm.containerPicker")
        let createButton = app.buttons["inventory.placeSelection.createButton"]
        XCTAssertTrue(waitForHittableElement(createButton, in: nil), "Expected the add Place action")
        createButton.tap()
        let nameField = app.textFields["inventory.placeSelection.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)
        let saveButton = app.buttons["inventory.placeSelection.saveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
    }

    func assertSelectedPlace(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.buttons["inventory.itemForm.containerPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(picker.label.contains(name), "Expected selected Place \(name), got \(picker.label)", file: file, line: line)
    }

    func assertPlacePickerDoesNotShow(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.buttons["inventory.itemForm.containerPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertFalse(picker.label.contains(name), file: file, line: line)
    }

    func tapAlertButton(identifier: String) {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Expected alert button \(identifier)")
        button.tap()
    }

    func managedValueRow(named name: String) -> XCUIElement {
        app.descendants(matching: .any)["inventory.lists.valueRow.\(name)"]
    }

    func viewItemsButton(inManagedValueRowNamed name: String) -> XCUIElement {
        managedValueRow(named: name).buttons["inventory.lists.viewItems"]
    }

    func actionsButton(inManagedValueRowNamed name: String) -> XCUIElement {
        managedValueRow(named: name).buttons["inventory.lists.valueActions"]
    }

    func actionsButton(alignedWith viewItemsButton: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let actionsButtons = app.buttons.matching(identifier: "inventory.lists.valueActions").allElementsBoundByIndex
        let alignedButton = actionsButtons.min {
            abs($0.frame.midY - viewItemsButton.frame.midY) < abs($1.frame.midY - viewItemsButton.frame.midY)
        }
        XCTAssertNotNil(alignedButton, "Expected an actions button beside the scoped View Items button", file: file, line: line)
        return alignedButton ?? app.buttons["inventory.lists.valueActions"].firstMatch
    }

    func dismissNotesEditorInteractively() {
        let sheetNavigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(sheetNavigationBar.waitForExistence(timeout: 3), "Expected stable Notes sheet chrome")
        sheetNavigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
    }

    func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line) {
        if waitForHittableElement(element, in: scrollView, failOnTimeout: false) { return }
        XCTFail("Could not find hittable element \(element.identifier) in \(scrollView?.identifier ?? "application")", file: file, line: line)
    }

    func waitForHittableElement(_ element: XCUIElement, in scrollView: XCUIElement?, failOnTimeout: Bool = true) -> Bool {
        for _ in 0..<8 {
            if element.waitForExistence(timeout: 1), element.isHittable { return true }
            if let scrollView { guard scrollView.waitForExistence(timeout: 1) else { continue }; scrollView.swipeUp() } else { app.swipeUp() }
        }
        if failOnTimeout { XCTFail("Could not find hittable element \(element.identifier) in expected container \(scrollView?.identifier ?? "application")") }
        return false
    }

    func waitForDetailNavigationTitleValue(_ title: String) -> Bool {
        let detail = element(identifier: "inventory.itemDetail")
        guard detail.waitForExistence(timeout: 3) else { return false }
        let detailScrollView = app.scrollViews["inventory.itemDetail"]
        for _ in 0..<8 {
            if detailScrollView.exists { detailScrollView.swipeUp() } else { app.swipeUp() }
            if waitForElement(detail, value: title, timeout: 1) { return true }
        }
        return detail.value as? String == title
    }

    func waitForElement(_ element: XCUIElement, value: String, timeout: TimeInterval) -> Bool {
        XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)], timeout: timeout) == .completed
    }
    func waitForKeyboardFocus(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)], timeout: timeout) == .completed
    }
    func waitForElementAboveKeyboard(_ element: XCUIElement, keyboard: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, keyboard.exists, element.frame.maxY <= keyboard.frame.minY { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.exists && keyboard.exists && element.frame.maxY <= keyboard.frame.minY
    }
    func tapBackButton() {
        if let backButton = hittableNavigationBackButton() { backButton.tap(); return }
        let firstNavigationButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(firstNavigationButton.waitForExistence(timeout: 3))
        firstNavigationButton.tap()
    }

    private func hittableNavigationBackButton() -> XCUIElement? {
        app.navigationBars.allElementsBoundByIndex.reversed().first { navigationBar in
            let backButton = navigationBar.buttons["BackButton"]
            return backButton.exists && backButton.isHittable
        }.map { $0.buttons["BackButton"] }
    }
    func uniqueTestSuffix() -> String { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)) }
    func row(named name: String) -> XCUIElement {
        element(identifier: "inventory.list").buttons["inventory.itemRow.\(name)"]
    }
    func assertFieldAcceptsTextAfterRowTaps(_ field: XCUIElement, textParts: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 3), file: file, line: line)
        let yOffsets: [CGFloat] = [0.15, 0.5, 0.85]
        XCTAssertEqual(textParts.count, yOffsets.count, file: file, line: line)
        for (yOffset, text) in zip(yOffsets, textParts) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: yOffset)).tap(); field.typeText(text)
            XCTAssertTrue((field.value as? String ?? "").contains(text), "Expected \(field.value as? String ?? "") to contain typed text \(text)", file: file, line: line)
        }
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)], timeout: timeout) == .completed
    }
}
