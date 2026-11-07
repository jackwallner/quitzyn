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

    // MARK: - SM-3 Slip and Undo past a year adds no grove tree

    /// `completedTreeStyles` is "a permanent record of milestones actually
    /// reached". Slip then Undo past 365 days used to add a second tree for a
    /// cycle already counted.
    @Test func sm3_undoingASlipAfterATreeCompletedDoesNotAddAnotherTree() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(400))
        #expect(sobriety.currentDayCount() == 401)
        #expect(garden.processCycleCompletions(days: 401) == 1)

        SlipRecorder.record(on: DateHelpers.startOfDay(), context: context)
        #expect(SlipRecorder.undo(on: .now, context: context))
        #expect(sobriety.currentDayCount() == 401)

        garden.processCycleCompletions(days: sobriety.currentDayCount())
        #expect(garden.current().completedTreeStyles.count == 1)
        #expect(garden.current().groveCountAtJourneyStart == 0)
    }

    /// Upgrade: a slip recorded by an older build has no stored baseline.
    /// Undoing it after the update still adds no tree.
    @Test func sm3_undoOfASlipFromAnOlderBuildAddsNoTree() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(800))
        #expect(garden.processCycleCompletions(days: sobriety.currentDayCount()) == 2)
        SlipRecorder.record(on: DateHelpers.startOfDay(), context: context)
        garden.current().groveCountBeforeSlip = nil
        try? context.save()

        #expect(SlipRecorder.undo(on: .now, context: context))
        garden.processCycleCompletions(days: sobriety.currentDayCount())
        #expect(garden.current().completedTreeStyles.count == 2)
    }

    /// Control: after a real slip a new run still grows its own trees.
    @Test func sm3_aRunAfterASlipStillAddsItsOwnTrees() {
        let garden = GardenService(context: context)
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(400))
        garden.processCycleCompletions(days: 401)
        SlipRecorder.record(on: DateHelpers.startOfDay(), context: context)
        #expect(garden.processCycleCompletions(days: 366) == 1)
        #expect(garden.current().completedTreeStyles.count == 2)
    }

    /// Upgrade: a garden row written before `groveCountBeforeSlip` existed
    /// opens with every value intact and the new field empty.
    @Test func sm3_aStoreFromTheOlderSchemaOpensWithItsGardenIntact() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sm3-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
            }
        }
        do {
            let legacy = try ModelContainer(
                for: LegacyGardenSchema.GardenState.self,
                configurations: ModelConfiguration(url: url)
            )
            let row = LegacyGardenSchema.GardenState()
            row.completedTreeStyles = ["traditional-bonsai"]
            row.groveCountAtJourneyStart = 1
            row.carryoverDays = 40
            row.carryoverBeforeSlip = 12
            legacy.mainContext.insert(row)
            try legacy.mainContext.save()
        }

        let upgraded = try ModelContainer(
            for: GardenState.self, configurations: ModelConfiguration(url: url)
        )
        let state = try #require(try upgraded.mainContext.fetch(FetchDescriptor<GardenState>()).first)
        #expect(state.completedTreeStyles == ["traditional-bonsai"])
        #expect(state.groveCountAtJourneyStart == 1)
        #expect(state.carryoverDays == 40)
        #expect(state.carryoverBeforeSlip == 12)
        #expect(state.groveCountBeforeSlip == nil)
    }
}

@Suite("State machine fixes 2026-11-06: Timeline pane")
@MainActor
struct TimelinePaneDraftRegressionTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// SM-7: the unfolded pane stays mounted while Home checks today in with
    /// a mood and note. The pane's draft must follow the saved row, or its
    /// Note field shows blank and the next keystroke replaces the saved note.
    @Test func sm7_aCheckInSavedOnHomeReachesThePaneDraft() throws {
        let today = DateHelpers.startOfDay()
        let selection = TimelineSelection()
        selection.loadDraft(from: nil, day: today)
        #expect(selection.draftNote.isEmpty)

        CheckInService(context: context).checkIn(for: today, wasSober: true, mood: 4, note: "Walked it off")
        let row = try #require(try context.fetch(FetchDescriptor<DailyCheckIn>()).first)
        selection.storedRowDidChange(row, day: today)

        #expect(selection.draftMood == 4)
        #expect(selection.draftNote == "Walked it off")
    }

    /// An assumed row appearing under a half-typed note keeps the note.
    @Test func sm7_anAssumedRowLeavesAHalfTypedNoteAlone() throws {
        let today = DateHelpers.startOfDay()
        let selection = TimelineSelection()
        selection.loadDraft(from: nil, day: today)
        selection.draftNote = "half-typed"

        let assumed = DailyCheckIn(day: today, wasSober: true)
        assumed.wasLogged = false
        context.insert(assumed)
        selection.storedRowDidChange(assumed, day: today)

        #expect(selection.draftNote == "half-typed")
    }
}

/// `GardenState` as shipped before `groveCountBeforeSlip` was added.
enum LegacyGardenSchema {
    @Model
    final class GardenState {
        var id: UUID = UUID()
        var vitality: Double = 1.0
        var lastWateredAt: Date?
        var unlockedItemIDs: [String] = ["moss"]
        var placedItemIDs: [String] = []
        var activeBonsaiStyleID: String = "traditional-bonsai"
        var gardenThemeID: String = "zen"
        var lastUnlockNotifiedAtDays: Int = 0
        var completedTreeStyles: [String] = []
        var groveCountAtJourneyStart: Int = 0
        var carryoverDays: Int = 0
        var carryoverBeforeSlip: Int = 0
        var vitalityDecayDays: Int = 0

        init() {}
    }
}
