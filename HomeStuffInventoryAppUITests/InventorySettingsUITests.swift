import XCTest

@MainActor
final class InventorySettingsUITests: InventoryUITestCase {
    func testFreeHierarchyDirectoryStaysReadableAndRoutesOnlyIntentionalStructuralActionsToUpgrade() {
        launchStartupApp(
            arguments: [
                "--use-sample-inventory-data",
                "--qa-hierarchy-management-fixture"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "en"
        )

        app.tabBars.buttons["Settings"].tap()
        let placesLink = app.buttons["settings.lists.placesLink"]
        scrollToElement(placesLink)
        placesLink.tap()

        let rootID = "B1F0A001-EE01-4E10-9000-000000000503"
        let childID = "B1F0A001-EE01-4E10-9000-000000000504"
        let leafID = "B1F0A001-EE01-4E10-9000-000000000505"
        let rootRow = element(identifier: "settings.places.hierarchy.row.\(rootID)")
        let childRow = element(identifier: "settings.places.hierarchy.row.\(childID)")
        let leafRow = element(identifier: "settings.places.hierarchy.row.\(leafID)")
        scrollToElement(rootRow)
        XCTAssertTrue(element(identifier: "settings.places.hierarchy.readOnly.\(rootID)").exists)
        XCTAssertFalse(element(identifier: "premium.upgrade").exists)

        let rootActions = element(identifier: "settings.places.hierarchy.actions.\(rootID)")
        scrollToElement(rootActions)
        rootActions.tap()
        XCTAssertFalse(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
        app.buttons["Add Nested Storage Place"].tap()
        XCTAssertTrue(element(identifier: "premium.upgrade").waitForExistence(timeout: 3))
        XCTAssertFalse(element(identifier: "settings.places.hierarchy.nameField").exists)
        app.buttons["premium.dismiss"].tap()

        rootActions.tap()
        app.buttons["Restructure"].tap()
        XCTAssertTrue(element(identifier: "premium.upgrade").waitForExistence(timeout: 3))
        XCTAssertFalse(element(identifier: "settings.places.hierarchy.move.review").exists)
        app.buttons["premium.dismiss"].tap()

        scrollToElement(childRow)
        XCTAssertTrue(element(identifier: "settings.places.hierarchy.readOnly.\(childID)").exists)
        scrollToElement(leafRow)
        XCTAssertTrue(element(identifier: "settings.places.hierarchy.readOnly.\(leafID)").exists)
        XCTAssertFalse(element(identifier: "premium.upgrade").exists)
    }

    func testUkrainianHierarchyReadOnlyStateAndContextualUpgradeRemainAccessible() {
        launchStartupApp(
            arguments: [
                "--use-sample-inventory-data",
                "--qa-hierarchy-management-fixture",
                "--qa-force-dark-appearance",
                "--qa-increase-contrast",
                "--qa-reduce-transparency"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "uk"
        )

        app.tabBars.buttons["Налаштування"].tap()
        let placesLink = app.buttons["settings.lists.placesLink"]
        scrollToElement(placesLink)
        placesLink.tap()

        let rootID = "B1F0A001-EE01-4E10-9000-000000000503"
        let rootRow = element(identifier: "settings.places.hierarchy.row.\(rootID)")
        let readOnly = app.staticTexts[
            "settings.places.hierarchy.readOnly.\(rootID)"
        ]
        scrollToElement(rootRow)
        XCTAssertTrue(readOnly.exists)
        XCTAssertTrue(readOnly.label.contains("лише для читання"))

        let actions = element(identifier: "settings.places.hierarchy.actions.\(rootID)")
        scrollToElement(actions)
        actions.tap()
        app.buttons["Додати вкладене місце"].tap()
        XCTAssertTrue(element(identifier: "premium.upgrade").waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Home Stuff Pro"].exists)
        XCTAssertTrue(app.staticTexts["Створіть вкладене місце зберігання"].exists)
    }

    func testPlaceDirectoryGroupsPlaceRowsUnderQuietLocationContextAndSupportsScopedEditor() {
        launchStartupApp(
            arguments: ["--use-sample-inventory-data", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "en"
        )

        app.tabBars.buttons["Settings"].tap()
        let places = app.buttons["settings.lists.placesLink"]
        scrollToElement(places)
        XCTAssertTrue(places.isHittable)
        places.tap()

        let officeHeader = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings.places.locationHeader."))
            .firstMatch
        XCTAssertTrue(officeHeader.waitForExistence(timeout: 3))
        let row = app.staticTexts["inventory.lists.valueTitle"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "settings.places.hierarchy.actions."
                )
            ).firstMatch.exists
        )
        add(attachment(named: "place-directory-en-dark-high-contrast-reduce-transparency-accessibility"))

        app.buttons["settings.places.addButton"].tap()
        XCTAssertTrue(app.buttons["settings.places.locationPicker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.places.iconPicker"].isHittable)
        XCTAssertFalse(app.buttons["settings.places.saveButton"].isEnabled)
        add(attachment(named: "place-directory-add-en-accessibility"))
    }

    func testPlaceDirectoryIsLocalizedInUkrainianAndLeavesLocationCategorySemanticsUntouched() {
        launchStartupApp(arguments: ["--use-sample-inventory-data"], contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL", locale: "uk")
        app.tabBars.buttons["Налаштування"].tap()
        let places = app.buttons["settings.lists.placesLink"]
        scrollToElement(places)
        XCTAssertEqual(places.label, "Керувати місцями зберігання")
        places.tap()
        XCTAssertTrue(app.navigationBars["Місця зберігання"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.places.addButton"].isHittable)
        add(attachment(named: "place-directory-uk-light-accessibility"))
    }

    func testPlaceDirectoryKeepsSameNamePlacesScopedAndRoutesExactUsedPlaceItems() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-place-management-fixture"])
        app.tabBars.buttons["Settings"].tap()
        let places = app.buttons["settings.lists.placesLink"]
        scrollToElement(places); places.tap()
        XCTAssertGreaterThanOrEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings.places.locationHeader.")).count, 2)
        let sharedBoxes = app.staticTexts.matching(NSPredicate(format: "label == %@", "Shared box")).allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(sharedBoxes.count, 2)

        let viewItems = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label == %@",
                "inventory.lists.viewItems",
                "View items in Shared box at Fixture Garage, 1 item"
            )
        ).firstMatch
        XCTAssertEqual(viewItems.label, "View items in Shared box at Fixture Garage, 1 item")
        scrollToElement(viewItems); viewItems.tap()
        XCTAssertTrue(app.buttons["inventory.itemRow.Scoped Place fixture Item"].waitForExistence(timeout: 3))
    }

    func testEmptyPlaceDirectoryExplainsLocationPrerequisiteAndRoutesToLocations() {
        launchStartupApp(arguments: ["--qa-empty-inventory-store"])
        app.tabBars.buttons["Settings"].tap()
        let places = app.buttons["settings.lists.placesLink"]
        scrollToElement(places); places.tap()
        XCTAssertTrue(app.buttons["settings.places.addLocationButton"].waitForExistence(timeout: 3))
        app.buttons["settings.places.addLocationButton"].tap()
        XCTAssertTrue(app.buttons["inventory.lists.addLocationButton"].waitForExistence(timeout: 3))
    }

    func testUsedPlaceDeleteKeepsScopeAndLocationDeleteShowsBlockedGuidance() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-place-management-fixture"])
        app.tabBars.buttons["Settings"].tap()
        let places = app.buttons["settings.lists.placesLink"]
        scrollToElement(places); places.tap()
        let fixtureViewItems = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "inventory.lists.viewItems", "View items in Shared box at Fixture Garage, 1 item")
        ).firstMatch
        scrollToElement(fixtureViewItems)
        let fixturePlaceID = "B1F0A001-EE01-4E10-9000-000000000403"
        let placeActions = app.buttons[
            "settings.places.hierarchy.actions.\(fixturePlaceID)"
        ]
        scrollToElement(placeActions); placeActions.tap(); app.buttons["Delete"].tap(); app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["View Items"].waitForExistence(timeout: 3))
        app.buttons["View Items"].tap()
        XCTAssertTrue(app.buttons["inventory.itemRow.Scoped Place fixture Item"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.lists.locationsLink"].tap()
        actionsButton(inManagedValueRowNamed: "Balcony cabinet").tap(); app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Value Is In Use"].waitForExistence(timeout: 3))
    }

    func testBlockedLocationDeleteUsesUkrainianGuidance() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-place-management-fixture"], locale: "uk")
        app.tabBars.buttons["Налаштування"].tap()
        app.buttons["settings.lists.locationsLink"].tap()
        actionsButton(inManagedValueRowNamed: "Balcony cabinet").tap(); app.buttons["Видалити"].tap()
        XCTAssertTrue(app.staticTexts["Значення використовується"].waitForExistence(timeout: 3))
    }

