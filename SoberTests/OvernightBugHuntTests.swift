import Testing
import Foundation
import SwiftData
@testable import Sober

/// The 2026-10-30 overnight bug hunt (`reports/nicfree.md`). Each test pins
/// one finding the report proved with a scratch test or a screenshot.

// MARK: - P1-1: a time zone change duplicated every logged day

@Suite("Check-in days survive a time zone change")
@MainActor
struct TimeZoneDayKeyTests {
    private let container: ModelContainer
    private let defaults: UserDefaults

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        defaults = UserDefaults(suiteName: "tz-day-keys-\(UUID().uuidString)")!
    }

    private var context: ModelContext { container.mainContext }

    private func rows() -> [DailyCheckIn] {
        (try? context.fetch(FetchDescriptor<DailyCheckIn>(sortBy: [SortDescriptor(\.day)]))) ?? []
    }

    /// A fixed-offset zone far from this one: more than twelve hours away
    /// from Los Angeles, where nearest-midnight guessing would pick the wrong day.
    private var farZone: TimeZone {
        let here = TimeZone.current.secondsFromGMT()
        return TimeZone(secondsFromGMT: here >= 0 ? -10 * 3600 : 9 * 3600)!
    }

    /// Nine hours from here, as on a flight from Los Angeles to Paris.
    private var nearZone: TimeZone {
        let here = TimeZone.current.secondsFromGMT()
        let shifted = here + 9 * 3600 <= 14 * 3600 ? here + 9 * 3600 : here - 9 * 3600
        return TimeZone(secondsFromGMT: shifted)!
    }

    /// Midnight in `zone` of the calendar date that is `daysAgo` days back here.
    private func midnight(daysAgo: Int, in zone: TimeZone) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: DateHelpers.daysAgo(daysAgo))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: comps)!
    }

    private func insert(daysAgo: Int, in zone: TimeZone, sober: Bool = true, logged: Bool = false, mood: Int? = nil, note: String? = nil) {
        let row = DailyCheckIn(day: .now, wasSober: sober, mood: mood, note: note, wasLogged: logged)
        // The initializer keys to this zone; overwrite with the other zone's midnight.
        row.day = midnight(daysAgo: daysAgo, in: zone)
        context.insert(row)
    }

    /// The report's repro: ten days filled in one zone, then the app opens in
    /// another and Home fills the journey again.
    @Test func travellingDoesNotDuplicateHistory() throws {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(10))
        for d in 1...10 { insert(daysAgo: d, in: farZone) }
        insert(daysAgo: 0, in: farZone, logged: true)
        try context.save()
        defaults.set(farZone.identifier, forKey: AppGroup.checkInDayKeyZoneKey)

        let svc = CheckInService(context: context, dayKeyDefaults: defaults)
        svc.fillJourney(start: DateHelpers.daysAgo(10), through: DateHelpers.daysAgo(1))

        #expect(rows().count == 11, "11 calendar days became \(rows().count) rows")
        #expect(svc.lifetimeSoberDayCount() == 11)
        #expect(svc.hasCheckedIn(), "today's check-in, written in the other zone, was lost")
        #expect(rows().allSatisfy { DateHelpers.startOfDay($0.day) == $0.day })
        #expect(defaults.string(forKey: AppGroup.checkInDayKeyZoneKey) == TimeZone.current.identifier)
    }

    /// Users who already travelled on an older build have both copies on disk
    /// and no record of the zone. The repair merges them and keeps every word.
    @Test func duplicatesFromEarlierBuildsMergeWithoutLosingAnything() throws {
        for d in 1...10 { insert(daysAgo: d, in: .current) }
        for d in 1...10 where d != 3 && d != 5 { insert(daysAgo: d, in: nearZone) }
        insert(daysAgo: 3, in: nearZone, sober: false, logged: true, note: "rough day")
        insert(daysAgo: 5, in: nearZone, logged: true, mood: 4, note: "walked it off")
        let five = rows().first { $0.day == midnight(daysAgo: 5, in: .current) }!
        five.wasLogged = true
        five.note = "first note"
        try context.save()
        #expect(rows().count == 20)

        CheckInService.normalizeDayKeys(context: context, defaults: defaults)

        let after = rows()
        #expect(after.count == 10)
        let slip = after.first { $0.day == DateHelpers.daysAgo(3) }
        #expect(slip?.wasSober == false)
        #expect(slip?.wasLogged == true)
        #expect(slip?.note == "rough day")
        let merged = after.first { $0.day == DateHelpers.daysAgo(5) }
        #expect(merged?.mood == 4)
        #expect(merged?.note?.contains("first note") == true)
        #expect(merged?.note?.contains("walked it off") == true)
        #expect(after.filter(\.wasLogged).count == 2)
    }

    @Test func aSecondPassChangesNothing() throws {
        for d in 1...5 { insert(daysAgo: d, in: .current) }
        try context.save()
        CheckInService.normalizeDayKeys(context: context, defaults: defaults)
        let first = rows().map(\.day)
        CheckInService.normalizeDayKeys(context: context, defaults: defaults)
        #expect(rows().map(\.day) == first)
        #expect(first.count == 5)
    }

    /// Los Angeles to Tokyo is more than twelve hours: the remembered zone
    /// maps it exactly, and the offset a midnight implies does too.
    @Test func calendarDayIsRecoveredAcrossTheWidestTrips() {
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let paris = TimeZone(identifier: "Europe/Paris")!
        func midnight(_ zone: TimeZone) -> Date {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = zone
            return cal.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        }
        #expect(CheckInService.startOfCalendarDay(containing: midnight(la), keyedIn: la, in: tokyo) == midnight(tokyo))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(la), keyedIn: nil, in: tokyo) == midnight(tokyo))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(tokyo), keyedIn: nil, in: la) == midnight(la))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(paris), keyedIn: nil, in: la) == midnight(la))
        #expect(CheckInService.startOfCalendarDay(containing: midnight(la), keyedIn: la, in: la) == midnight(la))
    }
}

