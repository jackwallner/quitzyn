import Testing
import Foundation
import SwiftData
@testable import Sober

/// Regressions for the bugs the 2026-11-06 state machine audit and its review
/// confirmed (`project-docs/audits/state-machines-2026-11-06-fixes.md`).

@Suite("State machine fixes 2026-11-06")
@MainActor
struct StateMachineFixRegressionTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - SM-4 Money is shown in the currency it was entered in

    /// Onboarding and Settings price the cost in the device currency. An
    /// existing user's row still carries the "USD" default nothing ever wrote,
    /// and the savings screens must not read it.
    @Test func sm4_moneyUsesTheDeviceCurrencyNotTheStoredDefault() {
        let settings = SettingsService(context: context).current()
        #expect(settings.currencyCode == "USD", "precondition: an upgraded row keeps the old default")

        let germany = Locale(identifier: "de_DE")
        #expect(UserSettings.displayCurrencyCode(locale: germany) == "EUR")
        let euros = UserSettings.formattedMoney(cents: 4800, locale: germany)
        #expect(euros.contains("€"), "got \(euros)")
        #expect(!euros.contains("$"), "got \(euros)")
        #expect(euros.contains("48"))

        let us = UserSettings.formattedMoney(cents: 4800, locale: Locale(identifier: "en_US"))
        #expect(us == "$48")
    }
}
