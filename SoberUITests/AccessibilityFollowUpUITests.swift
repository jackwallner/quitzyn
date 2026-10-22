import XCTest

/// Second pass of the accessibility audit: onboarding steps, the sheets that
/// take text, a destructive tap, and the trial offer. Attaches screenshots and
/// frame reports; the assertions only guard against the harness itself failing.
final class AccessibilityFollowUpUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private static let standard = "UICTContentSizeCategoryL"

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(size: String, extra: [String]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] + extra
        app.launch()
        return app
    }

    private func note(_ text: String, _ name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func frames(_ app: XCUIApplication, _ name: String) {
        let window = app.windows.firstMatch.frame
        var lines = ["window \(Int(window.width))x\(Int(window.height))"]
        for type in [XCUIElement.ElementType.button, .switch, .stepper, .slider, .textField, .textView, .link] {
            for element in app.descendants(matching: type).allElementsBoundByIndex.prefix(60) {
                let f = element.frame
                guard f.width > 0, f.height > 0 else { continue }
                let small = f.width < 44 || f.height < 44
                lines.append(String(format: "%@ \"%@\" x=%.0f y=%.0f w=%.0f h=%.0f hittable=%@%@",
                                    "\(type.rawValue)", element.label.replacingOccurrences(of: "\n", with: " "),
                                    f.minX, f.minY, f.width, f.height,
                                    element.isHittable ? "Y" : "N", small ? " SMALL" : ""))
            }
        }
        note(lines.joined(separator: "\n"), "\(name)-frames")
    }

    private func capture(_ app: XCUIApplication, _ name: String, report: Bool = true, wait: TimeInterval = 2) {
        Thread.sleep(forTimeInterval: wait)
        shot(app, name)
        if report { frames(app, name) }
    }

    // MARK: Check-in sheet and keyboard

    func testCheckInSheetKeyboard() {
        for (size, prefix) in [(Self.standard, "std"), (Self.ax5, "ax5")] {
            let app = launch(size: size, extra: ["-seedDemo", "-QuitZynScreenshot"])
            let checkIn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Check in'")).firstMatch
            guard checkIn.waitForExistence(timeout: 10) else {
                capture(app, "\(prefix)-checkin-missing")
                app.terminate()
                continue
            }
            capture(app, "\(prefix)-home-before-checkin")
            checkIn.tap()
            capture(app, "\(prefix)-checkin-sheet", wait: 1.5)
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 3) {
                field.tap()
                field.typeText("Hard afternoon, did not use.")
                capture(app, "\(prefix)-checkin-keyboard", wait: 1.5)
                note("Save hittable with keyboard: \(app.buttons["Save"].isHittable); Skip hittable: \(app.buttons["Skip"].isHittable)", "\(prefix)-checkin-keyboard-note")
            }
            app.terminate()
        }
    }

    // MARK: Timeline

    func testTimelineLogAX5() {
        let app = launch(size: Self.ax5, extra: ["-seedDemo", "-QuitZynScreenshot"])
        app.tabBars.buttons["Timeline"].tap()
        capture(app, "ax5-timeline-top", wait: 3)
        let before = app.windows.firstMatch.frame.height
        app.swipeUp()
        capture(app, "ax5-timeline-scrolled")
        app.swipeUp()
        capture(app, "ax5-timeline-bottom")
        note("window height \(before)", "ax5-timeline-note")
    }

    // MARK: Journal: lost draft, delete without confirmation

    func testJournalDraftLostOnSwipeDismiss() {
        let app = launch(size: Self.standard, extra: ["-seedDemo", "-QuitZynScreenshot", "-demoPro"])
        app.tabBars.buttons["Journal"].tap()
        let new = app.buttons["New entry"]
        XCTAssertTrue(new.waitForExistence(timeout: 8))
        new.tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("A long honest entry about the worst craving this month.")
        capture(app, "std-journal-compose-typed", wait: 1)
        // Swipe the sheet down from its top edge.
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.1, thenDragTo: end)
        capture(app, "std-journal-after-swipe-dismiss", wait: 1.5)
        note("Compose sheet still present after swipe: \(app.navigationBars["New Entry"].exists); alert shown: \(app.alerts.count > 0 || app.sheets.count > 0)", "std-journal-swipe-note")
    }

    func testJournalDeleteHasNoConfirmation() {
        let app = launch(size: Self.standard, extra: ["-seedDemo", "-QuitZynScreenshot", "-demoPro"])
        app.tabBars.buttons["Journal"].tap()
        let row = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Went a full workday'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        capture(app, "std-journal-list-before-delete", wait: 1)
        row.tap()
        let trash = app.buttons["Delete entry"]
        XCTAssertTrue(trash.waitForExistence(timeout: 5))
        capture(app, "std-journal-detail", wait: 1)
        trash.tap()
        capture(app, "std-journal-after-delete-tap", wait: 1.5)
        note("Entry still listed after one tap on the trash icon: \(row.exists); confirmation alert/dialog present: \(app.alerts.count > 0 || app.sheets.count > 0)", "std-journal-delete-note")
    }

    // MARK: Settings sheet dismissal and trial offer

    func testSettingsHasNoCloseControl() {
        let app = launch(size: Self.ax5, extra: ["-seedDemo", "-previewStore"])
        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        capture(app, "ax5-settings-top", wait: 3)
        let names = ["Done", "Close", "Cancel", "Dismiss"].filter { app.buttons[$0].exists }
        note("Close-like buttons present on Settings: \(names)", "ax5-settings-close-note")
        let upgrade = app.buttons["Upgrade"]
        if upgrade.waitForExistence(timeout: 3) {
            upgrade.tap()
            capture(app, "ax5-trial-offer", wait: 3)
            let notNow = app.buttons["Not now"]
            note("Not now exists: \(notNow.exists) frame: \(notNow.frame)", "ax5-trial-offer-note")
        }
    }

    func testTrialOfferDefaultSize() {
        let app = launch(size: Self.standard, extra: ["-seedDemo", "-previewStore"])
        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        let upgrade = app.buttons["Upgrade"]
        if upgrade.waitForExistence(timeout: 5) {
            upgrade.tap()
            capture(app, "std-trial-offer", wait: 3)
        }
    }
}
