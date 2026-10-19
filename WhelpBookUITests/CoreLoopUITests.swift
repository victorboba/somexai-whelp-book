import XCTest

/// Drives the real core loop through the real UI: a dam, her litter, a puppy born on the whelping
/// screen and a weigh-in on top of it. Every assertion is on content that can only appear if the
/// app genuinely did the work — a computed weight change, a recomputed count, a flag raised by the
/// weight maths — never merely that a button exists.
final class CoreLoopUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-skipOnboarding", "-uiTesting"] + extra
        app.launch()
        return app
    }

    func testDamToLitterToPuppyToWeighIn() {
        let app = launch(["-resetData"])

        // 1. The app opens on the empty timeline and asks for the dam.
        let startAddDam = app.buttons["Add a dam"].firstMatch
        XCTAssertTrue(startAddDam.waitForExistence(timeout: 20))
        startAddDam.tap()

        // 2. Add her.
        XCTAssertTrue(app.navigationBars["Dams"].waitForExistence(timeout: 10))
        app.buttons["Add a dam"].firstMatch.tap()
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Juno")
        app.buttons["Done"].firstMatch.tap()

        // 3. She is on file, and her interval screen is honest about having nothing to measure.
        let row = app.staticTexts["Juno"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["Juno"].waitForExistence(timeout: 10))
        let summary = app.staticTexts["dam.intervalSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("No seasons recorded"), summary.label)

        // 4. Start her litter.
        app.buttons["Start a litter"].firstMatch.tap()
        let studField = app.textFields["Stud name"]
        XCTAssertTrue(studField.waitForExistence(timeout: 10))
        studField.tap()
        studField.typeText("Ridge")
        app.buttons["Save"].firstMatch.tap()

        // 5. Back on the timeline, the litter is now the spine of the home screen.
        backToRoot(app)
        let headline = app.staticTexts["litter.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Juno x Ridge"].firstMatch.waitForExistence(timeout: 5),
                      "The home screen has to name the pairing it is tracking")

        // 6. Whelp one puppy through the three in the morning screen.
        app.buttons["jump.whelping"].firstMatch.tap()
        let bornButton = app.buttons["whelping.bornButton"]
        XCTAssertTrue(bornButton.waitForExistence(timeout: 10))
        bornButton.tap()

        let weightField = app.textFields["puppy.birthWeight"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 10))
        app.buttons["sex.male"].firstMatch.tap()
        weightField.tap()
        weightField.typeText("452")
        app.switches["puppy.placenta"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()

        // The count is recomputed from the stored puppies, not from a label we set.
        let count = app.staticTexts["whelping.count"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.label, "1 puppy")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "452 g")).firstMatch.exists,
                      "The birth weight has to come back in grams on the whelping row")

        // 7. Weigh it, and check the change the app worked out for itself.
        backToRoot(app)
        app.buttons["jump.weights"].firstMatch.tap()
        let weighButton = app.buttons["weigh.1"]
        XCTAssertTrue(weighButton.waitForExistence(timeout: 10))
        weighButton.tap()

        let valueField = app.textFields["weighin.value"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 10))
        valueField.tap()
        valueField.typeText("520")
        app.buttons["Save"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["520 g"].waitForExistence(timeout: 10),
                      "The latest weight has to appear on the puppy's row")
        XCTAssertTrue(app.staticTexts["+68 g"].waitForExistence(timeout: 5),
                      "520 g after a 452 g birth weight is a 68 g gain, and the app has to say so")
    }

    /// The reason the weight chart exists: a puppy whose last weigh-in did not go up is lifted to
    /// the top of the screen. This runs against the sample litter, where one puppy flattens out.
    func testThePuppyThatStoppedGainingIsFlagged() {
        let app = launch(["-resetData", "-sampleData"])

        XCTAssertTrue(app.buttons["jump.weights"].waitForExistence(timeout: 20))
        app.buttons["jump.weights"].firstMatch.tap()

        let attention = app.otherElements["weights.attention"]
        XCTAssertTrue(attention.waitForExistence(timeout: 10), "The attention band has to be on the weights screen")

        let flag = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "No gain since last weigh-in")).firstMatch
        XCTAssertTrue(flag.waitForExistence(timeout: 5),
                      "The flag has to name what the numbers did, in the app's own factual wording")

        let honest = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "not a diagnosis")).firstMatch
        XCTAssertTrue(honest.exists, "Every flag carries the sentence that keeps this a record, not a diagnosis")
    }

    /// The health grid is one row per puppy and one column per event, built from the whelping date.
    func testTheHealthGridFillsItselfFromTheWhelpingDate() {
        let app = launch(["-resetData", "-sampleData"])

        // With the attention band showing and all seven stages on the rail, the second row of the
        // quick-jump grid ("Health", "Buyers") starts below the fold on a fresh launch.
        revealAndTap(app.buttons["jump.health"].firstMatch, in: app)

        XCTAssertTrue(app.otherElements["health.grid"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Red collar"].firstMatch.waitForExistence(timeout: 5),
                      "Every puppy gets its own row")
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Worming")).firstMatch.exists,
                      "Every scheduled event gets its own column")
    }

    /// Scrolls the home timeline until `button` exists, then taps it. The quick-jump grid's second
    /// row can start below the fold (attention band, seven-stage rail), and XCUITest does not
    /// scroll on its own the way a person swiping the screen would.
    private func revealAndTap(_ button: XCUIElement, in app: XCUIApplication) {
        if !button.waitForExistence(timeout: 3) {
            for _ in 0..<5 {
                app.swipeUp()
                if button.waitForExistence(timeout: 2) { break }
            }
        }
        XCTAssertTrue(button.waitForExistence(timeout: 10), "\(button) never appeared even after scrolling")
        button.tap()
    }

    private func backToRoot(_ app: XCUIApplication) {
        for _ in 0..<4 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            guard back.exists, back.isHittable, app.navigationBars["Whelp Book"].exists == false else { break }
            back.tap()
        }
        _ = app.navigationBars["Whelp Book"].waitForExistence(timeout: 10)
    }
}
