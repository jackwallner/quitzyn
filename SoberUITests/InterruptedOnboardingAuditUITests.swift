import XCTest

/// Audit evidence for a first-run user who is pulled away part-way through
/// setup, and whose process is gone when they come back.
///
/// Needs a clean install: it must be the only audit class in its run, because
/// `-seedDemo` in any other test completes onboarding for the whole install.
/// Runs on the local preview offering (`-previewStore`), so no RevenueCat key is
/// configured, nothing reaches the network and no purchase control is tapped.
@MainActor
final class InterruptedOnboardingAuditUITests: InterruptedAuditCase {
    private let launchArguments = ["-previewStore"]

    /// Taps a day in the graphical start-date picker and says what happened.
    private func pickStartDate(daysAgo: Int) -> String {
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return "no target date" }
        let picker = app.datePickers.firstMatch
        guard picker.waitForExistence(timeout: 10) else { return "date picker not found" }
        if !calendar.isDate(target, equalTo: Date(), toGranularity: .month) {
            let previous = picker.buttons["Previous Month"]
            if previous.exists {
                previous.tap()
                usleep(600_000)
            }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM d"
        let monthDay = formatter.string(from: target)
        let pattern = ".*\\b\(monthDay)\\b.*"
        let predicate = NSPredicate(format: "label MATCHES[c] %@ OR identifier MATCHES[c] %@", pattern, pattern)
        let cell = picker.descendants(matching: .any).matching(predicate).firstMatch
        guard cell.waitForExistence(timeout: 5) else {
            let labels = picker.descendants(matching: .button).allElementsBoundByIndex.prefix(50).map { $0.label }
            return "no cell for \(monthDay); buttons: \(labels.joined(separator: " | "))"
        }
        cell.tap()
        usleep(600_000)
        return "tapped \(monthDay) (label '\(cell.label)')"
    }

    private func tapButton(_ label: String) {
        let button = app.buttons[label].firstMatch
        if !button.waitForExistence(timeout: 15) {
            note("MISSING button \(label)")
            return
        }
        if !button.isHittable { app.swipeUp() }
        button.tap()
    }

    /// Reads the figures the spend step shows, for the notes.
    private func spendSummary() -> String {
        let slider = app.sliders.firstMatch
        let perDay = slider.exists ? String(describing: slider.value ?? "?") : "(no slider)"
        let line = findText("^That.s about .*", timeout: 3)?.label ?? "(no summary line)"
        return "slider \(perDay); \(line)"
    }

    func testB1_KilledAtTheOfferStepRestartsFromTheWelcome() {
        tag = "B1"
        launch(launchArguments)
        guard app.buttons["Get Started"].waitForExistence(timeout: 30) else {
            note("MISSING welcome step on first launch")
            snap("welcome_missing")
            return
        }
        snap("welcome")
        tapButton("Get Started")

        // Quit date twelve days back, 20 pouches a day, 24 to the can.
        _ = app.datePickers.firstMatch.waitForExistence(timeout: 10)
        snap("start_date_default")
        note("start date: \(pickStartDate(daysAgo: 12))")
        snap("start_date_picked")
        tapButton("Continue")

        _ = app.sliders.firstMatch.waitForExistence(timeout: 10)
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.5)
        let twentyFour = app.buttons["24"]
        if twentyFour.waitForExistence(timeout: 3) { twentyFour.tap() }
        sleep(1)
        snap("spend_entered")
        note("entered on the spend step: \(spendSummary())")
        tapButton("Continue")

        guard app.buttons["Get started"].waitForExistence(timeout: 25) else {
            note("MISSING offer step after the spend step")
            snap("offer_missing")
            return
        }
        snap("offer_step")

        interrupt(seconds: 20)
        snap("offer_after_20s_away")
        note("offer step intact after 20s away: \(app.buttons["Get started"].exists)")

        killAndReopen(launchArguments)
        let welcomeAgain = app.buttons["Get Started"].waitForExistence(timeout: 30)
        snap("after_kill")
        note("after the kill the first screen is the welcome step: \(welcomeAgain), offer step: \(app.buttons["Get started"].exists)")

        // The user taps through what they already answered.
        tapButton("Get Started")
        _ = app.datePickers.firstMatch.waitForExistence(timeout: 10)
        snap("start_date_after_kill")
        tapButton("Continue")
        _ = app.sliders.firstMatch.waitForExistence(timeout: 10)
        snap("spend_after_kill")
        note("shown on the spend step after the kill: \(spendSummary())")
        tapButton("Continue")
        guard app.buttons["Get started"].waitForExistence(timeout: 25) else {
            note("MISSING offer step on the second pass")
            snap("offer_second_pass_missing")
            return
        }
        tapButton("Get started")
        if app.alerts["Keep the free version?"].waitForExistence(timeout: 5) {
            snap("keep_free_alert")
            app.alerts.buttons["Get started"].tap()
        }
        tapButton("Continue")
        snap("commitment")
        tapButton("Not now")
        answerSystemAlert(named: "notification_prompt")

        let counter = findText("^[0-9]+ days? nicotine-free.*", timeout: 20)?.label ?? "(counter not found)"
        snap("home_after_second_pass")
        note("day counter on Home after the second pass: \(counter) (the quit date entered before the kill was 12 days back)")
        clearTrialNudge(waitingUpTo: 9, label: "home_second_pass")

        tap(app.buttons["More"], "More menu")
        tap(app.buttons["Settings"], "Settings")
        _ = app.navigationBars["Settings"].waitForExistence(timeout: 8)
        sleep(1)
        snap("settings_after_second_pass")
        let perDay = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ / day$")).firstMatch
        let cost = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^\\$[0-9]+$")).firstMatch
        let start = app.datePickers.firstMatch
        note("Settings after the second pass: pouches '\(perDay.exists ? perDay.label : "?")', cost per day '\(cost.exists ? cost.label : "?")', start date '\(start.exists ? start.label : "?")' (entered before the kill: 20 pouches, 24 to the can at about $5 a day)")
    }
}
