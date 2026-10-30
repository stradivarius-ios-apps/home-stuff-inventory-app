import XCTest

@MainActor
final class RecentItemsTileLayoutUITests: XCTestCase {
    private enum Fixture {
        static let launchArgument = "--qa-recent-items-layout-fixture"
        static let locationName = "Recent Items Test Location"
        static let placeName = "Recent Items Test Place"
        static let items = [
            (id: "B1F0A001-EE01-4E10-9000-000000000001", name: "Recent layout item one"),
            (id: "B1F0A001-EE01-4E10-9000-000000000002", name: "Recent layout item two"),
            (id: "B1F0A001-EE01-4E10-9000-000000000003", name: "Recent layout item three")
        ]
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLocationRecentItemsUseFullWidthShelfRowsAndNavigate() {
        launchApp()
        openFixtureLocation()

        let tiles = recentItemTiles(in: locationRecentItems)
        assertStandardThreeShelfRowGeometry(tiles, in: locationRecentItems)
        assertOverflowSummary(in: locationRecentItems)

        let expectedItem = Fixture.items[2]
        let thirdTile = locationRecentItems.buttons[recentItemIdentifier(for: expectedItem.id)]
        XCTAssertTrue(thirdTile.isHittable)
        thirdTile.tap()
        assertItemDetail(for: expectedItem.name)
    }

    func testLocationRecentItemsShelfAlignsWithStoragePlaceCardInLightAndDarkAppearance() {
        assertLocationRecentItemsShelfAlignment(appearanceArgument: nil)
        assertLocationRecentItemsShelfAlignment(appearanceArgument: "--qa-force-dark-appearance")
    }

    func testPlaceRecentItemsUseFullWidthShelfRowsAndNavigate() {
        launchApp(itemCount: 5)
        openFixturePlace()

        let tiles = recentItemTiles(in: placeRecentItems)
        assertStandardThreeShelfRowGeometry(tiles, in: placeRecentItems)
        assertOverflowSummary(in: placeRecentItems)

        let expectedItem = Fixture.items[2]
        let thirdTile = placeRecentItems.buttons[recentItemIdentifier(for: expectedItem.id)]
        XCTAssertTrue(thirdTile.isHittable)
        thirdTile.tap()
        assertItemDetail(for: expectedItem.name)
    }

