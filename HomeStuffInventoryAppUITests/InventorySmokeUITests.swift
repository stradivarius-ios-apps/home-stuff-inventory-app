import XCTest

@MainActor
final class InventorySmokeUITests: InventoryUITestCase {
    func testOrdinaryDebugLaunchDoesNotInstallQAAppearanceMarker() {
        launchApp()

        XCTAssertFalse(app.descendants(matching: .any)["qa.appearance.light"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["qa.appearance.dark"].exists)
    }

    func testFreeReleaseGateLaunchCreateSearchAndReadWithoutEntitlement() {
        let itemName = "Free gate item \(uniqueTestSuffix())"
        let freeGateArguments = [
            "--use-sample-inventory-data",
            "--qa-suppress-export-share-sheet",
            "--qa-suppress-restore-importer"
        ]
        launchStartupApp(arguments: freeGateArguments)
        resetToInventoryList()

        XCTAssertTrue(app.tabBars.buttons["Inventory"].exists)
        app.buttons["inventory.addItemButton"].tap()
        let nameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(itemName)
        app.buttons["inventory.itemForm.saveButton"].tap()

        resetToInventoryList()
        openSearch()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText(itemName)
        XCTAssertTrue(waitForVisibleRow(named: itemName))
        row(named: itemName).tap()
        XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
    }

    func testFreeReleaseGateBrowseAndPortabilityWithoutEntitlement() {
        let freeGateArguments = [
            "--use-sample-inventory-data",
            "--qa-suppress-export-share-sheet",
            "--qa-suppress-restore-importer"
        ]
        launchStartupApp(arguments: freeGateArguments)
        resetToInventoryList()
        openSearch()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("Precision screwdriver set")
        openItem(named: "Precision screwdriver set")
        app.buttons["inventory.editItemButton"].tap()
        let movedPlaceName = "Moved \(uniqueTestSuffix())"
        createPlace(named: movedPlaceName)
        app.buttons["inventory.itemForm.saveButton"].tap()
        let movedPlace = element(identifier: "inventory.itemDetail.place")
        XCTAssertTrue(movedPlace.waitForExistence(timeout: 3))
        XCTAssertTrue(movedPlace.label.contains(movedPlaceName))

        openPlaceDetail(location: "Office", place: "Desk drawer")
        let placeHero = element(identifier: "locations.placeDetailHero")
        XCTAssertTrue(placeHero.waitForExistence(timeout: 3))
        XCTAssertTrue(placeHero.label.contains("Desk drawer"))
        XCTAssertTrue(placeHero.label.contains("Location: Office"))

        app.tabBars.buttons["Settings"].tap()
        let export = app.buttons["settings.export.action"]
        scrollToElement(export)
        export.tap()
        XCTAssertTrue(app.staticTexts["This file is not password-protected"].waitForExistence(timeout: 3))
        app.buttons["Continue to Export"].tap()
        XCTAssertTrue(element(identifier: "settings.export.invocationCompleted").waitForExistence(timeout: 5))

        let backup = app.buttons["settings.backup.action"]
        scrollToElement(backup)
        XCTAssertTrue(backup.isEnabled)

        let restore = app.buttons["settings.restore.action"]
        scrollToElement(restore)
        XCTAssertTrue(restore.isEnabled)
        restore.tap()
        XCTAssertTrue(element(identifier: "settings.restore.invocationCompleted").waitForExistence(timeout: 3))
    }

    func testMaximumDynamicTypeNavigatesLocationItemDetailAndPicker() {
        launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")

        let inventoryList = element(identifier: "inventory.list")
        let inventoryItem = row(named: "Ethernet cable 5m")
        scrollToElement(inventoryItem, in: inventoryList)
        inventoryItem.tap()
        XCTAssertTrue(element(identifier: "inventory.itemDetail.hero").waitForExistence(timeout: 3))
        tapBackButton()

        openPlaceDetail(location: "Living room", place: "TV cabinet")
        let placeItems = element(identifier: "locations.placeDetail.itemList")
        let placeItem = app.buttons["locations.placeDetail.itemRow.Ethernet cable 5m"]
        scrollToElement(placeItem, in: placeItems)
        placeItem.tap()

        let detail = element(identifier: "inventory.itemDetail")
        let editButton = app.buttons["inventory.editItemButton"]
        scrollToElement(editButton, in: detail)
        editButton.tap()

        let form = element(identifier: "inventory.itemForm")
        let categoryPicker = app.buttons["inventory.itemForm.categoryPicker"]
        scrollToElement(categoryPicker, in: form)
        categoryPicker.tap()
        let selection = element(identifier: "inventory.selection")
        let createButton = element(identifier: "inventory.selection.createButton")
        scrollToElement(createButton, in: selection)
    }
}
