package com.jackwallner.quitzyn

import com.jackwallner.quitzyn.content.SoberContent
import com.jackwallner.quitzyn.data.SoberStore
import com.jackwallner.quitzyn.data.StateFile
import com.jackwallner.quitzyn.model.BonsaiStage
import com.jackwallner.quitzyn.model.GrowthEvent
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
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
}
