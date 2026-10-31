import XCTest

/// Second wave of evidence for the interrupted persona: what is still there
/// when the process is gone and the person comes back, and the paths the first
/// wave did not reach (the slip sheet, Timeline's note, the Upgrade tab).
///
/// The class name sorts after `InterruptedOnboardingAuditUITests`, which needs
/// a clean install: `-seedDemo` in any test completes onboarding for the whole
/// run, so these must run after it. Each test copes with either a seeded
/// install or the state that onboarding walk leaves behind. No purchase control
/// is tapped and no RevenueCat key is configured on the simulator.
@MainActor
final class InterruptedReturnAuditUITests: InterruptedAuditCase {
    private let seeded = ["-seedDemo"]

    private var cravingStart: XCUIElement? { findButton("I'm having a", timeout: 30) }

    /// Selects a past day on Timeline's calendar, flipping to the previous month
    /// when that day is not in the month on show.
    private func selectDay(daysAgo: Int) {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return }
        if !calendar.isDate(target, equalTo: Date(), toGranularity: .month) {
            tap(app.buttons["Previous month"], "Previous month")
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM d"
        let name = formatter.string(from: target)
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        tap(cell, "calendar day \(name)")
        sleep(1)
    }

    /// Opens the check-in note sheet from whichever card Home is showing.
    private func openCheckInNoteSheet() -> Bool {
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
        return app.navigationBars["Checked in"].waitForExistence(timeout: 8)
    }

    // MARK: - R1: the check-in note against a kill

    func testR1_CheckInNoteDoesNotSurviveAKillButTheDayDoes() {
        tag = "R1"
        launch(seeded)
        guard cravingStart != nil else {
            note("MISSING Home")
            snap("home_missing")
            return
        }
        snap("home")
        guard openCheckInNoteSheet() else {
            note("MISSING note sheet")
            snap("sheet_missing")
            return
        }
        snap("sheet_open")
        measure("Skip", in: app.buttons["Skip"])
        measure("Save", in: app.buttons["Save"])
        tap(findButton("Good", timeout: 3), "mood Good")
        enter("Craving at the loading dock. Held on.", into: firstTextInput())
        snap("typed")
        note("note typed before the kill: '\(inputText(firstTextInput()))'")

        killAndReopen(seeded)
        _ = cravingStart
        snap("home_after_kill")
        note("after the kill Home shows the logged card: \(findText("^Today is logged.*", timeout: 3) != nil), the check-in button: \(findButton("Check in for today", timeout: 2) != nil)")
        guard openCheckInNoteSheet() else {
            note("MISSING note sheet after the kill")
            return
        }
        snap("sheet_reopened_after_kill")
        note("note field when reopened after the kill: '\(inputText(firstTextInput()))'")
        tap(app.buttons["Skip"], "Skip")
    }

    // MARK: - R2: the slip sheet

    func testR2_SlipNoteAgainstInterruptions() {
        tag = "R2"
        launch(seeded)
        guard cravingStart != nil else {
            note("MISSING Home")
            snap("home_missing")
            return
        }
        snap("home")
        tap(app.buttons["More"], "More menu")
        sleep(1)
        snap("more_menu")
        tap(findButton("I slipped", timeout: 5), "I slipped")
        let bar = app.navigationBars["Log a slip"]
        guard bar.waitForExistence(timeout: 8) else {
            note("MISSING slip sheet")
            snap("slip_missing")
            return
        }
        snap("slip_sheet")
        measure("Log it and keep going", in: findButton("Log it and keep going", timeout: 3))
        measure("Cancel", in: app.buttons["Cancel"])
        enter("Was at my brother's wedding. Everyone was using.", into: firstTextInput())
        snap("typed")

        interrupt(seconds: 5)
        snap("after_interruption")
        note("slip note after 5s away: '\(inputText(firstTextInput()))'")

        dragSheetDown(from: app.navigationBars["Log a slip"])
        snap("after_swipe_down")
        note("slip sheet still on screen after the swipe: \(app.navigationBars["Log a slip"].exists)")

        tap(app.buttons["More"], "More menu again")
        sleep(1)
        tap(findButton("I slipped", timeout: 5), "I slipped again")
        _ = app.navigationBars["Log a slip"].waitForExistence(timeout: 8)
        snap("reopened")
        note("slip note when reopened: '\(inputText(firstTextInput()))'")
        tap(app.buttons["Cancel"], "Cancel")
    }

    // MARK: - R3: Timeline's note, draft against autosave

