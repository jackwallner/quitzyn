import XCTest

/// Onboarding at the largest accessibility size. The class name sorts before the
/// other audit classes on purpose: they seed the demo store, which completes
/// onboarding for the rest of the run, so this has to see the store untouched.
final class AAOnboardingUITests: XCTestCase {
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

    // MARK: Onboarding (never finished, so the store stays un-onboarded)

    func testOnboardingStepsAX5() {
        // The date picker (1) and the hour wheel (4) are screenshot only: the
        // source says they wedge the accessibility bridge.
        // The two risky steps go last so a wedge cannot cost the others.
        for step in [0, 2, 3, 5, 1, 4] {
            let app = launch(size: Self.ax5, extra: ["-onboardingStep", "\(step)", "-previewStore"])
            capture(app, "ax5-onboarding-\(step)", report: step != 1 && step != 4, wait: 3)
            app.terminate()
        }
    }

    func testOnboardingTrialStepDefault() {
        let app = launch(size: Self.standard, extra: ["-onboardingStep", "3", "-previewStore"])
        capture(app, "std-onboarding-3", wait: 3)
    }
}
