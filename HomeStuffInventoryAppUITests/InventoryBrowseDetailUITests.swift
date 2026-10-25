import XCTest

@MainActor
final class InventoryBrowseDetailUITests: InventoryUITestCase {
    func testFirstLaunchDoesNotPresentProUpgrade() {
        launchApp()

        XCTAssertFalse(element(identifier: "premium.upgrade").exists)
        XCTAssertTrue(element(identifier: "inventory.list").waitForExistence(timeout: 3))
    }

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

        let notesContent = app.buttons["inventory.detail.notesContent"]
        scrollToElement(notesContent)
        notesContent.tap()
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
        app.buttons["inventory.filter.placeMenu"].tap()
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

    func testFilterSubmenusKeepFirstLevelCompactAndSelectionsIndependent() {
        launchFilterScaleApp()
        openFilterMenu()
        let category = filterSubmenu("category", title: "Category")
        let location = filterSubmenu("location", title: "Location")
        let place = filterSubmenu("place", title: "Storage Place")
        XCTAssertEqual(category.label, "Category")
        XCTAssertEqual(location.label, "Location")
        XCTAssertEqual(place.label, "Storage Place")
        XCTAssertLessThan(category.frame.midY, location.frame.midY)
        XCTAssertLessThan(location.frame.midY, place.frame.midY)
        XCTAssertFalse(app.buttons["Filter Category 01"].exists)
        XCTAssertFalse(app.buttons["Filter Location 01"].exists)
        XCTAssertFalse(app.buttons["Filter Place 01"].exists)
        XCTAssertFalse(app.buttons["inventory.filter.clearFiltersButton"].exists)
        category.tap()
        assertFilterChoiceSelected("Any Category")
        chooseFilterOption("Filter Category 01")
        selectFilter("location", title: "Location", option: "Filter Location 01")
        selectFilter("place", title: "Storage Place", option: "Filter Place 01")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Item 01"))
        XCTAssertFalse(row(named: "Filter Missing Place Item").exists)
        XCTAssertTrue(app.staticTexts["1 item"].exists)
        for badge in ["Category: Filter Category 01", "Location: Filter Location 01", "Storage Place: Filter Place 01"] {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", badge)).firstMatch.exists)
        }
        openFilterMenu()
        for (dimension, title) in [("category", "Category"), ("location", "Location"), ("place", "Storage Place")] {
            XCTAssertEqual(filterSubmenu(dimension, title: title).label, title)
        }
        filterSubmenu("place", title: "Storage Place").tap()
        assertFilterChoiceSelected("Filter Place 01")
        chooseFilterOption("Any Storage Place")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Missing Place Item"))
        XCTAssertTrue(app.staticTexts["2 items"].exists)
        openFilterSubmenu("place", title: "Storage Place")
        assertFilterChoiceSelected("Any Storage Place")
        chooseFilterOption("Any Storage Place")
        openFilterSubmenu("location", title: "Location")
        assertFilterChoiceSelected("Filter Location 01")
        chooseFilterOption("Any Location")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Missing Location Item"))
        openFilterSubmenu("location", title: "Location")
        assertFilterChoiceSelected("Any Location")
        chooseFilterOption("Any Location")
        openFilterSubmenu("category", title: "Category")
        assertFilterChoiceSelected("Filter Category 01")
        chooseFilterOption("Any Category")
        openFilterSubmenu("category", title: "Category")
        assertFilterChoiceSelected("Any Category")
        chooseFilterOption("Any Category")
        XCTAssertFalse(app.buttons["inventory.filterContext.clearButton"].exists)
    }

    func testInventoryFiltersRemainIndependentOfNativeSearchQuery() {
        launchFilterScaleApp()
        selectFilter("location", title: "Location", option: "Filter Location 02")
        openSearch()
        let query = app.searchFields.firstMatch
        query.tap(); query.typeText("Filter\n")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Item 01"))
        XCTAssertTrue(waitForVisibleRow(named: "Filter Item 02"))
        let clear = app.buttons["inventory.filterContext.clearButton"]
        XCTAssertEqual(clear.label, "Clear Search")
        clear.tap()
        XCTAssertNotEqual(query.value as? String, "Filter")
        XCTAssertFalse(clear.exists)
        let closeSearch = app.buttons.matching(NSPredicate(format: "label IN %@", ["Close", "Закрити"])).firstMatch
        if closeSearch.exists { closeSearch.tap() }
        resetToInventoryList()
        XCTAssertTrue(waitForVisibleRow(named: "Filter Item 02"))
        XCTAssertFalse(row(named: "Filter Item 01").exists)
        openFilterSubmenu("location", title: "Location")
        assertFilterChoiceSelected("Filter Location 02")
        chooseFilterOption("Any Location")
    }

