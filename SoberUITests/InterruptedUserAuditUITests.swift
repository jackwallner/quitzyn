import XCTest

/// Audit evidence for a tired, busy user who is interrupted mid-task and comes
/// back later: the craving session, the check-in note, the journal draft and
/// the return after days away.
///
/// Every test runs on the DEBUG demo fixture (`-seedDemo`), with the local
/// preview offering (`-previewStore`) only where a trial pitch has to exist. No
/// RevenueCat key is configured for the app on the simulator, nothing reaches
/// the network and no purchase control is tapped.
///
/// Tests run in name order on one install. A1 needs the trial nudge gate still
/// open, so it goes first; A2 leaves a day five days back logged, which turns
/// Home's check-in button into the welcome-back card, so A6 handles both.
@MainActor
final class InterruptedUserAuditUITests: InterruptedAuditCase {

    private var cravingStart: XCUIElement? { findButton("I'm having a", timeout: 30) }

    private func timerText() -> String {
        findText("^[0-9]+:[0-9]{2}$", timeout: 3)?.label ?? "(no timer)"
    }

    private func finishSession(outcomeButton: String = "It passed") {
        tap(app.buttons["I'm through it"], "I'm through it")
        tap(findButton(outcomeButton, timeout: 10), outcomeButton)
    }

    // MARK: - A1: the trial nudge against an urge

    func testA1_TrialNudgeAroundAnUrgeInTheFirstSecondsAfterLaunch() {
        tag = "A1"
        launch(["-seedDemo", "-previewStore"])
        guard let craving = cravingStart else {
            note("MISSING craving button on Home")
            snap("home_missing")
            return
        }
        let opened = Date()
        snap("home")
        measure("I'm having a craving", in: craving)
        craving.tap()
        guard app.buttons["I'm through it"].waitForExistence(timeout: 10) else {
            note("MISSING craving session")
            snap("session_missing")
            return
        }
        note("session open \(Int(Date().timeIntervalSince(opened)))s after Home appeared")
        snap("session_open")
        sleep(5)
        snap("session_plus5s")
        sleep(5)
        snap("session_plus10s")
        note("trial offer on screen during the session: \(app.buttons["See all plans"].exists)")

        finishSession()
        guard app.staticTexts["Logged."].waitForExistence(timeout: 10) else {
            note("MISSING Logged. screen")
            snap("logged_missing")
            return
        }
        snap("logged")
        tap(app.buttons["Back to the garden"], "Back to the garden")
        let back = Date()
        for wait: UInt32 in [2, 3, 3, 4] {
            sleep(wait)
            let seconds = Int(Date().timeIntervalSince(back))
            let shown = app.buttons["See all plans"].exists
            note("back on Home +\(seconds)s, trial offer on screen: \(shown)")
            snap("home_plus\(seconds)s")
        }
    }

    // MARK: - A2: returning after days away

    func testA2_ReturningAfterDaysAwayMeetsAWelcomeBackChoice() {
        tag = "A2"
        launch(["-seedDemo"])
        guard cravingStart != nil else {
            note("MISSING Home")
            snap("home_missing")
            return
        }
        snap("home_before")
        tapTab("Timeline")
        sleep(1)
        snap("timeline")
        measure("Previous month", in: app.buttons["Previous month"])
        measure("Next month", in: app.buttons["Next month"])

        // The only way to leave a tended day in the past without moving the
        // clock: tend one by hand on the calendar.
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: -5, to: Date()) else { return }
        if !calendar.isDate(target, equalTo: Date(), toGranularity: .month) {
            tap(app.buttons["Previous month"], "Previous month")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM d"
        let name = formatter.string(from: target)
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        measure("calendar day cell \(name)", in: cell)
        tap(cell, "calendar day \(name)")
        sleep(1)
        let log = app.buttons["Log as nicotine-free"]
        scrollTo(log)
        snap("past_day_selected")
        tap(log, "Log as nicotine-free")
        sleep(1)
        snap("past_day_logged")

        tapTab("Home")
        sleep(2)
        snap("home_after_days_away")
        let welcome = findText("^Welcome back.*", timeout: 5)
        note("welcome-back copy: \(welcome?.label ?? "(not shown)")")
        note("choices: still nicotine-free=\(findButton("Still nicotine-free", timeout: 2) != nil), I slipped=\(findButton("I slipped", timeout: 2) != nil)")
    }

    // MARK: - A3: a craving session while the app is away

    func testA3_CravingSessionWhileTheAppIsAway() {
        tag = "A3"
        launch(["-seedDemo"])
        guard let craving = cravingStart else {
            note("MISSING craving button on Home")
            return
        }
        craving.tap()
        guard app.buttons["I'm through it"].waitForExistence(timeout: 10) else {
            note("MISSING craving session")
            snap("session_missing")
            return
        }
        sleep(6)
        let before = timerText()
        snap("session_6s_in")
        XCUIDevice.shared.press(.home)
        sleep(30)
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 15)
        let onReturn = timerText()
        snap("session_back_after_30s_away")
        sleep(4)
        let later = timerText()
        snap("session_4s_after_return")
        note("timer before leaving \(before), on return \(onReturn), 4s later \(later); wall clock away 30s")
        measure("I'm through it", in: app.buttons["I'm through it"])
        measure("Give me another minute", in: findButton("Give me another minute", timeout: 2))
        measure("Close (x)", in: app.buttons["Close"])

