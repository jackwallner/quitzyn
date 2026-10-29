import Foundation

/// Deterministic "today's growth" phrasing keyed off the current day in the
/// bonsai's annual cycle. The bonsai renderer is a continuous function of day,
/// so something does change every day — this surfaces it in copy.
enum DailyGrowth {
    private static let phrases: [String] = [
        String(localized: "Since yesterday, a new leaf unfurled."),
        String(localized: "Since yesterday, the trunk gained a little girth."),
        String(localized: "Since yesterday, a fresh shoot pushed out."),
        String(localized: "Since yesterday, the canopy filled in a little."),
        String(localized: "Since yesterday, the bark hardened another shade."),
        String(localized: "Since yesterday, a tiny bud appeared."),
        String(localized: "Since yesterday, the roots spread a little further."),
        String(localized: "Since yesterday, the silhouette sharpened."),
        String(localized: "Since yesterday, the moss crept a little further."),
        String(localized: "Since yesterday, the needles deepened in color."),
        String(localized: "Since yesterday, a branch tip lengthened."),
        String(localized: "Since yesterday, the crown stretched higher."),
    ]

    static func note(forDayInCycle day: Int) -> String {
        guard day > 0 else { return String(localized: "Since yesterday, the seed is settling in.") }
        if day >= 365 { return String(localized: "Since yesterday, the tree is complete and the next cycle begins.") }
        let idx = abs(day) % phrases.count
        return phrases[idx]
    }
}
