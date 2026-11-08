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
        if loggedMarker(in: app).waitForExistence(timeout: 6) {
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
        // Unfolded, Home's timeline pane has a "Good" button too; tap the sheet's own once it rests.
        let sheet = navigationBar("Checked in", in: app)
        let good = mood("Good", in: app, sheet: sheet)
        XCTAssertTrue(good.waitForExistence(timeout: 10), "The check-in sheet has no Good mood")
        waitUntilStill(good)
        good.tap()
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
        XCTAssertTrue(loggedMarker(in: app).waitForExistence(timeout: 10), "Home did not show today as logged after saving the note")
        QA.checkpoint(app, "home-after-note")

        // Ride out a craving.
        cravingButton(in: app).tap()
        tap("I'm through it", in: app)
        tap("It passed", in: app)
        XCTAssertTrue(text("Logged.", in: app).waitForExistence(timeout: 10), "The craving session never reached its Logged. screen")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Saving the craving raised an alert")
        QA.checkpoint(app, "craving-saved")
        tap("Back to the garden", in: app)
        XCTAssertTrue(loggedMarker(in: app).waitForExistence(timeout: 10), "Home lost today's check-in after the craving")

        // Everything is still there after a cold start.
        QA.relaunch(app)
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20), "Home never came back after the relaunch")
        XCTAssertTrue(loggedMarker(in: app).waitForExistence(timeout: 10),
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
        "Great": "Super",
        "Skip": "Überspringen",
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

    /// Home's logged card, found by its "Add note" button: a button query comes back fast
    /// on the unfolded Duo, where a static text query over Home's tree times out.
    private func loggedMarker(in app: XCUIApplication) -> XCUIElement {
        button("Add note", in: app)
    }

    private func navigationBar(_ english: String, in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.matching(NSPredicate(format: "identifier IN %@", labels(english))).firstMatch
    }

    /// Core loop: check in for today with a mood, and the day and the mood
    /// are still there after a relaunch.
    func testCoreLoopCheckInLogsTodayAndKeepsIt() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        QA.launch(app, arguments: ["-seedDemo", "-previewStore"])
        let checkIn = checkInButton(in: app)
        let addNote = loggedMarker(in: app)
        // An earlier journey on this install may already have logged today;
        // the mood sheet is then one tap further.
        if checkIn.waitForExistence(timeout: 20) {
            QA.checkpoint(app, "home-before-check-in")
            checkIn.tap()
        } else {
            XCTAssertTrue(addNote.waitForExistence(timeout: 5), "today can be checked in or noted")
            addNote.tap()
        }
        // The unfolded Duo keeps the timeline's own mood row beside Home, so
        // wait for the sheet itself before looking for a mood button.
        let sheet = navigationBar("Checked in", in: app)
        // The sheet can be slow to rise; a tap that landed mid-transition is retried.
        if !sheet.waitForExistence(timeout: 10), addNote.exists { addNote.tap() }
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "the check-in sheet opens")
        // Pick the mood that is not already chosen, so the save is a change.
        let good = mood("Good", in: app, sheet: sheet)
        XCTAssertTrue(good.waitForExistence(timeout: 10))
        // Unfolded, the sheet keeps rising after it appears; tap once it rests.
        waitUntilStill(good)
        let choice = good.isSelected ? mood("Great", in: app, sheet: sheet) : good
        let chosen = choice.label
        choice.tap()
        // Unfolded, a tap can miss; a short press on the button selects it there.
        if !waitUntilSelected(chosen, in: app, sheet: sheet, timeout: 3) {
            choice.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05)
        }
        XCTAssertTrue(waitUntilSelected(chosen, in: app, sheet: sheet, timeout: 5), "\(chosen) is selected")
        tap("Save", in: app)
        XCTAssertTrue(loggedMarker(in: app).waitForExistence(timeout: 10), "Home did not show today as logged")
        XCTAssertFalse(checkIn.exists)
        QA.checkpoint(app, "home-checked-in")
        QA.relaunch(app)
        XCTAssertTrue(loggedMarker(in: app).waitForExistence(timeout: 20), "The check-in was gone after relaunch")
        XCTAssertFalse(checkInButton(in: app).exists)
        QA.checkpoint(app, "home-after-relaunch")
        tap("Add note", in: app)
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "the check-in sheet opens")
        XCTAssertTrue(mood(chosen, in: app, sheet: sheet).waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilSelected(chosen, in: app, sheet: sheet, timeout: 5), "the mood survives a relaunch")
        QA.checkpoint(app, "mood-after-relaunch")
        tap("Skip", in: app)
    }

    private func waitUntilSelected(_ name: String, in app: XCUIApplication, sheet: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if mood(name, in: app, sheet: sheet).isSelected { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return mood(name, in: app, sheet: sheet).isSelected
    }

    private func waitUntilStill(_ element: XCUIElement) {
        var last = element.frame
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.5)
            let now = element.frame
            if now == last { return }
            last = now
        }
    }

    /// The mood button inside the check-in sheet. Home's Timeline pane and the
    /// Home card can show buttons with the same label behind or beside it, and
    /// a tap on one of those lands on the sheet's backdrop and dismisses it.
    private func mood(_ name: String, in app: XCUIApplication, sheet: XCUIElement) -> XCUIElement {
        let names = labels(name)
        let matches = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ OR label ENDSWITH %@", names[0], names[1]))
        let box = sheet.frame
        let inSheet = matches.allElementsBoundByIndex.first {
            let f = $0.frame
            return f.minY > box.maxY && f.minX >= box.minX - 1 && f.maxX <= box.maxX + 1
        }
        return inSheet ?? matches.firstMatch
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
