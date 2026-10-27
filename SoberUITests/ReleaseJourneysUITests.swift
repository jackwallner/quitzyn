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
        tap("Timeline", in: app)
        QA.checkpoint(app, "timeline")
        QA.interrupt(app)
        QA.checkpoint(app, "timeline-after-interruption")
        QA.relaunch(app)
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "garden-after-relaunch")
    }

    func testCoreLoopCheckInAndCravingPersist() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        let note = "Walked past the shop and kept going"
        QA.launch(app, arguments: ["-seedDemo", "-previewStore", "-QuitZynScreenshot"])
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20))
        // The demo seed already logged today, so the loop starts from Home's logged card.
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 15))
        QA.checkpoint(app, "home-logged")

        // Add a mood and a note to today.
        tap("Add note", in: app)
        XCTAssertTrue(app.navigationBars["Checked in"].waitForExistence(timeout: 10))
        tap("Good", in: app)
        let field = app.textFields["Anything you want to remember about today?"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(note)
        QA.checkpoint(app, "check-in-note")
        tap("Save", in: app)
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 10))
        QA.checkpoint(app, "home-after-note")

        // Ride out a craving.
        cravingButton(in: app).tap()
        tap("I'm through it", in: app)
        tap("It passed", in: app)
        XCTAssertTrue(app.staticTexts["Logged."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["Not saved"].exists)
        QA.checkpoint(app, "craving-saved")
        tap("Back to the garden", in: app)
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 10))

        // Everything is still there after a cold start.
        QA.relaunch(app)
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 10),
                      "The check-in was gone after relaunch")
        QA.checkpoint(app, "home-after-relaunch")
        // A tab on a phone, a pane beside Home on the unfolded Duo.
        let timelineTab = app.buttons["Timeline"].firstMatch
        if timelineTab.waitForExistence(timeout: 3) && timelineTab.isHittable { timelineTab.tap() }
        let logged = app.staticTexts["Logged nicotine-free"]
        scrollTo(logged, in: app)
        XCTAssertTrue(logged.exists, "Timeline does not show today as logged")
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", note)).firstMatch
        scrollTo(saved, in: app)
        XCTAssertTrue(saved.exists, "The note did not survive relaunch")
        QA.checkpoint(app, "timeline-after-relaunch")
    }

    private func cravingButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 5)
        var swipes = 0
        while !element.exists && swipes < 4 { app.swipeUp(); swipes += 1 }
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), label)
        if !button.isHittable { app.swipeUp() }
        button.tap()
    }
}
