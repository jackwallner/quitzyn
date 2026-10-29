#if os(iOS)
import SwiftUI
import WidgetKit

struct SoberDayCounterView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let snapshot: WidgetSnapshot
    let days: Int
    let familyOverride: WidgetFamily?

    init(snapshot: WidgetSnapshot, days: Int, familyOverride: WidgetFamily? = nil) {
        self.snapshot = snapshot
        self.days = days
        self.familyOverride = familyOverride
    }

    private var family: WidgetFamily { familyOverride ?? widgetFamily }

    /// The tree follows the garden's day count (streak plus slip carryover);
    /// the number printed beside it stays the honest streak. Deriving the stage
    /// from `days` drew a day-one sapling in the widget while Home showed the
    /// tree the slip had just promised the user they had kept.
    private var treeDays: Int { snapshot.treeDays(streakDays: days) }
    private var stage: BonsaiStage { GardenService.stage(forDays: treeDays) }
    /// Past the first year, the bare in-cycle stage reads like a bug next to a
    /// big day count ("14600 days · Seedling"), prefix the year for context,
    /// matching the garden's stage badge.
    private var stageTitle: String {
        let completed = GardenService.cycleProgress(forDays: treeDays).completed
        return completed > 0 ? String(localized: "Year \(completed + 1) · \(stage.title)") : stage.title
    }
    private var dayInCycle: Int { GardenService.cycleProgress(forDays: treeDays).dayInCycle }
    private var bonsaiStyle: BonsaiStyle {
        switch snapshot.bonsaiStyleID {
        case "cascade-bonsai", "cascade": return .cascade
        case "windswept-bonsai", "windswept": return .windswept
        case "sakura-bonsai", "sakura": return .sakura
        case "maple-bonsai", "maple": return .maple
        case "pine-bonsai", "pine": return .pine
        default: return .traditional
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            // Long streaks reach 4-5 digits (a year-3 user is past 1,000 days;
            // 40 years is ~14,600), scale the number down rather than truncate.
            VStack(spacing: 0) {
                Text("\(days)")
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
                Text(DateHelpers.dayCountLabel(days)).font(.caption2)
            }
            .accessibilityLabel(Text("\(days) days nicotine-free"))
        case .accessoryRectangular:
            HStack {
                Image(systemName: "leaf.fill")
                Text("\(days) days nicotine-free")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(days) days nicotine-free"))
        case .accessoryInline:
            Text("\(days) days nicotine-free")
        case .systemMedium:
            HStack(spacing: 12) {
                BonsaiView(day: dayInCycle, style: bonsaiStyle, vitality: snapshot.gardenVitality)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(days)")
                        .font(Theme.bigNumber(44))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                    Text(DateHelpers.nicotineFreeDayLabel(days))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(stageTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 2)
                    if let start = snapshot.sobrietyStartDate {
                        Text("Since \(DateHelpers.mediumDate(start))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            // systemSmall: let the tree fill and bottom-anchor so it owns the
            // tile, and float the count in a top scrim band, the upper sky is
            // the sparsest region, so the number never collides with the
            // trunk/pot the way a bottom overlay did.
            BonsaiView(day: dayInCycle, style: bonsaiStyle, vitality: snapshot.gardenVitality, fill: true)
                .overlay(alignment: .top) {
                    VStack(spacing: -1) {
                        Text("\(days)")
                            .font(Theme.bigNumber(34))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 8)
                            .foregroundStyle(.white)
                        Text(DateHelpers.nicotineFreeDayLabel(days))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.28), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(days) days nicotine-free"))
        }
    }
}
#endif
