import Testing
import Foundation
import SwiftData
@testable import Sober

/// State machine audit repro (2026-11-06). Failing tests are expected: each one
/// asserts the behaviour the app's own copy or doc comment promises.
@Suite("StateMachineAuditRepro")
@MainActor
struct StateMachineAuditRepro {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self, UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - SM-1 A slip inside a run the Reset button ended

    /// Shape `SobrietyService.reset()` leaves behind: the old run ends at the
    /// reset instant and the new one starts at the same instant. No slip row.
    private func seedResetEndedRun() {
        let boundary = Date.now.addingTimeInterval(-10 * 86_400)
        context.insert(SobrietyJourney(startDate: DateHelpers.daysAgo(40), endDate: boundary))
        context.insert(SobrietyJourney(startDate: boundary))
        try? context.save()
    }

    /// Control: the same back-dated slip, when a later slip is on record,
    /// splits the run and the best streak stops at it (already pinned by
    /// SlipCorrectionRegressionTests; repeated here so the pair is readable).
    @Test func control_slipInsideRunEndedByALaterSlipSplitsTheLongestStreak() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: DateHelpers.daysAgo(10), context: context)
        #expect(sobriety.longestStreakDays() == 31)

        SlipRecorder.record(on: DateHelpers.daysAgo(25), context: context)
        #expect(sobriety.longestStreakDays() == 16)
    }

    /// Timeline's "Log a slip" alert promises "Your longest streak reflects the
    /// corrected dates" (TimelineView.swift:113). For a day inside a run that
    /// the Reset button ended (no slip row to anchor on) nothing is split.
    @Test func slipInsideAResetEndedRunSplitsTheLongestStreak() {
        seedResetEndedRun()
        let sobriety = SobrietyService(context: context)
        let checkIns = CheckInService(context: context)
        let slipDay = DateHelpers.daysAgo(25)

        // Preconditions: no slip on record, the day is inside the closed run,
        // the active run does not cover it, and the best streak is the whole
        // closed run (40 days ago through the reset 10 days ago = 31 days).
        #expect(checkIns.lastSlipDate() == nil)
        #expect(sobriety.activeJourneyCovers(slipDay) == false)
        #expect(sobriety.dayCount(asOf: slipDay) == 16)
        #expect(sobriety.longestStreakDays() == 31)

        SlipRecorder.record(on: slipDay, context: context)

        #expect(checkIns.loggedSlip(on: slipDay))
        // Promise: the slip stops the run it sits in. 40 to 25 days ago is 16
        // days, 24 to 10 days ago is 15, the active run is 11.
        #expect(sobriety.longestStreakDays() == 16,
                "longest streak still measures straight through the logged slip")
    }

    // MARK: - SM-2 Undo reaching past a later Reset

    private func slipTodayThenReset() -> (garden: GardenService, sobriety: SobrietyService) {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(40))
        SlipRecorder.record(on: .now, context: context)
        return (garden, sobriety)
    }

    /// Control: with nothing in between, undo is offered and restores 41 days.
    @Test func control_undoRightAfterTheSlipRestoresTheRun() {
        let (garden, sobriety) = slipTodayThenReset()
        #expect(sobriety.currentDayCount() == 1)
        #expect(garden.current().carryoverDays == 20)
        #expect(SlipRecorder.canUndo(on: .now, context: context))
        #expect(SlipRecorder.undo(on: .now, context: context))
        #expect(sobriety.currentDayCount() == 41)
        #expect(garden.current().carryoverDays == 0)
    }

    /// The Timeline copy: "Puts your counter and your tree back the way they
    /// were before this slip" (TimelineView.swift:507), and the doc on
    /// `reversibleSplit`: only the slip "the live counter is sitting on" is
    /// reversible. After Home's "Reset counter" the counter is not sitting on
    /// the slip's run, but Home still shows the slip card and its Undo.
    @Test func undoIsNotOfferedAfterTheCounterWasReset() {
        let (garden, sobriety) = slipTodayThenReset()
        let slipRunActiveId = sobriety.activeJourney()?.id
        #expect(CheckInService(context: context).loggedSlip(on: .now))
        #expect(SlipRecorder.canUndo(on: .now, context: context))

        // Exactly what HomeView's "Reset" alert button runs (HomeView.swift:105).
        sobriety.reset()
        garden.resetForNewJourney()

        // Preconditions: Home still shows the slip card (today's row is a
        // logged slip), the active run is a new one, the tree was wiped.
        #expect(CheckInService(context: context).loggedSlip(on: .now))
        #expect(sobriety.activeJourney()?.id != slipRunActiveId)
        #expect(garden.current().carryoverDays == 0)

        #expect(SlipRecorder.canUndo(on: .now, context: context) == false,
                "Undo is still offered although the slip's run is no longer the active run")
    }

    /// Same route, if the user taps the Undo that is still shown. The card
    /// promises the counter back "the way it was before this slip"; the slip's
    /// own run (a stub that began today) is what reopens, and the 41-day run
    /// the slip ended stays closed.
    @Test func undoAfterTheResetPutsTheCounterBackLikeThePromise() {
        let (_, sobriety) = slipTodayThenReset()
        sobriety.reset()
        #expect(sobriety.currentDayCount() == 1)
        #expect(CheckInService(context: context).loggedSlip(on: .now))

        let undone = SlipRecorder.undo(on: .now, context: context)

        #expect(undone, "precondition: undo ran")
        #expect(sobriety.currentDayCount() == 41,
                "counter after Undo: \(sobriety.currentDayCount()), the 41-day run stays closed")
    }

    // MARK: - SM-3 Undo leaves a phantom grove tree

    /// `GardenState.completedTreeStyles` is "a permanent record of milestones
    /// actually reached" (GardenState.swift:19). Slip then undo at a streak
    /// past 365 days adds a second tree for a cycle that was already counted.
    @Test func undoingASlipAfterATreeCompletedDoesNotAddAnotherTree() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(400))
        let days = sobriety.currentDayCount()
        #expect(days == 401)
        #expect(garden.processCycleCompletions(days: days) == 1)
        #expect(garden.current().completedTreeStyles.count == 1)

        SlipRecorder.record(on: .now, context: context)
        #expect(SlipRecorder.undo(on: .now, context: context))
        #expect(sobriety.currentDayCount() == 401)

        // What Home runs on its next refresh (HomeView.checkForGrowth).
        garden.processCycleCompletions(days: sobriety.currentDayCount())

        #expect(garden.current().completedTreeStyles.count == 1,
                "grove holds a second tree for the same 365-day cycle")
    }

    /// Control: below one year the same slip and undo changes nothing.
    @Test func control_undoingASlipBeforeAnyTreeCompletedAddsNoTree() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(100))
        SlipRecorder.record(on: .now, context: context)
        #expect(SlipRecorder.undo(on: .now, context: context))
        garden.processCycleCompletions(days: sobriety.currentDayCount())
        #expect(garden.current().completedTreeStyles.isEmpty)
    }

    // MARK: - SM-4 Cost is entered in the local currency, kept as USD

    /// Onboarding and Settings price in `Locale.current`'s currency
    /// (OnboardingView.swift:306, SettingsView.swift:107), but the Pro money
    /// screens format with `UserSettings.currencyCode` (HomeView.swift:918,
    /// BloomPlusTabView.swift:44), which nothing ever writes after the "USD"
    /// default (UserSettings.swift:24). Run with `-testRegion DE` to see it;
    /// under en_US this is the passing control.
    @Test func regionPrecondition_testRegionWasApplied() {
        #expect(Locale.current.region?.identifier == "DE",
                "run was not in DE: \(Locale.current.identifier)")
    }

    @Test func storedCurrencyMatchesTheCurrencyTheCostWasEnteredIn() {
        let local = Locale.current.currency?.identifier
        #expect(local != nil)
        // The same call OnboardingView.persistSetup makes (OnboardingView.swift:872).
        let settings = SettingsService(context: context).current()
        #expect(settings.currencyCode == local,
                "locale \(Locale.current.identifier) prices in \(local ?? "nil"), stored \(settings.currencyCode)")
    }
}