    func testFilterLocationReconcilesPlaceAndDistinguishesMissingFromAny() {
        launchFilterScaleApp()
        selectFilter("category", title: "Category", option: "Filter Category 01")
        selectFilter("place", title: "Storage Place", option: "Filter Place 01")
        selectFilter("location", title: "Location", option: "Filter Location 01")
        openFilterSubmenu("place", title: "Storage Place")
        assertFilterChoiceSelected("Filter Place 01")
        chooseFilterOption("Filter Place 01")
        selectFilter("location", title: "Location", option: "Filter Location 02")
        XCTAssertTrue(app.staticTexts["No Matching Items"].waitForExistence(timeout: 3))
        openFilterSubmenu("place", title: "Storage Place")
        assertFilterChoiceSelected("Any Storage Place")
        chooseFilterOption("Any Storage Place")
        openFilterSubmenu("category", title: "Category")
        assertFilterChoiceSelected("Filter Category 01")
        chooseFilterOption("Any Category")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Item 02"))
        selectFilter("location", title: "Location", option: "Filter Location 01")
        selectFilter("place", title: "Storage Place", option: "No Storage Place")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Missing Place Item"))
        XCTAssertFalse(row(named: "Filter Item 01").exists)
        selectFilter("place", title: "Storage Place", option: "Any Storage Place")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Item 01"))
        XCTAssertTrue(waitForVisibleRow(named: "Filter Missing Place Item"))
        selectFilter("location", title: "Location", option: "No location")
        XCTAssertTrue(waitForVisibleRow(named: "Filter Missing Location Item"))
        XCTAssertFalse(row(named: "Filter Missing Place Item").exists)
        selectFilter("category", title: "Category", option: "Filter Category 02")
        XCTAssertTrue(app.staticTexts["No Matching Items"].waitForExistence(timeout: 3))
        let emptyReset = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Clear Filters", "inventory.filterContext.clearButton")).firstMatch
        XCTAssertTrue(emptyReset.waitForExistence(timeout: 3)); emptyReset.tap()
        XCTAssertFalse(app.buttons["inventory.filterContext.clearButton"].exists)
    }

    func testFilterScaleSubmenusReachFortiethOption() {
        launchFilterScaleApp()
        for (dimension, title, option) in [
            ("category", "Category", "Filter Category 40"),
            ("location", "Location", "Filter Location 40"),
            ("place", "Storage Place", "Filter Place 40")
        ] {
            openFilterSubmenu(dimension, title: title)
            XCTAssertFalse(app.buttons[dimension == "category" ? "Filter Location 40" : "Filter Category 40"].exists)
            chooseFilterOption(option)
            XCTAssertTrue(waitForVisibleRow(named: "Filter Item 40"))
            openFilterSubmenu(dimension, title: title)
            assertFilterChoiceSelected(option)
            chooseFilterOption(option)
            openFilterMenu()
            app.buttons["inventory.filter.clearFiltersButton"].tap()
        }
    }

