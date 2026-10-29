import SwiftUI
import WidgetKit

struct SoberEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// Day count recomputed from the snapshot's start date at `date`, so the
    /// widget advances with the calendar between app launches.
    let days: Int
}

/// The stored `currentStreakDays` is frozen at the last app launch. Derive the
/// live count from the start date so crossing midnight bumps the widget on its
/// own (matches `SobrietyService.daysSinceStart`).
private func liveDays(_ snap: WidgetSnapshot, asOf date: Date) -> Int {
    guard let start = snap.sobrietyStartDate else { return snap.currentStreakDays }
    // 1-based: the start day is Day 1 (matches `SobrietyService.daysSinceStart`).
    return max(0, DateHelpers.daysBetween(start, date)) + 1
}

struct SoberProvider: TimelineProvider {
    func placeholder(in context: Context) -> SoberEntry {
        SoberEntry(date: .now, snapshot: .empty, days: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (SoberEntry) -> Void) {
        let snap = WidgetSnapshotStore.load()
        completion(SoberEntry(date: .now, snapshot: snap, days: liveDays(snap, asOf: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SoberEntry>) -> Void) {
        let now = Date.now
        let snap = WidgetSnapshotStore.load()
        let entry = SoberEntry(date: now, snapshot: snap, days: liveDays(snap, asOf: now))
        // Refresh at the next local midnight so the day count rolls over even if
        // the app isn't opened; fall back to +1h if midnight can't be computed.
        let nextMidnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct SoberDayCounterWidget: Widget {
    let kind: String = "SoberDayCounter"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SoberProvider()) { entry in
            SoberDayCounterView(snapshot: entry.snapshot, days: entry.days)
                .containerBackground(Theme.brandGradient, for: .widget)
        }
        .configurationDisplayName("Quit Zyn Days")
        .description("How long you've been nicotine-free.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct SoberWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SoberDayCounterWidget()
    }
}
