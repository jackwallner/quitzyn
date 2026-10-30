import Foundation
import SwiftData
import UserNotifications

enum NotificationService {
    static let dailyReminderID = "sober.daily-reminder"
    /// userInfo marker so the app can route a reminder tap straight to Home.
    static let deepLinkKey = "deepLink"
    static let deepLinkCheckIn = "checkIn"
    static let deepLinkBloomPlus = "bloomPlus"
    /// Fires before a Bloom+ free trial converts, so nobody is surprised by a charge.
    static let trialEndingID = "quitzyn.trial-ending"
    /// How many days ahead of a trial's conversion the reminder fires.
    static let trialReminderLeadDays = 2

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Authorization state, without prompting.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// True when a notification we schedule will actually be delivered.
    /// `UNUserNotificationCenter.add` succeeds without permission and the
    /// request is then silently dropped, so scheduling checks this first.
    /// Deliberately does NOT prompt.
    static func isAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// Ask for permission at a moment the user has just asked for something
    /// that needs it (starting a trial they'll want warning about). Returns
    /// false if they decline or already declined.
    @discardableResult
    static func ensureAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        default:
            return true
        }
    }

    /// How many days of reminders are queued ahead. Each one carries the day
    /// number for its own date, so they are one-shot requests rather than a
    /// repeating trigger, and every app open re-arms the window.
    static let reminderHorizonDays = 30

    /// Queue the daily reminder for the next `reminderHorizonDays` days.
    ///
    /// A repeating trigger carries one fixed body, written with whatever the
    /// counter read at the last Home refresh: a user who stopped opening the
    /// app got "Day 11 is waiting" every morning for weeks, and the morning
    /// after a slip it congratulated the streak that had just ended. Each
    /// request here is numbered from the journey start for the date it fires.
    static func scheduleDailyReminder(
        hour: Int,
        committed: Bool = true,
        journeyStart: Date? = nil,
        checkedInToday: Bool = false,
        now: Date = .now
    ) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        await cancelDailyReminder()

        let fireDates = reminderFireDates(hour: hour, now: now, checkedInToday: checkedInToday)
        for (index, fireDate) in fireDates.enumerated() {
            let copy = reminderContent(fireDate: fireDate, journeyStart: journeyStart, committed: committed)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.userInfo = [deepLinkKey: deepLinkCheckIn]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: dailyReminderRequestID(index), content: content, trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// The reminder's wording for the day it fires. Copy stays supportive:
    /// even the "committed" variants avoid guilt language, because people
    /// early in recovery delete apps that scold. The day number only appears
    /// once there is a streak worth naming, so the morning after a slip gets
    /// the plain encouragement rather than the run that just ended.
    static func reminderContent(
        fireDate: Date,
        journeyStart: Date?,
        committed: Bool
    ) -> (title: String, body: String) {
        let day = journeyStart.map { SobrietyService.daysSinceStart($0, asOf: fireDate) } ?? 0
        let daysIn = day - 1
        if daysIn > 1 {
            return (
                "Day \(day) is waiting",
                committed
                    ? "You're \(daysIn) days in. Log today and water your bonsai."
                    : "\(daysIn) days and growing. If today's nicotine-free, log it."
            )
        }
        return (
            committed ? "Showing up today" : "Daily check-in",
            committed
                ? "Log today and water your garden. You've got this."
                : "If today's nicotine-free, log it and water your garden."
        )
    }

    /// The next reminder times at `hour`, starting today when it is still
    /// ahead and today is not logged yet: a reminder for a day already
    /// checked in is noise.
    static func reminderFireDates(
        hour: Int,
        now: Date,
        checkedInToday: Bool,
        count: Int = reminderHorizonDays
    ) -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let todayFire = cal.date(bySettingHour: hour, minute: 0, second: 0, of: today) ?? today
        let firstOffset = (todayFire > now && !checkedInToday) ? 0 : 1
        return (firstOffset..<(firstOffset + count)).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: today).flatMap {
                cal.date(bySettingHour: hour, minute: 0, second: 0, of: $0)
            }
        }
    }

    /// Re-arm the reminder from the store: the active run's start and whether
    /// today is logged. Called after anything that changes either (a check-in,
    /// a slip, an undo, a reset, a start date edit) and on every Home refresh,
    /// and cancels the queue when the user has turned the reminder off.
    @MainActor
    static func refreshDailyReminder(context: ModelContext, now: Date = .now) {
        let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first
        guard let settings, settings.dailyReminderEnabled else {
            lastReminderPlan = nil
            Task { await cancelDailyReminder() }
            return
        }
        let hour = settings.dailyReminderHour
        let committed = settings.madeCommitment
        let start = SobrietyService(context: context).activeJourney()?.startDate
        let checkedIn = CheckInService(context: context).hasCheckedIn(on: now)
        // Home refreshes on every tab switch; re-queueing thirty requests each
        // time the answer has not changed is wasted work.
        let plan = "\(hour)|\(committed)|\(start?.timeIntervalSince1970 ?? 0)|\(checkedIn)|\(DateHelpers.startOfDay(now).timeIntervalSince1970)"
        guard plan != lastReminderPlan else { return }
        lastReminderPlan = plan
        Task {
            await scheduleDailyReminder(
                hour: hour, committed: committed, journeyStart: start, checkedInToday: checkedIn, now: now
            )
        }
    }

    @MainActor private static var lastReminderPlan: String?

    static func cancelDailyReminder() async {
        // The bare ID is the repeating request earlier builds scheduled.
        let ids = [dailyReminderID] + (0..<reminderHorizonDays).map(dailyReminderRequestID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func dailyReminderRequestID(_ index: Int) -> String {
        "\(dailyReminderID).\(index)"
    }

    // MARK: - Trial

    /// Heads-up before a free trial converts. This is the reminder the trial
    /// timeline promises on its middle step, so it has to exist: states the
    /// date plainly, because a surprise bill is how you earn a one-star review.
    @discardableResult
    static func scheduleTrialEndingReminder(
        endsAt: Date,
        summary: String?,
        now: Date = .now
    ) async -> Bool {
        guard await isAuthorized() else { return false }
        let center = UNUserNotificationCenter.current()
        cancelTrialEndingReminder()

        guard let fireDate = trialReminderFireDate(endsAt: endsAt, now: now) else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Your Bloom+ trial ends soon"
        if let summary, !summary.isEmpty {
            content.body = "\(summary) Keep the full garden, or cancel any time before it renews."
        } else {
            content.body = "Keep your full garden, journal, and savings, or cancel any time before it renews."
        }
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLinkBloomPlus]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, fireDate.timeIntervalSince(now)),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: trialEndingID, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    /// Two days before conversion, or the midpoint for trials too short for that.
    /// Nil when the trial ends too soon for a reminder to be anything but noise.
    static func trialReminderFireDate(endsAt: Date, now: Date = .now) -> Date? {
        let remaining = endsAt.timeIntervalSince(now)
        guard remaining > 3600 else { return nil }
        let lead = TimeInterval(trialReminderLeadDays) * 86_400
        let fire = remaining > lead
            ? endsAt.addingTimeInterval(-lead)
            : now.addingTimeInterval(remaining / 2)
        return fire > now ? fire : nil
    }

    static func cancelTrialEndingReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [trialEndingID]
        )
    }
}
