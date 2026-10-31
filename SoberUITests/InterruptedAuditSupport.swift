import XCTest

/// Shared helpers for the "interrupted" persona audit: a tired, busy user who
/// is pulled away mid-task and comes back later expecting state to survive.
///
/// The audit classes built on this record what the app does, not what it
/// should: every step attaches a full-screen capture and every observation goes
/// to one notes attachment per test. A missing element is noted and the flow
/// carries on, so a single run yields as much evidence as it can.
@MainActor
class InterruptedAuditCase: XCTestCase {
    let bundleID = "com.jackwallner.quitzyn"
    var app: XCUIApplication!
    var notes: [String] = []
    var shotIndex = 0
    var tag = "I00"

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        notes = []
        shotIndex = 0
    }

    override func tearDown() {
        let attachment = XCTAttachment(string: notes.joined(separator: "\n"))
        attachment.name = "\(tag)_notes.txt"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.tearDown()
    }

    // MARK: - Evidence

    func note(_ text: String) {
        notes.append(text)
        print("AUDIT[\(tag)] \(text)")
    }

    func snap(_ name: String) {
        shotIndex += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(tag)_\(String(format: "%02d", shotIndex))_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Launch and interruptions

    func launch(_ arguments: [String]) {
        if let existing = app, existing.state != .notRunning { existing.terminate() }
        app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "App should launch")
        note("LAUNCH \(arguments.joined(separator: " "))")
    }

    /// A call or a message: the app goes to the background, the user is away,
    /// then comes back to the same process.
    func interrupt(seconds: UInt32) {
        XCUIDevice.shared.press(.home)
        sleep(seconds)
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 15)
        sleep(1)
        note("INTERRUPT home, \(seconds)s away, foreground again: \(app.state == .runningForeground)")
    }

    /// The process is gone, as when iOS reclaims memory or the user swipes the
    /// app away, and the user opens it again.
    func killAndReopen(_ arguments: [String]) {
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()
        sleep(1)
        launch(arguments)
    }

    // MARK: - Finding things

    /// A button whose label contains `text`. A button's own label often starts
    /// with its icon's name, so a contained text is matched as well.
    func findButton(_ text: String, timeout: TimeInterval = 15) -> XCUIElement? {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let direct = app.buttons.matching(predicate).firstMatch
            if direct.exists { return direct }
            let nested = app.buttons.containing(predicate).firstMatch
            if nested.exists { return nested }
            usleep(300_000)
        } while Date() < deadline
        return nil
    }

    /// Any element whose label matches the regular expression `pattern`.
    func findText(_ pattern: String, timeout: TimeInterval = 10) -> XCUIElement? {
        let predicate = NSPredicate(format: "label MATCHES[c] %@", pattern)
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let match = app.descendants(matching: .any).matching(predicate).firstMatch
            if match.exists { return match }
            usleep(300_000)
        } while Date() < deadline
        return nil
    }

    @discardableResult
    func tap(_ element: XCUIElement?, _ what: String) -> Bool {
        guard let element, element.exists else {
            note("MISSING \(what)")
            return false
        }
        if !element.isHittable { app.swipeUp() }
        guard element.isHittable else {
            note("NOT HITTABLE \(what)")
            return false
        }
        element.tap()
        return true
    }

    func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 5), tab.isHittable {
            tab.tap()
            return
        }
        tap(app.buttons[name].firstMatch, "tab \(name)")
    }

    /// Scrolls up to `swipes` times until the element can be tapped.
    func scrollTo(_ element: XCUIElement, swipes: Int = 4) {
        var remaining = swipes
        while remaining > 0, !(element.exists && element.isHittable) {
            app.swipeUp()
            remaining -= 1
        }
    }

    /// Records the size of a control, since a tired thumb needs 44 pt.
    func measure(_ label: String, in element: XCUIElement?) {
        guard let element, element.exists else {
            note("MEASURE \(label): not on screen")
            return
        }
        let frame = element.frame
        note("MEASURE \(label): \(Int(frame.width)) x \(Int(frame.height)) pt at (\(Int(frame.minX)), \(Int(frame.minY)))")
    }

    // MARK: - Text input

    func firstTextInput() -> XCUIElement {
        let field = app.textFields.firstMatch
        return field.exists ? field : app.textViews.firstMatch
    }

    /// What the user would read in the field, never the placeholder.
    func inputText(_ element: XCUIElement) -> String {
        guard element.exists else { return "(no field)" }
        let value = (element.value as? String) ?? ""
        if let placeholder = element.placeholderValue, value == placeholder { return "" }
        return value
    }

    @discardableResult
    func enter(_ text: String, into element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 10) else {
            note("MISSING text input for \"\(text)\"")
            return false
        }
        element.tap()
        usleep(600_000)
        element.typeText(text)
        return true
    }

    /// Drags the top of a sheet down past its dismiss threshold, the way a
    /// thumb does when it slips.
    func dragSheetDown(from handle: XCUIElement) {
        guard handle.exists else {
            note("MISSING sheet handle to drag")
            return
        }
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 14))
        start.press(forDuration: 0.1, thenDragTo: end)
        sleep(1)
    }

    /// The notification permission prompt belongs to SpringBoard, not the app.
    func answerSystemAlert(named shot: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 6) else {
            note("no system alert appeared")
            return
        }
        snap(shot)
        note("SYSTEM ALERT: \(alert.label)")
        let allow = alert.buttons["Allow"]
        if allow.exists {
            allow.tap()
        } else if alert.buttons.count > 0 {
            alert.buttons.element(boundBy: 0).tap()
        }
        sleep(1)
    }
}
