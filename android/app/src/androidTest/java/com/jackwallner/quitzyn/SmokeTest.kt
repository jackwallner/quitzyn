package com.jackwallner.quitzyn

import android.content.Intent
import android.os.Bundle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.BySelector
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * First-run path and the paid boundary, driven through UI Automator (test tags
 * are resource ids). Compose's test rule is avoided on purpose: on the API 36.1
 * image its Espresso idling hook fails every test (see the fleet port notes).
 * The orchestrator clears app data between tests, so each starts from a clean
 * install; launch extras are the debug-only `DebugLaunchOptions`.
 */
@RunWith(AndroidJUnit4::class)
class SmokeTest {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private val pkg = "com.jackwallner.quitzyn"

    private fun launch(extras: Bundle.() -> Unit = {}) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = context.packageManager.getLaunchIntentForPackage(pkg)!!.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtras(Bundle().apply { putBoolean("uiTest", true); extras() })
        }
        context.startActivity(intent)
        device.wait(Until.hasObject(By.pkg(pkg).depth(0)), 10_000)
    }

    private fun find(selector: BySelector, timeout: Long = 8_000): UiObject2 =
        assertNotNull("Not on screen: $selector", device.wait(Until.findObject(selector), timeout)).let { device.findObject(selector) }

    /** Like [find], but scrolls the screen's scrollable down first when the target starts below the fold. */
    private fun findScrolling(selector: BySelector): UiObject2 {
        repeat(6) {
            device.wait(Until.findObject(selector), 1_500)?.let { return it }
            device.findObject(By.scrollable(true))?.scroll(androidx.test.uiautomator.Direction.DOWN, 0.8f)
        }
        return find(selector)
    }

    private fun tag(id: String) = By.res(id)

    @Test fun onboardingWithTheTrialReachesHomeUnlocked() {
        launch { putBoolean("previewStore", true) }
        find(tag("onboarding.start")).click()
        find(By.text("When did your nicotine-free journey begin?"))
        find(tag("onboarding.continue")).click()
        find(By.text("How much were you using?"))
        find(By.text("Your usual can"))
        find(tag("onboarding.savingsContinue")).click()
        find(By.text("7 days of Bloom+ free"))
        find(tag("onboarding.trialCTA")).click()
        find(By.text("Daily reminder time"))
        find(tag("onboarding.reminderContinue")).click()
        find(By.text("Make it official"))
        find(tag("onboarding.commit")).click()
        device.wait(Until.findObject(By.text("Allow")), 5_000)?.click()
        assertEquals("1", find(tag("home.dayCount")).text)
        find(By.desc("Bloom+"))
    }

    @Test fun skippingTheOfferKeepsTheFreeVersion() {
        launch { putBoolean("previewStore", true) }
        find(tag("onboarding.start")).click()
        find(tag("onboarding.continue")).click()
        find(tag("onboarding.savingsContinue")).click()
        find(tag("onboarding.skipTrial")).click()
        find(By.text("Keep the free version?"))
        find(By.text("Keep my free trial"))
        // The dialog's own window lists its buttons last; take the alert's "Get started".
        device.wait(Until.findObjects(By.text("Get started")), 5_000)!!.last().click()
        find(tag("onboarding.reminderContinue")).click()
        find(tag("onboarding.notNow")).click()
        device.wait(Until.findObject(By.text("Don’t allow")), 5_000)?.click()
        find(tag("home.dayCount"))
        find(By.desc("Upgrade"))
    }

    @Test fun freeUsersSeeLockedMilestonesPastTheFirstFive() {
        launch { putBoolean("seedDemo", true); putInt("seedDays", 45); putInt("tab", 2) }
        find(By.text("Heart rate and nicotine"))
        findScrolling(By.text("A future milestone"))
        findScrolling(By.text("Unlock with Bloom+"))
    }

    @Test fun subscribersSeePouchAndNicotineSavings() {
        launch { putBoolean("seedDemo", true); putInt("seedDays", 45); putBoolean("demoPro", true); putInt("tab", 4) }
        find(By.text("BLOOM+ ACTIVE"))
        find(By.text("pouches avoided"))
        find(By.text("368"))
        find(By.text("nicotine never absorbed"))
    }

    @Test fun aSlipCanBeLoggedAndTakenBack() {
        launch { putBoolean("seedDemo", true); putInt("seedDays", 45); putBoolean("slip", true) }
        findScrolling(By.text("Log it and keep going"))
        find(tag("slip.log")).click()
        find(By.text("Logged. You're still on the journey."))
        find(tag("slip.undo")).click()
        assertEquals("46", find(tag("home.dayCount")).text)
    }

    @Test fun riddenOutCravingIsLogged() {
        launch { putBoolean("seedDemo", true); putInt("seedDays", 10); putBoolean("craving", true) }
        find(By.text("Hold"))
        Thread.sleep(9_000)
        find(tag("craving.through")).click()
        find(By.text("What set it off?"))
        find(By.text("Coffee")).click()
        find(By.text("It passed")).click()
        find(By.text("Logged."))
        find(By.text("That's one craving you've ridden out."))
    }
}
