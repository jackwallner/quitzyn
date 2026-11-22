package com.jackwallner.quitzyn

import com.jackwallner.quitzyn.content.SoberContent
import com.jackwallner.quitzyn.data.HeldCheckInPitch
import com.jackwallner.quitzyn.data.SoberCodec
import com.jackwallner.quitzyn.data.SoberStore
import com.jackwallner.quitzyn.data.StateFile
import com.jackwallner.quitzyn.model.BonsaiStage
import com.jackwallner.quitzyn.model.CravingEpisode
import com.jackwallner.quitzyn.model.CravingInsights
import com.jackwallner.quitzyn.model.CravingOutcome
import com.jackwallner.quitzyn.model.GrowthEvent
import com.jackwallner.quitzyn.model.SoberState
import com.jackwallner.quitzyn.model.SpendScale
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ports of the iOS `BugCatalogRegressionTests` for the 2026-11-20 catalog. */
class BugCatalogRegressionTest {
    private class MemoryFile(var text: String? = null) : StateFile {
        override fun read(): String? = text
        override fun write(text: String) { this.text = text }
        override fun keepUnreadable(text: String, stamp: Long) = Unit
    }

    private val clock = TestClock()
    private val store = SoberStore(MemoryFile(), clock, SoberContent.shared)
    private fun day(daysAgo: Long): LocalDate = clock.today().minusDays(daysAgo)
    private fun start(daysAgo: Long): Instant = day(daysAgo).atStartOfDay(clock.zone()).toInstant()
    private fun startJourney(daysAgo: Long) = store.persistSetup(start(daysAgo), 800, 8, 9, true)

    // B4: a start date edited far back and corrected leaves no phantom tree

    @Test fun b4_correctingAFarEarlierStartDateDropsThePhantomTreeAndKeepsCelebrations() {
        startJourney(19)
        store.refresh()
        store.processGrowth()

        // Mis-tap: about 400 days back. Home then counts a finished tree.
        store.changeStart(start(399))
        store.refresh()
        store.processGrowth()
        assertEquals("precondition: the phantom tree was grown", 1, store.state.garden.completedTreeStyles.size)

        // Corrected back to the real date.
        store.changeStart(start(19))
        store.refresh()
        assertTrue(store.state.garden.completedTreeStyles.isEmpty())
        store.processGrowth()
        // Day 30 is the next stage, and it still celebrates.
        clock.instant = clock.instant.plus(Duration.ofDays(10))
        store.refresh()
        assertEquals(30, store.days)
        assertEquals(GrowthEvent.NewStage(BonsaiStage.ADOLESCENT), store.processGrowth())
    }

    // B5: Delete log inside a closed run keeps the day counted

    @Test fun b5_deletingALogInsideAClosedRunKeepsTheDay() {
        startJourney(19)
        store.refresh()
        val logged = day(15)
        store.logCheckIn(logged, wasSober = true, mood = 4, note = "Walked instead")
        store.recordSlip(day(10))
        val before = store.lifetimeSoberDays

        store.deleteCheckIn(logged)

        assertEquals(before, store.lifetimeSoberDays)
        assertFalse(store.hasCheckedIn(logged))
        assertNotNull(store.checkIn(logged))
        assertNull(store.checkIn(logged)?.mood)
        assertNull(store.checkIn(logged)?.note)
    }

    /** Control: on the live run, today's log is removed outright so Home offers the check-in again. */
    @Test fun b5_deletingTodaysLogStillClearsIt() {
        startJourney(5)
        store.checkInToday()
        store.deleteCheckIn(store.today)
        assertFalse(store.hasCheckedIn(store.today))
        assertNull(store.checkIn(store.today))
    }

    // B6: a slip on a day no run covers leaves the tree alone

    @Test fun b6_aSlipOnAGapDayLeavesTheTreeAndCounterAlone() {
        // A run that a slip ended 25 days ago, then the live run's start moved
        // later in Settings, leaving days no run covers.
        startJourney(40)
        store.recordSlip(day(25))
        store.changeStart(start(19))
        val gapDay = day(22)
        assertEquals("precondition: no run covers the day", 0, store.streakDays(gapDay))
        store.checkInToday()
        val garden = store.state.garden
        assertTrue("precondition: the tree carries days over from the slip", garden.carryoverDays > 0)
        val counter = store.days

        store.recordSlip(gapDay)

        assertTrue(store.loggedSlip(gapDay))
        assertEquals(counter, store.days)
        assertEquals(garden.carryoverDays, store.state.garden.carryoverDays)
        assertEquals(garden.vitality, store.state.garden.vitality, 0.0)
        assertNotNull(store.state.garden.lastWateredAt)
    }

    // B9: craving hours stay in the zone they were logged in

