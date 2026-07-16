import XCTest

final class PocketClosetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsClosetAndSeededTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Our Closet"].waitForExistence(timeout: 6))
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

    func testClosetSortSheetAddsCompoundCriteria() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA", "UITEST_RESET_SORT"]
        app.launch()

        let sortButton = app.buttons["sortItemsButton"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 6))
        sortButton.tap()

        XCTAssertTrue(app.navigationBars["Sort Order"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Edit"].exists)
        app.buttons["Add Sort"].tap()
        XCTAssertTrue(app.navigationBars["Add Sort"].waitForExistence(timeout: 3))
        app.buttons["addSortField-size"].tap()

        XCTAssertTrue(app.staticTexts["Size"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Smallest First"].exists)
        XCTAssertTrue(app.staticTexts["Date Added"].exists)
        XCTAssertEqual(app.cells.containing(.staticText, identifier: "Size").count, 1)
    }

    func testClosetSortDragReordersCriteria() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA", "UITEST_RESET_SORT"]
        app.launch()

        let sortButton = app.buttons["sortItemsButton"]
        XCTAssertTrue(sortButton.waitForExistence(timeout: 6))
        sortButton.tap()
        app.buttons["Add Sort"].tap()
        XCTAssertTrue(app.navigationBars["Add Sort"].waitForExistence(timeout: 3))
        app.buttons["addSortField-size"].tap()

        let dateRow = app.cells.containing(.staticText, identifier: "Date Added").element
        let sizeRow = app.cells.containing(.staticText, identifier: "Size").element
        XCTAssertTrue(dateRow.waitForExistence(timeout: 3))
        XCTAssertTrue(sizeRow.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(sizeRow.frame.minY, dateRow.frame.minY)

        let sizeHandle = sizeRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let dateHandle = dateRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        sizeHandle.press(forDuration: 1, thenDragTo: dateHandle)

        XCTAssertLessThan(
            app.cells.containing(.staticText, identifier: "Size").element.frame.minY,
            app.cells.containing(.staticText, identifier: "Date Added").element.frame.minY
        )
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

    func testClosetSharingUsesSingleInvitationAction() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_SEED_DATA"]
        app.launch()

        let sharingButton = app.buttons["Closet sharing"]
        XCTAssertTrue(sharingButton.waitForExistence(timeout: 6))
        sharingButton.tap()

        XCTAssertTrue(app.staticTexts["Family Sharing"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["Family member's iCloud email"].exists)
        XCTAssertFalse(app.buttons["Add Family Member"].exists)
        XCTAssertFalse(app.buttons["Repair Family Sharing"].exists)
        XCTAssertTrue(app.buttons["Share Closet"].exists || app.buttons["Send Invitation"].exists)
    }
}
