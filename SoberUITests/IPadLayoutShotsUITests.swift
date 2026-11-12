import XCTest

/// iPad layout proof: every main screen, onboarding steps and the paywall,
/// portrait then landscape. Attachments are named `<orientation>__<scene>.png`.
/// Run: `gh-sim test --device 'iPad Pro 13-inch (M5)' --only SoberUITests/IPadLayoutShotsUITests`.
final class IPadLayoutShotsUITests: XCTestCase {
    private let seeded = ["-seedDemo", "-demoPro", "-seedDays", "130", "-QuitZynScreenshot"]

    private struct Scene {
        let name: String
        let args: [String]
    }

    private var scenes: [Scene] {
        [
            Scene(name: "home", args: seeded),
            Scene(name: "health", args: seeded + ["-DuoScreen", "health"]),
            Scene(name: "journal", args: seeded + ["-DuoScreen", "journal"]),
            Scene(name: "bloom", args: seeded + ["-DuoScreen", "bloom"]),
            Scene(name: "timeline", args: seeded + ["-DuoScreen", "timeline"]),
            Scene(name: "craving", args: seeded + ["-craving"]),
            Scene(name: "slip", args: seeded + ["-slip"]),
            Scene(name: "garden", args: seeded + ["-screenshotGarden"]),
            Scene(name: "checkin", args: seeded + ["-screenshotCheckIn"]),
            Scene(name: "patterns", args: seeded + ["-DuoScreen", "bloom", "-screenshotPatterns"]),
            Scene(name: "paywall-trial", args: ["-PaywallSnapshot", "trial", "-previewStore"]),
            Scene(name: "paywall-yearly", args: ["-PaywallSnapshot", "yearly", "-previewStore"]),
            Scene(name: "bloom-free", args: ["-seedDemo", "-seedDays", "30", "-QuitZynScreenshot", "-DuoScreen", "bloom", "-previewStore"]),
        ] + (0...5).map { step in
            Scene(name: "onboarding\(step)", args: ["-onboardingStep", "\(step)", "-previewStore"])
        }
    }

    private func run(_ orientation: UIDeviceOrientation, label: String, only: Set<String>?) {
        XCUIDevice.shared.orientation = orientation
        Thread.sleep(forTimeInterval: 1)
        for scene in scenes where only?.contains(scene.name) ?? true {
            let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
            app.launchArguments = scene.args
            app.launchEnvironment = ["SOBER_SCREENSHOT_MODE": "1"]
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 30)
            Thread.sleep(forTimeInterval: 3)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "\(label)__\(scene.name).png"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    private var only: Set<String>? {
        ProcessInfo.processInfo.environment["IPAD_SCENES"].map { Set($0.split(separator: ",").map(String.init)) }
    }

    func testPortrait() { run(.portrait, label: "portrait", only: only) }
    func testLandscape() { run(.landscapeLeft, label: "landscape", only: only) }
}
