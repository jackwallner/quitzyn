import Foundation
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

    static func scheduleDailyReminder(hour: Int, committed: Bool = true, streakDays: Int = 0) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        await cancelDailyReminder()

        // Copy stays supportive — even the "committed" variants avoid guilt
        // language. People early in recovery delete apps that scold. When we
        // know the streak, lead with it so the reminder feels personal; the
        // schedule is refreshed on every check-in/app-open so it stays current.
        let content = UNMutableNotificationContent()
        if streakDays > 1 {
            content.title = "Day \(streakDays + 1) is waiting"
            content.body = committed
                ? "You're \(streakDays) days in. Log today and water your bonsai."
                : "\(streakDays) days and growing. If today's nicotine-free, log it."
        } else {
            content.title = committed ? "Showing up today" : "Daily check-in"
            content.body = committed
                ? "Log today and water your garden. You've got this."
                : "If today's nicotine-free, log it and water your garden."
        }
        content.sound = .default
        content.userInfo = [deepLinkKey: deepLinkCheckIn]

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Re-schedule the daily reminder with fresh streak copy, but only if one
    /// is already pending — never resurrects a reminder the user turned off.
    static func refreshDailyReminder(hour: Int, committed: Bool, streakDays: Int) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard pending.contains(where: { $0.identifier == dailyReminderID }) else { return }
        await scheduleDailyReminder(hour: hour, committed: committed, streakDays: streakDays)
    }

    static func cancelDailyReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailyReminderID]
        )
    }

    // MARK: - Trial

    /// Heads-up before a free trial converts. This is the reminder the trial
    /// timeline promises on its middle step, so it has to exist: states the
    /// date plainly, because a surprise bill is how you earn a one-star review.
    static func scheduleTrialEndingReminder(
        endsAt: Date,
        summary: String?,
        now: Date = .now
    ) async {
        guard await isAuthorized() else { return }
        let center = UNUserNotificationCenter.current()
        cancelTrialEndingReminder()

        guard let fireDate = trialReminderFireDate(endsAt: endsAt, now: now) else { return }

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
        try? await center.add(request)
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
