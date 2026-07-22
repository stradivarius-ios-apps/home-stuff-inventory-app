import XCTest

@MainActor
final class InventoryManagedValueRowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var settingsTabLabel = "Settings"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testManagedValueRowsKeepIdentityMetadataAndActionsHittable() {
        launchApp()
        openManagedLocations()

        assertUsedEditableLocationRow(named: "Balcony cabinet")

        tapBackButton()
        openManagedCategories()

        assertUsedBuiltInCategoryRow(named: "Tools")
    }

    func testMaximumDynamicTypeKeepsManagedRowIdentityBeforeActions() {
        launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        openManagedLocations()

        assertAccessibilityUsedEditableLocationRow(named: "Balcony cabinet")

        tapBackButton()
        openManagedCategories()

        assertAccessibilityUsedBuiltInCategoryRow(named: "Tools")
    }

    func testUkrainianStandardSizeKeepsThreeAndSixItemRowsStructurallyStable() {
        launchManagedValueRowRegressionApp()
        openManagedLocations()

        assertUkrainianRegressionRow(named: "Шафа на балконі", itemCount: "3 речі")
        assertUkrainianRegressionRow(named: "Комора", itemCount: "6 речей")
    }

    private func launchApp(contentSizeCategory: String? = nil) {
        app = XCUIApplication()
        settingsTabLabel = "Settings"
        app.launchArguments = [
            "--use-sample-inventory-data",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
    }

    private func launchManagedValueRowRegressionApp() {
        app = XCUIApplication()
        settingsTabLabel = "Налаштування"
        app.launchArguments = [
            "--use-managed-value-row-regression-data",
            "-AppleLanguages", "(uk)",
            "-AppleLocale", "uk_UA"
        ]
        app.launch()
    }

    private func openManagedLocations() {
        openManagedList(identifier: "settings.lists.locationsLink")
    }

    private func openManagedCategories() {
        openManagedList(identifier: "settings.lists.categoriesLink")
    }

    private func openManagedList(identifier: String) {
        app.tabBars.buttons[settingsTabLabel].tap()
        let link = app.buttons[identifier]

        for _ in 0..<8 where !link.isHittable {
            app.swipeUp()
        }

        XCTAssertTrue(link.isHittable, "Expected \(identifier) to be reachable in Settings")
        link.tap()
    }

    private func assertUsedEditableLocationRow(
        named title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = row(named: title)
        let count = row.descendants(matching: .any)["inventory.lists.itemCount"].firstMatch
        let viewItems = row.buttons["inventory.lists.viewItems"].firstMatch
        let accessory = row.buttons["inventory.lists.valueActions"].firstMatch

        assertStandardIdentityAndActions(
            row: row,
            title: title,
            count: count,
            viewItems: viewItems,
            accessory: accessory,
            file: file,
            line: line
        )
        viewItems.tap()
        XCTAssertTrue(app.buttons["inventory.itemRow.Drill bits"].waitForExistence(timeout: 3), file: file, line: line)
        tapBackButton()
    }

    private func assertUsedBuiltInCategoryRow(
        named title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let row = row(named: title)
        let count = row.descendants(matching: .any)["inventory.lists.itemCount"].firstMatch
        let viewItems = row.buttons["inventory.lists.viewItems"].firstMatch
        let defaultStatus = row.descendants(matching: .any)["inventory.lists.defaultStatus"].firstMatch

        assertStandardIdentityAndActions(
            row: row,
            title: title,
            count: count,
            viewItems: viewItems,
            accessory: defaultStatus,
            file: file,
            line: line
        )
        viewItems.tap()
        XCTAssertTrue(app.buttons["inventory.itemRow.Precision screwdriver set"].waitForExistence(timeout: 3), file: file, line: line)
        tapBackButton()
    }

    private func assertStandardIdentityAndActions(
        row: XCUIElement,
        title: String,
        count: XCUIElement,
        viewItems: XCUIElement,
        accessory: XCUIElement,
        file: StaticString,
        line: UInt
    ) {
        let titleText = row.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(titleText.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(count.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(viewItems.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(accessory.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(viewItems.isHittable, file: file, line: line)
        XCTAssertTrue(accessory.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(viewItems.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(viewItems.frame.height, 44, file: file, line: line)
        // Text elements report their expanded layout frame rather than glyph bounds, so
        // their frame may cover the trailing column even when the rendered title wraps.
        XCTAssertTrue(titleText.isHittable, file: file, line: line)
        XCTAssertTrue(count.isHittable, file: file, line: line)
    }

    private func assertAccessibilityUsedEditableLocationRow(named title: String) {
        assertAccessibilityIdentityPrecedesActions(
            in: row(named: title),
            title: title,
            accessory: row(named: title).buttons["inventory.lists.valueActions"].firstMatch
        )
    }

    private func assertUkrainianRegressionRow(named title: String, itemCount: String) {
        let managedRow = row(named: title)
        let titleText = managedRow.staticTexts[title].firstMatch
        let count = managedRow.descendants(matching: .any)["inventory.lists.itemCount"].firstMatch
        let viewItems = managedRow.buttons["inventory.lists.viewItems"].firstMatch
        let actions = managedRow.buttons["inventory.lists.valueActions"].firstMatch

        XCTAssertTrue(managedRow.waitForExistence(timeout: 3))
        XCTAssertTrue(titleText.waitForExistence(timeout: 3))
        XCTAssertEqual(count.label, itemCount)
        XCTAssertTrue(viewItems.waitForExistence(timeout: 3))
        XCTAssertTrue(actions.waitForExistence(timeout: 3))
        XCTAssertTrue(viewItems.isHittable)
        XCTAssertTrue(actions.isHittable)
        XCTAssertGreaterThanOrEqual(count.frame.midY, titleText.frame.midY)
        XCTAssertFalse(viewItems.frame.intersects(actions.frame))
    }

    private func assertAccessibilityUsedBuiltInCategoryRow(named title: String) {
        assertAccessibilityIdentityPrecedesActions(
            in: row(named: title),
            title: title,
            accessory: row(named: title).descendants(matching: .any)["inventory.lists.defaultStatus"].firstMatch
        )
    }

    private func assertAccessibilityIdentityPrecedesActions(
        in row: XCUIElement,
        title: String,
        accessory: XCUIElement
    ) {
        let titleText = row.staticTexts[title].firstMatch
        let count = row.descendants(matching: .any)["inventory.lists.itemCount"].firstMatch
        let viewItems = row.buttons["inventory.lists.viewItems"].firstMatch

        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(titleText.waitForExistence(timeout: 3))
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        XCTAssertTrue(viewItems.waitForExistence(timeout: 3))
        XCTAssertTrue(accessory.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(titleText.frame.maxY, viewItems.frame.minY)
        XCTAssertLessThanOrEqual(count.frame.maxY, viewItems.frame.minY)
        XCTAssertTrue(viewItems.isHittable)
        XCTAssertTrue(accessory.isHittable)
        XCTAssertGreaterThanOrEqual(viewItems.frame.width, 44)
        XCTAssertGreaterThanOrEqual(viewItems.frame.height, 44)
    }

    private func row(named title: String) -> XCUIElement {
        element(identifier: "inventory.lists.valueRow.\(title)")
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func tapBackButton() {
        if let backButton = app.navigationBars.allElementsBoundByIndex.reversed().first(where: { navigationBar in
            let candidate = navigationBar.buttons["BackButton"]
            return candidate.exists && candidate.isHittable
        }).map({ $0.buttons["BackButton"] }) {
            backButton.tap()
            return
        }

        let firstNavigationButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(firstNavigationButton.waitForExistence(timeout: 3))
        firstNavigationButton.tap()
    }
}