// MARK: - P1-2: Health countdowns showed the milestone's total time

@Suite("Health countdowns read the time left")
struct HealthCountdownTests {
    private func benefit(hours: Double) -> HealthBenefit {
        HealthBenefit(id: "t", hoursRequired: hours, title: "", summary: "", detail: "", sourceLabel: "", sourceURL: nil)
    }

    @Test func aMonthMilestoneOneDayOutReadsOneDay() {
        #expect(benefit(hours: 720).remainingWait(hoursElapsed: 696) == "1d")
    }

    @Test func aDayMilestoneFourHoursOutReadsFourHours() {
        #expect(benefit(hours: 24).remainingWait(hoursElapsed: 20) == "4h")
    }

    @Test func theMilestoneLabelStillReadsFromTheStart() {
        #expect(benefit(hours: 720).displayWait == "1mo")
    }

    @Test func minutesLeftStillReadAsAnHour() {
        #expect(benefit(hours: 24).remainingWait(hoursElapsed: 23.9) == "1h")
    }
}

// MARK: - P1-3: the daily reminder named a frozen or wrong day

@Suite("Daily reminder copy is numbered for the day it fires")
struct DailyReminderContentTests {
    private func at(daysFromToday offset: Int, hour: Int, minute: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: DateHelpers.startOfDay())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    /// Day 10 today: the start was nine days back.
    private var start: Date { DateHelpers.daysAgo(9) }

    @Test func laterTodayNamesToday() {
        let copy = NotificationService.reminderContent(fireDate: at(daysFromToday: 0, hour: 9), journeyStart: start, committed: true)
        #expect(copy.title == "Day 10 is waiting")
        #expect(copy.body.hasPrefix("You're 9 days in."))
    }

    @Test func tomorrowAndAWeekOutCountOnFromTheStart() {
        let tomorrow = NotificationService.reminderContent(fireDate: at(daysFromToday: 1, hour: 9), journeyStart: start, committed: true)
        #expect(tomorrow.title == "Day 11 is waiting")
        let week = NotificationService.reminderContent(fireDate: at(daysFromToday: 7, hour: 9), journeyStart: start, committed: false)
        #expect(week.title == "Day 17 is waiting")
        #expect(week.body.hasPrefix("16 days and growing."))
    }

    /// A slip at 22:00 starts a fresh run tonight. The next morning must not
    /// congratulate the run that just ended.
    @Test func theMorningAfterASlipNamesNoStreak() {
        let slipNight = at(daysFromToday: 0, hour: 22)
        let copy = NotificationService.reminderContent(fireDate: at(daysFromToday: 1, hour: 9), journeyStart: slipNight, committed: true)
        #expect(copy.title == "Showing up today")
        #expect(!copy.body.contains("days in"))
    }

