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
}
