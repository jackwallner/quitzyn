import Testing
import Foundation
import SwiftData
@testable import Sober

#if canImport(RevenueCat)
@Suite("Trial package preference")
struct TrialPackagePreferenceTests {
    @Test func yearlyWinsWhenBothTrialsExist() {
        #expect(SubscriptionService.preferredTrialKind(from: [.monthly, .yearly]) == .yearly)
    }

    @Test func monthlyIsTheFallback() {
        #expect(SubscriptionService.preferredTrialKind(from: [.monthly]) == .monthly)
    }

    @Test func unknownPackageIsStillUsable() {
        #expect(SubscriptionService.preferredTrialKind(from: [.other]) == .other)
    }

    @Test func emptyPackagesStayUnavailable() {
        #expect(SubscriptionService.preferredTrialKind(from: []) == nil)
    }

    @Test func yearlyWinsRegardlessOfPackageOrder() {
        #expect(SubscriptionService.preferredTrialKind(from: [.other, .monthly, .yearly]) == .yearly)
    }
}
#endif

@Suite("Garden stage progression")
struct GardenServiceTests {
    @Test func seedAtZero() {
        #expect(GardenService.stage(forDays: 0) == .seed)
    }

    @Test func seedlingAtWeek() {
        #expect(GardenService.stage(forDays: 7) == .seedling)
    }

    @Test func adolescentAtMonth() {
        #expect(GardenService.stage(forDays: 30) == .adolescent)
    }

    @Test func legendaryAtYear() {
        #expect(GardenService.stage(forDays: 365) == .legendary)
    }

}

@Suite("Garden year cycles")
struct GardenCycleTests {
    @Test func firstYearHasNoCompletedTrees() {
        let c = GardenService.cycleProgress(forDays: 365)
        #expect(c.completed == 0)
        #expect(c.dayInCycle == 365)
    }

    @Test func dayAfterAYearStartsFreshSapling() {
        let c = GardenService.cycleProgress(forDays: 366)
        #expect(c.completed == 1)
        #expect(c.dayInCycle == 1)
    }

    @Test func everyYearBoundaryCountsOneTree() {
        for years in 1...10 {
            let endOfYear = GardenService.cycleProgress(forDays: years * 365)
            #expect(endOfYear.completed == years - 1)
            #expect(endOfYear.dayInCycle == 365)

            let nextDay = GardenService.cycleProgress(forDays: years * 365 + 1)
            #expect(nextDay.completed == years)
            #expect(nextDay.dayInCycle == 1)
        }
    }

    @Test func stageRestartsEachCycle() {
        // Day 400 = day 35 of year two → adolescent, not stuck at legendary.
        #expect(GardenService.stage(forDays: 400) == .adolescent)
        #expect(GardenService.stage(forDays: 365 * 2) == .legendary)
    }
}

@Suite("Garden growth events")
struct GardenGrowthEventTests {
    @Test func stageAdvanceWithinCycle() {
        #expect(GardenService.growthEvent(previousDays: 6, currentDays: 7) == .newStage(.seedling))
    }

    @Test func noEventWithoutChange() {
        #expect(GardenService.growthEvent(previousDays: 10, currentDays: 10) == nil)
    }

    @Test func crossingYearBoundaryCompletesTree() {
        #expect(GardenService.growthEvent(previousDays: 364, currentDays: 366)
            == .treeCompleted(total: 1))
    }

    @Test func completionOutranksStageAdvance() {
        // 360 → 370 crosses the boundary AND would be a stage change;
        // the grove handoff is the story that explains the reset tree.
        #expect(GardenService.growthEvent(previousDays: 360, currentDays: 370)
            == .treeCompleted(total: 1))
    }

    @Test func freshWatermarkNeverAmbushes() {
        // First-ever check after a back-dated 40-year onboarding: no celebration.
        #expect(GardenService.growthEvent(previousDays: 0, currentDays: 365 * 40) == nil)
    }

    @Test func fortyYearBoundaryCounts() {
        #expect(GardenService.growthEvent(previousDays: 365 * 39, currentDays: 365 * 39 + 1)
            == .treeCompleted(total: 39))
    }

    @Test func stageAdvanceDeepIntoYearForty() {
        #expect(GardenService.growthEvent(previousDays: 365 * 39 + 29, currentDays: 365 * 39 + 30)
            == .newStage(.adolescent))
    }
}

