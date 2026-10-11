package com.jackwallner.quitzyn.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.quitzyn.model.AppClock
import java.time.temporal.ChronoUnit

/**
 * Tracks an in-flight Bloom+ free trial so the app can warn before it
 * converts: the end date, the pre-conversion reminder, and the Home recap.
 */
class TrialLifecycle(
    private val defaults: KeyValueStore,
    private val clock: AppClock,
    private val notifications: NotificationService,
) {
    /** Bumped on every change so Compose re-reads the banner state. */
    var revision by mutableIntStateOf(0)
        private set

    /** Set when a trial starts and the reminder still needs the permission asked. */
    var wantsReminderPermission by mutableStateOf(false)

    val endsAtMillis: Long? get() = defaults.getLong(ENDS_AT).takeIf { it > 0 }

    fun daysRemaining(): Int? {
        val end = endsAtMillis ?: return null
        val now = clock.now().toEpochMilli()
        if (end <= now) return null
        val days = ChronoUnit.DAYS.between(clock.now(), java.time.Instant.ofEpochMilli(end)).toInt()
        return maxOf(1, days)
    }

    var recapSummary: String?
        get() = defaults.getString(RECAP_SUMMARY)?.takeIf { it.isNotEmpty() }
        set(value) {
            if (value.isNullOrEmpty()) defaults.remove(RECAP_SUMMARY) else defaults.putString(RECAP_SUMMARY, value)
        }

    /**
     * Idempotent: only does work when the trial's end date changes, or when a
     * reminder for the same trial never landed (permission granted since). A
     * trial set not to renew needs no warning.
     */
    fun sync(isTrialing: Boolean, willRenew: Boolean = true, endsAt: Long?) {
        val now = clock.now().toEpochMilli()
        if (!isTrialing || !willRenew || endsAt == null || endsAt <= now) {
            clear()
            return
        }
        val current = endsAtMillis
        val sameTrial = current != null && kotlin.math.abs(current - endsAt) < 60_000
        if (sameTrial && defaults.getBoolean(REMINDER_SCHEDULED)) return
        defaults.putLong(ENDS_AT, endsAt)
        if (!sameTrial) defaults.remove(RECAP_DISMISSED_FOR)
        if (notifications.isAuthorized) {
            notifications.scheduleTrialEndingReminder(endsAt, recapSummary)
            defaults.putBoolean(REMINDER_SCHEDULED, notifications.isScheduled(NotificationService.TRIAL_ENDING_ID))
        } else if (!sameTrial) {
            // A retry for a trial already under way must not re-prompt.
            wantsReminderPermission = true
        }
        revision++
    }

    /** After the permission prompt the trial start raised. */
    fun scheduleReminderIfPossible() {
        wantsReminderPermission = false
        val end = endsAtMillis ?: return
        notifications.scheduleTrialEndingReminder(end, recapSummary)
        defaults.putBoolean(REMINDER_SCHEDULED, notifications.isScheduled(NotificationService.TRIAL_ENDING_ID))
    }

    fun clear() {
        if (defaults.getLong(ENDS_AT) <= 0) return
        defaults.remove(ENDS_AT)
        defaults.remove(RECAP_DISMISSED_FOR)
        defaults.remove(REMINDER_SCHEDULED)
        notifications.cancelTrialEndingReminder()
        revision++
    }

    fun shouldShowRecap(): Boolean {
        val end = endsAtMillis ?: return false
        if (end <= clock.now().toEpochMilli()) return false
        val remaining = daysRemaining() ?: return false
        if (remaining > RECAP_LEAD_DAYS) return false
        return defaults.getLong(RECAP_DISMISSED_FOR) != end
    }

    fun dismissRecap() {
        val end = endsAtMillis ?: return
        defaults.putLong(RECAP_DISMISSED_FOR, end)
        revision++
    }

    companion object {
        const val RECAP_LEAD_DAYS = 3
        private const val ENDS_AT = "trialLifecycle.endsAt"
        private const val RECAP_SUMMARY = "trialLifecycle.recapSummary"
        private const val RECAP_DISMISSED_FOR = "trialLifecycle.recapDismissedForEnd"
        private const val REMINDER_SCHEDULED = "trialLifecycle.reminderScheduled"
    }
}
