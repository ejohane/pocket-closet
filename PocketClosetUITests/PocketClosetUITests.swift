import XCTest

final class PocketClosetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsClosetAndSeededTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Pocket Closet"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.tabBars.buttons["Closet"].exists)
        XCTAssertTrue(app.tabBars.buttons["Add"].exists)
        XCTAssertTrue(app.tabBars.buttons["Manage"].exists)
    }

    func testManageShowsSeededBuckets() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        app.tabBars.buttons["Manage"].tap()

        XCTAssertTrue(app.navigationBars["Manage"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["In Closet"].exists)
        XCTAssertTrue(app.staticTexts["In Storage"].exists)
        XCTAssertTrue(app.staticTexts["Donate"].exists)
    }

    func testClosetSearchIsVisibleAndFiltersItems() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        let searchField = app.searchFields["Search clothes"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 6))
        searchField.tap()
        searchField.typeText("Outerwear")

        XCTAssertTrue(app.buttons["Outerwear, size 6X, Theo"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Top, size M, Me"].exists)
    }

    func testManageItemOpensDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        app.tabBars.buttons["Manage"].tap()
        app.buttons["Bottom, size 7, Emma"].tap()

        XCTAssertTrue(app.navigationBars["Bottom"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Edit"].exists)
    }

    func testManageSelectionEnablesBulkActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        app.tabBars.buttons["Manage"].tap()
        app.buttons["Select"].tap()
        app.buttons["Bottom, size 7, Emma"].tap()

        let bulkButton = app.buttons["Bulk"]
        XCTAssertTrue(bulkButton.exists)
        XCTAssertTrue(bulkButton.isEnabled)
    }
}