    func testFilterSubmenusUseUkrainianLabelsAtMaximumAccessibilitySize() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-filter-menu-scale-fixture", "--qa-force-dark-appearance", "--qa-increase-contrast", "--qa-reduce-transparency"], contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL", locale: "uk")
        resetToInventoryList()
        for (dimension, title, any) in [
            ("category", "Категорія", "Будь-яка категорія"),
            ("location", "Локація", "Будь-яка локація"),
            ("place", "Місце зберігання", "Будь-яке місце зберігання")
        ] {
            openFilterSubmenu(dimension, title: title)
            assertFilterChoiceSelected(any)
            chooseFilterOption(any)
        }
    }

    func testEmptyInventoryKeepsAllFilterSubmenusAndAnyChoices() {
        launchStartupApp(arguments: ["--qa-empty-inventory-store", "--qa-filter-menu-scale-fixture"], locale: "uk")
        resetToInventoryList()
        for (dimension, title, any) in [
            ("category", "Категорія", "Будь-яка категорія"),
            ("location", "Локація", "Будь-яка локація"),
            ("place", "Місце зберігання", "Будь-яке місце зберігання")
        ] {
            openFilterSubmenu(dimension, title: title)
            assertFilterChoiceSelected(any)
            chooseFilterOption(any)
        }
        XCTAssertTrue(app.buttons["inventory.empty.addItemButton"].exists)
        XCTAssertFalse(app.buttons["inventory.filterContext.clearButton"].exists)
    }

    private func launchFilterScaleApp() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-filter-menu-scale-fixture"])
        resetToInventoryList()
    }

    private func openFilterMenu() {
        let menu = app.buttons["inventory.filter.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3)); menu.tap()
    }

    private func filterSubmenu(_ dimension: String, title: String) -> XCUIElement {
        let identified = app.buttons["inventory.filter.\(dimension)Menu"]
        if identified.waitForExistence(timeout: 1) { return identified }
        // Native menu presentation can omit the SwiftUI identifier on older runtimes.
        let labeled = app.buttons[title]
        XCTAssertTrue(labeled.waitForExistence(timeout: 3))
        return labeled
    }

    private func openFilterSubmenu(_ dimension: String, title: String) {
        openFilterMenu()
        filterSubmenu(dimension, title: title).tap()
    }

    private func selectFilter(_ dimension: String, title: String, option: String) {
        openFilterSubmenu(dimension, title: title)
        chooseFilterOption(option)
    }

    private func filterOption(_ title: String) -> XCUIElement {
        let option = app.buttons[title]
        for _ in 0..<18 {
            if option.exists && option.isHittable { return option }
            let menu = app.collectionViews.firstMatch
            if menu.exists { menu.swipeUp() } else { app.swipeUp() }
        }
        XCTFail("Native filter option is unreachable: \(title)")
        return option
    }

    private func chooseFilterOption(_ title: String) { filterOption(title).tap() }

    private func assertFilterChoiceSelected(_ title: String) {
        let option = filterOption(title)
        XCTAssertTrue(option.isSelected || option.value as? String == "1", "Expected native selected state for \(title): \(option.debugDescription)")
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
        launchApp(); openItem(named: "USB-C to HDMI adapter"); tapBackButton(); openPlaceDetail(location: "Office", place: "Desk drawer"); XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3)); XCTAssertTrue(app.tabBars.buttons["Search inventory"].exists); let placeHero = element(identifier: "locations.placeDetailHero"); XCTAssertTrue(placeHero.waitForExistence(timeout: 3)); XCTAssertTrue(placeHero.label.contains("Desk drawer")); XCTAssertTrue(placeHero.label.contains("Location: Office")); XCTAssertTrue(placeHero.label.contains("1 item")); let parentLocation = element(identifier: "locations.placeDetailHero.parentLocation"); XCTAssertTrue(parentLocation.waitForExistence(timeout: 3)); XCTAssertTrue(parentLocation.label.contains("Office")); XCTAssertEqual(app.staticTexts["locations.placeDetail.path"].label, "Storage path: Office, Desk drawer"); XCTAssertFalse(element(identifier: "locations.placeDetail.countSummary").exists); XCTAssertEqual(element(identifier: "locations.placeDetail.itemsSectionHeader").label, "Items"); XCTAssertEqual(app.buttons["locations.placeDetail.itemRow.USB-C to HDMI adapter"].label, "USB-C to HDMI adapter, Cables & Adapters, Quantity 1"); XCTAssertFalse(element(identifier: "locations.placeRecentItems").exists); XCTAssertFalse(app.staticTexts["All items"].exists); XCTAssertFalse(app.buttons["All items"].exists); app.buttons["locations.placeDetail.addItemButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office")); assertSelectedPlace(named: "Desk drawer"); app.buttons["inventory.itemForm.cancelButton"].tap(); tapBackButton(); app.buttons["locations.locationDetail.addItemButton"].tap(); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office")); app.buttons["inventory.itemForm.cancelButton"].tap()
    }
    func testNestedPlaceRetainsExtendedContextWithoutLaunchFlags() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-hierarchy-management-fixture"])
        openPlaceDetail(location: "Hierarchy Office", place: "Hierarchy Cabinet")
        XCTAssertTrue(element(identifier: "locations.placeDetail.countSummary").exists)
        XCTAssertTrue(app.buttons["locations.placeDetail.allContainedItems"].exists)
        capturePlaceDetailEvidence("hierarchy-root")
        app.buttons["locations.placeDetail.allContainedItems"].tap()
        let containedRow = app.buttons["inventory.itemRow.Hierarchy fixture adapter"]
        XCTAssertTrue(containedRow.waitForExistence(timeout: 3))
        XCTAssertTrue(containedRow.label.contains("Hierarchy Office"))
        XCTAssertTrue(containedRow.label.contains("Hierarchy Cabinet › Hierarchy Drawer › Hierarchy Cable box"))
        capturePlaceDetailEvidence("hierarchy-all-contained")
        tapBackButton()
        tapVisibleButton(identifier: "locations.placeDetail.childPlace.B1F0A001-EE01-4E10-9000-000000000504")
        XCTAssertTrue(element(identifier: "locations.placeDetail.countSummary").exists)
        capturePlaceDetailEvidence("hierarchy-child")
        tapVisibleButton(identifier: "locations.placeDetail.childPlace.B1F0A001-EE01-4E10-9000-000000000505")
        XCTAssertEqual(app.staticTexts["locations.placeDetail.path"].label,
                       "Storage path: Hierarchy Office, Hierarchy Cabinet, Hierarchy Drawer, Hierarchy Cable box")
        XCTAssertTrue(element(identifier: "locations.placeDetail.countSummary").exists)
        XCTAssertEqual(element(identifier: "locations.placeDetail.itemsSectionHeader").label, "Direct Items")
        let row = app.buttons["locations.placeDetail.itemRow.Hierarchy fixture adapter"]
        scrollToElement(row, in: app.scrollViews["locations.placeDetail.itemList"])
        XCTAssertTrue(row.label.contains("Hierarchy Office"))
        XCTAssertTrue(row.label.contains("Hierarchy Cabinet › Hierarchy Drawer › Hierarchy Cable box"))
        capturePlaceDetailEvidence("hierarchy-nested-leaf")
        row.tap()
        XCTAssertTrue(element(identifier: "inventory.itemDetail.hero").waitForExistence(timeout: 3))
    }

    private func capturePlaceDetailEvidence(_ name: String) {
        let evidence = attachment(named: name)
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    func testDeletingLastPlaceItemKeepsEmptyPlaceContext() {
        launchApp(); openPlaceDetail(location: "Balcony cabinet", place: "Red organizer"); let itemRow = app.buttons["locations.placeDetail.itemRow.Drill bits"]; XCTAssertTrue(itemRow.waitForExistence(timeout: 3)); itemRow.tap(); tapVisibleButton(identifier: "inventory.deleteItemButton"); let confirmDeleteButton = app.buttons["inventory.confirmDeleteButton"].firstMatch; XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 3)); confirmDeleteButton.tap(); let placeHero = element(identifier: "locations.placeDetailHero"); XCTAssertTrue(placeHero.waitForExistence(timeout: 3)); XCTAssertTrue(placeHero.label.contains("Red organizer")); XCTAssertTrue(placeHero.label.contains("Location: Balcony cabinet")); XCTAssertTrue(placeHero.label.contains("0 items")); XCTAssertTrue(app.staticTexts["No Items in This Storage Place"].waitForExistence(timeout: 3))
    }

    func testPlaceContentsMovementActionDistinguishesAccessGateFromEmptyState() {
        launchStartupApp(arguments: [
            "--use-sample-inventory-data",
            "--qa-enable-lifetime-pro-launch",
            "--qa-storekit-product-fixture",
            "--qa-storekit-product-name",
            "UI Test Pro Product",
            "--qa-storekit-product-price",
            "Localized UI Test Price"
        ])
        resetToInventoryList()
        openPlaceDetail(location: "Office", place: "Desk drawer")

        let actions = app.buttons["locations.placeDetail.proActions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 3))
        actions.tap()
        let moveContents = app.buttons["locations.placeDetail.moveContentsButton"]
        XCTAssertTrue(moveContents.waitForExistence(timeout: 3))
        XCTAssertEqual(moveContents.label, "Move Place Contents")
        moveContents.tap()
        XCTAssertTrue(element(identifier: "premium.upgrade").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["premium.purchase"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["premium.restore"].waitForExistence(timeout: 3))
        let productName = app.staticTexts["premium.productName"]
        let productPrice = app.staticTexts["premium.price"]
        XCTAssertTrue(productName.waitForExistence(timeout: 3))
        XCTAssertTrue(productPrice.waitForExistence(timeout: 3))
        XCTAssertFalse(productName.label.isEmpty)
        XCTAssertFalse(productPrice.label.isEmpty)
        app.buttons["premium.dismiss"].tap()

        tapBackButton()
        tapBackButton()
        openPlaceDetail(location: "Balcony cabinet", place: "Red organizer")
        app.buttons["locations.placeDetail.itemRow.Drill bits"].tap()
        tapVisibleButton(identifier: "inventory.deleteItemButton")
        let confirmDelete = app.buttons["inventory.confirmDeleteButton"].firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 3))
        confirmDelete.tap()

        app.buttons["locations.placeDetail.proActions"].tap()
        let emptyMoveContents = app.buttons["locations.placeDetail.moveContentsButton"]
        XCTAssertTrue(emptyMoveContents.waitForExistence(timeout: 3))
        emptyMoveContents.tap()
        XCTAssertTrue(
            app.staticTexts[
                "This Storage Place has no items to move."
            ].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            element(identifier: "premium.upgrade").exists
        )
    }

    func testScopedRoomSweepUsesSharedUpgradeWithoutBlockingOrdinaryAddItem() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-enable-lifetime-pro-launch"])
        openPlaceDetail(location: "Office", place: "Desk drawer")

        app.buttons["locations.placeDetail.proActions"].tap()
        let roomSweep = app.buttons["locations.placeDetail.roomSweep"]
        XCTAssertTrue(roomSweep.waitForExistence(timeout: 3))
        roomSweep.tap()
        XCTAssertTrue(element(identifier: "premium.upgrade").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Continue with Room Sweep"].exists)
        app.buttons["premium.dismiss"].tap()

        app.buttons["locations.placeDetail.addItemButton"].tap()
        XCTAssertTrue(app.buttons["inventory.itemForm.cancelButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains("Office"))
        assertSelectedPlace(named: "Desk drawer")
    }

    func testProductionPlaceDetailOmitsCommercialActionsAndKeepsAddItemAvailable() {
        launchApp()
        openPlaceDetail(location: "Office", place: "Desk drawer")

        XCTAssertFalse(app.buttons["locations.placeDetail.proActions"].exists)
        XCTAssertFalse(app.buttons["locations.placeDetail.roomSweep"].exists)
        XCTAssertFalse(app.buttons["locations.placeDetail.moveContentsButton"].exists)
        XCTAssertTrue(app.buttons["locations.placeDetail.addItemButton"].exists)
        XCTAssertFalse(element(identifier: "premium.upgrade").exists)
    }

    func testItemDetailMovementHistoryIsReadableWithoutUpgrade() {
        launchApp()
        openItem(named: "USB-C to HDMI adapter")

        let history = app.buttons["inventory.itemDetail.movementHistory"]
        scrollToElement(history)
        history.tap()

        XCTAssertTrue(app.staticTexts["Movement History"].waitForExistence(timeout: 3))
        XCTAssertFalse(element(identifier: "premium.upgrade").exists)
    }
    func testOpeningItemDetailKeepsHeroAndRevealsNavigationTitleAfterScroll() {
        launchApp(); openItemFromSearch(named: "USB-C to HDMI adapter"); let detail = element(identifier: "inventory.itemDetail"); XCTAssertTrue(detail.waitForExistence(timeout: 3)); let hero = element(identifier: "inventory.itemDetail.hero"); XCTAssertTrue(hero.waitForExistence(timeout: 3)); XCTAssertTrue(hero.label.contains("USB-C to HDMI adapter")); XCTAssertTrue(hero.label.contains("Category: Cables & Adapters")); XCTAssertFalse(hero.label.contains("Last updated")); XCTAssertFalse(hero.label.contains("Office")); XCTAssertFalse(hero.label.contains("Desk drawer")); let title = element(identifier: "inventory.itemDetail.title"); XCTAssertTrue(title.waitForExistence(timeout: 3)); XCTAssertEqual(title.label, "USB-C to HDMI adapter"); let storage = element(identifier: "inventory.itemDetail.storage"); XCTAssertTrue(storage.waitForExistence(timeout: 3)); let location = element(identifier: "inventory.itemDetail.location"); XCTAssertTrue(location.waitForExistence(timeout: 3)); XCTAssertTrue(location.label.contains("Office")); let place = element(identifier: "inventory.itemDetail.place"); XCTAssertTrue(place.waitForExistence(timeout: 3)); XCTAssertTrue(place.label.contains("Desk drawer")); let quantity = element(identifier: "inventory.itemDetail.quantity"); XCTAssertTrue(quantity.waitForExistence(timeout: 3)); XCTAssertTrue(quantity.label.contains("Quantity")); let condition = element(identifier: "inventory.itemDetail.condition"); XCTAssertTrue(condition.waitForExistence(timeout: 3)); XCTAssertTrue(condition.label.contains("Condition")); XCTAssertTrue(condition.label.contains("Good")); XCTAssertNotEqual(detail.value as? String, "USB-C to HDMI adapter"); XCTAssertTrue(hero.isHittable); XCTAssertTrue(waitForDetailNavigationTitleValue("USB-C to HDMI adapter"))
    }

    func testItemDetailBoundsAndExpandsManyTagsAfterNotes() {
        launchApp()
        openItem(named: "USB-C to HDMI adapter")

        let notes = element(identifier: "inventory.detail.notesCard")
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

        let notes = element(identifier: "inventory.detail.notesCard")
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
    func testEmptyNotesEditingStartsOnlyFromContentText() {
        checkNotesContentHitArea(filled: false)
    }

    func testShortNotesEditingStartsOnlyFromContentText() {
        checkNotesContentHitArea(filled: true)
    }

    private func checkNotesContentHitArea(filled: Bool) {
        for locale in ["en", "uk"] {
            for size: String? in [nil, "UICTContentSizeCategoryAccessibilityXXXL"] {
                launchStartupApp(
                    arguments: ["--use-sample-inventory-data"],
                    contentSizeCategory: size,
                    locale: locale
                )
                resetToInventoryList()
                let itemName = "Notes Target \(uniqueTestSuffix())"
                app.buttons["inventory.addItemButton"].tap()
                let nameField = app.textFields["inventory.itemForm.nameField"]
                XCTAssertTrue(nameField.waitForExistence(timeout: 3))
                nameField.tap()
                nameField.typeText(itemName)
                app.buttons["inventory.itemForm.saveButton"].tap()
                resetToInventoryList()
                app.tabBars.buttons[locale == "uk" ? "Шукати в інвентарі" : "Search inventory"].tap()
                let search = app.searchFields.firstMatch
                XCTAssertTrue(search.waitForExistence(timeout: 3))
                search.tap()
                search.typeText(itemName)
                openItem(named: itemName)

                let content = app.buttons["inventory.detail.notesContent"]
                let editor = app.textViews["inventory.notesEditor.editor"]
                let text = filled ? (locale == "uk" ? "Кабель" : "Cable") : ""
                if filled {
                    scrollToElement(content)
                    content.tap()
                    XCTAssertTrue(editor.waitForExistence(timeout: 3))
                    XCTAssertEqual(editor.value as? String, "")
                    editor.tap()
                    editor.typeText(text)
                    app.buttons["inventory.notesEditor.saveButton"].tap()
                    XCTAssertFalse(editor.waitForExistence(timeout: 3))
                }
                positionWholeNotesCardInViewport()
                let label = locale == "uk"
                    ? "Нотатки: \(filled ? text : "Без нотаток")"
                    : "Notes: \(filled ? text : "No notes")"
                XCTAssertEqual(content.label, label)
                XCTAssertFalse(editor.exists)
                XCTAssertFalse(app.buttons["inventory.detail.editNotesButton"].exists)
                XCTAssertFalse(app.buttons["inventory.detail.notesCard"].exists)
                XCTAssertFalse(app.buttons["inventory.detail.notesHeader"].exists)
                for identifier in ["inventory.detail.notesCard", "inventory.detail.notesHeader", "inventory.detail.notesContent"] {
                    XCTAssertEqual(app.descendants(matching: .any).matching(identifier: identifier).count, 1)
                }
                let card = element(identifier: "inventory.detail.notesCard")
                XCTAssertEqual(card.buttons.count, 1)
                XCTAssertEqual(card.buttons.firstMatch.identifier, "inventory.detail.notesContent")
                let capture = attachment(named: "notes-\(locale)-\(size == nil ? "default" : "accessibility")-\(filled ? "short" : "empty")")
                capture.lifetime = .keepAlways
                add(capture)
                for zone in 0..<(filled ? 8 : 7) {
                    assertInertNotesZone(zone, expectedLabel: label)
                }
                content.tap()
                XCTAssertTrue(editor.waitForExistence(timeout: 3))
                XCTAssertEqual(app.textViews.matching(identifier: "inventory.notesEditor.editor").count, 1)
                XCTAssertEqual(editor.value as? String, text)
                XCTAssertFalse(element(identifier: "inventory.itemForm").exists)
                app.buttons["inventory.notesEditor.cancelButton"].tap()
                XCTAssertFalse(editor.waitForExistence(timeout: 3))
                XCTAssertEqual(content.label, label)
                content.tap()
                XCTAssertTrue(editor.waitForExistence(timeout: 3))
                XCTAssertEqual(editor.value as? String, text)
                editor.tap()
                editor.typeText(" Saved")
                app.buttons["inventory.notesEditor.saveButton"].tap()
                XCTAssertFalse(editor.waitForExistence(timeout: 3))
                XCTAssertTrue(content.label.contains("Saved"))
                content.tap()
                XCTAssertTrue(editor.waitForExistence(timeout: 3))
                XCTAssertEqual(editor.value as? String, (text + " Saved").trimmingCharacters(in: .whitespacesAndNewlines))
                app.buttons["inventory.notesEditor.cancelButton"].tap()
                XCTAssertFalse(editor.waitForExistence(timeout: 3))
            }
        }
    }

    private var notesVisibleViewport: CGRect {
        let screen = app.frame
        let top = max(screen.minY, app.navigationBars.firstMatch.frame.maxY)
        let bottom = min(screen.maxY, app.tabBars.firstMatch.frame.minY)
        return CGRect(x: screen.minX, y: top, width: screen.width, height: bottom - top)
    }

    private func positionWholeNotesCardInViewport() {
        let card = element(identifier: "inventory.detail.notesCard")
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        for _ in 0..<10 {
            let viewport = notesVisibleViewport.insetBy(dx: 1, dy: 8)
            let frame = card.frame
            if viewport.contains(frame) { return }
            let shift = min(max(frame.midY - viewport.midY, -viewport.height / 2), viewport.height / 2)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = CGPoint(x: viewport.midX, y: viewport.midY + shift / 2)
            let end = CGPoint(x: viewport.midX, y: viewport.midY - shift / 2)
            origin.withOffset(CGVector(dx: start.x - app.frame.minX, dy: start.y - app.frame.minY))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: end.x - app.frame.minX, dy: end.y - app.frame.minY)))
        }
        XCTAssertTrue(notesVisibleViewport.insetBy(dx: 1, dy: 8).contains(card.frame), "Whole Notes card must be visible: \(card.frame), viewport: \(notesVisibleViewport)")
    }

    private func assertInertNotesZone(_ zone: Int, expectedLabel: String) {
        let card = element(identifier: "inventory.detail.notesCard").frame
        let header = element(identifier: "inventory.detail.notesHeader").frame
        let content = app.buttons["inventory.detail.notesContent"]
        let text = content.frame
        for frame in [card, header, text] {
            XCTAssertGreaterThan(frame.width, 0)
            XCTAssertGreaterThan(frame.height, 0)
        }
        XCTAssertTrue(notesVisibleViewport.contains(card))
        XCTAssertTrue(card.contains(header))
        XCTAssertTrue(card.contains(text))
        XCTAssertGreaterThan(text.minY, header.maxY)
        let point: CGPoint
        switch zone {
        case 0: point = CGPoint(x: header.midX, y: header.midY)
        case 1: point = CGPoint(x: text.minX + min(8, text.width / 2), y: (header.maxY + text.minY) / 2)
        case 2: point = CGPoint(x: (card.minX + text.minX) / 2, y: text.midY)
        case 3: point = CGPoint(x: (text.maxX + card.maxX) / 2, y: text.midY)
        case 4: point = CGPoint(x: card.midX, y: (text.maxY + card.maxY) / 2)
        case 5: point = CGPoint(x: card.midX, y: (card.minY + header.minY) / 2)
        case 6: point = CGPoint(x: card.maxX - min(8, (card.maxX - header.maxX) / 2), y: header.midY)
        default:
            XCTAssertLessThan(text.maxX, header.maxX)
            point = CGPoint(x: (text.maxX + header.maxX) / 2, y: text.midY)
            XCTAssertLessThan(point.x, header.maxX)
        }
        XCTAssertTrue(card.contains(point), "Zone \(zone) must be inside the card")
        XCTAssertTrue(notesVisibleViewport.contains(point), "Zone \(zone) must be visible")
        XCTAssertFalse(text.contains(point), "Zone \(zone) must be outside the text: \(point), text: \(text)")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x - app.frame.minX, dy: point.y - app.frame.minY)).tap()
        XCTAssertFalse(app.textViews["inventory.notesEditor.editor"].waitForExistence(timeout: 1), "Zone \(zone) must stay inert; card: \(card), header: \(header), text: \(text), point: \(point), viewport: \(notesVisibleViewport)")
        XCTAssertFalse(element(identifier: "inventory.itemForm").exists)
        XCTAssertTrue(element(identifier: "inventory.itemDetail").exists)
        XCTAssertTrue(content.isHittable)
        XCTAssertEqual(content.label, expectedLabel)
    }

    func testExistingNotesEditorLifecycleSupportsDismissDiscardAndSave() {
        launchApp(); openItem(named: "USB-C to HDMI adapter"); let notesContent = app.buttons["inventory.detail.notesContent"]; scrollToElement(notesContent); XCTAssertTrue(notesContent.isHittable); XCTAssertFalse(app.buttons["inventory.detail.editNotesButton"].exists); XCTAssertFalse(app.buttons["inventory.detail.notesCard"].exists); XCTAssertFalse(app.buttons["inventory.detail.notesHeader"].exists)
        notesContent.tap(); let notesEditor = app.textViews["inventory.notesEditor.editor"]; XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); dismissNotesEditorInteractively(); XCTAssertFalse(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(element(identifier: "inventory.itemDetail").waitForExistence(timeout: 3))
        notesContent.tap(); XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); XCTAssertFalse(element(identifier: "inventory.itemForm").exists); notesEditor.tap(); notesEditor.typeText(" Updated"); let keyboard = app.keyboards.firstMatch; XCTAssertTrue(keyboard.waitForExistence(timeout: 3)); XCTAssertTrue(waitForElementAboveKeyboard(notesEditor, keyboard: keyboard, timeout: 3), "Expected detail notes editor to stay above keyboard; editor frame: \(notesEditor.frame), keyboard frame: \(keyboard.frame)"); dismissNotesEditorInteractively(); XCTAssertTrue(notesEditor.exists, "Dirty Notes editor should block interactive dismissal"); app.buttons["inventory.notesEditor.cancelButton"].tap(); XCTAssertTrue(app.buttons["inventory.notesEditor.confirmDiscardButton"].waitForExistence(timeout: 3)); tapAlertButton(identifier: "inventory.notesEditor.confirmDiscardButton"); XCTAssertFalse(notesEditor.waitForExistence(timeout: 1))
        notesContent.tap(); XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); notesEditor.tap(); notesEditor.typeText(" Saved"); app.buttons["inventory.notesEditor.saveButton"].tap(); XCTAssertFalse(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(notesContent.waitForExistence(timeout: 3)); XCTAssertTrue(notesContent.label.contains("Saved"))
    }
    func testEmptyNotesContentOpensNotesEditor() { launchApp(); let itemName = "Empty Notes \(uniqueTestSuffix())"; app.buttons["inventory.addItemButton"].tap(); let nameField = app.textFields["inventory.itemForm.nameField"]; XCTAssertTrue(nameField.waitForExistence(timeout: 3)); nameField.tap(); nameField.typeText(itemName); app.buttons["inventory.itemForm.saveButton"].tap(); resetToInventoryList(); openSearch(); let searchField = app.searchFields.firstMatch; XCTAssertTrue(searchField.waitForExistence(timeout: 3)); searchField.tap(); searchField.typeText(itemName); openItem(named: itemName); let detail = element(identifier: "inventory.itemDetail"); XCTAssertTrue(detail.waitForExistence(timeout: 3)); let notesContent = app.buttons["inventory.detail.notesContent"]; scrollToElement(notesContent); XCTAssertEqual(notesContent.label, "Notes: No notes"); XCTAssertTrue(notesContent.isHittable); notesContent.tap(); let notesEditor = app.textViews["inventory.notesEditor.editor"]; XCTAssertTrue(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(waitForKeyboardFocus(notesEditor, timeout: 3)); XCTAssertFalse(element(identifier: "inventory.itemForm").exists); let savedNotes = "Saved empty Notes \(uniqueTestSuffix())"; notesEditor.tap(); notesEditor.typeText(savedNotes); app.buttons["inventory.notesEditor.saveButton"].tap(); XCTAssertFalse(notesEditor.waitForExistence(timeout: 3)); XCTAssertTrue(detail.exists); XCTAssertTrue(notesContent.waitForExistence(timeout: 3)); XCTAssertTrue(notesContent.isHittable); XCTAssertTrue(notesContent.label.contains(savedNotes)); XCTAssertFalse(app.buttons["inventory.detail.notesCard"].exists); XCTAssertFalse(app.buttons["inventory.detail.notesHeader"].exists)
        notesContent.tap()
        XCTAssertTrue(notesEditor.waitForExistence(timeout: 3))
        XCTAssertEqual(notesEditor.value as? String, savedNotes)
        notesEditor.tap()
        notesEditor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: savedNotes.count))
        app.buttons["inventory.notesEditor.saveButton"].tap()
        XCTAssertFalse(notesEditor.waitForExistence(timeout: 3))
        XCTAssertEqual(notesContent.label, "Notes: No notes")
        notesContent.tap()
        XCTAssertTrue(notesEditor.waitForExistence(timeout: 3))
        XCTAssertEqual(notesEditor.value as? String, "")
        app.buttons["inventory.notesEditor.cancelButton"].tap()
        XCTAssertFalse(notesEditor.waitForExistence(timeout: 3))
    }
}

