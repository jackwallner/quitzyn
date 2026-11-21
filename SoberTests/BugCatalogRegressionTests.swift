import Testing
import Foundation
import SwiftData
@testable import Sober

/// Regressions for the 2026-11-20 bug catalog
/// (`project-docs/audits/2026-11-20-bug-ux.html`).

@Suite("Bug catalog 2026-11-20")
@MainActor
struct BugCatalogRegressionTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: DailyCheckIn.self, SobrietyJourney.self, GardenState.self, UserSettings.self, CravingEpisode.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - B2 Spend steppers follow the device currency

    @Test func b2_dollarAndEuroSteppersAreUnchanged() {
        for code in ["USD", "EUR", "GBP", nil] {
            let scale = SpendScale(currencyCode: code)
            #expect(scale.canPriceRange == 1...20)
            #expect(scale.canPriceStep == 0.5)
            #expect(scale.defaultCanPrice == 6)
            #expect(scale.dailyCostMaxCents == 20000)
            #expect(scale.dailyCostStepCents == 100)
        }
    }

    /// A can costs roughly 50 to 150 in these currencies, and the old 1...20
    /// stepper could not reach any of it.
    @Test func b2_localCanPricesFitTheStepper() {
        let typicalCan: [String: Double] = ["CZK": 130, "SEK": 55, "NOK": 110, "DKK": 45, "RUB": 450, "UAH": 200, "RON": 25, "PLN": 25]
        for (code, price) in typicalCan {
            let scale = SpendScale(currencyCode: code)
            #expect(scale.canPriceRange.contains(price), "\(code) \(price)")
            #expect(scale.clampedCanPrice(price) == price, "\(code) \(price) is not on the stepper's grid")
        }
    }

    @Test func b2_settingsReachesANormalDailyCostInYenAndWon() {
        #expect(SpendScale(currencyCode: "JPY").dailyCostMaxCents >= 2000 * 100)
        #expect(SpendScale(currencyCode: "KRW").dailyCostMaxCents >= 20000 * 100)
    }

    @Test func b2_clampingKeepsAPriceInsideTheRange() {
        let czk = SpendScale(currencyCode: "CZK")
        #expect(czk.clampedCanPrice(9999) == czk.canPriceRange.upperBound)
        #expect(czk.clampedCanPrice(0) == czk.canPriceRange.lowerBound)
        #expect(SpendScale(currencyCode: "USD").clampedCanPrice(6.3) == 6.5)
    }

    // MARK: - B4 A start date edited far back and corrected leaves no phantom tree

    @Test func b4_correctingAFarEarlierStartDateDropsThePhantomTreeAndKeepsCelebrations() {
        let sobriety = SobrietyService(context: context)
        let garden = GardenService(context: context)
        sobriety.startJourney(at: DateHelpers.daysAgo(19))
        _ = garden.processGrowthEvents(days: sobriety.currentDayCount())

        // Mis-tap: about 400 days back. Home then counts a finished tree.
        sobriety.updateStartDate(DateHelpers.daysAgo(399))
        let wrongDays = sobriety.currentDayCount()
        garden.processCycleCompletions(days: wrongDays)
        _ = garden.processGrowthEvents(days: garden.treeDays(streakDays: wrongDays))
        #expect(garden.current().completedTreeStyles.count == 1, "precondition: the phantom tree was grown")

        // Corrected back to the real date.
        sobriety.updateStartDate(DateHelpers.daysAgo(19))
        let days = sobriety.currentDayCount()
        garden.processCycleCompletions(days: days)
        #expect(garden.current().completedTreeStyles.isEmpty)
        // Day 30 is the next stage, and it still celebrates.
        _ = garden.processGrowthEvents(days: garden.treeDays(streakDays: days))
        #expect(garden.processGrowthEvents(days: 30) == .newStage(.adolescent))
    }
}
