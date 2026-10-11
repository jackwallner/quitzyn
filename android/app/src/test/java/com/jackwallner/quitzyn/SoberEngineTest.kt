package com.jackwallner.quitzyn

import com.jackwallner.quitzyn.content.SoberContent
import com.jackwallner.quitzyn.data.SoberCodec
import com.jackwallner.quitzyn.model.AppClock
import com.jackwallner.quitzyn.model.CheckIn
import com.jackwallner.quitzyn.model.CravingEpisode
import com.jackwallner.quitzyn.model.CravingInsights
import com.jackwallner.quitzyn.model.CravingOutcome
import com.jackwallner.quitzyn.model.DayMark
import com.jackwallner.quitzyn.model.GardenGrowth
import com.jackwallner.quitzyn.model.GardenState
import com.jackwallner.quitzyn.model.JournalEntry
import com.jackwallner.quitzyn.model.JourneyDays
import com.jackwallner.quitzyn.model.SoberEngine
import com.jackwallner.quitzyn.model.SoberState
import com.jackwallner.quitzyn.model.TendedWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class TestClock(var instant: Instant = Instant.parse("2026-10-02T19:00:00Z"), val timeZone: ZoneId = ZoneId.of("America/Los_Angeles")) : AppClock {
    override fun now(): Instant = instant
    override fun zone(): ZoneId = timeZone
}

class SoberEngineTest {
    private val clock = TestClock()
    private fun day(daysAgo: Long): LocalDate = clock.today().minusDays(daysAgo)
    private fun journey(daysAgo: Long): SoberState = SoberEngine.startJourney(SoberState(), day(daysAgo).atStartOfDay(clock.zone()).toInstant(), clock)

    @Test fun counterIsOneBasedAndCalendarBased() {
        assertEquals(1, JourneyDays.current(journey(0), clock))
        assertEquals(28, JourneyDays.current(journey(27), clock))
        assertEquals(0, JourneyDays.current(SoberState(), clock))
    }

    @Test fun daylightSavingDoesNotChangeCalendarDayCounting() {
        val zone = ZoneId.of("America/Los_Angeles")
        val start = LocalDate.of(2026, 3, 7).atStartOfDay(zone).toInstant()
        val now = LocalDate.of(2026, 3, 9).atStartOfDay(zone).toInstant()
        assertEquals(3, JourneyDays.since(start, now, zone))
        assertEquals(47, java.time.Duration.between(start, now).toHours())
    }

    @Test fun futureStartIsClamped() {
        val state = SoberEngine.startJourney(SoberState(), clock.now().plusSeconds(86400), clock)
        assertEquals(clock.now(), JourneyDays.active(state)?.start)
    }

    @Test fun backfillNeverMarksAssumedDaysTended() {
        val state = SoberEngine.fillJourney(journey(6), day(1), clock)
        assertEquals(6, state.checkIns.size)
        assertTrue(state.checkIns.all { it.wasSober && !it.wasLogged })
        assertFalse(SoberEngine.hasCheckedIn(state, clock.today()))
    }

    @Test fun loggedDaysAreNeverDemotedByBackfill() {
        val logged = SoberEngine.checkIn(journey(4), day(2), mood = 4, note = "A good day")
        val filled = SoberEngine.fillJourney(logged, day(1), clock)
        val entry = filled.checkIns.first { it.day == day(2) }
        assertTrue(entry.wasLogged)
        assertEquals(4, entry.mood)
        assertEquals("A good day", entry.note)
    }

    @Test fun neverLoggedIsNotTreatedAsHavingDisappeared() {
        val state = SoberEngine.fillJourney(journey(200), day(1), clock)
        assertEquals(0, SoberEngine.daysSinceLastCheckIn(state, clock))
    }

    @Test fun returningBackfillPromotesAssumedDaysWithoutOverwritingSlips() {
        var state = SoberEngine.fillJourney(journey(6), day(1), clock)
        state = SoberEngine.checkIn(state, day(5))
        state = SoberEngine.checkIn(state, day(3), wasSober = false)
        state = SoberEngine.backfillSoberDays(state, clock.today())
        assertTrue(state.checkIns.first { it.day == day(2) }.wasLogged)
        assertFalse(state.checkIns.first { it.day == day(3) }.wasSober)
        assertTrue(SoberEngine.hasCheckedIn(state, clock.today()))
    }

    @Test fun backdatedSlipStopsTheOldRunOnTheSlipDay() {
        val state = SoberEngine.recordSlip(journey(26), day(10), clock)
        val old = state.journeys.first { it.end != null }
        val current = JourneyDays.active(state)!!
        assertEquals(day(10), old.end!!.atZone(clock.zone()).toLocalDate())
        assertEquals(day(9), current.start.atZone(clock.zone()).toLocalDate())
        assertTrue(old.end < current.start)
        assertEquals(10, JourneyDays.current(state, clock))
        assertEquals(17, JourneyDays.longest(state, clock))
    }