        tap(app.buttons["I'm through it"], "I'm through it")
        let stayed = findText("^You stayed with it for .*", timeout: 10)?.label ?? "(missing)"
        snap("reflect")
        note("reflect copy after 30s away: \(stayed)")
        measure("It passed", in: findButton("It passed", timeout: 2))
        measure("Not sure yet. Close session", in: findButton("Not sure yet", timeout: 2))
        measure("I gave in", in: findButton("I gave in", timeout: 2))
        tap(findButton("It passed", timeout: 10), "It passed")
        _ = app.staticTexts["Logged."].waitForExistence(timeout: 10)
        snap("logged")
        tap(app.buttons["Back to the garden"], "Back to the garden")
    }

    // MARK: - A4: a craving session the system ends

    func testA4_CravingSessionEndedBySystemLeavesNoTrace() {
        tag = "A4"
        launch(["-seedDemo"])
        guard let craving = cravingStart else {
            note("MISSING craving button on Home")
            return
        }
        craving.tap()
        guard app.buttons["I'm through it"].waitForExistence(timeout: 10) else {
            note("MISSING craving session")
            return
        }
        sleep(8)
        snap("session_8s_in")
        killAndReopen(["-seedDemo"])
        let home = cravingStart
        snap("home_after_kill")
        note("after the kill Home shows the craving button: \(home != nil), session resumed: \(app.buttons["I'm through it"].exists)")

        tap(home, "craving button")
        finishSession()
        _ = app.staticTexts["Logged."].waitForExistence(timeout: 10)
        let count = findText("^That's .*ridden out.*", timeout: 5)?.label ?? "(no count line)"
        snap("logged_after_kill")
        note("first completed session after the kill reports: \(count)")
        tap(app.buttons["Back to the garden"], "Back to the garden")
    }

    // MARK: - A5: a journal draft

    func testA5_JournalDraftAgainstInterruptions() {
        tag = "A5"
        launch(["-seedDemo"])
        guard cravingStart != nil else {
            note("MISSING Home")
            return
        }
        tapTab("Journal")
        sleep(1)
        snap("journal")
        tap(app.buttons["New entry"], "New entry")
        let bar = app.navigationBars["New Entry"]
        guard bar.waitForExistence(timeout: 8) else {
            note("MISSING compose sheet")
            snap("compose_missing")
            return
        }
        let editor = app.textViews.firstMatch
        enter("Rough afternoon. Craving hit at the loading dock and I walked it off. Writing it down before I forget how it felt.", into: editor)
        snap("typed")
        note("editor after typing: \(inputText(editor).count) characters")

        interrupt(seconds: 5)
        snap("after_interruption")
        note("editor after a 5s interruption: \(inputText(app.textViews.firstMatch).count) characters")

        dragSheetDown(from: app.navigationBars["New Entry"])
        snap("after_swipe_down")
        note("compose sheet still on screen after the swipe: \(app.navigationBars["New Entry"].exists)")

        tap(app.buttons["New entry"], "New entry again")
        _ = app.navigationBars["New Entry"].waitForExistence(timeout: 8)
        snap("reopened")
        note("editor when reopened: \(inputText(app.textViews.firstMatch).count) characters")

        enter("Second try, longer. This is the draft the system takes away.", into: app.textViews.firstMatch)
        snap("second_draft_typed")
        killAndReopen(["-seedDemo"])
        _ = cravingStart
        tapTab("Journal")
        sleep(1)
        snap("journal_after_kill")
        note("after the kill the Journal tab shows a draft or entry: \(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Second try")).count > 0)")
    }

    // MARK: - A6: the check-in note

    func testA6_CheckInNoteAgainstInterruptions() {
        tag = "A6"
        launch(["-seedDemo"])
        guard cravingStart != nil else {
            note("MISSING Home")
            return
        }
        snap("home")
        if let checkIn = findButton("Check in for today", timeout: 3) {
            checkIn.tap()
        } else if let still = findButton("Still nicotine-free", timeout: 3) {
            note("Home showed the welcome-back card; confirming it to reach the note sheet")
            still.tap()
            sleep(1)
            tap(findButton("Add note", timeout: 5), "Add note")
        } else {
            tap(findButton("Add note", timeout: 3), "Add note")
        }
        let bar = app.navigationBars["Checked in"]
        guard bar.waitForExistence(timeout: 8) else {
            note("MISSING note sheet")
            snap("sheet_missing")
            return
        }
        snap("sheet_open")
        tap(findButton("Good", timeout: 3), "mood Good")
        enter("Skipped the break-room run. Walked instead.", into: firstTextInput())
        snap("typed")

        interrupt(seconds: 5)
        snap("after_interruption")
        note("note field after a 5s interruption: '\(inputText(firstTextInput()))'")

        dragSheetDown(from: app.navigationBars["Checked in"])
        snap("after_swipe_down")
        note("note sheet still on screen after the swipe: \(app.navigationBars["Checked in"].exists)")

        tap(findButton("Add note", timeout: 5), "Add note after the swipe")
        _ = app.navigationBars["Checked in"].waitForExistence(timeout: 8)
        snap("reopened_after_swipe")
        note("note field when reopened after the swipe: '\(inputText(firstTextInput()))'")

        enter("Morning: skipped the break-room run.", into: firstTextInput())
        tap(app.buttons["Save"], "Save")
        sleep(1)
        snap("saved_morning_note")
        measure("Add note (Home)", in: findButton("Add note", timeout: 3))

        interrupt(seconds: 3)
        tap(findButton("Add note", timeout: 5), "Add note later in the day")
        _ = app.navigationBars["Checked in"].waitForExistence(timeout: 8)
        snap("evening_form")
        note("note field when reopened to add to a saved note: '\(inputText(firstTextInput()))'")
        enter("Evening: two cravings, both passed.", into: firstTextInput())
        tap(app.buttons["Save"], "Save")
        sleep(1)
        snap("saved_evening_note")

        tapTab("Timeline")
        sleep(1)
        let field = firstTextInput()
        scrollTo(field)
        snap("timeline_note")
        note("today's note on Timeline: '\(inputText(field))'")
    }
}