    func testR3_TimelineNoteDraftAgainstAutosave() {
        tag = "R3"
        launch(seeded)
        guard cravingStart != nil else {
            note("MISSING Home")
            snap("home_missing")
            return
        }
        tapTab("Timeline")
        sleep(1)
        // Today has no row until it is logged, so what is typed is only a draft.
        var field = firstTextInput()
        scrollTo(field)
        snap("today_before")
        measure("Timeline note field", in: field)
        enter("Draft written before I checked in.", into: field)
        snap("today_draft_typed")

        tapTab("Home")
        sleep(1)
        tapTab("Timeline")
        sleep(1)
        field = firstTextInput()
        scrollTo(field)
        note("today's draft after a round trip through Home: '\(inputText(field))'")
        snap("today_after_round_trip")

        interrupt(seconds: 5)
        note("today's draft after 5s away: '\(inputText(firstTextInput()))'")

        killAndReopen(seeded)
        _ = cravingStart
        tapTab("Timeline")
        sleep(1)
        field = firstTextInput()
        scrollTo(field)
        note("today's draft after a kill: '\(inputText(field))'")
        snap("today_after_kill")

        // Yesterday already has a row, so each keystroke is saved as it is typed.
        selectDay(daysAgo: 1)
        field = firstTextInput()
        scrollTo(field)
        snap("yesterday_selected")
        enter("Walked instead of the break room.", into: field)
        snap("yesterday_typed")

        killAndReopen(seeded)
        _ = cravingStart
        tapTab("Timeline")
        sleep(1)
        selectDay(daysAgo: 1)
        field = firstTextInput()
        scrollTo(field)
        note("yesterday's note after typing and a kill: '\(inputText(field))'")
        snap("yesterday_after_kill")
    }

    // MARK: - R4: the Upgrade tab

    func testR4_UpgradeTabAfterAnInterruptionAndAKill() {
        tag = "R4"
        let arguments = ["-seedDemo", "-previewStore"]
        launch(arguments)
        guard cravingStart != nil else {
            note("MISSING Home")
            snap("home_missing")
            return
        }
        tapTab("Upgrade")
        sleep(3)
        snap("upgrade_tab")
        let labels = app.buttons.allElementsBoundByIndex.prefix(14).map { $0.label }
        note("buttons on the Upgrade tab: \(labels.joined(separator: " | "))")

        interrupt(seconds: 8)
        snap("upgrade_after_interruption")
        note("Upgrade tab still selected after 8s away: \(app.tabBars.buttons["Upgrade"].isSelected)")

        app.swipeUp()
        app.swipeUp()
        sleep(1)
        snap("upgrade_footer")
        measure("Restore Purchases", in: findButton("Restore Purchases", timeout: 3))

        killAndReopen(arguments)
        _ = cravingStart
        snap("home_after_kill")
        note("after the kill the app opens on Home: \(cravingStart != nil)")
    }

    // MARK: - R5: Upgrade from inside Settings

    /// Settings is a sheet raised by Home, the trial offer is a sheet raised by
    /// the tab view underneath it. Records what the Upgrade row does, and what
    /// the way out looks like after the person has been away.
    func testR5_SettingsUpgradeRowThenAnInterruption() {
        tag = "R5"
        launch(["-seedDemo", "-previewStore"])
        guard cravingStart != nil else {
            note("MISSING Home")
            snap("home_missing")
            return
        }
        clearTrialNudge(waitingUpTo: 9, label: "home")
        tap(app.buttons["More"], "More menu")
        sleep(1)
        tap(app.buttons["Settings"], "Settings")
        guard app.navigationBars["Settings"].waitForExistence(timeout: 8) else {
            note("MISSING Settings sheet")
            snap("settings_missing")
            return
        }
        sleep(1)
        snap("settings")
        measure("Settings Done", in: app.buttons["Done"])
        // The tab bar button behind the sheet is also called Upgrade; the row
        // in the sheet is the one high on the screen.
        let called = app.buttons.matching(NSPredicate(format: "label == %@", "Upgrade")).allElementsBoundByIndex
        let places = called.map { element in
            "y=\(Int(element.frame.minY)) h=\(Int(element.frame.height))"
        }
        note("buttons called Upgrade: \(places)")
        let row = called.first { $0.frame.minY < 600 }
        measure("Settings Upgrade row", in: row)
        tap(row, "Settings Upgrade row")
        sleep(3)
        snap("after_upgrade_tap")
        note("after tapping Upgrade: Settings on screen=\(app.navigationBars["Settings"].exists), trial offer (See all plans)=\(app.buttons["See all plans"].exists), Not now=\(app.buttons["Not now"].exists)")

        interrupt(seconds: 5)
        snap("after_interruption")
        note("after 5s away: Settings on screen=\(app.navigationBars["Settings"].exists), trial offer=\(app.buttons["See all plans"].exists)")

        if app.buttons["Not now"].exists {
            tap(app.buttons["Not now"], "Not now")
            sleep(2)
        }
        snap("after_exit")
        note("after the exit: Settings on screen=\(app.navigationBars["Settings"].exists), Home craving button=\(findButton("I'm having a", timeout: 2) != nil)")
        if app.navigationBars["Settings"].exists { tap(app.buttons["Done"], "Done") }
    }
}
