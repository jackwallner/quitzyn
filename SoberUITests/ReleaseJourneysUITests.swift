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

    /// Core loop: check in for today with a note, and the day and the note
    /// are still there after a relaunch.
    func testCoreLoopCheckInLogsTodayAndKeepsIt() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore"])
        let checkIn = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Check in for today")).firstMatch
        let addNote = app.buttons["Add note"].firstMatch
        // An earlier journey on this install may already have logged today;
        // the note sheet is then one tap further.
        if checkIn.waitForExistence(timeout: 20) {
            QA.checkpoint(app, "home-before-check-in")
            checkIn.tap()
        } else {
            XCTAssertTrue(addNote.waitForExistence(timeout: 5), "today can be checked in or noted")
            addNote.tap()
        }
        let note = "Walked it off \(Int(Date().timeIntervalSince1970) % 100_000)"
        let field = noteField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        focus(field)
        field.typeText(note)
        tap("Save", in: app)
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 10))
        XCTAssertFalse(checkIn.exists)
        QA.checkpoint(app, "home-checked-in")
        QA.relaunch(app)
        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Check in for today")).firstMatch.exists)
        QA.checkpoint(app, "home-after-relaunch")
        tap("Add note", in: app)
        let kept = noteField(in: app)
        XCTAssertTrue(kept.waitForExistence(timeout: 10))
        XCTAssertTrue((kept.value as? String ?? "").contains(note), "the note survives a relaunch")
        QA.checkpoint(app, "note-after-relaunch")
        tap("Skip", in: app)
    }

    /// A tap can miss on the unfolded Duo; a short press on the field's
    /// own coordinate focuses it there.
    private func focus(_ field: XCUIElement) {
        field.tap()
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<3 {
            let wait = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: focused, object: field)], timeout: 2)
            if wait == .completed { return }
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05)
        }
    }

    private func noteField(in app: XCUIApplication) -> XCUIElement {
        let types = [XCUIElement.ElementType.textField, .textView].map(\.rawValue)
        return app.descendants(matching: .any).matching(NSPredicate(format: "elementType IN %@", types)).firstMatch
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
