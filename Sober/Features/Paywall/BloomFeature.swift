import SwiftUI

/// Bloom+ capabilities — single source of truth for trial-sheet and paywall copy.
/// When a pitch is triggered by tapping a locked feature, that feature becomes
/// the focus so the pitch leads with what the user reached for.
enum BloomFeature: CaseIterable {
    case gardenSpecies
    case healthTimeline
    case journal
    case savingsTracking

    var icon: String {
        switch self {
        case .gardenSpecies: "leaf.fill"
        case .healthTimeline: "heart.text.square.fill"
        case .journal: "book.closed.fill"
        case .savingsTracking: "dollarsign.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .gardenSpecies: "All 6 bonsai species"
        case .healthTimeline: "Full health timeline"
        case .journal: "Daily journal"
        case .savingsTracking: "Money & pouch tracking"
        }
    }

    var detail: String {
        switch self {
        case .gardenSpecies: "Switch your tree as your streak grows."
        case .healthTimeline: "13 nicotine-recovery milestones with sources."
        case .journal: "Prompts and reflections on hard days."
        case .savingsTracking: "Every dollar and pouch you avoid, tracked."
        }
    }

    var pitchHeadline: String {
        switch self {
        case .gardenSpecies: "Grow every species."
        case .healthTimeline: "See what's coming back."
        case .journal: "Write through the cravings."
        case .savingsTracking: "Watch your savings add up."
        }
    }

    var pitchSubheadline: String {
        switch self {
        case .gardenSpecies: "Unlock every bonsai species and switch whenever you like, plus the rest of Bloom+."
        case .healthTimeline: "Unlock the full 13-milestone recovery timeline, plus the rest of Bloom+."
        case .journal: "Daily journal prompts when you need them most, plus the rest of Bloom+."
        case .savingsTracking: "Track every dollar and pouch you avoid, plus the rest of Bloom+."
        }
    }
}

/// Routes trial-offer presentation to `MainTabView`, which owns the sheets.
@MainActor
final class TrialOfferCoordinator: ObservableObject {
    static let shared = TrialOfferCoordinator()

    enum Intent: String {
        case postOnboarding
        case journal
        case healthTimeline
        case gardenSpecies
        case progressSheet
        case settings
        case growthCelebration
        case checkInMilestone

        var focusFeature: BloomFeature? {
            switch self {
            case .journal: .journal
            case .healthTimeline: .healthTimeline
            case .gardenSpecies: .gardenSpecies
            case .progressSheet: .savingsTracking
            case .postOnboarding, .settings, .growthCelebration, .checkInMilestone: nil
            }
        }
    }

    /// How `MainTabView` should present a pending pitch.
    enum PitchPolicy: Equatable {
        /// Day-0 / onboarding follow-up — always trial-first when eligible.
        case initial
        /// Settings upgrade row — trial-first when eligible.
        case explicitUpgrade
        /// Locked-feature tap after onboarding — plan picker first, trial on repeat intent.
        case subsequentLocked
        /// Positive-moment / tab-visit repitch — usage threshold + passive cooldown.
        case subsequentPassive
    }

    struct PendingRequest: Equatable {
        let intent: Intent
        let policy: PitchPolicy
    }

    @Published var pendingRequest: PendingRequest?

    /// True while MainTabView has the trial-offer or paywall sheet on screen.
    /// The review-prompt scheduler checks this (and vice versa) so the two
    /// sheet systems — owned by different view layers — never race to present.
    @Published var isPresentingSheet = false

    private init() {}

    func request(_ intent: Intent, policy: PitchPolicy = .subsequentLocked) {
        pendingRequest = PendingRequest(intent: intent, policy: policy)
    }

    func clear() { pendingRequest = nil }
}

/// Session cap + persisted action counts for *subsequent* trial pitches (not the
/// onboarding / post-onboarding initial pitch). Mirrors StatScout's PaywallGate
/// and Vitals' intent-vs-passive split.
@MainActor
enum TrialSubsequentPitchGate {
    /// Locked-feature taps get the high-converting trial sheet from the 2nd reach onward.
    static let lockedFeatureThreshold = 2
    /// Tab visits, growth celebrations, and check-ins repitch after this many uses.
    static let passiveUsageThreshold = 2
    /// Cap trial-sheet presentations per intent per app session.
    static let maxTrialPitchesPerIntentPerSession = 2

    private static var sessionTrialPitchCounts: [String: Int] = [:]

    static func actionCount(for intent: TrialOfferCoordinator.Intent) -> Int {
        AppGroup.defaults.integer(forKey: AppGroup.bloomActionCountKey(for: intent.rawValue))
    }

