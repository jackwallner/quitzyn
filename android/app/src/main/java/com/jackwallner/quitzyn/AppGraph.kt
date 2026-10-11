package com.jackwallner.quitzyn

import android.content.Context
import androidx.glance.appwidget.updateAll
import com.jackwallner.quitzyn.content.SoberContent
import com.jackwallner.quitzyn.data.AlarmReminderPlatform
import com.jackwallner.quitzyn.data.AtomicStateFile
import com.jackwallner.quitzyn.data.ConversionDiagnostics
import com.jackwallner.quitzyn.data.NotificationService
import com.jackwallner.quitzyn.data.PermissionBridge
import com.jackwallner.quitzyn.data.PitchScheduler
import com.jackwallner.quitzyn.data.ReviewPromptTracker
import com.jackwallner.quitzyn.data.SharedPreferencesStore
import com.jackwallner.quitzyn.data.SoberStore
import com.jackwallner.quitzyn.data.SubscriptionService
import com.jackwallner.quitzyn.data.TrialLifecycle
import com.jackwallner.quitzyn.data.TrialNudgeGate
import com.jackwallner.quitzyn.data.TrialOfferCoordinator
import com.jackwallner.quitzyn.data.TrialSubsequentPitchGate
import com.jackwallner.quitzyn.model.SystemAppClock
import com.jackwallner.quitzyn.widget.SoberWidget
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

/** Every long-lived object the screens share, built once per process. */
class AppGraph(context: Context) {
    val appContext: Context = context.applicationContext
    val scope = MainScope()
    val clock = SystemAppClock()
    val content = SoberContent.shared
    val defaults = SharedPreferencesStore(appContext)
    val permissions = PermissionBridge()
    val notifications = NotificationService(AlarmReminderPlatform(appContext), defaults).also {
        it.permissionRequester = permissions::request
    }
    val store = SoberStore(AtomicStateFile(appContext.filesDir), clock, content) { refreshWidgets() }
    val review = ReviewPromptTracker(defaults, clock)
    val diagnostics = ConversionDiagnostics(defaults, clock)
    val trial = TrialLifecycle(defaults, clock, notifications)
    val subscriptions = SubscriptionService(appContext, defaults, diagnostics, trial)
    val coordinator = TrialOfferCoordinator()
    val nudges = TrialNudgeGate(defaults, clock)
    val pitchGate = TrialSubsequentPitchGate(defaults, nudges)
    val pitches = PitchScheduler(subscriptions, coordinator, nudges, pitchGate)

    /** `WidgetSnapshotPump.push`: the home-screen widget reads the store directly. */
    fun refreshWidgets() {
        scope.launch { runCatching { SoberWidget().updateAll(appContext) } }
    }
}
