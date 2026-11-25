import Foundation

extension Notification.Name {
    /// Posted after a satisfaction moment on Home. Home may request the system
    /// rating prompt after a short delay, with no question in front of it.
    static let soberPositiveMomentForReview = Notification.Name("com.jackwallner.sober.positiveMomentForReview")
}

/// The only moments that may ask for a rating: a result the user just
/// achieved and can see. Never launch, a view appearing, a tab switch, an open
/// count, a slip, a bad result, onboarding or anything around a paywall.
enum ReviewMoment: Equatable, Sendable {
    /// Today's check-in tapped.
    case dailyCheckIn
    /// "Still nicotine-free" after days away, which fills those days in.
    case welcomeBackCheckIn
    /// A garden growth celebration finished.
    case growthCelebration
    /// An urge session ended. Only riding it out counts.
    case craving(CravingOutcome)

    /// Whether this is a clearly positive result. A craving that was not ridden
    /// out (gave in, or left unanswered) is never a reason to ask.
    var isGoodResult: Bool {
        switch self {
        case .dailyCheckIn, .welcomeBackCheckIn, .growthCelebration: return true
        case .craving(let outcome): return outcome == .rodeItOut
        }
    }
}

/// What the user did about a review. Only opening the review page ends the
/// passive asks: someone who sent feedback can still rate.
enum ReviewPromptOutcome: String, Sendable {
    case openedWriteReview
    /// Sent feedback by mail. Never stops the asks.
    case submittedFeedback
}

/// Persists launch counts, positive moments, and review-prompt eligibility in the app group.
@MainActor
enum ReviewPromptTracker {
    private static let defaults = AppGroup.defaults

    private static let launchCountKey = "reviewPrompt.appLaunchCount"
    private static let firstOpenKey = "reviewPrompt.firstAppOpenDate"
    private static let lastShownKey = "reviewPrompt.lastShownDate"
    private static let outcomeKey = "reviewPrompt.outcome"
    private static let positiveMomentCountKey = "reviewPrompt.positiveMomentCount"
    private static let pendingPositiveMomentKey = "reviewPrompt.pendingPositiveMoment"
    private static let pendingPositiveMomentAtKey = "reviewPrompt.pendingPositiveMomentAt"

    /// A moment that could not ask right away (a note sheet was open over it)
    /// is still the user's good result for this long, then it lapses so an
    /// unrelated sheet closing later never asks on its behalf.
    static let momentFreshnessSeconds: TimeInterval = 10 * 60

    /// Ask early. Most installs are gone within a week, and a rating from
    /// someone who checked in twice beats no rating at all. The only tenure
    /// gate is "not the first session": a second cold start.
    static let minimumLaunchCount = 2
    /// Days between our calls. Apple shows the prompt at most three times a
    /// year per device and decides each time, so this paces the asks rather
    /// than the user's answers.
    static let cooldownDays = 30

    static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: launchCountKey), 0) }
        set { defaults.set(newValue, forKey: launchCountKey) }
    }

    static var firstAppOpenDate: Date? {
        get { defaults.object(forKey: firstOpenKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: firstOpenKey)
            } else {
                defaults.removeObject(forKey: firstOpenKey)
            }
        }
    }

    static var lastShownDate: Date? {
        get { defaults.object(forKey: lastShownKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: lastShownKey)
            } else {
                defaults.removeObject(forKey: lastShownKey)
            }
        }
    }

    static var outcome: ReviewPromptOutcome? {
        get {
            guard let raw = defaults.string(forKey: outcomeKey) else { return nil }
            return ReviewPromptOutcome(rawValue: raw)
        }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: outcomeKey)
            } else {
                defaults.removeObject(forKey: outcomeKey)
            }
        }
    }

    static var positiveMomentCount: Int {
        get { max(defaults.integer(forKey: positiveMomentCountKey), 0) }
        set { defaults.set(newValue, forKey: positiveMomentCountKey) }
    }

    static var hasPendingPositiveMoment: Bool {
        get { isPendingPositiveMomentFresh() }
        set {
            defaults.set(newValue, forKey: pendingPositiveMomentKey)
            if newValue {
                defaults.set(Date.now, forKey: pendingPositiveMomentAtKey)
            } else {
                defaults.removeObject(forKey: pendingPositiveMomentAtKey)
            }
        }
    }

    /// A flag stored by an older build has no stamp and reads as lapsed.
    static func isPendingPositiveMomentFresh(now: Date = .now) -> Bool {
        guard defaults.bool(forKey: pendingPositiveMomentKey),
              let at = defaults.object(forKey: pendingPositiveMomentAtKey) as? Date else { return false }
        return now >= at && now.timeIntervalSince(at) <= momentFreshnessSeconds
    }

    static func recordAppLaunch(now: Date = .now) {
        if firstAppOpenDate == nil {
            firstAppOpenDate = now
        }
        appLaunchCount += 1
    }

    static func recordPositiveMoment() {
        positiveMomentCount += 1
        hasPendingPositiveMoment = true
    }

    /// Records the moment when it is a good result. Returns whether it counted.
    @discardableResult
    static func recordPositiveMoment(_ moment: ReviewMoment) -> Bool {
        guard moment.isGoodResult else { return false }
        recordPositiveMoment()
        return true
    }

    static func consumePendingPositiveMoment() {
        hasPendingPositiveMoment = false
    }

    static func passivePromptAllowed(now: Date = .now) -> Bool {
        guard outcome != .openedWriteReview else { return false }
        guard let last = lastShownDate else { return true }
        let cooldown = TimeInterval(cooldownDays) * 86_400
        return now.timeIntervalSince(last) >= cooldown
    }

    static func canRequestReview(hasCompletedSetup: Bool, now: Date = .now) -> Bool {
        guard !ScreenshotConfig.isEnabled else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        return appLaunchCount >= minimumLaunchCount
    }

    static func shouldRequestAfterPositiveMoment(
        hasCompletedSetup: Bool,
        now: Date = .now
    ) -> Bool {
        guard hasPendingPositiveMoment else { return false }
        return canRequestReview(hasCompletedSetup: hasCompletedSetup, now: now)
    }

    static func markShown(now: Date = .now) {
        lastShownDate = now
        consumePendingPositiveMoment()
    }

    static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    /// Never overwrites `.openedWriteReview`: feedback sent after the review
    /// page must not reopen the asks that page ended.
    static func markFeedbackSubmitted() {
        if outcome != .openedWriteReview {
            outcome = .submittedFeedback
        }
    }
}
