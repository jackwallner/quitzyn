import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var costPerDayCents: Int          // store as integer cents to avoid Decimal in SwiftData
    var currencyCode: String
    var pouchesPerDay: Int
    var dailyReminderEnabled: Bool
    var dailyReminderHour: Int
    var hasCompletedOnboarding: Bool
    /// Whether the user accepted the explicit pledge at the end of onboarding.
    /// Drives whether nudge copy uses commitment-anchored language ("you said
    /// you'd…") vs. neutral encouragement. SwiftData default keeps the value
    /// stable across the lightweight migration when a user upgrades from a
    /// build that didn't have this field.
    var madeCommitment: Bool = true
    var appearancePreferenceRaw: String = AppearancePreference.system.rawValue

    init(
        id: UUID = UUID(),
        costPerDayCents: Int = 800,         // ~$8/day default (about half a can of pouches)
        currencyCode: String = "USD",
        pouchesPerDay: Int = 8,
        dailyReminderEnabled: Bool = true,
        dailyReminderHour: Int = 9,
        hasCompletedOnboarding: Bool = false,
        appearancePreference: AppearancePreference = .system
    ) {
        self.id = id
        self.costPerDayCents = costPerDayCents
        self.currencyCode = currencyCode
        self.pouchesPerDay = pouchesPerDay
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.appearancePreferenceRaw = appearancePreference.rawValue
    }

    var appearancePreference: AppearancePreference {
        get { AppearancePreference(rawValue: appearancePreferenceRaw) ?? .system }
        set { appearancePreferenceRaw = newValue.rawValue }
    }

    var costPerDay: Decimal {
        Decimal(costPerDayCents) / 100
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
