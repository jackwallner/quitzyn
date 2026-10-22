import XCTest

/// Walks the main screens at the default text size and at the largest
/// accessibility size, attaching a screenshot and a frame report for each.
/// It asserts nothing about layout: it exists so a human can look.
final class AccessibilityAuditUITests: XCTestCase {
    private static let ax5 = "UICTContentSizeCategoryAccessibilityXXXL"
    private static let standard = "UICTContentSizeCategoryL"

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(size: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
        app.launchArguments += ["-seedDemo", "-QuitZynScreenshot", "-UIPreferredContentSizeCategoryName", size] + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Every control's frame, and whether it is on screen and hittable.
    private func report(_ app: XCUIApplication, _ name: String) {
        let window = app.windows.firstMatch.frame
        var lines = ["window \(Int(window.width))x\(Int(window.height))"]
        for type in [XCUIElement.ElementType.button, .switch, .stepper, .textField, .textView, .cell] {
            for element in app.descendants(matching: type).allElementsBoundByIndex.prefix(60) {
                let f = element.frame
                guard f.width > 0, f.height > 0 else { continue }
                let onScreen = window.contains(f)
                let small = f.width < 44 || f.height < 44
                lines.append(String(format: "%@ \"%@\" x=%.0f y=%.0f w=%.0f h=%.0f hittable=%@ onscreen=%@%@",
                                    "\(type.rawValue)", element.label.replacingOccurrences(of: "\n", with: " "),
                                    f.minX, f.minY, f.width, f.height,
                                    element.isHittable ? "Y" : "N", onScreen ? "Y" : "N", small ? " SMALL" : ""))
            }
        }
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "\(name)-frames"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(_ app: XCUIApplication, _ name: String, wait: TimeInterval = 2) {
        Thread.sleep(forTimeInterval: wait)
        shot(app, name)
        report(app, name)
    }

    private func walkTabs(_ app: XCUIApplication, prefix: String) {
        capture(app, "\(prefix)-home", wait: 4)
        for tab in ["Timeline", "Health", "Journal"] {
            let button = app.tabBars.buttons[tab]
            if button.waitForExistence(timeout: 5) {
                button.tap()
                capture(app, "\(prefix)-\(tab.lowercased())")
            } else {
                capture(app, "\(prefix)-no-\(tab.lowercased())-tab")
            }
        }
        let bloom = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Bloom'")).firstMatch
        if bloom.exists {
            bloom.tap()
            capture(app, "\(prefix)-bloom")
        }
    }

    func testTabsDefaultSize() {
        walkTabs(launch(size: Self.standard), prefix: "std")
    }

    func testTabsAX5() {
        walkTabs(launch(size: Self.ax5), prefix: "ax5")
    }

    func testCravingAX5() {
        let app = launch(size: Self.ax5, extra: ["-craving"])
        capture(app, "ax5-craving-start", wait: 3)
        let through = app.buttons["I'm through it"]
        if through.waitForExistence(timeout: 5) {
            through.tap()
            capture(app, "ax5-craving-reflect")
            let passed = app.buttons["It passed"]
            if passed.waitForExistence(timeout: 5) {
                passed.tap()
                capture(app, "ax5-craving-done")
            }
        }
    }

    func testCravingDefault() {
        let app = launch(size: Self.standard, extra: ["-craving"])
        capture(app, "std-craving-start", wait: 3)
    }

    func testSlipAX5() {
        let app = launch(size: Self.ax5, extra: ["-slip"])
        capture(app, "ax5-slip", wait: 3)
    }

    func testSlipDefault() {
        let app = launch(size: Self.standard, extra: ["-slip"])
        capture(app, "std-slip", wait: 3)
    }

    func testHomeMenuAndSheetsAX5() {
        let app = launch(size: Self.ax5)
        capture(app, "ax5-home-top", wait: 4)
        app.buttons["More"].tap()
        capture(app, "ax5-more-menu")
        let settings = app.buttons["Settings"]
        if settings.waitForExistence(timeout: 3) {
            settings.tap()
            capture(app, "ax5-settings", wait: 3)
            app.swipeUp()
            capture(app, "ax5-settings-bottom")
        }
    }

    func testProgressSheetAX5() {
        let app = launch(size: Self.ax5)
        _ = app.buttons["Progress"].waitForExistence(timeout: 10)
        app.buttons["Progress"].tap()
        capture(app, "ax5-progress", wait: 3)
    }

    func testCheckInDefaultAndAX5() {
        for (size, prefix) in [(Self.standard, "std"), (Self.ax5, "ax5")] {
            let app = launch(size: size, extra: ["-resetCheckIn"])
            let checkIn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Check in'")).firstMatch
            if checkIn.waitForExistence(timeout: 8), checkIn.isHittable {
                checkIn.tap()
                capture(app, "\(prefix)-checkin-sheet")
            } else {
                capture(app, "\(prefix)-checkin-unreachable")
            }
            app.terminate()
        }
    }
}
