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

    // MARK: - SM-2 Undo after a Reset reverses the slip, not the Reset

    private func sortedJourneys() -> [SobrietyJourney] {
        let descriptor = FetchDescriptor<SobrietyJourney>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func expectNoOverlap() {
        let all = sortedJourneys()
        for (earlier, later) in zip(all, all.dropFirst()) {
            #expect((earlier.endDate ?? .distantFuture) <= later.startDate,
                    "runs overlap: \(earlier.startDate)...\(String(describing: earlier.endDate)) and \(later.startDate)")
        }
        #expect(all.filter(\.isActive).count == 1)
    }

    /// What Home's "Reset" alert runs (HomeView.swift).
    private func resetCounter() {
        SobrietyService(context: context).reset()
        GardenService(context: context).resetForNewJourney()
    }

    /// Slip today from the slip sheet (`startOfDay()`), Reset, then Undo on
    /// Home's slip card (`.now`). The slip's boundary goes, the Reset stays.
    @Test func sm2_todaySlipThenResetThenUndoKeepsTheResetAndDropsTheSlip() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.startOfDay(), context: context)
        resetCounter()
        #expect(sobriety.currentDayCount() == 1)
        #expect(SlipRecorder.canUndo(on: .now, context: context))
        #expect(sobriety.undoReopensLiveRun(endedOn: .now) == false)

        #expect(SlipRecorder.undo(on: .now, context: context))

        #expect(CheckInService(context: context).loggedSlip(on: .now) == false)
        #expect(sobriety.currentDayCount() == 1, "the Reset was thrown away")
        #expect(sortedJourneys().allSatisfy { $0.resetReason != "slip" }, "the slip's boundary is still on record")
        #expect(sobriety.longestStreakDays() == 41)
        #expect(garden.current().carryoverDays == 0, "the Reset wiped the tree; undo must not regrow it")
        expectNoOverlap()
    }

    /// The same with the slip dated yesterday: the Reset used to be discarded
    /// and the stub it closed left overlapping the reopened run.
    @Test func sm2_yesterdaySlipThenResetThenUndoLeavesNoOverlappingRuns() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        let yesterday = DateHelpers.startOfDay(DateHelpers.daysAgo(1))
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: yesterday, context: context)
        resetCounter()
        #expect(SlipRecorder.canUndo(on: yesterday, context: context))

        #expect(SlipRecorder.undo(on: yesterday, context: context))

        #expect(CheckInService(context: context).loggedSlip(on: yesterday) == false)
        #expect(sobriety.currentDayCount() == 1, "the Reset was thrown away")
        #expect(garden.current().carryoverDays == 0)
        expectNoOverlap()
    }

    /// Control: with no Reset in between, undo still restores the whole run
    /// and the tree, and the Timeline caption that promises it still shows.
    @Test func sm2_undoWithoutAResetStillRestoresTheRunAndTheTree() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.startOfDay(), context: context)
        #expect(garden.current().carryoverDays == 20)
        #expect(sobriety.undoReopensLiveRun(endedOn: .now))

        #expect(SlipRecorder.undo(on: .now, context: context))
        #expect(sobriety.currentDayCount() == 41)
        #expect(garden.current().carryoverDays == 0)
        expectNoOverlap()
    }

    /// A slip followed by another slip is still not reversible after a Reset.
    @Test func sm2_aSlipBehindALaterSlipStaysIrreversibleAfterAReset() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        let older = DateHelpers.startOfDay(DateHelpers.daysAgo(20))
        SlipRecorder.record(on: older, context: context)
        SlipRecorder.record(on: DateHelpers.startOfDay(DateHelpers.daysAgo(5)), context: context)
        resetCounter()
        #expect(SlipRecorder.canUndo(on: older, context: context) == false)
    }
}
