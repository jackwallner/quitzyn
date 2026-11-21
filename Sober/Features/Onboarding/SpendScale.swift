import Foundation

/// Sizes the spend steppers to the device currency. A can of pouches costs
/// about 6 dollars or euros, but about 120 koruna, 60 kronor or 600 yen, and
/// steppers built for dollars capped those users at a fifth of a real price.
struct SpendScale: Equatable {
    /// Local units that buy about what one US dollar buys, rounded to a
    /// 1, 2, 5 step so the stepper lands on round prices. Only the order of
    /// magnitude matters, so rate drift does not need updates.
    let unit: Double

    init(currencyCode: String?) {
        unit = Self.units[currencyCode?.uppercased() ?? ""] ?? 1
    }

    static var current: SpendScale {
        SpendScale(currencyCode: Locale.current.currency?.identifier)
    }

    // MARK: Onboarding can price

    var canPriceRange: ClosedRange<Double> { unit...(20 * unit) }
    var canPriceStep: Double { 0.5 * unit }
    var defaultCanPrice: Double { 6 * unit }

    /// A price snapped to the stepper's grid and kept inside its range.
    func clampedCanPrice(_ price: Double) -> Double {
        let snapped = (price / canPriceStep).rounded() * canPriceStep
        return min(canPriceRange.upperBound, max(canPriceRange.lowerBound, snapped))
    }

    // MARK: Settings cost per day, in hundredths of the currency

    var dailyCostMaxCents: Int { 20000 * Int(unit) }
    var dailyCostStepCents: Int { 100 * Int(unit) }

    private static let units: [String: Double] = [
        "BGN": 2, "GEL": 2, "AZN": 2,
        "PLN": 5, "RON": 5, "BRL": 5, "ILS": 5, "AED": 5, "SAR": 5, "QAR": 5,
        "MYR": 5, "PEN": 5, "TND": 5,
        "SEK": 10, "NOK": 10, "DKK": 10, "CNY": 10, "HKD": 10, "MAD": 10,
        "CZK": 20, "MXN": 20, "ZAR": 20,
        "UAH": 50, "TRY": 50, "THB": 50, "TWD": 50, "PHP": 50, "EGP": 50,
        "RUB": 100, "JPY": 100, "INR": 100, "ISK": 100, "RSD": 100, "KES": 100,
        "MKD": 50, "BYN": 5, "KZT": 500, "HUF": 500, "PKR": 200, "LKR": 200,
        "KRW": 1000, "CLP": 1000, "NGN": 1000, "ARS": 1000, "COP": 5000,
        "IDR": 10000, "VND": 20000,
    ]
}
