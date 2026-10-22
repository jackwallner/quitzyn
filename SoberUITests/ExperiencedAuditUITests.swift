import XCTest

/// Walks the app as someone who has been using it for months (a seeded
/// 129-day journey) and keeps coming back for the same few jobs: the daily
/// check-in, riding out a craving, correcting history on Timeline, reading the
/// money and pattern numbers, and logging a slip.
///
/// These are observation tests. They record screenshots, element frames and
/// the visible numbers as attachments rather than asserting on UX opinions;
/// they only fail when a screen the walk depends on never shows up.
final class ExperiencedAuditUITests: XCTestCase {
    private var app: XCUIApplication!
    private var observations: [String] = []

    override func setUp() {
        continueAfterFailure = true
        observations = []
    }

    override func tearDown() {
        let text = observations.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = "observations"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Helpers

    /// `plain` leaves today unlogged (the check-in button exists); `rich` adds
    /// the screenshot seed (journal, moods through today, cravings) and marks
    /// today logged.
    private func launch(pro: Bool = true, rich: Bool = false, extra: [String] = []) {
        app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        var args = ["-seedDemo", "-seedDays", "129"]
        if pro { args.append("-demoPro") }
        if rich { args.append("-QuitZynScreenshot") }
        app.launchArguments += args + extra
        app.launch()
        dismissCelebrationIfShown()
    }

    private func dismissCelebrationIfShown() {
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 4) {
            shot("00-growth-celebration-on-open")
            note("Growth celebration overlay shown on open; tapped Continue")
            cont.tap()
        }
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ text: String) {
        observations.append(text)
        NSLog("AUDIT %@", text)
    }

    private func dumpTree(_ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "tree-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func frameText(_ element: XCUIElement) -> String {
        guard element.exists else { return "missing" }
        let f = element.frame
        return "x\(Int(f.minX)) y\(Int(f.minY)) w\(Int(f.width)) h\(Int(f.height)) hittable=\(element.isHittable)"
    }

    private func tab(_ name: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[name]
        return inBar.exists ? inBar : app.buttons[name]
    }