    @Test fun b9_peakHoursDoNotMoveWithTheDeviceZone() {
        val home = clock.zone()
        for ((daysAgo, hour) in listOf(1L to 15, 2L to 15, 3L to 15, 4L to 15, 5L to 3, 6L to 3)) {
            val startedAt = day(daysAgo).atTime(hour, 10).atZone(home).toInstant()
            store.recordCraving(startedAt, 90, CravingOutcome.RODE_IT_OUT, 3, null)
        }
        val away = ZoneOffset.ofTotalSeconds(home.rules.getOffset(clock.now()).totalSeconds + 6 * 3600)

        val peak = CravingInsights.peakWindow(store.state.cravingFacts, away)
        assertEquals(13, peak?.startHour)
        assertEquals(4, peak?.count)
        val weekday = day(1).dayOfWeek.value % 7 + 1
        assertTrue(CravingInsights.hardestWeekday(
            List(4) { CravingEpisode(startedAt = day(1).atTime(23, 30).atZone(home).toInstant(), endedAt = clock.now(), timeZoneId = home.id) },
            away,
        )?.sundayBasedDay == weekday)
    }

    /** Upgrade: a craving saved before the zone was stored opens intact and reads in the device's zone. */
    @Test fun b9_aStoreFromBeforeTheZoneOpensWithItsCravingsIntact() {
        val startedAt = Instant.ofEpochSecond(1_790_000_000)
        val saved = SoberState(cravings = listOf(CravingEpisode(
            startedAt = startedAt, endedAt = startedAt.plusSeconds(95), outcome = CravingOutcome.RODE_IT_OUT,
            trigger = "Stress", secondsElapsed = 95, timeZoneId = "Asia/Tokyo",
        )))
        val json = JSONObject(SoberCodec.encode(saved))
        json.getJSONArray("cravings").getJSONObject(0).remove("timeZoneID")

        val episode = SoberCodec.decode(json.toString()).cravings.single()
        assertEquals(startedAt, episode.startedAt)
        assertEquals(95, episode.secondsElapsed)
        assertEquals("Stress", episode.trigger)
        assertNull(episode.timeZoneId)
        assertEquals(clock.zone(), episode.zone(clock.zone()))
        assertEquals("Asia/Tokyo", SoberCodec.decode(SoberCodec.encode(saved)).cravings.single().timeZoneId)
    }

    // B7: the craving clock counts time the timer missed

    @Test fun b7_cravingClockCountsTimeTheTimerMissed() {
        val startedAt = 1_000_000L
        assertEquals("one tick after a 20 s stall", 29, CravingEpisode.elapsedSeconds(shown = 9, startedAtMillis = startedAt, nowMillis = startedAt + 29_400))
        assertEquals(1, CravingEpisode.elapsedSeconds(shown = 0, startedAtMillis = startedAt, nowMillis = startedAt + 1_050))
        assertEquals("a clock set back never rewinds it", 40, CravingEpisode.elapsedSeconds(shown = 40, startedAtMillis = startedAt, nowMillis = startedAt - 5_000))
    }

    // B2: can price and cost per day reach real prices in every currency

    @Test fun b2_dollarAndEuroSteppersAreUnchanged() {
        for (code in listOf("USD", "EUR", "GBP", null)) {
            val scale = SpendScale(code)
            assertEquals(1.0..20.0, scale.canPriceRange)
            assertEquals(0.5, scale.canPriceStep, 0.0)
            assertEquals(6.0, scale.defaultCanPrice, 0.0)
            assertEquals(20_000, scale.dailyCostMaxCents)
            assertEquals(100, scale.dailyCostStepCents)
        }
    }

    /** A can costs roughly 50 to 150 in these currencies, and the old 1...20 stepper could not reach any of it. */
    @Test fun b2_localCanPricesFitTheStepper() {
        val typicalCan = mapOf("CZK" to 130.0, "SEK" to 55.0, "NOK" to 110.0, "DKK" to 45.0, "RUB" to 450.0, "UAH" to 200.0, "RON" to 25.0, "PLN" to 25.0)
        for ((code, price) in typicalCan) {
            val scale = SpendScale(code)
            assertTrue("$code $price", price in scale.canPriceRange)
            assertEquals("$code $price is not on the stepper's grid", price, scale.clampedCanPrice(price), 0.0)
        }
    }

    @Test fun b2_settingsReachesANormalDailyCostInYenAndWon() {
        assertTrue(SpendScale("JPY").dailyCostMaxCents >= 2_000 * 100)
        assertTrue(SpendScale("KRW").dailyCostMaxCents >= 20_000 * 100)
    }

    @Test fun b2_clampingKeepsAPriceInsideTheRange() {
        val czk = SpendScale("CZK")
        assertEquals(czk.canPriceRange.endInclusive, czk.clampedCanPrice(9_999.0), 0.0)
        assertEquals(czk.canPriceRange.start, czk.clampedCanPrice(0.0), 0.0)
        assertEquals(6.5, SpendScale("USD").clampedCanPrice(6.3), 0.0)
    }
}
