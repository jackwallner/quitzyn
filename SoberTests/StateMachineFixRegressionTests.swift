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

    // MARK: - SM-5 Allowing notifications later re-arms the reminder

    /// A pass that ran without permission queued nothing, so the same plan
    /// must run again once permission arrives. The memo used to swallow it
    /// until the plan changed (a check-in, a slip, a new day). The test host
    /// can't grant permission, so this pins the half it can observe: the
    /// unauthorized pass leaves the plan unarmed.
    @Test func sm5_aPassWithoutPermissionLeavesThePlanUnarmed() async {
        guard await !NotificationService.isAuthorized() else { return }
        _ = SettingsService(context: context).current()
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(5))

        let first = NotificationService.refreshDailyReminder(context: context)
        #expect(first != nil, "precondition: the first pass runs")
        await first?.value

        let retry = NotificationService.refreshDailyReminder(context: context)
        #expect(retry != nil, "the same plan was treated as armed although nothing was queued")
        await retry?.value
    }

    // MARK: - SM-1 A slip back-logged into a run the Reset button ended

    /// The shape `SobrietyService.reset()` leaves: the old run ends at the
    /// reset instant and the new one starts there. No slip row.
    private func seedResetEndedRun() {
        let boundary = Date.now.addingTimeInterval(-10 * 86_400)
        context.insert(SobrietyJourney(startDate: DateHelpers.daysAgo(40), endDate: boundary))
        context.insert(SobrietyJourney(startDate: boundary))
        try? context.save()
    }

    /// Timeline's "Log a slip" promises "Your longest streak reflects the
    /// corrected dates". The slip is history, so the live tree stays as it was.
    @Test func sm1_slipInsideAResetEndedRunSplitsItAndLeavesTheTreeAlone() {
        seedResetEndedRun()
        let sobriety = SobrietyService(context: context)
        let checkIns = CheckInService(context: context)
        let garden = GardenService(context: context)
        let slipDay = DateHelpers.startOfDay(DateHelpers.daysAgo(25))

        #expect(checkIns.lastSlipDate() == nil)
        #expect(sobriety.activeJourneyCovers(slipDay) == false)
        #expect(sobriety.longestStreakDays() == 31)
        let carryoverBefore = garden.current().carryoverDays
        let vitalityBefore = garden.current().vitality
        let counterBefore = sobriety.currentDayCount()

        SlipRecorder.record(on: slipDay, context: context)

        #expect(checkIns.loggedSlip(on: slipDay))
        // 40 to 25 days ago is 16 days, 24 to 10 days ago is 15, the active run 11.
        #expect(sobriety.longestStreakDays() == 16)
        #expect(sobriety.currentDayCount() == counterBefore)
        #expect(garden.current().carryoverDays == carryoverBefore)
        #expect(garden.current().vitality == vitalityBefore)
    }

    /// Control: a back-dated slip inside the live run still restarts it.
    @Test func sm1_backDatedSlipInsideTheLiveRunStillRestartsTheCounter() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        let outcome = SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.currentDayCount() == 10)
        #expect(outcome.carryoverDays == 15)
    }
}
