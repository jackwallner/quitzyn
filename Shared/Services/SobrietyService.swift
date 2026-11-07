import Foundation
import SwiftData

@MainActor
final class SobrietyService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func activeJourney() -> SobrietyJourney? {
        let descriptor = FetchDescriptor<SobrietyJourney>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func startJourney(at startDate: Date = .now) -> SobrietyJourney {
        // End any open journey first
        if let current = activeJourney() {
            current.endDate = .now
        }
        let new = SobrietyJourney(startDate: startDate)
        context.insert(new)
        context.saveOrReport()
        return new
    }

    /// Move the active journey's start to a new timestamp (e.g. the user
    /// correcting their start date/time). Clamped to not run into the future.
    func updateStartDate(_ date: Date) {
        guard let journey = activeJourney() else { return }
        journey.startDate = min(date, .now)
        context.saveOrReport()
    }

    func reset(reason: String? = nil) {
        if let current = activeJourney() {
            current.endDate = .now
            current.resetReason = reason
        }
        let new = SobrietyJourney(startDate: .now)
        context.insert(new)
        context.saveOrReport()
    }

    /// End the active journey and begin a new one at `start` (clamped to now).
    /// Used when a slip resets the counter: a past-dated slip starts the fresh
    /// journey the day after the slip, so the recovered streak is counted.
    ///
    /// `endingPreviousOn` is the day the run that just ended actually stopped,
    /// which for a back-dated slip is not today. Closing it at `.now` instead
    /// left the old journey covering the same dates as the fresh one, and
    /// `longestStreakDays()` measured the old run straight through the slip it
    /// was supposed to stop at: entering a slip from ten days ago *raised* the
    /// user's best streak. Journeys must not overlap.
    @discardableResult
    func resetJourney(
        startingAt start: Date,
        endingPreviousOn end: Date = .now,
        reason: String? = "slip"
    ) -> SobrietyJourney {
        if let current = activeJourney() {
            // A run can't end before it began, or in the future.
            current.endDate = max(current.startDate, min(end, .now))
            current.resetReason = reason
        }
        let new = SobrietyJourney(startDate: min(start, .now))
        context.insert(new)
        context.saveOrReport()
        return new
    }

    /// Whether `day` falls inside the run the counter is currently on.
    func activeJourneyCovers(_ day: Date) -> Bool {
        guard let active = activeJourney() else { return false }
        return DateHelpers.startOfDay(day) >= DateHelpers.startOfDay(active.startDate)
    }

    /// The closed run that `day` falls inside, before the day it ended.
    func closedJourney(containing day: Date) -> SobrietyJourney? {
        let target = DateHelpers.startOfDay(day)
        let journeys = (try? context.fetch(FetchDescriptor<SobrietyJourney>())) ?? []
        return journeys.first { j in
            guard let end = j.endDate else { return false }
            return target >= DateHelpers.startOfDay(j.startDate)
                && target < DateHelpers.startOfDay(end)
        }
    }

    /// Split the closed run that contains `day` at that day, for a slip entered
    /// after a newer one. The run stops on the slip day and a closed run covers
    /// the days after it, up to where the original stopped, so the longest
    /// streak no longer measures straight through the older slip. The active
    /// run is not touched: the counter already sits after the newer slip.
    @discardableResult
    func splitClosedJourney(on day: Date) -> Bool {
        let target = DateHelpers.startOfDay(day)
        guard let containing = closedJourney(containing: day), let originalEnd = containing.endDate,
              let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: target)
        else { return false }