    func testRealLeafRetainsPathAndRecentItemsBeforeDirectList() {
        launchApp(itemCount: 5)
        openFixturePlace()
        let path = app.staticTexts["locations.placeDetail.path"]
        let heading = element(identifier: "locations.placeDetail.itemsSectionHeader")
        XCTAssertEqual(path.label, "Storage path: Recent Items Test Location, Recent Items Test Place")
        XCTAssertEqual(heading.label, "Items")
        XCTAssertFalse(element(identifier: "locations.placeDetail.countSummary").exists)
        XCTAssertLessThan(app.otherElements["locations.placeDetailHero"].frame.maxY, path.frame.minY)
        XCTAssertLessThan(path.frame.maxY, placeRecentItems.frame.minY)
        XCTAssertLessThan(placeRecentItems.frame.maxY, heading.frame.minY)
        let tiles = recentItemTiles(in: placeRecentItems)
        XCTAssertEqual(tiles.allElementsBoundByIndex.map(\.identifier), Fixture.items.map { recentItemIdentifier(for: $0.id) })
        assertStandardThreeShelfRowGeometry(tiles, in: placeRecentItems)
        assertOverflowSummary(in: placeRecentItems)
        let direct = app.buttons["locations.placeDetail.itemRow.Recent layout item four"]
        XCTAssertLessThan(heading.frame.maxY, direct.frame.minY)
        XCTAssertEqual(direct.label, "Recent layout item four, Miscellaneous, Quantity 1")
        for expected in Fixture.items {
            let tile = placeRecentItems.buttons[recentItemIdentifier(for: expected.id)]
            scrollToHittable(tile, in: placeDetail)
            tile.tap()
            assertItemDetail(for: expected.name)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(placeDetail.waitForExistence(timeout: 3))
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let allItems = app.buttons["Show all items in Recent Items Test Location"]
        scrollToHittable(allItems, in: locationDetail)
        allItems.tap()
        let allLocationRow = app.buttons["inventory.itemRow.Recent layout item one"]
        scrollToHittable(allLocationRow, in: app.scrollViews["locations.scopedItemList"])
        XCTAssertEqual(allLocationRow.label,
                       "Recent layout item one, Recent Items Test Location, Recent Items Test Place, Miscellaneous, Quantity 1")
    }

    func testRealLeafVisualConfigurations() {
        let configurations: [(String, String, Int, Int, String)] = [
            ("en", "light", 5, 3, "UICTContentSizeCategoryL"),
            ("uk", "light", 5, 3, "UICTContentSizeCategoryL"),
            ("en", "light", 5, 4, "UICTContentSizeCategoryL"),
            ("uk", "dark", 5, 4, "UICTContentSizeCategoryL"),
            ("en", "dark", 4, 4, "UICTContentSizeCategoryL"),
            ("uk", "light", 4, 4, "UICTContentSizeCategoryL"),
            ("en", "light", 5, 0, "UICTContentSizeCategoryL"),
            ("uk", "dark", 5, 4, "UICTContentSizeCategoryAccessibilityXXXL")
        ]
        for (locale, appearance, count, history, size) in configurations {
            launchApp(locale: locale, contentSizeCategory: size, itemCount: count,
                      appearanceArgument: "--qa-force-\(appearance)-appearance", historyCount: history,
                      additionalArguments: size.hasSuffix("XXXL")
                        ? ["--qa-reduce-motion", "--qa-reduce-transparency", "--qa-increase-contrast"] : [])
            openFixturePlace(expectRecentItems: count >= 5 && history > 0, expectLocationRecentItems: history > 0)
            let name = "\(locale)-\(appearance)-items\(count)-history\(history)-\(size)"
            captureEvidence(name + "-top")
            let path = app.staticTexts["locations.placeDetail.path"]
            XCTAssertTrue(path.isHittable)
            XCTAssertEqual(path.label, (locale == "uk" ? "Шлях зберігання: " : "Storage path: ")
                           + "Recent Items Test Location, Recent Items Test Place")
            XCTAssertEqual(placeRecentItems.exists, count >= 5 && history > 0)
            if count >= 5 && history > 0 {
                let third = placeRecentItems.buttons[recentItemIdentifier(for: Fixture.items[2].id)]
                scrollToHittable(third, in: placeDetail)
                captureEvidence(name + "-recent")
            }
            let direct = app.buttons["locations.placeDetail.itemRow.Recent layout item four"]
            scrollToHittable(direct, in: placeDetail)
            XCTAssertGreaterThanOrEqual(direct.frame.height, 44)
            captureEvidence(name + "-direct")
            app.terminate()
        }
    }

    func testLongRealLeafWrapsInUkrainianAccessibilityDarkAppearance() {
        let locationName = "Домашній кабінет із довгою назвою для родинних речей і запасних аксесуарів"
        let placeName = "Верхня шухляда великої шафи з кабелями, зарядними пристроями та перехідниками"
        let itemName = "Комплект запасних кабелів і перехідників для сімейних подорожей — Recent layout item four"
        launchApp(locale: "uk", contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
                  appearanceArgument: "--qa-force-dark-appearance", additionalArguments: [
                    "--qa-recent-items-layout-fixture-long-names", "--qa-reduce-motion",
                    "--qa-reduce-transparency", "--qa-increase-contrast"
                  ])
        let location = app.buttons["locations.locationRow.\(locationName)"]
        scrollToHittable(location, in: locationsList)
        location.tap()
        let place = app.buttons["locations.placeRow.\(placeName)"]
        scrollToHittable(place, in: locationDetail)
        place.tap()
        XCTAssertTrue(placeDetail.waitForExistence(timeout: 3))
        captureEvidence("uk-dark-long-names-accessibility-top")
        let path = app.staticTexts["locations.placeDetail.path"]
        XCTAssertEqual(path.label, "Шлях зберігання: \(locationName), \(placeName)")
        scrollToHittable(path, in: placeDetail)
        captureEvidence("uk-dark-long-names-accessibility-path")
        let recent = placeRecentItems.buttons[recentItemIdentifier(for: Fixture.items[2].id)]
        scrollToHittable(recent, in: placeDetail)
        XCTAssertGreaterThanOrEqual(recent.frame.height, 44)
        captureEvidence("uk-dark-long-names-accessibility-recent")
        let row = app.buttons["locations.placeDetail.itemRow.\(itemName)"]
        scrollToHittable(row, in: placeDetail)
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        XCTAssertGreaterThanOrEqual(row.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
        XCTAssertFalse(row.label.contains(locationName))
        XCTAssertTrue(row.label.contains("Кабелі, зарядні пристрої та різноманітні запасні аксесуари для подорожей"))
        captureEvidence("uk-dark-long-names-accessibility-direct")
        row.tap()
        assertItemDetail(for: itemName)
    }

    func testOneAndZeroRealLeafKeepContextAndAddPrefillInBothLanguages() {
        for locale in ["en", "uk"] {
            launchApp(locale: locale, itemCount: 1, historyCount: 0)
            openFixturePlace(expectRecentItems: false, expectLocationRecentItems: false)
            let row = app.buttons["locations.placeDetail.itemRow.Recent layout item one"]
            XCTAssertTrue(row.isHittable)
            XCTAssertFalse(row.label.contains(Fixture.locationName))
            captureEvidence("\(locale)-one-item")
            row.tap()
            let delete = app.buttons["inventory.deleteItemButton"]
            scrollToHittable(delete, in: itemDetail)
            delete.tap()
            let confirm = app.buttons["inventory.confirmDeleteButton"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 3))
            confirm.tap()
            XCTAssertTrue(app.otherElements["locations.placeDetailHero"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["locations.placeDetail.path"].isHittable)
            XCTAssertFalse(element(identifier: "locations.placeDetail.countSummary").exists)
            XCTAssertTrue(app.otherElements["locations.placeDetailHero"].label.contains(locale == "uk" ? "0 речей" : "0 items"))
            captureEvidence("\(locale)-zero-items")
            app.buttons["locations.placeDetail.addItemButton"].tap()
            let locationPicker = app.buttons["inventory.itemForm.locationPicker"]
            XCTAssertTrue(locationPicker.waitForExistence(timeout: 3))
            XCTAssertTrue(locationPicker.label.contains(Fixture.locationName))
            XCTAssertTrue(app.buttons["inventory.itemForm.containerPicker"].label.contains(Fixture.placeName))
            app.buttons["inventory.itemForm.cancelButton"].tap()
            app.terminate()
        }
    }

    private func captureEvidence(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFourItemPlaceDoesNotExposeRecentItems() {
        launchApp(itemCount: 4)
        openFixturePlace(expectRecentItems: false)

        XCTAssertFalse(placeRecentItems.exists)
        let expectedItemIdentifiers = [
            "locations.placeDetail.itemRow.Recent layout item four",
            "locations.placeDetail.itemRow.Recent layout item one",
            "locations.placeDetail.itemRow.Recent layout item three",
            "locations.placeDetail.itemRow.Recent layout item two"
        ]
        let completeListItemIdentifiers = placeDetail.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "locations.placeDetail.itemRow."))
            .allElementsBoundByIndex
            .map(\.identifier)
        XCTAssertEqual(completeListItemIdentifiers, expectedItemIdentifiers)

        let completeListItem = app.buttons["locations.placeDetail.itemRow.Recent layout item four"]
        scrollToHittable(completeListItem, in: placeDetail)
        XCTAssertTrue(completeListItem.isHittable)
    }

    func testAccessibilityDynamicTypeKeepsFiveItemPlaceRecentItemsNavigable() {
        launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL", itemCount: 5)
        openFixturePlace()

        let item = Fixture.items[2]
        let tile = placeRecentItems.buttons[recentItemIdentifier(for: item.id)]
        scrollToHittable(tile, in: placeDetail)
        XCTAssertGreaterThanOrEqual(tile.frame.height, 44)
        tile.tap()
        assertItemDetail(for: item.name)
    }

    func testAccessibilityDynamicTypeReachesAndActivatesEveryLocationRecentTile() {
        launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        openFixtureLocation()

        let tiles = recentItemTiles(in: locationRecentItems)
        XCTAssertEqual(tiles.count, 3, "Expected exactly three visible Recent item tiles.")
        let expectedItems = Fixture.items.map { (identifier: recentItemIdentifier(for: $0.id), name: $0.name) }

        for expectedItem in expectedItems {
            let tile = locationRecentItems.buttons[expectedItem.identifier]
            scrollToHittable(tile, in: locationDetail)
            XCTAssertGreaterThanOrEqual(tile.frame.height, 44, "Expected \(expectedItem.identifier) to retain a 44-point hit target.")
            XCTAssertEqual(
                tile.frame.minX,
                locationRecentItems.frame.minX,
                accuracy: 24,
                "Expected \(expectedItem.identifier) to use the full-width accessibility row layout."
            )
            XCTAssertGreaterThanOrEqual(
                tile.frame.width,
                locationRecentItems.frame.width - 48,
                "Expected \(expectedItem.identifier) to use the full-width accessibility row layout."
            )

            tile.tap()
            assertItemDetail(for: expectedItem.name)
            tapBackToLocationDetail()
        }
    }

    func testLocationDetailPlacesFollowRecentItemsCard() {
        launchApp()
        openFixtureLocation()

        let hero = app.otherElements["locations.detailHero"]
        let placesHeader = element(identifier: "locations.placesSectionHeader")
        let place = app.buttons["locations.placeRow.\(Fixture.placeName)"]

        XCTAssertTrue(hero.exists)
        XCTAssertTrue(locationRecentItems.exists)
        XCTAssertFalse(element(identifier: "locations.itemsAccess").exists)
        XCTAssertTrue(placesHeader.exists)
        XCTAssertTrue(place.exists)
        XCTAssertLessThan(hero.frame.maxY, locationRecentItems.frame.minY)
        XCTAssertLessThan(locationRecentItems.frame.maxY, placesHeader.frame.minY)
        XCTAssertLessThan(placesHeader.frame.maxY, place.frame.minY)
    }

    func testLocationDetailUsesAllItemsAccessWhenRecentItemsAreAbsent() {
        launchStandardApp()

        let location = app.buttons["locations.locationRow.Office"]
        scrollToHittable(location, in: locationsList)
        location.tap()

        let hero = app.otherElements["locations.detailHero"]
        let allItemsAccess = element(identifier: "locations.itemsAccess")
        let placesHeader = element(identifier: "locations.placesSectionHeader")
        let place = app.buttons["locations.placeRow.Desk drawer"]

        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(allItemsAccess.exists)
        XCTAssertFalse(locationRecentItems.exists)
        XCTAssertTrue(placesHeader.exists)
        XCTAssertTrue(place.exists)
        XCTAssertLessThan(hero.frame.maxY, allItemsAccess.frame.minY)
        XCTAssertLessThan(allItemsAccess.frame.maxY, placesHeader.frame.minY)
        XCTAssertLessThan(placesHeader.frame.maxY, place.frame.minY)

        let allItemsButton = app.buttons["Show all items in Office"]
        XCTAssertTrue(allItemsButton.waitForExistence(timeout: 3))
        allItemsButton.tap()
        XCTAssertTrue(app.scrollViews["locations.scopedItemList"].waitForExistence(timeout: 3))
    }

    func testLocationDetailPlacesEmptyStateFollowsHeader() {
        launchEmptyLocationFixture()

        let location = app.buttons["locations.locationRow.Empty Location Test"]
        scrollToHittable(location, in: locationsList)
        location.tap()

        let hero = app.otherElements["locations.detailHero"]
        let allItemsAccess = element(identifier: "locations.itemsAccess")
        let placesHeader = element(identifier: "locations.placesSectionHeader")
        let emptyState = element(identifier: "locations.placesEmptyState")

        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertFalse(allItemsAccess.exists)
        XCTAssertFalse(locationRecentItems.exists)
        XCTAssertTrue(placesHeader.exists)
        XCTAssertTrue(emptyState.exists)
        let addItem = app.buttons["locations.placesEmptyState.addItemButton"]
        XCTAssertTrue(addItem.exists)
        XCTAssertLessThan(hero.frame.maxY, placesHeader.frame.minY)
        XCTAssertLessThan(placesHeader.frame.maxY, emptyState.frame.minY)
        XCTAssertFalse(emptyState.frame.isEmpty)
        XCTAssertGreaterThanOrEqual(addItem.frame.height, 44)
        addItem.tap()
        let locationPicker = app.buttons["inventory.itemForm.locationPicker"]
        XCTAssertTrue(locationPicker.waitForExistence(timeout: 3))
        XCTAssertTrue(locationPicker.label.contains("Empty Location Test"))
    }

    func testLocationDetailCompositionFitsUkrainianAccessibilityInDarkAppearance() {
        launchApp(
            locale: "uk",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            appearanceArgument: "--qa-force-dark-appearance"
        )

        let location = app.buttons["locations.locationRow.\(Fixture.locationName)"]
        scrollToHittable(location, in: locationsList)
        location.tap()

        let hero = app.otherElements["locations.detailHero"]
        let recentItemsShelf = locationRecentItemsShelf
        let placesHeader = element(identifier: "locations.placesSectionHeader")
        let place = app.buttons["locations.placeRow.\(Fixture.placeName)"]

        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(locationRecentItems.exists)
        XCTAssertTrue(recentItemsShelf.exists)
        XCTAssertFalse(element(identifier: "locations.itemsAccess").exists)
        XCTAssertTrue(placesHeader.exists)
        XCTAssertTrue(place.exists)
        XCTAssertLessThan(hero.frame.maxY, locationRecentItems.frame.minY)
        XCTAssertLessThan(locationRecentItems.frame.maxY, placesHeader.frame.minY)
        XCTAssertLessThan(placesHeader.frame.maxY, place.frame.minY)
        XCTAssertGreaterThanOrEqual(place.frame.height, 44)
        XCTAssertGreaterThanOrEqual(place.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(place.frame.maxX, app.frame.maxX)
        XCTAssertEqual(recentItemsShelf.frame.minX, place.frame.minX, accuracy: 2)
        XCTAssertEqual(recentItemsShelf.frame.maxX, place.frame.maxX, accuracy: 2)
    }

    func testLocationDetailWithReduceMotionKeepsCompositionVisible() {
        assertLocationDetailAccessibilityMode(
            argument: "--qa-reduce-motion",
            marker: "qa.accessibility.reduceMotion",
            name: "reduce-motion"
        )
    }

    func testLocationDetailWithReduceTransparencyKeepsCompositionVisible() {
        assertLocationDetailAccessibilityMode(
            argument: "--qa-reduce-transparency",
            marker: "qa.accessibility.reduceTransparency",
            name: "reduce-transparency"
        )
    }

    func testLocationDetailWithIncreaseContrastKeepsCompositionVisible() {
        assertLocationDetailAccessibilityMode(
            argument: "--qa-increase-contrast",
            marker: "qa.accessibility.increaseContrast",
            name: "increase-contrast"
        )
    }

    func testDifferentiateWithoutColorKeepsItemLocationAndPlaceContextDistinct() {
        launchApp(accessibilityArgument: "--qa-differentiate-without-color")
        XCTAssertTrue(element(identifier: "qa.accessibility.differentiateWithoutColor").waitForExistence(timeout: 3))

        openFixtureLocation()
        let locationHero = app.otherElements["locations.detailHero"]
        XCTAssertTrue(locationHero.label.contains(Fixture.locationName))
        XCTAssertEqual(locationHero.elementType, .other)
        let locationHeroIdentifier = locationHero.identifier

        let placeRow = app.buttons["locations.placeRow.\(Fixture.placeName)"]
        scrollToHittable(placeRow, in: locationDetail)
        XCTAssertTrue(placeRow.label.contains(Fixture.placeName))
        XCTAssertEqual(placeRow.elementType, .button)
        XCTAssertGreaterThanOrEqual(placeRow.frame.height, 44)
        XCTAssertLessThan(locationHero.frame.maxY, locationRecentItems.frame.minY)
        XCTAssertLessThan(locationRecentItems.frame.maxY, placeRow.frame.minY)
        placeRow.tap()

        let placeHero = app.otherElements["locations.placeDetailHero"]
        XCTAssertTrue(placeHero.waitForExistence(timeout: 3))
        XCTAssertTrue(placeHero.label.contains(Fixture.placeName))
        XCTAssertTrue(placeHero.label.contains(Fixture.locationName))
        let placeHeroIdentifier = placeHero.identifier

        scrollUntilVisible(placeRecentItems, in: placeDetail)
        let expectedItem = Fixture.items[0]
        let itemTile = placeRecentItems.buttons[recentItemIdentifier(for: expectedItem.id)]
        scrollToHittable(itemTile, in: placeDetail)
        XCTAssertTrue(itemTile.label.contains(expectedItem.name))
        XCTAssertEqual(itemTile.elementType, .button)
        XCTAssertGreaterThanOrEqual(itemTile.frame.height, 44)
        itemTile.tap()
        assertItemDetail(for: expectedItem.name)
        XCTAssertEqual(itemDetailHero.elementType, .other)

        XCTAssertNotEqual(locationHeroIdentifier, placeHeroIdentifier)
        XCTAssertNotEqual(placeHeroIdentifier, itemDetailHero.identifier)
    }

    private func assertLocationDetailAccessibilityMode(argument: String, marker: String, name: String) {
        launchApp(accessibilityArgument: argument)
        XCTAssertTrue(element(identifier: marker).waitForExistence(timeout: 3))
        openFixtureLocation()

        let hero = app.otherElements["locations.detailHero"]
        let placesHeader = element(identifier: "locations.placesSectionHeader")
        let place = app.buttons["locations.placeRow.\(Fixture.placeName)"]

        XCTAssertTrue(hero.exists)
        XCTAssertTrue(locationRecentItems.exists)
        XCTAssertTrue(placesHeader.exists)
        XCTAssertTrue(place.exists)
        XCTAssertLessThan(hero.frame.maxY, locationRecentItems.frame.minY)
        XCTAssertLessThan(locationRecentItems.frame.maxY, placesHeader.frame.minY)
        XCTAssertLessThan(placesHeader.frame.maxY, place.frame.minY)

        scrollToHittable(place, in: locationDetail)
        XCTAssertGreaterThanOrEqual(place.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(place.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(place.frame.height, 44)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "location-detail-\(name)"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    private func launchApp(
        locale: String = "en",
        contentSizeCategory: String = "UICTContentSizeCategoryL",
        itemCount: Int = 5,
        accessibilityArgument: String? = nil,
        appearanceArgument: String? = nil,
        historyCount: Int = 4,
        additionalArguments: [String] = []
    ) {
        app = XCUIApplication()
        app.launchArguments = [
            "--use-sample-inventory-data",
            Fixture.launchArgument,
            "--qa-recent-items-layout-fixture-count", "\(itemCount)",
            "--qa-recent-items-layout-fixture-history-count", "\(historyCount)",
            "-AppleLanguages", "(\(locale))",
            "-AppleLocale", locale == "uk" ? "uk_UA" : "en_US",
            "-UIPreferredContentSizeCategoryName", contentSizeCategory
        ]
        if let accessibilityArgument {
            app.launchArguments.append(accessibilityArgument)
        }
        if let appearanceArgument {
            app.launchArguments.append(appearanceArgument)
        }
        app.launchArguments += additionalArguments
        app.launch()
        XCTAssertTrue(locationsList.waitForExistence(timeout: 5), "Expected Locations root after fixture launch.")
    }

    private func launchStandardApp(
        locale: String = "en",
        contentSizeCategory: String = "UICTContentSizeCategoryL",
        appearanceArgument: String? = nil
    ) {
        app = XCUIApplication()
        app.launchArguments = [
            "--use-sample-inventory-data",
            "-AppleLanguages", "(\(locale))",
            "-AppleLocale", locale == "uk" ? "uk_UA" : "en_US",
            "-UIPreferredContentSizeCategoryName", contentSizeCategory
        ]
        if let appearanceArgument {
            app.launchArguments.append(appearanceArgument)
        }
        app.launch()
        XCTAssertTrue(locationsList.waitForExistence(timeout: 5), "Expected Locations root after sample launch.")
    }

    private func launchEmptyLocationFixture() {
        app = XCUIApplication()
        app.launchArguments = [
            "--use-sample-inventory-data",
            "--qa-location-detail-empty-fixture",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
        ]
        app.launch()
        XCTAssertTrue(locationsList.waitForExistence(timeout: 5), "Expected Locations root after empty fixture launch.")
    }

    private func openFixtureLocation(expectRecentItems: Bool = true) {
        let location = app.buttons["locations.locationRow.\(Fixture.locationName)"]
        scrollToHittable(location, in: locationsList)
        location.tap()
        XCTAssertTrue(locationDetail.waitForExistence(timeout: 3), "Expected fixture Location Detail.")
        if expectRecentItems {
            scrollUntilVisible(locationRecentItems, in: locationDetail)
        }
    }

    private func openFixturePlace(expectRecentItems: Bool = true, expectLocationRecentItems: Bool = true) {
        openFixtureLocation(expectRecentItems: expectLocationRecentItems)
        let place = app.buttons["locations.placeRow.\(Fixture.placeName)"]
        scrollToHittable(place, in: locationDetail)
        place.tap()
        XCTAssertTrue(placeDetail.waitForExistence(timeout: 3), "Expected fixture Place Detail.")
        if expectRecentItems {
            scrollUntilVisible(placeRecentItems, in: placeDetail)
        }
    }

    private func assertStandardThreeShelfRowGeometry(_ tiles: XCUIElementQuery, in section: XCUIElement) {
        XCTAssertEqual(tiles.count, 3, "Expected exactly three visible Recent Item shelf rows.")

        let first = tiles.element(boundBy: 0)
        let second = tiles.element(boundBy: 1)
        let third = tiles.element(boundBy: 2)

        XCTAssertLessThan(first.frame.maxY, second.frame.minY, "First shelf row should be above the second without overlap.")
        XCTAssertLessThan(second.frame.maxY, third.frame.minY, "Second shelf row should be above the third without overlap.")

        for row in [first, second, third] {
            XCTAssertEqual(row.frame.minX, first.frame.minX, accuracy: 8, "Shelf rows should share a leading edge.")
            XCTAssertEqual(row.frame.width, first.frame.width, accuracy: 12, "Shelf rows should have equal widths.")
            XCTAssertGreaterThanOrEqual(row.frame.height, 59.5, "Shelf rows should retain a 60-point hit target.")
            XCTAssertGreaterThanOrEqual(
                row.frame.width,
                section.frame.width - 48,
                "Shelf rows should remain full-width within the Recent Items section."
            )
        }
    }

    private func assertLocationRecentItemsShelfAlignment(appearanceArgument: String?) {
        launchApp(appearanceArgument: appearanceArgument)
        openFixtureLocation()

        let place = app.buttons["locations.placeRow.\(Fixture.placeName)"]
        let recentItemsShelf = locationRecentItemsShelf

        scrollToHittable(place, in: locationDetail)
        XCTAssertTrue(recentItemsShelf.exists)
        XCTAssertEqual(recentItemsShelf.frame.minX, place.frame.minX, accuracy: 2)
        XCTAssertEqual(recentItemsShelf.frame.maxX, place.frame.maxX, accuracy: 2)
    }

    private func assertOverflowSummary(in section: XCUIElement) {
        let overflowSummary = section.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "1 more"))
            .firstMatch
        XCTAssertTrue(overflowSummary.waitForExistence(timeout: 3), "Expected the one-hidden-item overflow summary.")
    }

    private func assertItemDetail(for expectedName: String) {
        XCTAssertTrue(itemDetail.waitForExistence(timeout: 3), "Expected Item Detail for \(expectedName).")
        XCTAssertTrue(itemDetailHero.label.contains(expectedName), "Expected Item Detail hero for \(expectedName), got \(itemDetailHero.label).")
    }

    private func tapBackToLocationDetail() {
        if let backButton = app.navigationBars.allElementsBoundByIndex.reversed().first(where: { navigationBar in
            let candidate = navigationBar.buttons["BackButton"]
            return candidate.exists && candidate.isHittable
        }).map({ $0.buttons["BackButton"] }) {
            backButton.tap()
        } else {
            let navigationBackButton = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(navigationBackButton.waitForExistence(timeout: 3), "Expected Item Detail back navigation.")
            navigationBackButton.tap()
        }
        XCTAssertTrue(locationDetail.waitForExistence(timeout: 3), "Expected fixture Location Detail after returning from Item Detail.")
    }

    private func scrollToHittable(_ element: XCUIElement, in container: XCUIElement) {
        XCTAssertTrue(container.waitForExistence(timeout: 3), "Expected scroll container \(container.identifier).")
        for _ in 0..<8 {
            if element.isHittable {
                return
            }
            container.swipeUp()
        }
        XCTFail(
            "Expected \(element.identifier) to become hittable in \(container.identifier); " +
                "exists=\(element.exists), frame=\(element.frame)."
        )
    }

    private func scrollUntilVisible(_ element: XCUIElement, in container: XCUIElement) {
        XCTAssertTrue(container.waitForExistence(timeout: 3), "Expected scroll container \(container.identifier).")
        for _ in 0..<8 {
            if element.exists, !element.frame.isEmpty {
                return
            }
            container.swipeUp()
        }
        XCTFail(
            "Expected visible \(element.identifier) in \(container.identifier); " +
                "exists=\(element.exists), frame=\(element.frame)."
        )
    }

    private func recentItemTiles(in section: XCUIElement) -> XCUIElementQuery {
        section.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "locations.recentItems.item."))
    }

    private func recentItemIdentifier(for itemID: String) -> String {
        "locations.recentItems.item.\(itemID)"
    }

    private var locationsList: XCUIElement { element(identifier: "locations.list") }
    private var locationDetail: XCUIElement { element(identifier: "locations.locationDetail") }
    private var locationRecentItems: XCUIElement { app.otherElements["locations.recentItems"] }
    private var locationRecentItemsShelf: XCUIElement { app.otherElements["locations.recentItems.shelf"] }
    private var placeDetail: XCUIElement { element(identifier: "locations.placeDetail.itemList") }
    private var placeRecentItems: XCUIElement { app.otherElements["locations.placeRecentItems"] }
    private var itemDetail: XCUIElement { element(identifier: "inventory.itemDetail") }
    private var itemDetailHero: XCUIElement { element(identifier: "inventory.itemDetail.hero") }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
