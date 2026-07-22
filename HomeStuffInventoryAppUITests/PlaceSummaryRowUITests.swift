import XCTest

@MainActor
final class PlaceSummaryRowUITests: XCTestCase {
    private static let longPlaceName = "Clear hardware drawer with an unusually long descriptive label"
    private static let longItemName = "Довгий комплект дрібних кабелів, зарядних пристроїв і перехідників для сімейних подорожей"
    private let app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchArguments = [
            "--use-sample-inventory-data",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        if name.contains("testLongPlaceNameKeepsCountChevronAndFullRowNavigation")
            || name.contains("testLongItemNameRemainsReachableAtAccessibilityDynamicType") {
            app.launchArguments += ["--use-long-place-fixture"]
        }
        if name.contains("testLocationCardPopularityDoesNotChangeLocationDetailPlaceOrder") {
            app.launchArguments += ["--qa-place-popularity-fixture"]
        }
        if name.contains("testAdaptiveCategory") {
            app.launchArguments += ["--qa-place-category-fixture"]
        }
        if name.contains("testPlaceRowRemainsNavigableAtAccessibilityDynamicType") {
            app.launchArguments += ["--qa-place-category-fixture"]
        }
        if name.contains("Ukrainian") {
            app.launchArguments = [
                "--use-sample-inventory-data",
                "-AppleLanguages", "(uk)",
                "-AppleLocale", "uk_UA",
                "--qa-place-category-fixture"
            ]
        }
        let contentSizeCategory = name.contains("testPlaceRowRemainsNavigableAtAccessibilityDynamicType")
            || name.contains("testLongItemNameRemainsReachableAtAccessibilityDynamicType")
            || name.contains("testAdaptiveCategoryAtAccessibilityDynamicType")
            ? "UICTContentSizeCategoryAccessibilityXXXL"
            : "UICTContentSizeCategoryL"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        app.launch()
        let locationsTabExists = app.tabBars.buttons[locationsTabName].waitForExistence(timeout: 3)
        XCTAssertTrue(locationsTabExists)
    }

