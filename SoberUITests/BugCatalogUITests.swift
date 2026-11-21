import XCTest

/// Flows from the 2026-11-20 bug catalog that only a running app can show.
/// The class sorts first in the bundle so the check-in test meets a store no
/// other test has logged today on.
@MainActor
final class BugCatalogUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private let bundleID = "com.jackwallner.quitzyn"

    private func cravingButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// B3: the trial pitch a free user's third check-in earns used to replace
    /// the open mood and note sheet, throwing away what they had typed. It
    /// now waits for the sheet to close.
    func test1CheckInPitchWaitsForTheNoteSheet() throws {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        // The usage count lives in app-group defaults; the argument domain
        // presets it so this check-in is past the pitch threshold.
        app.launchArguments += ["-seedDemo", "-previewStore", "-checkInCompletedCount", "5"]
        app.launch()
        XCTAssertTrue(cravingButton(in: app).waitForExistence(timeout: 20), "Home never appeared")
        let checkIn = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Check in for today")).firstMatch
        guard checkIn.waitForExistence(timeout: 6) else {
            throw XCTSkip("Today was already logged by an earlier test in this run")
        }
        checkIn.tap()
        let sheet = app.navigationBars["Checked in"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "The note sheet never opened")
        let prompt = "Anything you want to remember about today?"
        let byPrompt = NSPredicate(format: "label == %@ OR placeholderValue == %@", prompt, prompt)
        let fields = [app.textViews.matching(byPrompt).firstMatch, app.textFields.matching(byPrompt).firstMatch]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, !fields.contains(where: \.exists) { usleep(300_000) }
        let field = try XCTUnwrap(fields.first(where: \.exists), "The note field is missing")
        // The sheet slides up; tap once the field has settled on screen.
        let settle = Date().addingTimeInterval(5)
        while Date() < settle, !field.isHittable { usleep(200_000) }
        field.tap()
        app.typeText("Walked past the shop")
        // The pitch used to fire 2.5 s after the tap, over the sheet.
        sleep(6)
        attach(app, "b3-note-sheet-after-6s")
        XCTAssertTrue(sheet.exists, "The note sheet was replaced while the user was typing")
        XCTAssertFalse(app.buttons["Not now"].exists, "The trial pitch rose over the note sheet")
        app.navigationBars["Checked in"].buttons["Save"].tap()
        // The pitch is deferred, not dropped.
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 10), "The trial pitch never followed the note sheet")
        attach(app, "b3-pitch-after-save")
    }

    /// B7: the craving countdown counted timer ticks, so time the timer did
    /// not fire (the app suspended in the background) was never counted. The
    /// simulator under XCUITest keeps a backgrounded app running, so a 20 s
    /// main-thread stall stands in for the suspension: the timer misses its
    /// ticks the same way.
    func test2CravingClockCountsTimeTheTimerMissed() throws {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += ["-seedDemo", "-debugStallCravingClock"]
        app.launch()
        let start = cravingButton(in: app)
        XCTAssertTrue(start.waitForExistence(timeout: 20), "Home never showed the craving button")
        start.tap()
        let timer = app.staticTexts["craving.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10), "The session countdown never appeared")
        sleep(26)
        attach(app, "b7-countdown-after-stall")
        let parts = timer.label.split(separator: ":").compactMap { Int($0) }
        let left = try XCTUnwrap(parts.count == 2 ? parts[0] * 60 + parts[1] : nil, "Unreadable countdown \(timer.label)")
        // A 2:00 session about 27 s in, 20 of them stalled: about 1:33 left.
        // Counting ticks it read about 1:52.
        XCTAssertLessThanOrEqual(left, 100, "The countdown read \(timer.label) after a 20 s stall")
    }
}
