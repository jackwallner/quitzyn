import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test01FirstRunToGarden() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        QA.launch(app, arguments: ["-previewStore"])
        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "welcome")
        tap("Get Started", in: app)
        QA.checkpoint(app, "start-date")
        tap("Continue", in: app)
        QA.checkpoint(app, "daily-spend")
        tap("Continue", in: app)
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap("Get started", in: app)
        XCTAssertTrue(app.alerts["Keep the free version?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Get started"].tap()
        QA.checkpoint(app, "reminder")
        tap("Continue", in: app)
        QA.checkpoint(app, "commitment")
        tap("Not now", in: app)
        let craving = cravingButton(in: app)
        XCTAssertTrue(craving.waitForExistence(timeout: 20))
        QA.checkpoint(app, "first-garden")
    }

    func test02CravingTimelineAndReturn() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore", "-QuitZynScreenshot"])
        let craving = cravingButton(in: app)
        XCTAssertTrue(craving.waitForExistence(timeout: 20))
        QA.checkpoint(app, "garden-return")
        craving.tap()
        XCTAssertTrue(app.buttons["I'm through it"].waitForExistence(timeout: 10))
        QA.checkpoint(app, "craving-session")
        tap("I'm through it", in: app)
        tap("It passed", in: app)
        XCTAssertTrue(app.staticTexts["Logged."].waitForExistence(timeout: 10))
        QA.checkpoint(app, "craving-saved")
        tap("Back to the garden", in: app)
        // Unfolded, the Timeline is the trailing pane and has no tab.
        if app.buttons["Timeline"].firstMatch.waitForExistence(timeout: 3) { tap("Timeline", in: app) }
        QA.checkpoint(app, "timeline")
        QA.interrupt(app)
        QA.checkpoint(app, "timeline-after-interruption")
        QA.relaunch(app)
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "garden-after-relaunch")
    }

    /// Core loop: check in for today with a mood, and the day and the mood
    /// are still there after a relaunch.
    func testCoreLoopCheckInLogsTodayAndKeepsIt() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore"])
        let checkIn = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Check in for today")).firstMatch
        let addNote = app.buttons["Add note"].firstMatch
        // An earlier journey on this install may already have logged today;
        // the mood sheet is then one tap further.
        if checkIn.waitForExistence(timeout: 20) {
            QA.checkpoint(app, "home-before-check-in")
            checkIn.tap()
        } else {
            XCTAssertTrue(addNote.waitForExistence(timeout: 5), "today can be checked in or noted")
            addNote.tap()
        }
        // Pick the mood that is not already chosen, so the save is a change.
        let good = mood("Good", in: app)
        // The sheet can be slow to rise; a tap that landed mid-transition is retried.
        if !good.waitForExistence(timeout: 10), addNote.exists { addNote.tap() }
        XCTAssertTrue(good.waitForExistence(timeout: 10))
        let choice = good.isSelected ? mood("Great", in: app) : good
        let chosen = choice.label
        choice.tap()
        assertSelected(chosen, in: app, "\(chosen) is selected")
        tap("Save", in: app)
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 10))
        XCTAssertFalse(checkIn.exists)
        QA.checkpoint(app, "home-checked-in")
        QA.relaunch(app)
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Check in for today")).firstMatch.exists)
        QA.checkpoint(app, "home-after-relaunch")
        tap("Add note", in: app)
        XCTAssertTrue(mood(chosen, in: app).waitForExistence(timeout: 10))
        assertSelected(chosen, in: app, "the mood survives a relaunch")
        QA.checkpoint(app, "mood-after-relaunch")
        tap("Skip", in: app)
    }

    /// Home can show a button ending in the same mood word behind the sheet,
    /// so look for a selected one rather than the first match.
    private func assertSelected(_ name: String, in app: XCUIApplication, _ message: String) {
        let selected = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ AND isSelected == true", name)).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 5), message)
    }

    private func mood(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", name)).firstMatch
    }

    private func cravingButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), label)
        if !button.isHittable { QA.swipe(app.windows.firstMatch, .up) }
        button.tap()
    }
}
