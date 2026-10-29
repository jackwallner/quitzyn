import Foundation

/// Expresses a Bloom+ price in the user's own habit spend — "about a day and a
/// half of drinking" — which is the one anchor this app has that the App Store
/// cannot provide. Everywhere else a price appears it competes with other apps;
/// here it competes with the thing the user is trying to stop paying for.
///
/// Deliberately names no amount. The real localized price is always displayed
/// separately (Apple 3.1.2), and a figure written here would be a literal that
/// goes stale on the next ladder move.
enum HabitPriceComparison {
    /// Past this many habit-days the line stops flattering the price and starts
    /// drawing attention to the total, so it is suppressed instead.
    static let maxDays: Double = HabitVocabulary.priceComparisonMaxDays

    /// `price` and `costPerDay` have to be the same currency. Both come from the
    /// user's own storefront (StoreKit price, and a figure they typed into a
    /// slider labelled in their locale's currency), so they are.
    static func daysOfHabit(price: Double, costPerDay: Double) -> Double? {
        guard price > 0, costPerDay > 0 else { return nil }
        let days = price / costPerDay
        guard days <= maxDays else { return nil }
        return days
    }

    enum Span: Equatable {
        case underADay
        case aboutADay
        case aboutADayAndAHalf
        case aboutDays(Int)
        case aboutDaysAndAHalf(Int)
    }

    static func span(_ days: Double) -> Span {
        if days < 0.75 { return .underADay }
        if days < 1.25 { return .aboutADay }
        if days < 1.75 { return .aboutADayAndAHalf }
        let halves = (days * 2).rounded()
        let whole = Int(halves / 2)
        return halves.truncatingRemainder(dividingBy: 2) == 0
            ? .aboutDays(whole)
            : .aboutDaysAndAHalf(whole)
    }

}
