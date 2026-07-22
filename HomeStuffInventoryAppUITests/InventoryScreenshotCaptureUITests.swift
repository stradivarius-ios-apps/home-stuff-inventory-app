#if PR_UI_SCREENSHOTS
import XCTest

@MainActor
final class InventoryScreenshotCaptureUITests: InventoryScreenshotUITestCase {

    func testEnglishLightReviewScreenshots() {
        captureReviewScreenshots(locale: "en", appearance: .light)
    }

    func testEnglishDarkReviewScreenshots() {
        captureReviewScreenshots(locale: "en", appearance: .dark)
    }

    func testUkrainianLightReviewScreenshots() {
        captureReviewScreenshots(locale: "uk", appearance: .light)
    }

    func testUkrainianDarkReviewScreenshots() {
        captureReviewScreenshots(locale: "uk", appearance: .dark)
    }

    func testCompactInventoryHighContrastScreenshot() {
        launchApp(
            locale: "en",
            appearance: .dark,
            accessibilityLaunchArguments: ["--qa-increase-contrast"]
        )

        waitFor("qa.accessibility.increaseContrast")
        tapTab(named: ["Inventory"])
        waitFor("inventory.list")
        attach(named: "en-dark-increased-contrast-compact-inventory")

        app.terminate()
    }

    func testCompactInventoryUkrainianAccessibilityScreenshot() {
        launchApp(
            locale: "uk",
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        tapTab(named: ["Інвентар"])
        waitFor("inventory.list")
        for _ in 0..<4 {
            app.swipeDown()
        }
        attach(named: "uk-light-accessibility-xxxl-compact-inventory")

        app.terminate()
    }

    private func captureReviewScreenshots(locale: String, appearance: XCUIDevice.Appearance) {
        let appearanceName = appearance == .light ? "light" : "dark"
        let prefix = "\(locale)-\(appearanceName)"

        launchApp(locale: locale, appearance: appearance)

        waitFor("locations.list")
        attach(named: "\(prefix)-locations-overview")

        tapAfterScrolling("locations.locationRow.Office")
        waitFor("locations.detailHero")
        attach(named: "\(prefix)-location-detail")

        tapAfterScrolling("locations.placeRow.Desk drawer")
        waitFor("locations.placeDetailHero")
        attach(named: "\(prefix)-place-detail")

        app.terminate()

        launchApp(locale: locale, appearance: appearance)
        tapTab(named: locale == "uk" ? ["Інвентар"] : ["Inventory"])
        waitFor("inventory.list")
        attach(named: "\(prefix)-inventory-overview")

        tapAfterScrolling("inventory.itemRow.USB-C to HDMI adapter")
        waitFor("inventory.itemDetail")
        attach(named: "\(prefix)-item-detail")

        app.terminate()

        launchApp(locale: locale, appearance: appearance)
        tapTab(named: locale == "uk" ? ["Шукати в інвентарі"] : ["Search inventory"])

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("2032")
        waitFor("inventory.itemRow.CR2032 batteries")
        attach(named: "\(prefix)-search-results")

        app.terminate()
    }

    func testItemDetailAppearanceScreenshots() {
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            launchApp(locale: "en", appearance: appearance)

            tapTab(named: ["Inventory"])
            tapAfterScrolling("inventory.itemRow.USB-C to HDMI adapter")
            waitFor("inventory.itemDetail")
            attach(named: "item-detail-\(appearance == .light ? "light" : "dark")")

            app.terminate()
        }
    }

