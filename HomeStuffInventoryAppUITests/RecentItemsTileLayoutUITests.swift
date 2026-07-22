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
        let placesHeader = element(identifier: "locations.placesSectionHeader")
        let place = app.buttons["locations.placeRow.\(Fixture.placeName)"]

        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        XCTAssertTrue(locationRecentItems.exists)
        XCTAssertFalse(element(identifier: "locations.itemsAccess").exists)
        XCTAssertTrue(placesHeader.exists)
        XCTAssertTrue(place.exists)
        XCTAssertLessThan(hero.frame.maxY, locationRecentItems.frame.minY)
        XCTAssertLessThan(locationRecentItems.frame.maxY, placesHeader.frame.minY)
        XCTAssertLessThan(placesHeader.frame.maxY, place.frame.minY)
        XCTAssertGreaterThanOrEqual(place.frame.height, 44)
        XCTAssertGreaterThanOrEqual(place.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(place.frame.maxX, app.frame.maxX)
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
        appearanceArgument: String? = nil
    ) {
        app = XCUIApplication()
        app.launchArguments = [
            "--use-sample-inventory-data",
            Fixture.launchArgument,
            "--qa-recent-items-layout-fixture-count", "\(itemCount)",
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

    private func openFixtureLocation() {
        let location = app.buttons["locations.locationRow.\(Fixture.locationName)"]
        scrollToHittable(location, in: locationsList)
        location.tap()
        XCTAssertTrue(locationDetail.waitForExistence(timeout: 3), "Expected fixture Location Detail.")
        scrollUntilVisible(locationRecentItems, in: locationDetail)
    }

    private func openFixturePlace(expectRecentItems: Bool = true) {
        openFixtureLocation()
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
    private var placeDetail: XCUIElement { element(identifier: "locations.placeDetail.itemList") }
    private var placeRecentItems: XCUIElement { app.otherElements["locations.placeRecentItems"] }
    private var itemDetail: XCUIElement { element(identifier: "inventory.itemDetail") }
    private var itemDetailHero: XCUIElement { element(identifier: "inventory.itemDetail.hero") }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
