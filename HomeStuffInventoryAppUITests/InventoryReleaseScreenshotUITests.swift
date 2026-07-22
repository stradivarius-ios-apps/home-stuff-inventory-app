#if RELEASE_APP_STORE_SCREENSHOTS
import XCTest

@MainActor
final class InventoryReleaseScreenshotUITests: InventoryScreenshotUITestCase {

    private struct AppStoreDemoCopy {
        let locale: String
        let overviewAnchorLocation: String
        let homeOffice: String
        let topDeskDrawer: String
        let adapter: String
        let hdmiCable: String
        let warrantyFolder: String

        init(locale: String) {
            self.locale = locale
            if locale == "uk" {
                overviewAnchorLocation = "Домашній кабінет"
                homeOffice = "Домашній кабінет"
                topDeskDrawer = "Верхня шухляда столу"
                adapter = "Відеоадаптер USB-C"
                hdmiCable = "Кабель HDMI, 2 м"
                warrantyFolder = "Папка з гарантіями на техніку"
            } else {
                overviewAnchorLocation = "Entryway"
                homeOffice = "Home Office"
                topDeskDrawer = "Top desk drawer"
                adapter = "USB-C display adapter"
                hdmiCable = "HDMI cable, 2 m"
                warrantyFolder = "Electronics warranty folder"
            }
        }
    }

    func testReleaseAppStoreScreenshots() {
        for locale in ["en", "uk"] {
            let copy = AppStoreDemoCopy(locale: locale)
            captureSearchAndItemDetail(copy: copy)
            captureLocationPlaceAndAddFlow(copy: copy)
        }
    }

    private func captureSearchAndItemDetail(copy: AppStoreDemoCopy) {
        launchReleaseFixture(locale: copy.locale)
        tapTab(named: copy.locale == "uk" ? ["Шукати в інвентарі"] : ["Search inventory"])

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("HDMI\n")
        waitForKeyboardDismissal()
        waitFor("inventory.itemRow.\(copy.hdmiCable)")
        waitFor("inventory.itemRow.\(copy.adapter)")
        waitFor("inventory.search.match.tag.A5500000-0000-4000-8000-000000000001")
        attach(named: "\(copy.locale)-05-search-answer")

        tap("inventory.itemRow.\(copy.adapter)")
        [
            "inventory.itemDetail",
            "inventory.itemDetail.hero",
            "inventory.itemDetail.location",
            "inventory.itemDetail.place",
            "inventory.itemDetail.quantity",
            "inventory.itemDetail.condition"
        ].forEach { waitFor($0) }
        XCTAssertTrue(app.descendants(matching: .any)["inventory.itemDetail.location"].label.contains(copy.homeOffice))
        XCTAssertTrue(app.descendants(matching: .any)["inventory.itemDetail.place"].label.contains(copy.topDeskDrawer))
        attach(named: "\(copy.locale)-01-item-detail")
        app.terminate()
    }

    private func captureLocationPlaceAndAddFlow(copy: AppStoreDemoCopy) {
        launchReleaseFixture(locale: copy.locale)
        waitFor("locations.list")
        waitFor("locations.locationRow.\(copy.overviewAnchorLocation)")
        attach(named: "\(copy.locale)-02-locations-overview")

        tapAfterScrolling("locations.locationRow.\(copy.homeOffice)")
        ["locations.locationDetail", "locations.detailHero", "locations.recentItems", "locations.placesSectionHeader"].forEach { waitFor($0) }
        positionLocationDetail(for: copy)
        attach(named: "\(copy.locale)-03-location-detail")

        tapAfterScrolling("locations.placeRow.\(copy.topDeskDrawer)")
        ["locations.placeDetailHero", "locations.placeDetail.itemList"].forEach { waitFor($0) }
        let placeHero = app.descendants(matching: .any)["locations.placeDetailHero"]
        XCTAssertTrue(placeHero.label.contains("4"))
        XCTAssertTrue(app.buttons["locations.placeDetail.itemRow.\(copy.adapter)"].waitForExistence(timeout: 5))
        _ = scrollUntilHittable("locations.placeDetail.itemRow.\(copy.warrantyFolder)", in: app.scrollViews["locations.placeDetail.itemList"])
        XCTAssertTrue(placeHero.isHittable || app.navigationBars.staticTexts[copy.topDeskDrawer].exists)
        attach(named: "\(copy.locale)-04-place-detail")

        tap("locations.placeDetail.addItemButton")
        ["inventory.itemForm", "inventory.itemForm.nameField", "inventory.itemForm.locationPicker", "inventory.itemForm.containerPicker"].forEach { waitFor($0) }
        let nameField = app.textFields["inventory.itemForm.nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        let locationPicker = app.buttons["inventory.itemForm.locationPicker"]
        let placePicker = app.buttons["inventory.itemForm.containerPicker"]
        XCTAssertTrue(locationPicker.label.contains(copy.homeOffice))
        XCTAssertTrue(placePicker.label.contains(copy.topDeskDrawer))
        nameField.tap()
        nameField.typeText("USB hub\n")
        waitForKeyboardDismissal()
        XCTAssertEqual(nameField.value as? String, "USB hub")
        XCTAssertTrue(locationPicker.label.contains(copy.homeOffice))
        XCTAssertTrue(placePicker.label.contains(copy.topDeskDrawer))
        XCTAssertTrue(app.buttons["inventory.itemForm.saveButton"].isEnabled)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        attach(named: "\(copy.locale)-06-add-item-context")
        app.terminate()
    }

    private func launchReleaseFixture(locale: String) {
        launchApp(
            locale: locale,
            dataLaunchArguments: ["--use-app-store-demo-data", "--app-store-demo-locale", locale]
        )
    }

    private func positionLocationDetail(for copy: AppStoreDemoCopy) {
        let detail = app.scrollViews["locations.locationDetail"]
        let recentItems = app.descendants(matching: .any)["locations.recentItems"]
        let placesHeader = app.descendants(matching: .any)["locations.placesSectionHeader"]
        for _ in 0..<8 {
            if recentItems.isHittable && placesHeader.isHittable {
                XCTAssertTrue(
                    app.descendants(matching: .any)["locations.detailHero"].isHittable ||
                        app.navigationBars.staticTexts[copy.homeOffice].exists
                )
                return
            }
            detail.swipeUp()
        }
        XCTFail("Could not position recent Items and Places for \(copy.homeOffice)")
    }

}
#endif
