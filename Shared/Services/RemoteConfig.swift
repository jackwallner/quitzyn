import Foundation

/// Everything RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every variant
/// ships in the binary; a missing, non-string or unknown value is the control,
/// which is what the build shipped before the key existed. Keys a switch reads
/// must be set the same on every offering, or an Experiment arm would flip them
/// as a side effect. Wording tests go through the `trial_cta` key.
///
/// DEBUG builds can pin any key for captures: `-quitzyn.rc.<key> <value>`.
enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string, or
    /// not one of the shipped variants.
    static func value<T: RawRepresentable>(
        _ key: String,
        in metadata: [String: Any]?,
        default fallback: T
    ) -> T where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    /// On unless the metadata says "off".
    static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-quitzyn.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}

/// Remote off switches, for what is worth pausing without a release.
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a good moment. "off" pauses the automatic ask.
    case ratingPrompt = "rating_prompt"
}

/// The trial button's wording, one test for every surface.
///
/// The control is each surface's own copy as it shipped, because the surfaces
/// never agreed: onboarding says "Start my N-day free trial" in sentence case,
/// the trial sheet "Start My N-Day Free Trial", and the paywall names the
/// selected plan's own intro offer ("Start 7-Day Free Trial"). Without the
/// store's trial length the control degrades to a length-free line, as before.
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: today's copy on every surface.
    case myDays = "my_days"
    /// The length without a pronoun: "Start 7-day free trial".
    case sevenDay = "seven_day"
    /// "Start my free trial".
    case my
    /// "Start your free trial".
    case your

    enum Surface {
        /// The onboarding trial page, sentence case.
        case onboarding
        /// The one-tap trial sheet, title case.
        case sheet
        /// The paywall's purchase button, title case.
        case paywall
    }

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .myDays)
    }

    /// The button title for a customer who can start the trial.
    ///
    /// - Parameters:
    ///   - days: the trial length from StoreKit, nil until it loads.
    ///   - planTitle: the paywall's own title for the selected plan's intro
    ///     offer ("Start 7-Day Free Trial", or the month and year variants).
    func title(_ surface: Surface, days: Int?, planTitle: String? = nil) -> String {
        switch (self, surface) {
        case (.my, .onboarding):
            return String(localized: "Start my free trial")
        case (.my, .sheet), (.my, .paywall):
            return String(localized: "Start My Free Trial")
        case (.your, .onboarding):
            return String(localized: "Start your free trial")
        case (.your, .sheet), (.your, .paywall):
            return String(localized: "Start Your Free Trial")
        case (.sevenDay, .onboarding):
            guard let days else { return String(localized: "Start free trial") }
            return String(localized: "Start \(days)-day free trial")
        case (.sevenDay, .sheet):
            guard let days else { return String(localized: "Start Free Trial") }
            return String(localized: "Start \(days)-Day Free Trial")
        case (.sevenDay, .paywall), (.myDays, .paywall):
            // The paywall's copy was never first person: it is the plan's own
            // intro offer, so control and this arm read the same there.
            return planTitle ?? String(localized: "Start Free Trial")
        case (.myDays, .onboarding):
            guard let days else { return String(localized: "Start my free trial") }
            return String(localized: "Start my \(days)-day free trial")
        case (.myDays, .sheet):
            guard let days else { return String(localized: "Start My Free Trial") }
            return String(localized: "Start My \(days)-Day Free Trial")
        }
    }
}