    @Test fun anOlderSlipDoesNotRewindTheLiveCounter() {
        var state = SoberEngine.recordSlip(journey(26), day(10), clock)
        state = SoberEngine.recordSlip(state, day(20), clock)
        assertEquals(10, JourneyDays.current(state, clock))
    }

    @Test fun repeatedChronologicalSlipsLeaveDistinctRuns() {
        var state = journey(40)
        for (daysAgo in listOf(30L, 20L, 5L)) state = SoberEngine.recordSlip(state, day(daysAgo), clock)
        val runs = state.journeys.sortedBy { it.start }
        runs.zipWithNext().forEach { (old, newer) -> assertTrue(old.end!! < newer.start) }
    }

    @Test fun resubmittingASlipDoesNotHalveTheGardenTwice() {
        val once = SoberEngine.recordSlip(journey(40), day(2), clock)
        val twice = SoberEngine.recordSlip(once, day(2), clock, mood = 2, note = "Corrected note")
        assertEquals(once.garden.carryoverDays, twice.garden.carryoverDays)
        assertEquals(once.journeys, twice.journeys)
        assertEquals("Corrected note", twice.checkIns.first { it.day == day(2) }.note)
    }

    @Test fun undoRestoresTodaysCounterAndExactTreeInheritance() {
        val initial = journey(27)
        val slipped = SoberEngine.recordSlip(initial, clock.today(), clock)
        assertEquals(1, JourneyDays.current(slipped, clock))
        assertEquals(14, slipped.garden.carryoverDays)
        assertTrue(SoberEngine.canUndoSlip(slipped, clock.today(), clock))
        val undone = SoberEngine.undoSlip(slipped, clock.today(), clock)
        assertEquals(28, JourneyDays.current(undone, clock))
        assertEquals(0, undone.garden.carryoverDays)
        assertFalse(SoberEngine.loggedSlip(undone, clock.today()))
    }

    @Test fun undoABackdatedSlipReopensTheOriginalRun() {
        val slipped = SoberEngine.recordSlip(journey(26), day(10), clock)
        val undone = SoberEngine.undoSlip(slipped, day(10), clock)
        assertEquals(27, JourneyDays.current(undone, clock))
        assertEquals(27, JourneyDays.longest(undone, clock))
    }

    @Test fun undoRestoresTheExactPreSlipCarryover() {
        val first = SoberEngine.recordSlip(journey(40), day(20), clock)
        val second = SoberEngine.recordSlip(first, clock.today(), clock)
        assertNotEquals(first.garden.carryoverDays, second.garden.carryoverDays)
        val restored = SoberEngine.undoSlip(second, clock.today(), clock)
        assertEquals(first.garden.carryoverDays, restored.garden.carryoverDays)
    }

    @Test fun anOldSlipCannotBeHalfUndone() {
        var state = SoberEngine.recordSlip(journey(40), day(20), clock)
        state = SoberEngine.recordSlip(state, day(5), clock)
        assertFalse(SoberEngine.canUndoSlip(state, day(20), clock))
        assertEquals(state, SoberEngine.undoSlip(state, day(20), clock))
        assertTrue(SoberEngine.loggedSlip(state, day(20)))
    }

    @Test fun aDeliberateResetKeepsHistoryAndCompletedTrees() {
        val previous = journey(40).copy(garden = GardenState(carryoverDays = 14, completedTreeStyles = listOf("traditional-bonsai")))
        val reset = SoberEngine.resetCounter(previous, clock)
        assertEquals(1, JourneyDays.current(reset, clock))
        assertEquals(0, reset.garden.carryoverDays)
        assertEquals(previous.garden.completedTreeStyles, reset.garden.completedTreeStyles)
        assertEquals(2, reset.journeys.size)
    }

    @Test fun postResetCyclesAddToThePermanentGrove() {
        val state = SoberState(garden = GardenState(completedTreeStyles = listOf("traditional-bonsai"), groveCountAtJourneyStart = 1))
        val completed = SoberEngine.completeCycles(state, 366)
        assertEquals(2, completed.garden.completedTreeStyles.size)
        assertEquals(completed, SoberEngine.completeCycles(completed, 366))
    }

    @Test fun aFreeUserCannotSelectAPremiumOrUnknownSpecies() {
        val ids = SoberContent.shared.speciesIds
        val state = SoberState()
        assertEquals(state, SoberEngine.selectSpecies(state, "maple-bonsai", ids, false))
        assertEquals(state, SoberEngine.selectSpecies(state, "not-a-species", ids, true))
        assertEquals("maple-bonsai", SoberEngine.selectSpecies(state, "maple-bonsai", ids, true).garden.speciesId)
    }

