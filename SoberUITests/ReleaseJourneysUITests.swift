import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test01FirstRunToGarden() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        QA.launch(app, arguments: ["-previewStore"])
        XCTAssertTrue(button("Get Started", in: app).waitForExistence(timeout: 20))
        QA.checkpoint(app, "welcome")
        tap("Get Started", in: app)
        QA.checkpoint(app, "start-date")
        tap("Continue", in: app)
        QA.checkpoint(app, "daily-spend")
        tap("Continue", in: app)
        XCTAssertTrue(button("Get started", in: app).waitForExistence(timeout: 15))
        QA.checkpoint(app, "onboarding-trial", paywall: true)
        tap("Get started", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons.firstMatch.tap()
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
        XCTAssertTrue(button("I'm through it", in: app).waitForExistence(timeout: 10))
        // The breathing circle and the countdown move on purpose; nothing else may.
        QA.checkpoint(app, "craving-session", ambient: ["craving.breathing", "craving.timer"])
        tap("I'm through it", in: app)
        tap("It passed", in: app)
        XCTAssertTrue(text("Logged.", in: app).waitForExistence(timeout: 10))
        QA.checkpoint(app, "craving-saved")
        tap("Back to the garden", in: app)
        // A tab on a phone, already a pane beside Home on the unfolded Duo.
        let timelineTab = button("Timeline", in: app)
        if timelineTab.waitForExistence(timeout: 3) && timelineTab.isHittable { timelineTab.tap() }
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
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20), "Home never showed the craving button")
        // The store outlives a test: this one runs after test01 and test02 (alphabetical order),
        // which already finished onboarding, so -seedDemo does not log today and Home offers the
        // check-in instead. Start from whichever state Home is really in.
        if text("Today is logged", in: app).waitForExistence(timeout: 6) {
            QA.checkpoint(app, "home-logged")
            tap("Add note", in: app)
        } else {
            QA.checkpoint(app, "home-unlogged")
            let checkIn = checkInButton(in: app)
            XCTAssertTrue(checkIn.waitForExistence(timeout: 10), "Home showed neither a logged day nor the check-in button")
            checkIn.tap()
        }
        // Either path ends on the check-in sheet.
        XCTAssertTrue(navigationBar("Checked in", in: app).waitForExistence(timeout: 10), "The check-in sheet never opened")
        tap("Good", in: app)
        let fieldPrompt = NSPredicate(format: "label IN %@ OR placeholderValue IN %@", labels("Anything you want to remember about today?"), labels("Anything you want to remember about today?"))
        // A vertical-axis TextField is a text view on some layouts (the unfolded Duo).
        let field = app.textFields.matching(fieldPrompt).firstMatch.exists
            ? app.textFields.matching(fieldPrompt).firstMatch
            : app.textViews.matching(fieldPrompt).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The note field is missing from the check-in sheet")
        field.tap()
        field.typeText(note)
        QA.checkpoint(app, "check-in-note")
        tap("Save", in: app)
        XCTAssertTrue(text("Today is logged", in: app).waitForExistence(timeout: 10), "Home did not show today as logged after saving the note")
        QA.checkpoint(app, "home-after-note")

        // Ride out a craving.
        cravingButton(in: app).tap()
        tap("I'm through it", in: app)
        tap("It passed", in: app)
        XCTAssertTrue(text("Logged.", in: app).waitForExistence(timeout: 10), "The craving session never reached its Logged. screen")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Saving the craving raised an alert")
        QA.checkpoint(app, "craving-saved")
        tap("Back to the garden", in: app)
        XCTAssertTrue(text("Today is logged", in: app).waitForExistence(timeout: 10), "Home lost today's check-in after the craving")

        // Everything is still there after a cold start.
        QA.relaunch(app)
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20), "Home never came back after the relaunch")
        XCTAssertTrue(text("Today is logged", in: app).waitForExistence(timeout: 10),
                      "The check-in was gone after relaunch")
        QA.checkpoint(app, "home-after-relaunch")
        // A tab on a phone, a pane beside Home on the unfolded Duo.
        let timelineTab = button("Timeline", in: app)
        if timelineTab.waitForExistence(timeout: 3) && timelineTab.isHittable { timelineTab.tap() }
        let logged = text("Logged nicotine-free", in: app)
        scrollTo(logged, in: app)
        XCTAssertTrue(logged.exists, "Timeline does not show today as logged")
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "value == %@", note)).firstMatch
        scrollTo(saved, in: app)
        XCTAssertTrue(saved.exists, "The note did not survive relaunch")
        QA.checkpoint(app, "timeline-after-relaunch")
    }

    /// English and German labels, copied from Localizable.xcstrings, so the
    /// journeys run on the german persona too.
    private static let german: [String: String] = [
        "Get Started": "Los geht's",
        "Get started": "Los geht's",
        "Continue": "Weiter",
        "Not now": "Nicht jetzt",
        "Keep the free version?": "Kostenlose Version behalten?",
        "I'm through it": "Ich hab's geschafft",
        "It passed": "Es ist vorbei",
        "Logged.": "Eingetragen.",
        "Back to the garden": "Zurück zum Garten",
        "Timeline": "Verlauf",
        "Today is logged": "Heute erfasst",
        "Add note": "Notiz hinzufügen",
        "Check in for today": "Mach den heutigen Check-in",
        "Checked in": "Eingecheckt",
        "Good": "Gut",
        "Anything you want to remember about today?": "Möchtest du dir etwas von heute merken?",
        "Save": "Sichern",
        "Logged nicotine-free": "Nikotinfrei eingetragen"
    ]

    private func labels(_ english: String) -> [String] {
        [english, Self.german[english] ?? english]
    }

    private func button(_ english: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", labels(english))).firstMatch
    }

    private func text(_ english: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label IN %@", labels(english))).firstMatch
    }

    private func navigationBar(_ english: String, in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.matching(NSPredicate(format: "identifier IN %@", labels(english))).firstMatch
    }

    private func cravingButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "I'm having a", "Ich verspüre gerade")).firstMatch
    }

    private func checkInButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Check in for today", "Mach den heutigen Check-in")).firstMatch
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 5)
        var swipes = 0
        while !element.exists && swipes < 4 { QA.swipe(app, .up); swipes += 1 }
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let target = button(label, in: app)
        XCTAssertTrue(target.waitForExistence(timeout: 15), label)
        if !target.isHittable { QA.swipe(app, .up) }
        target.tap()
    }
}
