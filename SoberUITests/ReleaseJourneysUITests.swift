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
        QA.checkpoint(app, "craving-session")
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
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20))
        // The demo seed already logged today, so the loop starts from Home's logged card.
        XCTAssertTrue(text("Today is logged", in: app).waitForExistence(timeout: 15))
        QA.checkpoint(app, "home-logged")

        // Add a mood and a note to today.
        tap("Add note", in: app)
        XCTAssertTrue(navigationBar("Checked in", in: app).waitForExistence(timeout: 10))
        tap("Good", in: app)
        let field = app.textFields.matching(NSPredicate(format: "label IN %@ OR placeholderValue IN %@", labels("Anything you want to remember about today?"), labels("Anything you want to remember about today?"))).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(note)
        QA.checkpoint(app, "check-in-note")
        tap("Save", in: app)
        XCTAssertTrue(text("Today is logged", in: app).waitForExistence(timeout: 10))
        QA.checkpoint(app, "home-after-note")

        // Ride out a craving.
        cravingButton(in: app).tap()
        tap("I'm through it", in: app)
        tap("It passed", in: app)
        XCTAssertTrue(text("Logged.", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        QA.checkpoint(app, "craving-saved")
        tap("Back to the garden", in: app)
        XCTAssertTrue(text("Today is logged", in: app).waitForExistence(timeout: 10))

        // Everything is still there after a cold start.
        QA.relaunch(app)
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20))
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