    @Test fun aSlipDoesNotKillTheGarden() {
        val state = SoberEngine.recordSlip(journey(30), clock.today(), clock)
        assertTrue(state.garden.vitality >= 0.3)
    }

    @Test fun theWeekDistinguishesAssumedAndTendedDays() {
        val facts = listOf(CheckIn(day(2), wasLogged = false), CheckIn(day(1), mood = 4), CheckIn(clock.today(), wasSober = false))
        val week = TendedWeek.days(clock.today(), facts)
        assertEquals(listOf(DayMark.ASSUMED, DayMark.TENDED, DayMark.SLIP), week.takeLast(3).map { it.mark })
        assertEquals(1, TendedWeek.tendedCount(week))
        assertEquals("mostly good", TendedWeek.moodSummary(week))
    }

    @Test fun skippedIntensityIsNotInventedAndAnsweredIntensityIsClamped() {
        val skipped = SoberEngine.addCraving(SoberState(), clock.now(), -2, CravingOutcome.UNRESOLVED, null, null, clock)
        assertEquals(0, skipped.cravings.first().intensity)
        assertEquals(0, skipped.cravings.first().secondsElapsed)
        val answered = SoberEngine.addCraving(SoberState(), clock.now(), 60, CravingOutcome.RODE_IT_OUT, 99, null, clock)
        assertEquals(5, answered.cravings.first().intensity)
    }

    @Test fun abandonedSessionsDoNotCountAsFailures() {
        val facts = listOf(CravingOutcome.RODE_IT_OUT, CravingOutcome.RODE_IT_OUT, CravingOutcome.GAVE_IN,
            CravingOutcome.UNRESOLVED, CravingOutcome.UNRESOLVED).map {
            CravingEpisode(startedAt = clock.now(), endedAt = clock.now(), outcome = it)
        }
        assertEquals(CravingInsights.Rate(2, 3), CravingInsights.rideOutRate(facts))
    }

    @Test fun medianAndOutcomeRateRespectTheirSampleFloors() {
        val two = listOf(60, 600).map { CravingEpisode(startedAt = clock.now(), endedAt = clock.now(), outcome = CravingOutcome.RODE_IT_OUT, secondsElapsed = it) }
        assertNull(CravingInsights.medianRideOutSeconds(two))
        assertNull(CravingInsights.rideOutRate(two))
        assertEquals(120, CravingInsights.medianRideOutSeconds(two + CravingEpisode(startedAt = clock.now(), endedAt = clock.now(), outcome = CravingOutcome.RODE_IT_OUT, secondsElapsed = 120)))
    }

    @Test fun aSingleClusterOfUrgesIsNotLabeledAHardestTime() {
        val facts = List(4) { CravingEpisode(startedAt = clock.now(), endedAt = clock.now()) }
        assertNull(CravingInsights.peakWindow(facts, clock.zone()))
    }

    @Test fun usableSessionsNotUnansweredRowsDriveTheUnlockLine() {
        val abandoned = List(5) { CravingEpisode(startedAt = clock.now(), endedAt = clock.now()) }
        assertEquals("4 more logged cravings and your patterns start filling in.", CravingInsights.nextUnlock(abandoned))
    }

    @Test fun allStoredFieldsSurviveRoundTrip() {
        var state = SoberEngine.fillJourney(journey(27), day(1), clock)
        state = SoberEngine.checkIn(state, clock.today(), mood = 4, note = "Private note")
        state = SoberEngine.recordSlip(state, day(5), clock)
        state = SoberEngine.addCraving(state, clock.now(), 180, CravingOutcome.RODE_IT_OUT, 4, "Stress", clock)
        state = SoberEngine.putJournalEntry(state, JournalEntry(createdAt = clock.now(), text = "A private reflection"), true)
        assertEquals(state, SoberCodec.decode(SoberCodec.encode(state)))
    }

    @Test fun corruptOrFutureDataIsRejectedRatherThanSilentlyDiscarded() {
        try { SoberCodec.decode("not-json"); fail("Corrupt data must be rejected") } catch (_: Exception) {}
        val encoded = JSONObject(SoberCodec.encode(SoberState())).put("schemaVersion", 2).toString()
        try { SoberCodec.decode(encoded); fail("Future data must be rejected") } catch (_: IllegalArgumentException) {}
    }

