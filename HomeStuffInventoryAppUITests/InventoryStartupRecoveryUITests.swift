import XCTest

@MainActor
final class InventoryStartupRecoveryUITests: InventoryUITestCase {
    func testForcedStoreStartupFailureShowsRecoveryInsteadOfLaunchingTheApp() {
        launchStartupApp(arguments: ["--qa-force-store-startup-failure"])
        let recovery = element(identifier: "inventory.startup.recovery")
        XCTAssertTrue(recovery.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["inventory.startup.tryAgain"].exists)
        XCTAssertFalse(app.tabBars.buttons["Locations"].exists)
        add(attachment(named: "primary-action-startup-retry-en-light"))
    }

    func testStoreStartupFailureOnceCanRetryIntoNormalApp() {
        launchStartupApp(arguments: ["--qa-force-store-startup-failure-once"])
        let retry = app.buttons["inventory.startup.tryAgain"]
        XCTAssertTrue(retry.waitForExistence(timeout: 3))
        retry.tap()
        XCTAssertTrue(app.tabBars.buttons["Locations"].waitForExistence(timeout: 3))
        XCTAssertFalse(element(identifier: "inventory.startup.recovery").exists)
    }

    func testNormalLaunchOpensLocationsWithoutRecoveryScreen() {
        launchStartupApp()
        XCTAssertTrue(app.tabBars.buttons["Locations"].waitForExistence(timeout: 3))
        XCTAssertFalse(element(identifier: "inventory.startup.recovery").exists)
    }
}
