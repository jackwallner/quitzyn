import XCTest

/// Newcomer audit walk: fresh install through onboarding, then the first
/// useful action (craving mode) and a pass over the tabs. Screenshots are
/// attached for review.
final class NewcomerAuditUITests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testFreshOnboardingThenTabs() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        app.launch()
        shot("01-welcome")
        let start = app.buttons["Get Started"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        sleep(1); shot("02-start-date")
        app.buttons["Continue"].firstMatch.tap()
        sleep(1); shot("03-usage")
        app.buttons["Continue"].firstMatch.tap()
        sleep(2); shot("04-offer")
        app.swipeUp(); shot("05-offer-scrolled")
    }

    func testSeededHomeCravingAndTabs() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        app.launchArguments += ["-seedDemo"]
        app.launch()
        let craving = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "I'm having a")).firstMatch
        XCTAssertTrue(craving.waitForExistence(timeout: 20))
        shot("10-home")
        craving.tap()
        sleep(2); shot("11-craving")
        let through = app.buttons["I'm through it"]
        if through.waitForExistence(timeout: 10) { through.tap(); sleep(1); shot("12-rate") }
        let passed = app.buttons["It passed"]
        if passed.waitForExistence(timeout: 10) { passed.tap(); sleep(1); shot("13-logged") }
        let back = app.buttons["Back to the garden"]
        if back.waitForExistence(timeout: 10) { back.tap() }
        sleep(1)
        dismissRatingSheetIfPresent(app)
        let tabs = app.tabBars.buttons
        for i in 0..<tabs.count {
            let t = tabs.element(boundBy: i)
            let label = t.label
            t.tap(); sleep(2)
            shot("20-tab-\(i)-\(label)")
            if !t.isHittable { XCTFail("tab \(label) unhittable") }
            if t.frame.height < 44 { XCTFail("tab \(label) height \(t.frame.height)") }
        }
    }

    /// Return visit plus the exit paths a newcomer looks for: the Home menu
    /// (settings, restore purchases) from a cold relaunch of a seeded journey.
    func testReturnVisitSettingsAndRestore() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        app.launchArguments += ["-seedDemo"]
        app.launch()
        XCTAssertTrue(app.buttons["Check in for today"].waitForExistence(timeout: 20)
            || app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Check in")).firstMatch.exists)
        app.terminate()
        app.launch()
        sleep(3); shot("30-return-visit")
        let menu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'more' OR label CONTAINS[c] 'settings'")).firstMatch
        if menu.waitForExistence(timeout: 5) {
            menu.tap(); sleep(2); shot("31-menu")
            let settings = app.buttons["Settings"]
            if settings.waitForExistence(timeout: 3) { settings.tap(); sleep(2); shot("32-settings") }
        } else {
            shot("31-menu-not-found")
            XCTFail("Home menu button not found by label")
        }
        let upgrade = app.tabBars.buttons.element(boundBy: 4)
        if upgrade.exists { upgrade.tap(); sleep(2); shot("33-upgrade-tab") }
    }

    private func dismissRatingSheetIfPresent(_ app: XCUIApplication) {
        // The system review prompt (SKStoreReviewController) lives in the app
        // process on the simulator, so its buttons are queryable.
        let notNow = app.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 6) {
            shot("14-rating-sheet-over-home")
            notNow.tap()
            sleep(1)
        }
    }
}