        let tail = SobrietyJourney(startDate: dayAfter)
        tail.endDate = originalEnd
        tail.resetReason = containing.resetReason
        context.insert(tail)
        containing.endDate = max(containing.startDate, target)
        containing.resetReason = "slip"
        context.saveOrReport()
        return true
    }

    /// What taking a slip back changed.
    struct SlipReversal {
        /// The live counter after the undo.
        let currentDays: Int
        /// True when the counter went back onto the run the slip ended. False
        /// when a Reset came after the slip: the Reset stands, and only the
        /// slip's boundary leaves the history.
        let reopenedLiveRun: Bool
    }

    /// Reverse the split a slip on `day` made: remove the run the slip started
    /// and give its span back to the run the slip closed. Returns nil when no
    /// such split is on record.
    ///
    /// Nil is the important half. Timeline offered "Change to sober" on a slip
    /// long before anything could reverse one, so the row went green while Home
    /// kept the counter the slip had reset. A caller that can't move the counter
    /// must not present the correction as done.
    ///
    /// Only the most recent slip is reversible: every run after it ended on a
    /// Reset, so the undo is a local edit to two rows. Undoing an older slip
    /// would mean re-deriving every run after it, which is a rewrite of the
    /// user's history rather than an undo. When the run the slip started is
    /// still the active one the counter goes back to the run the slip ended.
    /// When a Reset closed it, the closed run takes over its end and reason, so
    /// the Reset is kept and no two runs overlap.
    @discardableResult
    func reopenJourney(endedOn day: Date) -> SlipReversal? {
        guard let (closed, opened) = reversibleSplit(endedOn: day) else { return nil }
        let reopenedLiveRun = opened.isActive
        closed.endDate = opened.endDate
        closed.resetReason = opened.resetReason
        context.delete(opened)
        context.saveOrReport()
        return SlipReversal(currentDays: currentDayCount(), reopenedLiveRun: reopenedLiveRun)
    }

    /// Whether `reopenJourney(endedOn:)` would find something to reverse, so a
    /// view can decide whether to offer the correction at all.
    func canReopenJourney(endedOn day: Date) -> Bool {
        reversibleSplit(endedOn: day) != nil
    }

    /// Whether undoing the slip on `day` would put the counter back on the run
    /// it ended, rather than leave a later Reset in place.
    func undoReopensLiveRun(endedOn day: Date) -> Bool {
        reversibleSplit(endedOn: day)?.opened.isActive ?? false
    }

    /// The (run the slip closed, run the slip started) pair, when the slip on
    /// `day` is the most recent slip on record.
    ///
    /// The adjacency check is what keeps this an undo. Matching on the end date
    /// alone would happily "reverse" a slip from three slips ago: it would
    /// reopen a run that a later slip has already closed and delete the current
    /// one, leaving overlapping runs and a counter reading past slips the user
    /// never took back. A back-dated slip starts the fresh run the next day; one
    /// logged today starts it the same day, because the start clamps to now.
    ///
    /// The run closed is the one the slip marked. A Reset later the same day
    /// closes a second run on this date (the stub the slip opened), and
    /// picking that one reopened the stub and left the slip's split in place.
    private func reversibleSplit(endedOn day: Date) -> (closed: SobrietyJourney, opened: SobrietyJourney)? {
        guard activeJourney() != nil else { return nil }
        let target = DateHelpers.startOfDay(day)
        let descriptor = FetchDescriptor<SobrietyJourney>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        let journeys = (try? context.fetch(descriptor)) ?? []
        guard let closedIndex = journeys.lastIndex(where: { j in
            guard let end = j.endDate else { return false }
            return j.resetReason == "slip" && DateHelpers.startOfDay(end) == target
        }), closedIndex + 1 < journeys.count else { return nil }

        let opened = journeys[closedIndex + 1]
        let gap = DateHelpers.daysBetween(target, DateHelpers.startOfDay(opened.startDate))
        guard gap == 0 || gap == 1 else { return nil }
        let later = journeys[(closedIndex + 1)...]
        guard !later.contains(where: { $0.resetReason == "slip" }) else { return nil }
        return (journeys[closedIndex], opened)
    }

    /// Whole days since the active journey's start. Returns 0 if none.
    func currentDayCount(asOf date: Date = .now) -> Int {
        guard let journey = activeJourney() else { return 0 }
        return SobrietyService.daysSinceStart(journey.startDate, asOf: date)
    }

    /// Whole days accrued as of `date` by whichever journey covered that date.
    ///
    /// Unlike `currentDayCount(asOf:)` this keeps answering correctly once a
    /// later reset has ended the journey in question, which is what a
    /// back-dated slip needs: the streak that was running on the day of the
    /// event, not the one running when the user got around to entering it.
    /// Journeys are scanned oldest-first so a date sitting on the boundary
    /// between a journey that ended and the one that replaced it resolves to
    /// the run that was actually going on that day.
    func dayCount(asOf date: Date) -> Int {
        let day = DateHelpers.startOfDay(date)
        let descriptor = FetchDescriptor<SobrietyJourney>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        let journeys = (try? context.fetch(descriptor)) ?? []
        let covering = journeys.first { j in
            guard day >= DateHelpers.startOfDay(j.startDate) else { return false }
            guard let end = j.endDate else { return true }
            return day <= DateHelpers.startOfDay(end)
        }
        guard let journey = covering else { return 0 }
        return SobrietyService.daysSinceStart(journey.startDate, asOf: date)
    }

    /// Hours since the active journey's start.
    func currentHours(asOf date: Date = .now) -> Double {
        guard let journey = activeJourney() else { return 0 }
        return max(0, DateHelpers.hoursBetween(journey.startDate, date))
    }

    /// 1-based: the start day itself is "Day 1" (matches how every other
    /// sobriety counter reads, and keeps the streak counter aligned with the
    /// count of sober check-ins, which also includes the start day). Callers
    /// distinguish "no journey" via the guards above, which return 0.
    nonisolated static func daysSinceStart(_ start: Date, asOf date: Date = .now) -> Int {
        max(0, DateHelpers.daysBetween(start, date)) + 1
    }

    /// Best (longest) streak across all journeys recorded so far, in days.
    func longestStreakDays() -> Int {
        let descriptor = FetchDescriptor<SobrietyJourney>()
        let journeys = (try? context.fetch(descriptor)) ?? []
        let now = Date.now
        return journeys.map { j -> Int in
            let end = j.endDate ?? now
            return SobrietyService.daysSinceStart(j.startDate, asOf: end)
        }.max() ?? 0
    }
}