    func testItemFormAppearanceScreenshots() {
        for appearance in [XCUIDevice.Appearance.light, .dark] {
            let appearanceName = appearance == .light ? "light" : "dark"

            launchApp(locale: "en", appearance: appearance)
            tapTab(named: ["Inventory"])
            tap("inventory.addItemButton")
            waitFor("inventory.itemForm.locationPicker")
            attach(named: "item-form-error-\(appearanceName)")

            tapAfterScrolling("inventory.itemForm.iconPicker")
            waitFor("inventory.itemIconPicker.default")
            attach(named: "item-icon-picker-\(appearanceName)")
            app.navigationBars.buttons.firstMatch.tap()

            tap("inventory.itemForm.locationPicker")
            waitFor("inventory.selection.empty")
            attach(named: "location-selection-\(appearanceName)")
            app.navigationBars.buttons.firstMatch.tap()

            let nameField = app.textFields["inventory.itemForm.nameField"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5))
            nameField.tap()
            nameField.typeText("Spare travel adapter\n")
            waitForKeyboardDismissal()
            app.swipeDown()
            attach(named: "item-form-create-\(appearanceName)")
            app.terminate()

            launchApp(locale: "en", appearance: appearance)
            tapTab(named: ["Inventory"])
            tapAfterScrolling("inventory.itemRow.Precision screwdriver set")
            tap("inventory.editItemButton")
            waitFor("inventory.itemForm.locationPicker")
            attach(named: "item-form-edit-\(appearanceName)")
            app.terminate()
        }
    }

    func testRecentItemsLocationOneScreenshot() {
        captureRecentItemsLocation(locale: "en", count: 1)
    }

    func testRecentItemsLocationTwoScreenshot() {
        captureRecentItemsLocation(locale: "en", count: 2)
    }

    func testRecentItemsLocationThreeScreenshot() {
        captureRecentItemsLocation(locale: "en", count: 3)
    }

    func testRecentItemsLocationThreePlusOverflowScreenshot() {
        captureRecentItemsLocation(locale: "en", count: 4)
    }

    func testRecentItemsPlaceEnglishDarkScreenshot() {
        launchRecentItemsFixture(locale: "en", appearance: .dark, count: 5)
        openRecentItemsFixturePlace()
        attach(named: "recent-items-place-en-dark-three-plus-overflow")
        app.terminate()
    }

    func testRecentItemsPlaceUkrainianDarkScreenshot() {
        launchRecentItemsFixture(locale: "uk", appearance: .dark, count: 5)
        openRecentItemsFixturePlace()
        attach(named: "recent-items-place-uk-dark-three-plus-overflow")
        app.terminate()
    }

    func testRecentItemsUkrainianLocationScreenshot() {
        launchRecentItemsFixture(locale: "uk", appearance: .light, count: 4)
        openRecentItemsFixtureLocation()
        attach(named: "recent-items-location-uk-light-three-plus-overflow")
        app.terminate()
    }

    func testRecentItemsAccessibilityScreenshot() {
        launchRecentItemsFixture(
            locale: "en",
            appearance: .light,
            count: 4,
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        openRecentItemsFixtureLocation()
        attach(named: "recent-items-location-en-light-accessibility-xxxl")
        app.terminate()
    }

    private func launchRecentItemsFixture(
        locale: String,
        appearance: XCUIDevice.Appearance,
        count: Int,
        contentSizeCategory: String = "UICTContentSizeCategoryL"
    ) {
        XCUIDevice.shared.appearance = appearance
        let appearanceName = appearance == .light ? "light" : "dark"

        app = XCUIApplication()
        app.launchArguments = [
            "--use-sample-inventory-data",
            "--qa-recent-items-layout-fixture",
            "--qa-recent-items-layout-fixture-count", "\(count)",
            appearance == .light ? "--qa-force-light-appearance" : "--qa-force-dark-appearance",
            "-AppleLanguages", "(\(locale))",
            "-AppleLocale", locale == "uk" ? "uk_UA" : "en_US",
            "-UIPreferredContentSizeCategoryName", contentSizeCategory
        ]
        app.launch()

        let marker = app.descendants(matching: .any)["qa.appearance.\(appearanceName)"]
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        waitFor("locations.list")
    }

    private func openRecentItemsFixtureLocation() {
        tapAfterScrolling("locations.locationRow.Recent Items Test Location")
        waitFor("locations.locationDetail")
        scrollRecentItemsSection("locations.recentItems", in: "locations.locationDetail")
    }

    private func captureRecentItemsLocation(locale: String, count: Int) {
        launchRecentItemsFixture(locale: locale, appearance: .light, count: count)
        openRecentItemsFixtureLocation()
        attach(named: "recent-items-location-\(locale)-light-\(count)-visible")
        app.terminate()
    }

    private func openRecentItemsFixturePlace() {
        openRecentItemsFixtureLocation()
        tapAfterScrolling("locations.placeRow.Recent Items Test Place")
        waitFor("locations.placeDetail.itemList")
        scrollRecentItemsSection("locations.placeRecentItems", in: "locations.placeDetail.itemList")
    }

    private func scrollRecentItemsSection(_ sectionIdentifier: String, in containerIdentifier: String) {
        let section = app.otherElements[sectionIdentifier]
        let container = app.descendants(matching: .any)[containerIdentifier]
        XCTAssertTrue(container.waitForExistence(timeout: 5))
        for _ in 0..<8 where !section.isHittable {
            container.swipeUp()
        }
        XCTAssertTrue(section.isHittable, "Expected \(sectionIdentifier) in \(containerIdentifier).")
    }

}
#endif
