import XCTest

/// App Store iPad frames: one launch per locale, seven scenes in the iPad
/// split, full-screen portrait captures. Locales come from
/// `StoreScreenshotLocales.json` (written by the screenshot kit).
/// Run: `gh-sim test --scheme SoberUITests --device 'iPad Pro 13-inch (M5)'
/// --only SoberUITests/IPadStoreScreenshotsUITests`.
final class IPadStoreScreenshotsUITests: XCTestCase {
    private struct LocaleList: Decodable {
        let locales: [StoreLocale]
    }

    private struct StoreLocale: Decodable {
        let store_locale: String
        let language: String
        let region: String
    }

    func testCaptureIPadStoreFrames() throws {
        XCUIDevice.shared.orientation = .portrait
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "StoreScreenshotLocales", withExtension: "json"))
        let localeList = try JSONDecoder().decode(LocaleList.self, from: Data(contentsOf: url))

        for locale in localeList.locales {
            let app = XCUIApplication(bundleIdentifier: "com.jackwallner.quitzyn")
            app.launchArguments = [
                "-seedDemo", "-demoPro", "-seedDays", "130", "-QuitZynScreenshot",
                "-AppleLanguages", "(\(locale.language))",
                "-AppleLocale", locale.region,
            ]
            app.launchEnvironment = ["SOBER_SCREENSHOT_MODE": "1"]
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "App did not foreground for \(locale.store_locale)")
            XCUIDevice.shared.orientation = .portrait

            capture("home", locale: locale.store_locale)
            tap("storeScreenshot.garden", app: app)
            capture("garden", locale: locale.store_locale)
            tap("storeScreenshot.garden.done", app: app)
            tapTab(1, app: app)
            capture("timeline", locale: locale.store_locale)
            tapTab(3, app: app)
            capture("journal", locale: locale.store_locale)
            tapTab(0, app: app)
            tap("storeScreenshot.craving", app: app)
            capture("craving", locale: locale.store_locale)
            tap("storeScreenshot.craving.close", app: app)
            tap("storeScreenshot.checkin", app: app)
            capture("checkin", locale: locale.store_locale)
            tap("storeScreenshot.checkin.save", app: app)
            tapTab(4, app: app)
            tap("storeScreenshot.patterns", app: app, scrollIfNeeded: true)
            capture("patterns", locale: locale.store_locale)
            app.terminate()
        }
    }

    private func tap(_ identifier: String, app: XCUIApplication, scrollIfNeeded: Bool = false) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 20), "Missing screenshot control: \(identifier)")
        if scrollIfNeeded && !button.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(button.isHittable, "Screenshot control is not visible: \(identifier)")
        button.tap()
    }

    private func tapTab(_ tag: Int, app: XCUIApplication) {
        let tab = app.buttons["paneTab.\(tag)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Missing pane tab \(tag)")
        tab.tap()
    }

    private func capture(_ scene: String, locale: String) {
        Thread.sleep(forTimeInterval: 1.5)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(locale)__\(scene).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
