import XCTest

/// Walks through the main screens and attaches a screenshot of each.
/// CI exports these attachments as build artifacts, so the app can be reviewed without a Mac.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()

        XCTAssertTrue(app.buttons["seed-week"].waitForExistence(timeout: 10))
        capture("01-start")

        app.buttons["seed-week"].tap()
        XCTAssertTrue(app.staticTexts["Diese Woche"].waitForExistence(timeout: 5))
        capture("02-week-tuesday")

        app.buttons["day-Do"].tap()
        XCTAssertTrue(app.staticTexts["16:20"].waitForExistence(timeout: 5), "Thursday pickup exception is shown")
        capture("03-week-thursday")

        app.buttons["tab-today"].tap()
        XCTAssertTrue(app.staticTexts["Zahnarzt anrufen"].waitForExistence(timeout: 5))
        capture("04-today")

        app.buttons["tab-tasks"].tap()
        XCTAssertTrue(app.buttons["advance-gift"].waitForExistence(timeout: 5))
        app.buttons["advance-gift"].tap()
        XCTAssertTrue(app.buttons["status-Läuft"].waitForExistence(timeout: 5))
        capture("05-tasks")

        // Create a task through the plus button.
        app.buttons["add-task"].tap()
        let titleField = app.textFields["task-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Fahrrad reparieren")
        capture("05b-new-task")
        app.buttons["task-save"].tap()
        XCTAssertTrue(app.staticTexts["Fahrrad reparieren"].waitForExistence(timeout: 5))

        app.buttons["tab-more"].tap()
        XCTAssertTrue(app.buttons["open-shopping"].waitForExistence(timeout: 5))
        app.buttons["open-shopping"].tap()
        XCTAssertTrue(app.buttons["item-tomatoes"].waitForExistence(timeout: 5))
        app.buttons["item-tomatoes"].tap()
        capture("06-shopping")

        // The dandelion button leads back to the start screen from anywhere.
        XCTAssertTrue(app.buttons["tab-start"].waitForExistence(timeout: 5))
        app.buttons["tab-start"].tap()
        XCTAssertTrue(app.buttons["seed-today"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