    func testPlaceRowKeepsFullCardHitTargetAndOpensExactPlaceDetail() {
        let placeRow = openDeskDrawerPlaceRow()

        XCTAssertEqual(placeRow.identifier, "locations.placeRow.Desk drawer")
        XCTAssertTrue(placeRow.label.contains("Desk drawer"))
        XCTAssertTrue(placeRow.label.localizedCaseInsensitiveContains("item"))
        XCTAssertGreaterThanOrEqual(placeRow.frame.width, 44)
        XCTAssertGreaterThanOrEqual(placeRow.frame.height, 44)
        placeRow.tap()

        XCTAssertTrue(app.otherElements["locations.placeDetailHero"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["locations.placeDetailHero.title"].label, "Desk drawer")

    }

    func testPlaceRowRemainsNavigableAtAccessibilityDynamicType() {
        let placeRow = openPlaceRow(named: "Category test drawer")
        XCTAssertGreaterThanOrEqual(placeRow.frame.height, 44)
        XCTAssertTrue(placeRow.label.contains("4 more categories"), "Place row label: \(placeRow.label)")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "accessibility-xxxl-location-detail"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)

        placeRow.tap()

        XCTAssertTrue(app.otherElements["locations.placeDetailHero"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["locations.placeDetailHero.title"].label, "Category test drawer")
    }

    func testLongPlaceNameKeepsCountChevronAndFullRowNavigation() {
        let placeRow = openPlaceRow(named: Self.longPlaceName)
        XCTAssertTrue(placeRow.label.contains(Self.longPlaceName))
        XCTAssertTrue(placeRow.label.contains("1 item"), "Place row label: \(placeRow.label)")
        XCTAssertGreaterThanOrEqual(placeRow.frame.width, 44)
        XCTAssertGreaterThanOrEqual(placeRow.frame.height, 44)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "long-place-name-count-and-chevron"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)

        placeRow.tap()
        XCTAssertTrue(app.otherElements["locations.placeDetailHero"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["locations.placeDetailHero.title"].label, Self.longPlaceName)
    }

    func testLongItemNameRemainsReachableAtAccessibilityDynamicType() {
        let placeRow = openPlaceRow(named: Self.longPlaceName)
        placeRow.tap()

        let itemList = app.scrollViews["locations.placeDetail.itemList"]
        XCTAssertTrue(itemList.waitForExistence(timeout: 3))
        let itemRow = app.buttons["locations.placeDetail.itemRow.\(Self.longItemName)"]
        scrollToVisible(itemRow, in: itemList)

        XCTAssertTrue(itemRow.exists)
        XCTAssertTrue(itemRow.isHittable)
        XCTAssertTrue(itemRow.label.contains(Self.longItemName))
        XCTAssertGreaterThanOrEqual(itemRow.frame.height, 44)
        XCTAssertGreaterThanOrEqual(itemRow.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(itemRow.frame.maxX, app.frame.maxX)

        XCTAssertGreaterThan(
            itemRow.frame.height,
            200,
            "The shared Item card must expand for the full accessibility title and metadata."
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "long-item-name-accessibility-xxxl"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)

        itemRow.tap()
        XCTAssertTrue(app.otherElements["inventory.itemDetail.hero"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["inventory.itemDetail.hero"].label.contains(Self.longItemName))
    }

    func testLocationCardPopularityDoesNotChangeLocationDetailPlaceOrder() {
        app.tabBars.buttons["Locations"].tap()
        let locationRow = app.buttons["locations.locationRow.Office"]
        scrollToVisible(locationRow, in: app.scrollViews["locations.list"])
        XCTAssertTrue(locationRow.label.contains("PC parts box"))
        XCTAssertTrue(locationRow.label.range(of: "PC parts box")!.lowerBound < locationRow.label.range(of: "Desk drawer")!.lowerBound)

        locationRow.tap()
        let deskDrawer = app.buttons["locations.placeRow.Desk drawer"]
        let partsBox = app.buttons["locations.placeRow.PC parts box"]
        scrollToVisible(deskDrawer, in: app.scrollViews["locations.locationDetail"])
        XCTAssertTrue(partsBox.exists)
        XCTAssertLessThan(deskDrawer.frame.minY, partsBox.frame.minY)
    }

    func testAdaptiveCategoryRowKeepsWholeEntriesOrExactOverflowAtNarrowWidth() {
        let placeRow = openPlaceRow(named: "Category test drawer")

        XCTAssertTrue(placeRow.label.contains("Category test drawer"))
        XCTAssertTrue(placeRow.label.contains("6 items"), "Place row label: \(placeRow.label)")
        XCTAssertFalse(placeRow.label.contains("Extremely Long English Category Name That Must Stay Whole"))
        XCTAssertTrue(placeRow.label.contains("4 more categories"), "Place row label: \(placeRow.label)")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "adaptive-categories-narrow-standard-light"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    func testAdaptiveCategoryUkrainianRowPreservesLocalizedCountAndFullName() {
        let placeRow = openPlaceRow(named: "Category test drawer")

        XCTAssertTrue(placeRow.label.contains("6 речей"), "Place row label: \(placeRow.label)")
        XCTAssertFalse(placeRow.label.contains("Надзвичайно довга українська назва категорії без скорочення"))
        XCTAssertTrue(placeRow.label.contains("ще 4 категорії"), "Place row label: \(placeRow.label)")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "adaptive-categories-ukrainian-dark"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    private func openDeskDrawerPlaceRow() -> XCUIElement {
        openPlaceRow(named: "Desk drawer")
    }

    private func openPlaceRow(named name: String) -> XCUIElement {
        app.tabBars.buttons[locationsTabName].tap()

        let locationRow = app.buttons["locations.locationRow.Office"]
        scrollToVisible(locationRow, in: app.scrollViews["locations.list"])
        locationRow.tap()

        let placeRow = app.buttons["locations.placeRow.\(name)"]
        scrollToVisible(placeRow, in: app.scrollViews["locations.locationDetail"])
        return placeRow
    }

    private func scrollToVisible(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<4 where !element.exists || !element.isHittable {
            scrollView.swipeUp()
        }
    }

    private var locationsTabName: String {
        name.contains("Ukrainian") ? "Локації" : "Locations"
    }
}