    @discardableResult
    static func recordAction(for intent: TrialOfferCoordinator.Intent) -> Int {
        let next = actionCount(for: intent) + 1
        AppGroup.defaults.set(next, forKey: AppGroup.bloomActionCountKey(for: intent.rawValue))
        return next
    }

    static func canPresentTrialPitch(for intent: TrialOfferCoordinator.Intent) -> Bool {
        sessionTrialPitchCounts[intent.rawValue, default: 0] < maxTrialPitchesPerIntentPerSession
    }

    static func markTrialPitchPresented(for intent: TrialOfferCoordinator.Intent) {
        sessionTrialPitchCounts[intent.rawValue, default: 0] += 1
        TrialNudgeGate.markShown()
    }

    @discardableResult
    static func incrementPersistedCount(key: String) -> Int {
        let next = AppGroup.defaults.integer(forKey: key) + 1
        AppGroup.defaults.set(next, forKey: key)
        return next
    }
}

/// Locked Bloom+ control tapped while free — routes through the subsequent-pitch
/// policy so the first reach shows the plan picker and repeat intent gets the trial sheet.
@MainActor
func requestSubsequentLockedFeaturePitch(_ intent: TrialOfferCoordinator.Intent) {
    TrialOfferCoordinator.shared.request(intent, policy: .subsequentLocked)
}

/// Cooldown gate for *passive* trial nudges — the ones the app surfaces on its
/// own (landing on Home, Timeline, or Health) rather than in response to a tap.
/// The interval *escalates*: the small trial popup shows roughly daily at first
/// — the cadence that drives high trial-start rates — then backs off so it never
/// becomes spam (and stays clear of App Store "persistent paywall" concerns).
enum TrialNudgeGate {
    /// Hours to wait before the next nudge, indexed by how many have shown.
    private static let scheduleHours: [Double] = [20, 28, 44, 96, 168]

    private static var shownCount: Int {
        AppGroup.defaults.integer(forKey: AppGroup.trialNudgeCountKey)
    }

    static func canShow() -> Bool {
        let last = AppGroup.defaults.double(forKey: AppGroup.lastTrialNudgeKey)
        guard last > 0 else { return true }
        let idx = min(max(shownCount, 1), scheduleHours.count) - 1
        let gap = scheduleHours[idx] * 3600
        return Date().timeIntervalSince1970 - last >= gap
    }

    static func markShown() {
        AppGroup.defaults.set(Date().timeIntervalSince1970, forKey: AppGroup.lastTrialNudgeKey)
        AppGroup.defaults.set(shownCount + 1, forKey: AppGroup.trialNudgeCountKey)
    }
}

/// Passive, cooldown-gated trial nudge shared by the Home, Timeline, and Health
/// tabs. Safe to call from every tab's `.task` — the gate handles frequency, so
/// whichever tab a returning free user lands on surfaces the small trial sheet
/// once the interval has elapsed. No-op for subscribers or trial-ineligible users.
@MainActor
func presentPassiveTrialNudge(
    _ subscriptions: SubscriptionService,
    intent: TrialOfferCoordinator.Intent,
    delay: Double = 4
) async {
    guard !subscriptions.isProSubscriber,
          !subscriptions.hasClaimedTrial,
          subscriptions.hasTrialOfferAvailable,
          TrialOfferCoordinator.shared.pendingRequest == nil,
          TrialNudgeGate.canShow()
    else { return }
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    guard !Task.isCancelled,
          !subscriptions.isProSubscriber,
          TrialOfferCoordinator.shared.pendingRequest == nil
    else { return }
    TrialOfferCoordinator.shared.request(intent, policy: .subsequentPassive)
}

/// Usage-counted repitch after a positive moment (2nd growth celebration, 3rd
/// check-in, 2nd Journal tab open, etc.). Skips the initial onboarding pitches.
@MainActor
func evaluateUsageBasedTrialPitch(
    _ subscriptions: SubscriptionService,
    intent: TrialOfferCoordinator.Intent,
    usageCount: Int,
    threshold: Int = TrialSubsequentPitchGate.passiveUsageThreshold,
    delay: Double = 1.5
) async {
    guard !subscriptions.isProSubscriber,
          !subscriptions.hasClaimedTrial,
          subscriptions.hasTrialOfferAvailable,
          usageCount >= threshold,
          TrialOfferCoordinator.shared.pendingRequest == nil,
          TrialNudgeGate.canShow(),
          TrialSubsequentPitchGate.canPresentTrialPitch(for: intent)
    else { return }
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    guard !Task.isCancelled,
          !subscriptions.isProSubscriber,
          TrialOfferCoordinator.shared.pendingRequest == nil,
          TrialNudgeGate.canShow(),
          TrialSubsequentPitchGate.canPresentTrialPitch(for: intent)
    else { return }
    TrialOfferCoordinator.shared.request(intent, policy: .subsequentPassive)
}