@Suite("Garden grove across resets")
@MainActor
struct GardenGroveResetTests {
    @Test func completionsAfterResetStillJoinGrove() throws {
        let container = try ModelContainer(
            for: GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let svc = GardenService(context: container.mainContext)

        // Two years sober → two trees in the grove.
        svc.processCycleCompletions(days: 365 * 2 + 1)
        #expect(svc.current().completedTreeStyles.count == 2)

        // Slip → reset. The grove is a permanent record and survives.
        svc.resetForNewJourney()
        #expect(svc.current().completedTreeStyles.count == 2)

        // The new journey's first completed year must still join the grove
        // (journey cycle count restarts; the baseline keeps it from being
        // absorbed by the pre-reset trees).
        svc.processCycleCompletions(days: 366)
        #expect(svc.current().completedTreeStyles.count == 3)
    }

    @Test func backdatedOnboardingBackfillsWholeGrove() throws {
        let container = try ModelContainer(
            for: GardenState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let svc = GardenService(context: container.mainContext)

        // 40 years sober at first launch → 39 completed trees, year 40 running.
        svc.processCycleCompletions(days: 365 * 40)
        #expect(svc.current().completedTreeStyles.count == 39)
    }
}

@Suite("Health benefit catalog")
struct HealthBenefitCatalogTests {
    @Test func heartRateSteadiesUnlocksAtTwoHours() {
        let unlocked = HealthBenefitCatalog.unlocked(hoursSober: 2)
        #expect(unlocked.contains { $0.id == "heart-rate-steadies" })
    }

    @Test func nothingUnlockedAtZero() {
        #expect(HealthBenefitCatalog.unlocked(hoursSober: 0).isEmpty)
    }

    @Test func nextBenefitProgresses() {
        let next = HealthBenefitCatalog.next(after: 0)
        #expect(next?.id == "heart-rate-steadies")
    }
}

@Suite("Sobriety day counting")
struct SobrietyServiceTests {
    @Test func startDayIsDayOne() {
        // 1-based: the moment you start, you're on Day 1.
        let now = Date()
        #expect(SobrietyService.daysSinceStart(now, asOf: now) == 1)
    }

    @Test func eighthDayAfterAWeek() {
        // Start day is Day 1, so seven calendar days later is Day 8.
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        #expect(SobrietyService.daysSinceStart(weekAgo, asOf: now) == 8)
    }
}

@Suite("Habit price comparison")
struct HabitPriceComparisonTests {
    @Test func defaultPouchUserGetsTheYearlyComparison() {
        // The onboarding defaults: 8 pouches a day from a $6, 15-pouch can is
        // $3.20 a day, so a $34.99 year is about 11 days of pouches.
        #expect(HabitPriceComparison.phrase(price: 34.99, costPerDay: 3.2) == "about 11 days of pouches")
    }

    @Test func heavyUserGetsAShorterComparison() {
        #expect(HabitPriceComparison.phrase(price: 34.99, costPerDay: 9) == "about 4 days of pouches")
    }

    @Test func lightSpendersGetNoComparison() {
        // $34.99 at $1/day is 35 habit-days, past the point where the
        // comparison flatters the price, so it is suppressed entirely.
        #expect(HabitPriceComparison.phrase(price: 34.99, costPerDay: 1) == nil)
    }

    @Test func missingSpendDataProducesNothing() {
        #expect(HabitPriceComparison.phrase(price: 34.99, costPerDay: 0) == nil)
        #expect(HabitPriceComparison.daysOfHabit(price: 0, costPerDay: 3) == nil)
    }

    @Test func exactlyAtTheCeilingStillRenders() {
        #expect(HabitPriceComparison.phrase(price: 42, costPerDay: 2) == "about 21 days of pouches")
    }

    @Test func halfDaysAreSpelledOut() {
        #expect(HabitPriceComparison.dayCount(0.5) == "less than a day")
        #expect(HabitPriceComparison.dayCount(1.5) == "about a day and a half")
        #expect(HabitPriceComparison.dayCount(2.4) == "about 2 and a half days")
    }
}