extension InventoryBrowseDetailUITests {
    func testEmptyLocationsShortcutsKeepAddItemAndFullManagersInLocationsStack() {
        launchStartupApp(arguments: ["--qa-empty-inventory-store"])
        XCTAssertTrue(app.buttons["locations.empty.addItemButton"].waitForExistence(timeout: 3))
        app.buttons["locations.empty.addItemButton"].tap()
        XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].waitForExistence(timeout: 3))
        app.buttons["inventory.itemForm.cancelButton"].tap()
        app.buttons["locations.addItemButton"].tap()
        XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].waitForExistence(timeout: 3))
        app.buttons["inventory.itemForm.cancelButton"].tap()

        openLocationsAction("locations.managePlaces")
        XCTAssertTrue(app.buttons["settings.places.addLocationButton"].waitForExistence(timeout: 3))
        tapBackButton()
        openLocationsAction("locations.manageLocations")
        addManagedLocation("Office")
        tapBackButton()
        XCTAssertTrue(app.buttons["locations.locationRow.Office"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Locations"].isSelected)
        XCTAssertEqual(app.buttons.matching(identifier: "locations.locationRow.Office").count, 1)
    }

    func testDirectLocationEditRenamesStableRouteAndPreservesLinkedItemContext() {
        launchStartupApp(arguments: ["--use-sample-inventory-data"])
        let renamed = "Study \(uniqueTestSuffix())"
        app.buttons["locations.locationRow.Office"].tap()
        openDirectLocationEditor()
        XCTAssertEqual(app.textFields["inventory.lists.valueField"].value as? String, "Office")
        replaceManagedLocationName(renamed)
        app.buttons["inventory.lists.locationIconPicker"].tap()
        app.buttons["locationIcons.option.kitchen"].tap()
        app.buttons["inventory.lists.saveButton"].tap()
        XCTAssertTrue(element(identifier: "locations.locationDetail").waitForExistence(timeout: 3))
        XCTAssertTrue(element(identifier: "locations.detailHero").label.contains(renamed))
        XCTAssertFalse(app.textFields["inventory.lists.valueField"].exists)
        openDirectLocationEditor()
        XCTAssertTrue(app.buttons["inventory.lists.locationIconPicker"].label.contains("Kitchen"))
        app.buttons["inventory.lists.cancelButton"].tap()

        app.buttons["locations.placeRow.Desk drawer"].tap()
        XCTAssertEqual(app.staticTexts["locations.placeDetail.path"].label, "Storage path: \(renamed), Desk drawer")
        app.buttons["locations.placeDetail.itemRow.USB-C to HDMI adapter"].tap()
        XCTAssertTrue(element(identifier: "inventory.itemDetail.hero").waitForExistence(timeout: 3))
        tapBackButton()
        tapBackButton()
        XCTAssertTrue(element(identifier: "locations.detailHero").label.contains(renamed))
        app.buttons["locations.locationDetail.addItemButton"].tap()
        XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.itemForm.locationPicker"].label.contains(renamed))
        app.buttons["inventory.itemForm.cancelButton"].tap()
        tapBackButton()
        XCTAssertEqual(app.buttons.matching(identifier: "locations.locationRow.\(renamed)").count, 1)
        XCTAssertFalse(app.buttons["locations.locationRow.Office"].exists)
    }

    func testLocationEditCancelIconOnlyAndDuplicateRetryKeepSameEditor() {
        launchStartupApp(arguments: ["--qa-empty-inventory-store"])
        openLocationsAction("locations.manageLocations")
        addManagedLocation("Kitchen")
        addManagedLocation("Office")
        tapBackButton()
        app.buttons["locations.locationRow.Office"].tap()
        openDirectLocationEditor()
        replaceManagedLocationName("Discarded")
        app.buttons["inventory.lists.locationIconPicker"].tap()
        app.buttons["locationIcons.option.kitchen"].tap()
        app.buttons["inventory.lists.cancelButton"].tap()
        XCTAssertTrue(element(identifier: "locations.detailHero").label.contains("Office"))
        openDirectLocationEditor()
        XCTAssertEqual(app.textFields["inventory.lists.valueField"].value as? String, "Office")
        XCTAssertTrue(app.buttons["inventory.lists.locationIconPicker"].label.contains("Default"))
        app.buttons["inventory.lists.locationIconPicker"].tap()
        app.buttons["locationIcons.option.kitchen"].tap()
        app.buttons["inventory.lists.saveButton"].tap()
        openDirectLocationEditor()
        XCTAssertEqual(app.textFields["inventory.lists.valueField"].value as? String, "Office")
        XCTAssertTrue(app.buttons["inventory.lists.locationIconPicker"].label.contains("Kitchen"))
        replaceManagedLocationName("   ")
        XCTAssertFalse(app.buttons["inventory.lists.saveButton"].isEnabled)
        replaceManagedLocationName("Kitchen")
        app.buttons["inventory.lists.saveButton"].tap()
        XCTAssertTrue(app.alerts["Name Already Exists"].waitForExistence(timeout: 3))
        app.alerts.buttons["OK"].tap()
        XCTAssertEqual(app.textFields["inventory.lists.valueField"].value as? String, "Kitchen")
        XCTAssertTrue(app.buttons["inventory.lists.locationIconPicker"].label.contains("Kitchen"))
        replaceManagedLocationName("Study")
        app.buttons["inventory.lists.saveButton"].tap()
        XCTAssertTrue(element(identifier: "locations.detailHero").label.contains("Study"))
        tapBackButton()
        XCTAssertTrue(app.buttons["locations.locationRow.Kitchen"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "locations.locationRow.Study").count, 1)
        XCTAssertFalse(app.buttons["locations.locationRow.Office"].exists)
    }

    func testMissingLocationHasNoManagementMenuAndKeepsAddItemAvailable() {
        launchStartupApp(arguments: ["--qa-empty-inventory-store"])
        app.buttons["locations.addItemButton"].tap()
        let name = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Unsorted cable")
        app.buttons["inventory.itemForm.saveButton"].tap()
        let missing = app.buttons["locations.locationRow.No location"]
        XCTAssertTrue(missing.waitForExistence(timeout: 3))
        missing.tap()
        XCTAssertTrue(element(identifier: "locations.locationDetail").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["locations.locationDetail.managementMenu"].exists)
        app.buttons["locations.locationDetail.addItemButton"].tap()
        XCTAssertTrue(app.textFields["inventory.itemForm.nameField"].waitForExistence(timeout: 3))
        app.buttons["inventory.itemForm.cancelButton"].tap()
        tapBackButton()
        openLocationsAction("locations.manageLocations")
        XCTAssertTrue(app.staticTexts["No reusable locations yet."].waitForExistence(timeout: 3))
    }

    func testLocationManagementShortcutsReuseGlobalDirectoryAndReturnToTheirSource() {
        launchStartupApp(arguments: ["--use-sample-inventory-data", "--qa-place-management-fixture"])
        openLocationsAction("locations.managePlaces")
        assertFullPlaceDirectory()
        tapBackButton()
        app.buttons["locations.locationRow.Office"].tap()
        app.buttons["locations.locationDetail.managementMenu"].tap()
        app.buttons["locations.locationDetail.managePlaces"].tap()
        assertFullPlaceDirectory()
        tapBackButton()
        XCTAssertTrue(element(identifier: "locations.detailHero").label.contains("Office"))
        XCTAssertTrue(app.tabBars.buttons["Locations"].isSelected)
        app.tabBars.buttons["Settings"].tap()
        tapVisibleButton(identifier: "settings.lists.placesLink")
        assertFullPlaceDirectory()
    }

    private func openLocationsAction(_ identifier: String) {
        let menu = app.buttons["locations.managementMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        XCTAssertEqual(menu.label, "Location actions")
        menu.tap()
        app.buttons[identifier].tap()
    }

    private func openDirectLocationEditor() {
        let menu = app.buttons["locations.locationDetail.managementMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        app.buttons["locations.locationDetail.editLocation"].tap()
        XCTAssertTrue(app.textFields["inventory.lists.valueField"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["inventory.lists.addLocationButton"].isHittable)
    }

    private func addManagedLocation(_ name: String) {
        tapVisibleButton(identifier: "inventory.lists.addLocationButton")
        let field = app.textFields["inventory.lists.valueField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(name)
        app.buttons["inventory.lists.saveButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
    }

    private func replaceManagedLocationName(_ name: String) {
        let field = app.textFields["inventory.lists.valueField"]
        field.tap()
        let value = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count) + name)
    }

    private func assertFullPlaceDirectory() {
        XCTAssertTrue(app.buttons["settings.places.addButton"].waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "settings.places.locationHeader.")
        ).count, 2)
        XCTAssertTrue(app.staticTexts["Shared box"].firstMatch.exists)
    }
}
