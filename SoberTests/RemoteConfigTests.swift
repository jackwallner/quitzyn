import Foundation
import Testing
@testable import Sober

/// RevenueCat offering metadata drives the trial button's wording. A missing,
/// non-string or unknown value is the control, and the control is each
/// surface's copy from before the key existed.
@Suite("Remote config")
struct RemoteConfigTests {
    private func arm(_ metadata: [String: Any]?) -> TrialCTA { TrialCTA.from(metadata: metadata) }

    @Test func missingValueIsControl() {
        #expect(arm(nil) == .myDays)
        #expect(arm([:]) == .myDays)
        #expect(arm(["other": "my"]) == .myDays)
    }

    @Test func nonStringAndUnknownValuesAreControl() {
        #expect(arm(["trial_cta": 3]) == .myDays)
        #expect(arm(["trial_cta": true]) == .myDays)
        #expect(arm(["trial_cta": "ours"]) == .myDays)
        #expect(arm(["trial_cta": ""]) == .myDays)
    }

    @Test func eachKnownValueIsItsArm() {
        #expect(arm(["trial_cta": "my_days"]) == .myDays)
        #expect(arm(["trial_cta": "seven_day"]) == .sevenDay)
        #expect(arm(["trial_cta": "my"]) == .my)
        #expect(arm(["trial_cta": "your"]) == .your)
    }

    // MARK: - Titles

    @Test func controlIsTodaysOnboardingCopy() {
        #expect(TrialCTA.myDays.title(.onboarding, days: 7) == String(localized: "Start my \(7)-day free trial"))
        #expect(TrialCTA.myDays.title(.onboarding, days: 3) == String(localized: "Start my \(3)-day free trial"))
        #expect(TrialCTA.myDays.title(.onboarding, days: nil) == String(localized: "Start my free trial"))
        #expect(TrialCTA.myDays.title(.onboarding, days: 7) == "Start my 7-day free trial")
    }

    @Test func controlIsTodaysSheetCopy() {
        #expect(TrialCTA.myDays.title(.sheet, days: 7) == String(localized: "Start My \(7)-Day Free Trial"))
        #expect(TrialCTA.myDays.title(.sheet, days: nil) == String(localized: "Start My Free Trial"))
        #expect(TrialCTA.myDays.title(.sheet, days: 7) == "Start My 7-Day Free Trial")
    }

    @Test func controlIsThePlansOwnTitleOnThePaywall() {
        #expect(TrialCTA.myDays.title(.paywall, days: 7, planTitle: "Start 7-Day Free Trial") == "Start 7-Day Free Trial")
        #expect(TrialCTA.myDays.title(.paywall, days: 1, planTitle: "Start 1-Month Free Trial") == "Start 1-Month Free Trial")
    }

    @Test func otherArmsReword() {
        #expect(TrialCTA.my.title(.onboarding, days: 7) == "Start my free trial")
        #expect(TrialCTA.my.title(.sheet, days: 7) == "Start My Free Trial")
        #expect(TrialCTA.my.title(.paywall, days: 7, planTitle: "Start 7-Day Free Trial") == "Start My Free Trial")
        #expect(TrialCTA.your.title(.onboarding, days: 7) == "Start your free trial")
        #expect(TrialCTA.your.title(.sheet, days: 7) == "Start Your Free Trial")
        #expect(TrialCTA.your.title(.paywall, days: 7, planTitle: "Start 7-Day Free Trial") == "Start Your Free Trial")
        #expect(TrialCTA.sevenDay.title(.onboarding, days: 7) == "Start 7-day free trial")
        #expect(TrialCTA.sevenDay.title(.sheet, days: 7) == "Start 7-Day Free Trial")
        #expect(TrialCTA.sevenDay.title(.paywall, days: 7, planTitle: "Start 7-Day Free Trial") == "Start 7-Day Free Trial")
    }

    @Test func theRealTrialLengthIsNeverHardcoded() {
        #expect(TrialCTA.sevenDay.title(.onboarding, days: 3) == "Start 3-day free trial")
        #expect(TrialCTA.sevenDay.title(.sheet, days: 14) == "Start 14-Day Free Trial")
        #expect(TrialCTA.sevenDay.title(.onboarding, days: nil) == "Start free trial")
    }

    // MARK: - Switches

    @Test func switchIsOnByDefault() {
        #expect(RemoteConfig.isOn(.ratingPrompt, in: nil))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": 0]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
    }

    @Test func switchIsOffOnlyForOff() {
        #expect(!RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
    }
}
