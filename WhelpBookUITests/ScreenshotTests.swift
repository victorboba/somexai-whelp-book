import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh WhelpBook.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["litter.headline"].waitForExistence(timeout: 20))
        snap("01-timeline", app)

        app.buttons["jump.weights"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Weights"].waitForExistence(timeout: 10))
        snap("02-weights", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["jump.whelping"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["whelping.count"].waitForExistence(timeout: 10))
        snap("03-whelping", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // The quick-jump grid's second row can start below the fold with the sample litter's
        // attention band and full stage rail on screen, so scroll until it shows.
        let healthButton = app.buttons["jump.health"].firstMatch
        if !healthButton.waitForExistence(timeout: 3) {
            for _ in 0..<5 {
                app.swipeUp()
                if healthButton.waitForExistence(timeout: 2) { break }
            }
        }
        XCTAssertTrue(healthButton.waitForExistence(timeout: 10))
        healthButton.tap()
        XCTAssertTrue(app.navigationBars["Health"].waitForExistence(timeout: 10))
        snap("04-health", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["How do I use this app?"].waitForExistence(timeout: 10))
        app.buttons["How do I use this app?"].tap()
        snap("05-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 20))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