    @Test fun theFirstJournalEntryAndEditingOwnedEntriesAreFree() {
        val entry = JournalEntry(createdAt = clock.now(), text = "A thought")
        val saved = SoberEngine.putJournalEntry(SoberState(), entry, false)
        assertEquals(1, saved.journal.size)
        val second = JournalEntry(createdAt = clock.now(), text = "Another thought")
        assertEquals(saved, SoberEngine.putJournalEntry(saved, second, false))
        val edited = SoberEngine.putJournalEntry(saved, entry.copy(text = "Edited"), false)
        assertEquals("Edited", edited.journal.first().text)
        assertEquals(2, SoberEngine.putJournalEntry(saved, second, true).journal.size)
        assertTrue(SoberEngine.deleteJournalEntry(saved, entry.id).journal.isEmpty())
    }

    @Test fun exportedCountsAndGrowthMatchTheSwiftSource() {
        val resource = javaClass.getResourceAsStream("/quitzyn-parity.json")!!
        val parity = resource.bufferedReader().use { JSONObject(it.readText()) }
        val counts = parity.getJSONObject("counts")
        val content = SoberContent.shared
        assertEquals(counts.getInt("healthBenefits"), content.health.size)
        assertEquals(counts.getInt("achievements"), content.achievements.size)
        assertEquals(counts.getInt("journalPrompts"), content.prompts.size)
        assertEquals(counts.getInt("species"), content.species.size)
        for (index in 0 until parity.getJSONArray("growth").length()) {
            val row = parity.getJSONArray("growth").getJSONObject(index)
            val progress = GardenGrowth.cycle(row.getInt("days"))
            assertEquals(row.getInt("dayInCycle"), progress.dayInCycle)
            assertEquals(row.getInt("completed"), progress.completed)
            assertEquals(row.getInt("stage"), GardenGrowth.stage(row.getInt("days")).ordinal)
        }
        for (index in 0 until parity.getJSONArray("carryover").length()) {
            val row = parity.getJSONArray("carryover").getJSONObject(index)
            assertEquals(row.getInt("treeDays"), GardenGrowth.treeDays(row.getInt("days"), row.getInt("carryover")))
        }
        for (index in 0 until parity.getJSONArray("coach").length()) {
            val row = parity.getJSONArray("coach").getJSONObject(index)
            assertEquals(row.getString("line"), content.coach(row.getInt("elapsed"), row.getInt("target")))
        }
    }

    @Test fun theHealthTimelineMakesNoMedicalPromises() {
        val text = SoberContent.shared.health.joinToString(" ") { "${it.title} ${it.summary} ${it.detail}" }
        assertFalse(text.contains("full body recovery", ignoreCase = true))
        assertFalse(text.contains("restored", ignoreCase = true))
        assertFalse(text.contains("cleared from", ignoreCase = true))
        assertTrue(text.contains("cannot measure the nicotine in your body"))
        assertEquals(13, SoberContent.shared.health.size)
        assertEquals("heart-rate-steadies", SoberContent.shared.health.first().id)
    }

    @Test fun anOlderSlipEnteredLaterSplitsHistoryAndLeavesTheGardenAlone() {
        val newer = SoberEngine.recordSlip(journey(40), day(10), clock)
        val older = SoberEngine.recordSlip(newer, day(25), clock)
        assertEquals(newer.garden, older.garden)
        assertEquals(10, JourneyDays.current(older, clock))
        assertTrue(older.journeys.any { it.end?.atZone(clock.zone())?.toLocalDate() == day(25) && it.resetReason == "slip" })
        assertTrue(JourneyDays.longest(older, clock) < JourneyDays.longest(newer, clock))
    }

    @Test fun accidentalOpensAreNotLoggedOrCounted() {
        assertFalse(CravingEpisode.isWorthLogging(CravingOutcome.UNRESOLVED, 7))
        assertTrue(CravingEpisode.isWorthLogging(CravingOutcome.UNRESOLVED, 8))
        assertTrue(CravingEpisode.isWorthLogging(CravingOutcome.RODE_IT_OUT, 2))
        val start = clock.now().minusSeconds(60)
        val state = SoberState(cravings = listOf(
            CravingEpisode(startedAt = start, endedAt = start.plusSeconds(3), outcome = CravingOutcome.UNRESOLVED, secondsElapsed = 3),
            CravingEpisode(startedAt = start, endedAt = start.plusSeconds(90), outcome = CravingOutcome.RODE_IT_OUT, secondsElapsed = 90),
        ))
        assertEquals(1, state.cravingFacts.size)
    }

    @Test fun nicotineVocabularyComesFromTheSwiftForkPoint() {
        val words = SoberContent.shared.words
        assertEquals("nicotine", words.substance)
        assertEquals("pouches", words.habitGerund)
        assertEquals("nicotine-free", words.cleanDayAdjective)
        assertEquals(120, words.typicalUrgeSeconds)
        assertEquals("After a meal", words.triggers.first())
    }

    @Test fun promptOfDayUsesTheSameOneBasedDayOrdinal() {
        assertEquals("p2", SoberContent.shared.promptOfDay(LocalDate.of(2026, 1, 1)).id)
    }
}
