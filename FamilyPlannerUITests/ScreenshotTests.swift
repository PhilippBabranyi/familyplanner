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

        app.buttons["tab-more"].tap()
        XCTAssertTrue(app.buttons["open-start"].waitForExistence(timeout: 5))
        app.buttons["open-start"].tap()
        XCTAssertTrue(app.buttons["seed-today"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