    func testSettingsShowsAlwaysAvailableManualBackupAction() {
        launchApp(); app.tabBars.buttons["Settings"].tap()
        let backupAction = app.buttons["settings.backup.action"]
        for _ in 0..<3 where !backupAction.exists { app.swipeUp() }
        XCTAssertTrue(backupAction.waitForExistence(timeout: 3)); XCTAssertTrue(backupAction.isEnabled); XCTAssertTrue(backupAction.isHittable); XCTAssertEqual(backupAction.label, "Back Up Inventory")
    }

    func testSettingsRestoreRowIsAlwaysAvailableAndInvokesTheImporterAction() {
        launchStartupApp(arguments: ["--qa-suppress-restore-importer"]); app.tabBars.buttons["Settings"].tap()
        let restoreAction = app.buttons["settings.restore.action"]
        scrollToElement(restoreAction); XCTAssertTrue(restoreAction.isEnabled); XCTAssertTrue(restoreAction.isHittable); XCTAssertEqual(restoreAction.label, "Restore Inventory from Backup")
        restoreAction.tap(); XCTAssertTrue(element(identifier: "settings.restore.invocationCompleted").waitForExistence(timeout: 3))
    }

    func testFreeGlobalHistoryPresentsExtendedUndoUpgradeFromCurrentSheet() {
        launchStartupApp(
            arguments: [
                "--use-sample-inventory-data",
                "--qa-movement-history-fixture"
            ]
        )
        app.tabBars.buttons["Settings"].tap()

        let history = app.buttons["settings.pro.history"]
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()

        let undo = app.buttons["premium.history.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertTrue(undo.isEnabled)
        undo.tap()

        XCTAssertTrue(element(identifier: "premium.upgrade").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Use Extended Undo"].exists)
        XCTAssertTrue(app.buttons["premium.restore"].exists)
    }

    func testListManagementEditorTextFieldSavesFromSettings() {
        launchApp(); openManagedLocations(); let managedLocationName = "Managed \(uniqueTestSuffix())"; tapVisibleButton(identifier: "inventory.lists.addLocationButton")
        let valueField = app.textFields["inventory.lists.valueField"]; XCTAssertTrue(valueField.waitForExistence(timeout: 3)); valueField.tap(); valueField.typeText(managedLocationName)
        app.buttons["inventory.lists.saveButton"].tap(); XCTAssertTrue(app.staticTexts[managedLocationName].waitForExistence(timeout: 3))
    }

    func testSettingsDisclosesPlaintextExportAndBackupBeforeInvokingEitherAction() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-suppress-export-share-sheet", "--qa-suppress-backup-file-exporter"]); app.tabBars.buttons["Settings"].tap()
        let export = app.buttons["settings.export.action"]; scrollToElement(export); XCTAssertGreaterThanOrEqual(export.frame.height, 44); export.tap()
        XCTAssertTrue(app.staticTexts["This file is not password-protected"].waitForExistence(timeout: 3)); XCTAssertTrue(staticText(labeled: "The export may include item names, locations, storage places, categories, quantities, conditions, tags, notes, and dates. Home Stuff does not encrypt or password-protect the exported JSON file. After you save or share it, its protection depends on the destination you choose.").exists); XCTAssertTrue(app.buttons["Continue to Export"].exists); add(attachment(named: "plaintext-export-disclosure-en-light")); XCTAssertFalse(element(identifier: "settings.export.invocationCompleted").exists); app.buttons["Cancel"].tap(); XCTAssertFalse(element(identifier: "settings.export.invocationCompleted").exists)
        export.tap(); app.buttons["Continue to Export"].tap(); XCTAssertTrue(element(identifier: "settings.export.invocationCompleted").waitForExistence(timeout: 5))
        let backup = app.buttons["settings.backup.action"]; scrollToElement(backup); backup.tap(); XCTAssertTrue(staticText(labeled: "The backup contains your complete local inventory, including item details, locations, storage places, notes, tags, dates, and recent item-view history. Home Stuff does not encrypt or password-protect the backup file. After you save it, its protection depends on the destination you choose.").waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["Continue to Backup"].exists); add(attachment(named: "plaintext-backup-disclosure-en-light")); XCTAssertFalse(element(identifier: "settings.backup.invocationCompleted").exists); app.buttons["Cancel"].tap(); XCTAssertFalse(element(identifier: "settings.backup.invocationCompleted").exists)
        backup.tap(); app.buttons["Continue to Backup"].tap(); XCTAssertTrue(element(identifier: "settings.backup.invocationCompleted").waitForExistence(timeout: 5))
    }

    func testSettingsUkrainianPlaintextDisclosuresRemainActionSpecificAtAccessibilitySize() {
        launchStartupApp(
            arguments: [
                "--use-sample-inventory-data",
                "--qa-force-dark-appearance",
                "--qa-suppress-export-share-sheet",
                "--qa-suppress-backup-file-exporter"
            ],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "uk"
        )
        app.tabBars.buttons["Налаштування"].tap()

        let export = app.buttons["settings.export.action"]
        scrollToElement(export)
        export.tap()
        XCTAssertTrue(app.staticTexts["Цей файл не захищено паролем"].waitForExistence(timeout: 3))
        XCTAssertTrue(staticText(labeled: "Експорт може містити назви речей, локації, місця зберігання, категорії, кількість, стан, теги, нотатки та дати. Home Stuff не шифрує й не захищає паролем експортований JSON-файл. Після збереження або надсилання його захист залежить від вибраного місця призначення.").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Продовжити експорт"].waitForExistence(timeout: 3))
        add(attachment(named: "plaintext-export-disclosure-uk-dark-accessibility"))
        app.buttons["Скасувати"].tap()

        let backup = app.buttons["settings.backup.action"]
        scrollToElement(backup)
        backup.tap()
        XCTAssertTrue(staticText(labeled: "Резервна копія містить увесь локальний інвентар, зокрема дані речей, локації, місця зберігання, нотатки, теги, дати та історію нещодавніх переглядів. Home Stuff не шифрує й не захищає паролем файл резервної копії. Після збереження його захист залежить від вибраного місця призначення.").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Продовжити створення копії"].waitForExistence(timeout: 3))
        add(attachment(named: "plaintext-backup-disclosure-uk-dark-accessibility"))
    }

    func testLocationIconPickerSavesLocationFromSettings() {
        launchApp(); openManagedLocations(); let managedLocationName = "Icon Location \(uniqueTestSuffix())"; tapVisibleButton(identifier: "inventory.lists.addLocationButton")
        let valueField = app.textFields["inventory.lists.valueField"]; XCTAssertTrue(valueField.waitForExistence(timeout: 3)); valueField.tap(); valueField.typeText(managedLocationName); app.buttons["inventory.lists.locationIconPicker"].tap(); app.buttons["locationIcons.option.kitchen"].tap(); XCTAssertTrue(app.textFields["inventory.lists.valueField"].waitForExistence(timeout: 3)); app.buttons["inventory.lists.saveButton"].tap(); XCTAssertTrue(app.staticTexts[managedLocationName].waitForExistence(timeout: 3))
    }

    func testLocationManagementKeepsLocationEditorAndPickerSeparateFromCategories() {
        launchStartupApp(
            arguments: ["--use-sample-inventory-data", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"],
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            locale: "uk"
        )

        app.tabBars.buttons["Налаштування"].tap()
        let locations = app.buttons["settings.lists.locationsLink"]
        scrollToElement(locations)
        locations.tap()
        tapVisibleButton(identifier: "inventory.lists.addLocationButton")

        XCTAssertTrue(app.textFields["inventory.lists.valueField"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.lists.locationIconPicker"].isHittable)
        XCTAssertFalse(app.buttons["inventory.lists.saveButton"].isEnabled)
        add(attachment(named: "location-management-uk-dark-high-contrast-reduce-transparency-accessibility"))

        app.buttons["inventory.lists.locationIconPicker"].tap()
        XCTAssertTrue(app.buttons["locationIcons.option.default"].waitForExistence(timeout: 3))
        add(attachment(named: "location-icon-picker-uk-dark-high-contrast-reduce-transparency-accessibility"))
        tapBackButton()
        app.buttons["inventory.lists.cancelButton"].tap()
        tapBackButton()

        let categories = app.buttons["settings.lists.categoriesLink"]
        scrollToElement(categories)
        categories.tap()
        tapVisibleButton(identifier: "inventory.lists.addCategoryButton")
        XCTAssertTrue(app.textFields["inventory.lists.valueField"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["inventory.lists.locationIconPicker"].exists)
        XCTAssertFalse(app.buttons["inventory.lists.saveButton"].isEnabled)
        add(attachment(named: "category-management-negative-control-uk-dark-high-contrast-reduce-transparency-accessibility"))
    }

    func testUsedManagedLocationOpensItemsAndBlockedDeleteShowsGuidance() {
        launchApp(); openManagedLocations(); let viewItems = viewItemsButton(inManagedValueRowNamed: "Balcony cabinet"); scrollToElement(viewItems); XCTAssertGreaterThanOrEqual(viewItems.frame.width, 44); XCTAssertGreaterThanOrEqual(viewItems.frame.height, 44); viewItems.tap()
        let item = app.buttons["inventory.itemRow.Drill bits"]; XCTAssertTrue(item.waitForExistence(timeout: 3)); item.tap(); XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3)); tapBackButton(); tapBackButton(); actionsButton(inManagedValueRowNamed: "Balcony cabinet").tap(); app.buttons["Delete"].tap(); XCTAssertTrue(app.staticTexts["Value Is In Use"].waitForExistence(timeout: 3)); XCTAssertTrue(staticText(labeled: "Balcony cabinet contains 1 storage place. Remove that storage place before deleting this location.").exists)
    }
}