    @discardableResult
    private func tapIf(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            note("MISSING: \(label)")
            return false
        }
        element.tap()
        return true
    }

    private func labels(containing needle: String) -> [String] {
        app.staticTexts.allElementsBoundByIndex
            .map { $0.label }
            .filter { $0.contains(needle) }
    }

    private func allLabels() -> String {
        app.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
    }

    private var checkInButton: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Check in for today")).firstMatch
    }

    private var cravingButton: XCUIElement {
        app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
    }

    private func openMore(_ item: String) {
        if tapIf(app.buttons["More"], "More menu") {
            tapIf(app.buttons[item], "More > \(item)")
        }
    }

    private func typeInto(_ field: XCUIElement, _ text: String, _ label: String) {
        guard field.waitForExistence(timeout: 5) else { note("MISSING field: \(label)"); return }
        field.tap()
        field.typeText(text)
    }

    // MARK: - 1. Daily check-in, then coming back

    func testDailyCheckInAndReturn() {
        launch()
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 20), "Home never showed the check-in button")
        shot("01-home-before-checkin")
        note("Home labels before check-in: \(allLabels())")
        note("check-in button frame: \(frameText(checkInButton))")
        note("craving button frame: \(frameText(cravingButton))")

        checkInButton.tap()
        let skip = app.buttons["Skip"]
        note("Checked-in sheet appeared after tap: \(skip.waitForExistence(timeout: 5))")
        shot("02-checkin-note-sheet")
        note("sheet Skip frame: \(frameText(skip))  Save frame: \(frameText(app.buttons["Save"]))")
        tapIf(skip, "Skip")

        XCTAssertTrue(app.staticTexts["Today is logged"].waitForExistence(timeout: 8))
        shot("03-home-after-checkin")
        note("Home labels after check-in: \(allLabels())")
        note("Add note frame: \(frameText(app.buttons["Add note"]))")

        // Add a note afterwards, as an experienced user does when they remember.
        if tapIf(app.buttons["Add note"], "Add note") {
            shot("04-add-note-sheet-empty")
            let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
            typeInto(field, "Long meeting, no urge", "note field")
            tapIf(app.buttons["Good"], "mood Good")
            shot("05-add-note-sheet-filled-keyboard")
            note("mood Good frame: \(frameText(app.buttons["Good"]))")
            tapIf(app.buttons["Save"], "Save")
        }
        sleep(1)
        shot("06-home-after-note-saved")

        app.terminate()
        app.launch()
        dismissCelebrationIfShown()
        sleep(2)
        shot("07-home-after-relaunch")
        note("Home labels after relaunch: \(allLabels())")
        note("Check-in button present after relaunch: \(checkInButton.exists)")
    }

    // MARK: - 2. Money numbers: Progress sheet vs Settings

    func testProgressAndSettingsCostNumbers() {
        launch()
        XCTAssertTrue(app.buttons["Progress"].waitForExistence(timeout: 20))
        note("Progress button frame: \(frameText(app.buttons["Progress"]))  More frame: \(frameText(app.buttons["More"]))")
        app.buttons["Progress"].tap()
        sleep(1)
        shot("10-progress-sheet-top")
        note("Progress labels: \(allLabels())")
        app.swipeUp()
        shot("11-progress-sheet-scrolled")
        note("Progress labels after scroll: \(allLabels())")
        tapIf(app.buttons["Done"], "Progress Done")

        openMore("Settings")
        sleep(1)
        shot("12-settings-top")
        app.swipeUp()
        shot("13-settings-cost-section")
        note("Settings labels: \(allLabels())")
        note("steppers: \(app.steppers.count)")
        for index in 0..<app.steppers.count {
            note("stepper \(index) frame: \(frameText(app.steppers.element(boundBy: index))) label=\(app.steppers.element(boundBy: index).label) value=\(String(describing: app.steppers.element(boundBy: index).value))")
        }
        // Cost per day is the stepper whose label starts with "Cost".
        let cost = app.steppers.matching(NSPredicate(format: "label BEGINSWITH %@", "Cost")).firstMatch
        if cost.exists {
            note("cost before: label=\(cost.label) value=\(String(describing: cost.value))")
            cost.buttons["Increment"].tap()
            shot("14-settings-cost-after-increment")
            note("cost after +1 step: label=\(cost.label) value=\(String(describing: cost.value))")
            note("labels with $: \(labels(containing: "$"))")
        }
        let hour = app.steppers.matching(NSPredicate(format: "label BEGINSWITH %@", "Hour")).firstMatch
        note("reminder stepper: label=\(hour.label) value=\(String(describing: hour.value))")
        dumpTree("settings")
    }

    // MARK: - 3. Craving: leave early vs finish, then the patterns it feeds

    func testCravingEarlyExitVersusFinishAndPatterns() {
        launch(rich: true)
        XCTAssertTrue(cravingButton.waitForExistence(timeout: 20))
        openPatterns(tag: "20-patterns-before")

        // Early exit through the X after the urge fades.
        cravingButton.tap()
        sleep(12)
        shot("21-craving-breathing-12s")
        let close = app.buttons["Close"]
        note("craving Close frame: \(frameText(close))  'I'm through it' frame: \(frameText(app.buttons["I'm through it"]))")
        note("breathing labels: \(allLabels())")
        tapIf(close, "Close (X)")
        sleep(1)
        shot("22-home-after-x-exit")
        note("After X: Home craving button present = \(cravingButton.waitForExistence(timeout: 5))")
        openPatterns(tag: "23-patterns-after-x-exit")

        // Full path: I'm through it, rate, tag, It passed.
        cravingButton.tap()
        sleep(10)
        tapIf(app.buttons["I'm through it"], "I'm through it")
        sleep(1)
        shot("24-craving-reflect")
        note("reflect labels: \(allLabels())")
        let notSure = app.buttons["Not sure yet. Close session"]
        let gaveIn = app.buttons["I gave in"]
        let passed = app.buttons["It passed"]
        note("frames: passed \(frameText(passed)) | notSure \(frameText(notSure)) | gaveIn \(frameText(gaveIn))")
        note("intensity 3 frame: \(frameText(app.buttons["Intensity 3 of 5"]))  Stress chip: \(frameText(app.buttons["Stress"]))")
        tapIf(app.buttons["Intensity 4 of 5"], "intensity 4")
        tapIf(app.buttons["After a meal"], "trigger After a meal")
        shot("25-craving-reflect-filled")
        tapIf(passed, "It passed")
        sleep(1)
        shot("26-craving-done")
        note("done labels: \(allLabels())")
        tapIf(app.buttons["Back to the garden"], "Back to the garden")
        sleep(1)
        shot("27-home-after-craving")
        openPatterns(tag: "28-patterns-after-full-session")
    }

    private func openPatterns(tag: String) {
        tapIf(tab("Support"), "Support tab (Bloom+ hub in screenshot mode)")
        let link = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Your patterns")).firstMatch
        if tapIf(link, "Your patterns row") {
            sleep(1)
            shot(tag)
            note("\(tag) labels: \(allLabels())")
            let back = app.navigationBars.buttons.firstMatch
            if back.exists { back.tap() }
        }
        tapIf(tab("Home"), "Home tab")
    }

    // MARK: - 4. Craving that runs to the end of the clock

    func testCravingTimerRunsOutWhileStillCraving() {
        launch()
        XCTAssertTrue(cravingButton.waitForExistence(timeout: 20))
        cravingButton.tap()
        let started = Date()
        sleep(60)
        shot("30-craving-60s")
        note("at 60s labels: \(allLabels())")
        sleep(52)
        shot("31-craving-112s")
        note("at ~112s labels: \(allLabels())  'another minute' frame: \(frameText(app.buttons["Give me another minute"]))")
        let questions = app.staticTexts["Two quick questions while it's fresh. Both optional."]
        let appeared = questions.waitForExistence(timeout: 30)
        note("auto-advance to questions after \(Int(Date().timeIntervalSince(started)))s: \(appeared)")
        shot("32-craving-auto-advanced")
        note("any way back to breathing? 'Give me another minute' exists=\(app.buttons["Give me another minute"].exists), 'Keep breathing' exists=\(app.buttons["Keep breathing"].exists)")
        tapIf(app.buttons["Not sure yet. Close session"], "Not sure yet")
        sleep(1)
        shot("33-home-after-not-sure")
    }

    // MARK: - 5. Timeline: correct history

    func testTimelineEditingAndNavigation() {
        launch(rich: true)
        tapIf(tab("Timeline"), "Timeline tab")
        sleep(1)
        shot("40-timeline-top")
        note("Timeline labels: \(allLabels())")
        note("prev month frame: \(frameText(app.buttons["Previous month"]))  next month: \(frameText(app.buttons["Next month"]))")
        dumpTree("timeline")

        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day, value: -2, to: .now) ?? .now
        if calendar.component(.month, from: target) != calendar.component(.month, from: .now) {
            tapIf(app.buttons["Previous month"], "Previous month")
        }
        let dayNumber = String(calendar.component(.day, from: target))
        let cell = app.staticTexts[dayNumber]
        note("day cell \(dayNumber) frame: \(frameText(cell))")
        if tapIf(cell, "day cell \(dayNumber)") {
            sleep(1)
            shot("41-timeline-day-selected")
            note("selected-day labels: \(allLabels())")
        }

        // Mood tap and note typing on a logged day save per keystroke.
        tapIf(app.buttons["Rough"], "mood Rough")
        let noteField = app.textFields["How did the day go?"].exists
            ? app.textFields["How did the day go?"]
            : app.textViews["How did the day go?"]
        typeInto(noteField, "Edited note", "timeline note")
        shot("42-timeline-note-typed-keyboard")
        app.swipeUp()
        shot("43-timeline-editor-bottom")
        note("bottom labels: \(allLabels())")
        let change = app.buttons["Change to slip"]
        let delete = app.buttons["Delete log"]
        note("Change to slip frame: \(frameText(change))  Delete log frame: \(frameText(delete))")

        if tapIf(delete, "Delete log") {
            sleep(1)
            shot("44-timeline-after-delete-no-confirm")
            note("alerts after Delete log tap: \(app.alerts.count)")
            note("labels after delete: \(allLabels())")
        }

        // Jump back several months: is there a way home?
        app.swipeDown()
        for _ in 0..<4 { tapIf(app.buttons["Previous month"], "Previous month", timeout: 2) }
        shot("45-timeline-four-months-back")
        note("Today shortcut present: \(app.buttons["Today"].exists)")

        // Swipe across the grid to change month.
        let before = allLabels()
        app.swipeLeft()
        sleep(1)
        note("swipe left changed labels: \(before != allLabels())")
    }

    // MARK: - 6. Slip: log, undo, log again, log twice

    func testSlipLoggingAndUndo() {
        launch()
        XCTAssertTrue(checkInButton.waitForExistence(timeout: 20))
        openMore("I slipped")
        sleep(1)
        shot("50-slip-sheet")
        note("slip sheet labels: \(allLabels())")
        tapIf(app.buttons["Log it and keep going"], "Log it and keep going")
        sleep(1)
        shot("51-slip-confirmation")
        note("confirmation labels: \(allLabels())")
        tapIf(app.buttons["Undo, I didn't slip"], "Undo, I didn't slip")
        sleep(1)
        shot("52-home-after-undo")
        note("Home labels after undo: \(allLabels())  check-in button back=\(checkInButton.exists)")

        openMore("I slipped")
        tapIf(app.buttons["Log it and keep going"], "Log it again")
        tapIf(app.buttons["Done"], "Done")
        sleep(1)
        shot("53-home-after-slip")
        note("Home labels after slip: \(allLabels())")
        note("Undo on card: \(frameText(app.buttons["Undo"]))")

        // A second slip the same day from the menu.
        openMore("I slipped")
        sleep(1)
        shot("54-slip-sheet-second-time-same-day")
        tapIf(app.buttons["Log it and keep going"], "second slip log")
        sleep(1)
        shot("55-second-slip-confirmation")
        note("second slip labels: \(allLabels())")
        tapIf(app.buttons["Done"], "Done 2")

        tapIf(tab("Timeline"), "Timeline")
        sleep(1)
        shot("56-timeline-after-slip")
        note("Timeline after slip: \(allLabels())")
    }

    // MARK: - 7. Reset counter wording vs what it does

    func testResetCounterWipesTree() {
        launch()
        XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 20))
        shot("60-home-before-reset")
        openMore("Reset counter")
        sleep(1)
        shot("61-reset-alert")
        note("reset alert text: \(app.alerts.firstMatch.label) / \(app.alerts.firstMatch.staticTexts.allElementsBoundByIndex.map { $0.label })")
        tapIf(app.alerts.buttons["Reset"], "Reset")
        sleep(2)
        shot("62-home-after-reset")
        note("after reset labels: \(allLabels())")
        tapIf(tab("Timeline"), "Timeline")
        sleep(1)
        shot("63-timeline-after-reset")
        note("Timeline after reset: \(allLabels())")
    }

    // MARK: - 8. Journal: the loss paths

    func testJournalLossPaths() {
        launch(rich: true)
        tapIf(tab("Journal"), "Journal tab")
        sleep(1)
        shot("70-journal")
        note("journal pencil frame: \(frameText(app.buttons["New entry"]))")

        // Cancel after typing.
        if tapIf(app.buttons["New entry"], "New entry") {
            let editor = app.textViews.firstMatch
            typeInto(editor, "A long entry I do not want to lose after a hard evening.", "compose editor")
            shot("71-compose-typed")
            note("Cancel frame: \(frameText(app.buttons["Cancel"]))  Save frame: \(frameText(app.buttons["Save"]))")
            tapIf(app.buttons["Cancel"], "Cancel")
            sleep(1)
            shot("72-after-cancel-no-confirm")
            note("alerts/confirmation after Cancel: alerts=\(app.alerts.count) sheets=\(app.sheets.count)")
        }

        // Swipe-down dismissal with text typed.
        if tapIf(app.buttons["New entry"], "New entry 2") {
            typeInto(app.textViews.firstMatch, "Second draft text", "compose editor 2")
            app.swipeDown(velocity: .fast)
            sleep(1)
            shot("73-after-swipe-dismiss")
            note("compose still open after swipe: \(app.navigationBars["New Entry"].exists)")
        }

        // Open an entry, look at the toolbar, edit, then delete.
        let entry = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Went a full workday")).firstMatch
        if tapIf(entry, "first seeded entry") {
            sleep(1)
            shot("74-entry-detail")
            note("trash frame: \(frameText(app.buttons["Delete entry"]))  pencil frame: \(frameText(app.buttons["Edit entry"]))  Done: \(frameText(app.buttons["Done"]))")
            tapIf(app.buttons["Edit entry"], "Edit entry")
            sleep(1)
            shot("75-entry-editing")
            note("while editing: Cancel exists=\(app.buttons["Cancel"].exists) Done exists=\(app.buttons["Done"].exists) Save exists=\(app.buttons["Save"].exists)")
            let count = app.staticTexts.count
            tapIf(app.buttons["Delete entry"], "Delete entry")
            sleep(1)
            shot("76-after-delete-no-confirm")
            note("alerts after trash tap: \(app.alerts.count); static text count \(count) -> \(app.staticTexts.count); detail sheet still up: \(app.navigationBars["Free Write"].exists)")
        }
    }

    // MARK: - 9. Free user: what the same walk looks like without Bloom+

    func testFreeUserReturnVisit() {
        launch(pro: false)
        sleep(3)
        shot("80-free-home-3s")
        note("free Home labels: \(allLabels())")
        sleep(9)
        shot("81-free-home-12s")
        note("sheets at 12s: \(app.sheets.count); labels: \(allLabels())")

        tapIf(tab("Health"), "Health tab")
        sleep(1)
        shot("82-free-health")
        tapIf(tab("Journal"), "Journal tab")
        sleep(1)
        shot("83-free-journal")
        tapIf(tab("Timeline"), "Timeline tab")
        sleep(1)
        shot("84-free-timeline")
        note("free Timeline labels: \(allLabels())")
        tapIf(tab("Upgrade"), "Upgrade tab")
        sleep(2)
        shot("85-free-upgrade-tab")
        note("upgrade tab labels: \(allLabels())")
        tapIf(tab("Home"), "Home tab")

        // Settings, restore.
        openMore("Settings")
        sleep(1)
        shot("86-free-settings-top")
        if tapIf(app.buttons["Restore Purchases"], "Restore Purchases") {
            sleep(3)
            shot("87-free-after-restore")
            note("after restore labels: \(allLabels())")
        }

        // Progress sheet for a free user.
        tapIf(app.buttons["Done"], "Settings Done", timeout: 2)
        tapIf(app.buttons["Progress"], "Progress")
        sleep(1)
        shot("88-free-progress")
        note("free progress labels: \(allLabels())")
    }

    // MARK: - 10. Pro hub and Health

    func testProHubAndHealth() {
        launch(rich: true)
        tapIf(tab("Support"), "Bloom+ hub tab")
        sleep(1)
        shot("90-pro-hub")
        note("hub labels: \(allLabels())")
        app.swipeUp()
        shot("91-pro-hub-scrolled")
        tapIf(tab("Health"), "Health")
        sleep(1)
        shot("92-pro-health")
        note("health labels: \(allLabels())")
        app.swipeUp()
        shot("93-pro-health-scrolled")
    }

    // MARK: - 11. Large text

    func testLargeTextHomeCravingTimeline() {
        launch(rich: true, extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        sleep(2)
        shot("100-axxl-home")
        note("AX XL Home: craving frame \(frameText(cravingButton))  More: \(frameText(app.buttons["More"]))")
        if tapIf(cravingButton, "craving") {
            sleep(3)
            shot("101-axxl-craving-breathing")
            note("AX XL breathing: through-it frame \(frameText(app.buttons["I'm through it"]))")
            tapIf(app.buttons["I'm through it"], "through it")
            sleep(1)
            shot("102-axxl-craving-reflect")
            app.swipeUp()
            shot("103-axxl-craving-reflect-bottom")
            tapIf(app.buttons["Not sure yet. Close session"], "Not sure yet")
        }
        sleep(1)
        tapIf(tab("Timeline"), "Timeline")
        sleep(1)
        shot("104-axxl-timeline")
    }
}
