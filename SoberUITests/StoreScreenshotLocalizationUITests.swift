import XCTest

final class StoreScreenshotLocalizationUITests: XCTestCase {
    private struct LocaleList: Decodable {
        let locales: [StoreLocale]
    }

    private struct StoreLocale: Decodable {
        let store_locale: String
        let language: String
        let region: String
        let scenes: [String]?

        func captures(_ scene: String) -> Bool {
            scenes?.contains(scene) ?? true
        }
    }

    func testCaptureStoreFrames() throws {
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

            if locale.captures("home") {
                capture("home", locale: locale.store_locale, app: app)
            }
            tap("storeScreenshot.garden", app: app)
            if locale.captures("garden") {
                capture("garden", locale: locale.store_locale, app: app)
            }
            tap("storeScreenshot.garden.done", app: app)
            tapTab(1, app: app)
            if locale.captures("timeline") {
                capture("timeline", locale: locale.store_locale, app: app)
            }
            tapTab(3, app: app)
            if locale.captures("journal") {
                capture("journal", locale: locale.store_locale, app: app)
            }
            tapTab(0, app: app)
            tap("storeScreenshot.craving", app: app)
            if locale.captures("craving") {
                capture("craving", locale: locale.store_locale, app: app)
            }
            tap("storeScreenshot.craving.close", app: app)
            tap("storeScreenshot.checkin", app: app)
            if locale.captures("checkin") {
                capture("checkin", locale: locale.store_locale, app: app)
            }
            tap("storeScreenshot.checkin.save", app: app)
            tapTab(4, app: app)
            tap("storeScreenshot.patterns", app: app, scrollIfNeeded: true)
            if locale.captures("patterns") {
                capture("patterns", locale: locale.store_locale, app: app)
            }
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

    private func tapTab(_ index: Int, app: XCUIApplication) {
        let tab = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Missing tab at index \(index)")
        tab.tap()
    }

    private func capture(_ scene: String, locale: String, app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(locale)__\(scene).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
