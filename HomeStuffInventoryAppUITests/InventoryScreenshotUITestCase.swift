#if PR_UI_SCREENSHOTS || RELEASE_APP_STORE_SCREENSHOTS
import XCTest

@MainActor
class InventoryScreenshotUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launchApp(
        locale: String,
        appearance: XCUIDevice.Appearance = .light,
        dataLaunchArguments: [String] = ["--use-sample-inventory-data"],
        accessibilityLaunchArguments: [String] = [],
        contentSizeCategory: String = "UICTContentSizeCategoryL"
    ) {
        XCUIDevice.shared.appearance = appearance
        let appearanceName = appearance == .light ? "light" : "dark"

        app = XCUIApplication()
        app.launchArguments = dataLaunchArguments + accessibilityLaunchArguments + [
            appearance == .light ? "--qa-force-light-appearance" : "--qa-force-dark-appearance",
            "-AppleLanguages", "(\(locale))",
            "-AppleLocale", locale == "uk" ? "uk_UA" : "en_US",
            "-UIPreferredContentSizeCategoryName", contentSizeCategory
        ]
        app.launch()

        let marker = app.descendants(matching: .any)["qa.appearance.\(appearanceName)"]
        XCTAssertTrue(
            marker.waitForExistence(timeout: 5),
            "App did not confirm \(appearanceName) appearance before screenshot capture"
        )
    }

    func tap(_ identifier: String) {
        let button = app.buttons[identifier].firstMatch
        if button.waitForExistence(timeout: 1) {
            button.tap()
            return
        }

        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing element: \(identifier)")
        element.tap()
    }

    func tapTab(named names: [String]) {
        let tab = names
            .lazy
            .map { self.app.tabBars.buttons[$0] }
            .first { $0.waitForExistence(timeout: 1) }
        XCTAssertNotNil(tab, "Missing tab matching \(names.joined(separator: ", "))")
        guard let tab else { return }
        tab.tap()
    }

    func waitFor(_ identifier: String) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing element: \(identifier)")
    }

    func tapAfterScrolling(_ identifier: String, in scrollView: XCUIElement? = nil) {
        let element = app.descendants(matching: .any)[identifier]
        for _ in 0..<24 {
            if element.waitForExistence(timeout: 1) {
                element.tap()
                return
            }
            (scrollView?.exists == true ? scrollView! : app).swipeUp()
        }
        XCTFail("Missing element after scrolling: \(identifier)")
    }

    @discardableResult
    func scrollUntilHittable(
        _ identifier: String,
        in scrollView: XCUIElement? = nil,
        maximumSwipes: Int = 8
    ) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        for _ in 0..<maximumSwipes {
            if element.isHittable {
                return element
            }
            (scrollView?.exists == true ? scrollView! : app).swipeUp()
        }
        if element.isHittable {
            return element
        }
        XCTFail("Element did not become hittable after scrolling: \(identifier)")
        return element
    }

    func attach(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func waitForKeyboardDismissal() {
        XCTAssertTrue(app.keyboards.firstMatch.waitForScreenshotNonExistence(timeout: 5))
    }
}

extension XCUIElement {
    fileprivate func waitForScreenshotNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
#endif
