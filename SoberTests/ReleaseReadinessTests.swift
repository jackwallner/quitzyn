import Testing
import Foundation
import SwiftData
@testable import Sober

/// Pins the gaps closed before 1.2.4: the trial reminder the timeline promises,
/// the widget and watch drawing the carried-over tree, and the legacy check-in
/// repair only marking itself done once it has actually run.

@MainActor
private final class RecordingTrialNotificationScheduler: TrialNotificationScheduling {
    var authorizationRequests = 0
    var scheduledEnd: Date?
    var cancellations = 0

    func ensureAuthorized() async -> Bool {
        authorizationRequests += 1
        return true
    }

    func scheduleTrialEndingReminder(endsAt: Date, summary: String?, now: Date) async {
        scheduledEnd = endsAt
    }

    func cancelTrialEndingReminder() {
        cancellations += 1
    }
}

@Suite("Trial ending reminder", .serialized)
@MainActor
struct TrialEndingReminderTests {
    @Test func startingATrialSchedulesTheReminderOnce() async {
        let scheduler = RecordingTrialNotificationScheduler()
        let previous = TrialLifecycle.notificationScheduler
        TrialLifecycle.notificationScheduler = scheduler
        defer {
            TrialLifecycle.clear()
            TrialLifecycle.notificationScheduler = previous
        }
        TrialLifecycle.clear()

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = now.addingTimeInterval(7 * 86_400)
        TrialLifecycle.sync(isTrialing: true, endsAt: endsAt, now: now)
        // A refresh for the same trial must not reschedule.
        TrialLifecycle.sync(isTrialing: true, endsAt: endsAt, now: now)
        for _ in 0..<5 { await Task.yield() }

        #expect(scheduler.authorizationRequests == 1)
        #expect(scheduler.scheduledEnd == endsAt)
        #expect(TrialLifecycle.endsAt == endsAt)

        TrialLifecycle.sync(isTrialing: false, endsAt: nil, now: now)
        #expect(scheduler.cancellations == 1)
        #expect(TrialLifecycle.endsAt == nil)
    }

    @Test func timelineDayMatchesTheDayTheReminderFires() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let endsAt = now.addingTimeInterval(7 * 86_400)
        let fire = NotificationService.trialReminderFireDate(endsAt: endsAt, now: now)
        #expect(fire == endsAt.addingTimeInterval(-2 * 86_400))
        #expect(TrialTimeline.reminderDay(forTrialOf: 7) == 5)
    }

    @Test func shortTrialsFireAtTheMidpointAndExpiringOnesNotAtAll() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dayOut = now.addingTimeInterval(86_400)
        #expect(NotificationService.trialReminderFireDate(endsAt: dayOut, now: now) == now.addingTimeInterval(43_200))
        #expect(NotificationService.trialReminderFireDate(endsAt: now.addingTimeInterval(1_800), now: now) == nil)
    }
}

@Suite("Widget and watch tree after a slip")
struct SnapshotTreeDaysTests {
    @Test func carryoverGrowsTheTreePastTheStreak() {
        var snap = WidgetSnapshot.empty
        snap.carryoverDays = 40
        let tree = snap.treeDays(streakDays: 1)
        #expect(tree == 41)
        #expect(GardenService.stage(forDays: tree).rawValue > GardenService.stage(forDays: 1).rawValue)
    }

    @Test func oldPayloadWithoutCarryoverStillDecodes() throws {
        let json = #"{"currentStreakDays":12,"longestStreakDays":12,"bonsaiStage":2,"bonsaiStyleID":"traditional","gardenVitality":1,"placedItemIDs":[],"unlockedItemIDs":[],"generatedAt":0}"#
        let snap = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(json.utf8))
        #expect(snap.currentStreakDays == 12)
        #expect(snap.carryoverDays == 0)
    }
}

@Suite("Legacy check-in repair marker", .serialized)
@MainActor
struct LegacyRepairMarkerTests {
    @Test func markerIsWrittenOnlyAfterTheRepairLands() throws {
        let container = try ModelContainer(
            for: DailyCheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let key = AppGroup.legacyCheckInsMarkedLoggedKey
        AppGroup.defaults.removeObject(forKey: key)
        defer { AppGroup.defaults.removeObject(forKey: key) }

        container.mainContext.insert(DailyCheckIn(day: DateHelpers.daysAgo(2), wasSober: true))
        try container.mainContext.save()

        CheckInService.migrateLegacyCheckInsIfNeeded(context: container.mainContext)
        #expect(AppGroup.defaults.bool(forKey: key))
        let rows = try container.mainContext.fetch(FetchDescriptor<DailyCheckIn>())
        let allLogged = rows.allSatisfy { $0.wasLogged }
        #expect(allLogged)
    }
}