    @Test func firesTodayOnlyWhenItIsAheadAndTodayIsUnlogged() {
        let early = at(daysFromToday: 0, hour: 7, minute: 30)
        let dates = NotificationService.reminderFireDates(hour: 9, now: early, checkedInToday: false)
        #expect(dates.first == at(daysFromToday: 0, hour: 9))
        #expect(dates.count == NotificationService.reminderHorizonDays)
        #expect(dates.last == at(daysFromToday: NotificationService.reminderHorizonDays - 1, hour: 9))

        let logged = NotificationService.reminderFireDates(hour: 9, now: early, checkedInToday: true)
        #expect(logged.first == at(daysFromToday: 1, hour: 9))

        let late = NotificationService.reminderFireDates(hour: 9, now: at(daysFromToday: 0, hour: 10), checkedInToday: false)
        #expect(late.first == at(daysFromToday: 1, hour: 9))
    }
}

// MARK: - P2-1 and P2-5

@Suite("Garden vitality and check-in badges")
@MainActor
struct VitalityAndBadgeTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self, UnlockedAchievement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    /// P2-1: Home calls the decay on every appearance; a missed day is
    /// charged once.
    @Test func aMissedDayDecaysVitalityOnce() {
        let garden = GardenService(context: context)
        let yesterday = Calendar.current.date(byAdding: .hour, value: 12, to: DateHelpers.daysAgo(1))!
        garden.water(at: yesterday)
        #expect(garden.current().vitality == 1.0)
        for _ in 0..<4 { garden.applyVitalityDecay() }
        #expect(abs(garden.current().vitality - 0.9) < 0.0001, "vitality \(garden.current().vitality)")

        // Watering clears the charge, so the next missed day decays again.
        garden.water()
        #expect(abs(garden.current().vitality - 1.0) < 0.0001)
        garden.applyVitalityDecay(asOf: Calendar.current.date(byAdding: .day, value: 2, to: .now)!)
        #expect(abs(garden.current().vitality - 0.8) < 0.0001)
    }

    /// P2-5: "Daily check-ins for 7 days straight" needs check-ins.
    @Test func checkInBadgesNeedCheckIns() {
        SobrietyService(context: context).startJourney(at: DateHelpers.daysAgo(100))
        let checkIns = CheckInService(context: context, dayKeyDefaults: UserDefaults(suiteName: "badges-\(UUID().uuidString)")!)
        checkIns.fillJourney(start: DateHelpers.daysAgo(100), through: DateHelpers.daysAgo(1))
        let achievements = AchievementService(context: context)
        achievements.processUnlocks(currentDays: 101)

        let streakIDs = Set(AchievementCatalog.all.filter { $0.kind == .streak }.map(\.id))
        let unlocked = Set(achievements.unlocked().map(\.achievementID))
        #expect(unlocked.isDisjoint(with: streakIDs), "unlocked with 0 check-ins: \(unlocked.intersection(streakIDs))")
        // Time milestones still unlock by days, for everyone.
        #expect(unlocked.contains("strong-foundation"))

        for d in 0..<7 { checkIns.checkIn(for: DateHelpers.daysAgo(d)) }
        achievements.processUnlocks(currentDays: 101)
        #expect(achievements.unlocked().contains { $0.achievementID == "perfect-week" })
    }

    /// P2-4: moving the start date later drops the assumed days before it,
    /// and keeps anything the user logged.
    @Test func movingTheStartDateLaterDropsDaysOutsideTheJourney() {
        let sobriety = SobrietyService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(29))
        let checkIns = CheckInService(context: context, dayKeyDefaults: UserDefaults(suiteName: "start-\(UUID().uuidString)")!)
        checkIns.fillJourney(start: DateHelpers.daysAgo(29), through: DateHelpers.daysAgo(1))
        checkIns.checkIn(for: DateHelpers.daysAgo(20), mood: 5)

        sobriety.updateStartDate(DateHelpers.daysAgo(9))
        checkIns.dropAssumedDaysOutsideJourneys()
        checkIns.fillJourney(start: DateHelpers.daysAgo(9), through: DateHelpers.daysAgo(1))

        // Nine assumed days in the run, plus the one day the user logged.
        #expect(checkIns.lifetimeSoberDayCount() == 10)
        #expect(checkIns.hasCheckedIn(on: DateHelpers.daysAgo(20)))
    }
}
