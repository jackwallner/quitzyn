package com.jackwallner.quitzyn

import android.content.Intent
import com.jackwallner.quitzyn.data.NotificationService
import com.jackwallner.quitzyn.data.PackageKind
import com.jackwallner.quitzyn.data.PeriodUnit
import com.jackwallner.quitzyn.data.Plan
import com.jackwallner.quitzyn.data.PlanPeriod
import com.jackwallner.quitzyn.model.JournalEntry
import com.jackwallner.quitzyn.model.JournalKind
import com.jackwallner.quitzyn.model.SoberEngine
import com.jackwallner.quitzyn.model.SoberState

/**
 * Debug-only launch extras, the Android side of the iOS launch arguments.
 * None of this is compiled into a release or QA build.
 *
 *     adb shell am start -n com.jackwallner.quitzyn/.MainActivity \
 *         --ez resetAll true --ez seedDemo true --ei seedDays 127 --ez demoPro true --ei tab 4
 */
object DebugLaunchOptions {
    var launchTab: Int? = null
        private set
    var showProgress: Boolean = false
        private set
    var onboardingStep: Int? = null
        private set
    var gallery: Boolean = false
        private set
    var openCraving: Boolean = false
        private set
    var openSlip: Boolean = false
        private set

    fun apply(graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("uiTest")) graph.review.isAutomationRun = true
        if (extras.getBoolean("resetAll")) {
            graph.store.update { SoberState() }
            graph.defaults.keys().forEach(graph.defaults::remove)
        }
        if (extras.getBoolean("demoPro")) graph.subscriptions.forceProForDebug()
        if (extras.getBoolean("previewStore")) {
            val trialDays = extras.getInt("previewTrialDays", 7)
            graph.subscriptions.loadPreviewPlans(previewPlans(trialDays), history = extras.getBoolean("previewTrialUsed"))
        }
        if (extras.getBoolean("seedDemo") && !graph.store.hasCompletedOnboarding) seed(graph, extras.getInt("seedDays", 24))
        if (extras.getBoolean("seedCravings")) seedCravings(graph)
        // Rewind the growth watermark so Home replays a celebration (`--ei watermark 10`).
        if (extras.containsKey("watermark")) {
            val mark = extras.getInt("watermark")
            graph.store.update { it.copy(garden = it.garden.copy(watermark = mark)) }
        }
        if (extras.containsKey("testReminderIn")) {
            graph.notifications.scheduleForTesting(extras.getString("testReminderId") ?: NotificationService.DAILY_ID, extras.getInt("testReminderIn"))
        }
        if (extras.containsKey("tab")) launchTab = extras.getInt("tab")
        showProgress = extras.getBoolean("showProgress")
        gallery = extras.getBoolean("gallery")
        openCraving = extras.getBoolean("craving")
        openSlip = extras.getBoolean("slip")
        if (extras.containsKey("onboardingStep")) onboardingStep = extras.getInt("onboardingStep")
    }

    /** `-seedDemo -seedDays N`: one number drives counter, calendar, health, and savings. */
    private fun seed(graph: AppGraph, days: Int) {
        val clock = graph.clock
        val start = clock.today().minusDays(days.toLong()).atStartOfDay(clock.zone()).toInstant()
        graph.store.update { old ->
            var next = SoberEngine.startJourney(old, start, clock)
            next = SoberEngine.fillJourney(next, clock.today(), clock)
            next = next.copy(settings = next.settings.copy(
                costPerDayCents = 320,
                pouchesPerDay = 8,
                madeCommitment = true,
                hasCompletedOnboarding = true,
            ))
            val entries = listOf(
                Triple(1L, "Long drive to my sister's and I didn't reach for the glovebox once. Gum and a podcast did the job.", "good"),
                Triple(6L, "The 3pm slump hit hard and my hand went to my pocket out of habit. Went for a walk around the block instead. It passed.", "neutral"),
                Triple(13L, "Food actually tastes like something again. Had a peach today and it was ridiculous.", "excellent"),
            ).filter { it.first <= days }.map { (daysAgo, text, feeling) ->
                JournalEntry(createdAt = clock.now().minusSeconds(daysAgo * 86_400), kind = JournalKind.DAILY, text = text, feeling = feeling)
            }
            next.copy(journal = entries)
        }
    }

    private fun seedCravings(graph: AppGraph) {
        val clock = graph.clock
        val triggers = listOf("Coffee", "Stress", "Driving", "Work break", "Stress", "After a meal")
        graph.store.update { old ->
            triggers.foldIndexed(old) { index, state, trigger ->
                val started = clock.today().minusDays((index * 2 + 1).toLong()).atTime(10 + (index % 3) * 3, 10).atZone(clock.zone()).toInstant()
                state.copy(cravings = state.cravings + com.jackwallner.quitzyn.model.CravingEpisode(
                    startedAt = started,
                    endedAt = started.plusSeconds(70L + index * 10),
                    intensity = 2 + index % 3,
                    outcome = if (index == 3) com.jackwallner.quitzyn.model.CravingOutcome.GAVE_IN else com.jackwallner.quitzyn.model.CravingOutcome.RODE_IT_OUT,
                    trigger = trigger,
                    secondsElapsed = 70 + index * 10,
                ))
            }
        }
    }

    /** `PaywallPreviewStore`: the Android US ladder, so the real paywall renders without a store. */
    private fun previewPlans(trialDays: Int): List<Plan> {
        val trial = if (trialDays % 7 == 0) PlanPeriod(trialDays / 7, PeriodUnit.WEEK) else PlanPeriod(maxOf(1, trialDays), PeriodUnit.DAY)
        return listOf(
            Plan("\$rc_annual", "com.jackwallner.quitzyn.pro.yearly", PackageKind.YEARLY, 27_990_000, "$27.99", "USD", PlanPeriod(1, PeriodUnit.YEAR), trial, "Bloom+ Yearly"),
            Plan("\$rc_monthly", "com.jackwallner.quitzyn.pro.monthly", PackageKind.MONTHLY, 6_990_000, "$6.99", "USD", PlanPeriod(1, PeriodUnit.MONTH), trial, "Bloom+ Monthly"),
            Plan("\$rc_lifetime", "com.jackwallner.quitzyn.pro.lifetime", PackageKind.LIFETIME, 63_990_000, "$63.99", "USD", null, null, "Bloom+ Lifetime"),
        )
    }
}
