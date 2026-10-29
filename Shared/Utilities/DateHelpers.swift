import Foundation

enum DateHelpers {
    static func startOfDay(_ date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func daysAgo(_ days: Int, from date: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: startOfDay(date))
            ?? startOfDay(date)
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let dayA = cal.startOfDay(for: a)
        let dayB = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: dayA, to: dayB).day ?? 0
    }

    static func hoursBetween(_ a: Date, _ b: Date) -> Double {
        b.timeIntervalSince(a) / 3600.0
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    static func dayOfYear(_ date: Date = .now) -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    /// These labels sit beside a separate large day count. Keep the count in
    /// the localized phrase so String Catalog can select the language's plural
    /// form, then remove that formatted prefix before drawing the caption.
    static func dayCountLabel(_ days: Int) -> String {
        labelWithoutCount(String(localized: "\(days) days label"), count: days)
    }

    static func nicotineFreeDayLabel(_ days: Int) -> String {
        labelWithoutCount(String(localized: "\(days) days nicotine-free label"), count: days)
    }

    private static func labelWithoutCount(_ label: String, count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.locale = .current
        formatter.usesGroupingSeparator = false
        let countText = formatter.string(from: NSNumber(value: count)) ?? String(count)
        guard label.hasPrefix(countText) else { return label }
        return label.dropFirst(countText.count).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let mediumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    static func mediumDate(_ date: Date) -> String { mediumFormatter.string(from: date) }
    static func dayOfWeek(_ date: Date) -> String { dayOfWeekFormatter.string(from: date) }
}
