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

    private func cravingButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), label)
        if !button.isHittable { app.swipeUp() }
        button.tap()
    }
}
