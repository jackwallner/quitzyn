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
        let tabs = app.tabBars.buttons
        for i in 0..<tabs.count {
            let t = tabs.element(boundBy: i)
            t.tap(); sleep(2)
            shot("20-tab-\(i)-\(t.label)")
            if !t.isHittable { XCTFail("tab \(t.label) unhittable") }
            if t.frame.height < 44 { XCTFail("tab \(t.label) height \(t.frame.height)") }
        }
    }
}
