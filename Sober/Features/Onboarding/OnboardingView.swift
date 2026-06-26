import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step: Int = 0
    @State private var startDate: Date = .now
    @State private var pouchesPerDay: Double = 8
    @State private var costPerCan: Double = 6
    @State private var pouchesPerCan: Int = 15
    @State private var reminderHour: Int = 9

    /// Cost is *derived* from real-world purchase units (a can/tin has a fixed
    /// pouch count at a fixed price) so the dollars and pouches the user sees can
    /// never disagree — unlike two free sliders. Per-pouch price = $/can ÷
    /// pouches/can; daily spend = pouches/day × per-pouch price.
    private var derivedCostPerDay: Double {
        guard pouchesPerCan > 0 else { return 0 }
        return pouchesPerDay * costPerCan / Double(pouchesPerCan)
    }

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            VStack {
                switch step {
                case 0: welcome
                case 1: startDateStep
                case 2: spendStep
                case 3: reminderStep
                case 4: commitStep
                default: welcome
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.l)
            .foregroundStyle(.white)
        }
    }

    private var welcome: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 96))
            Text("Quit Zyn").font(Theme.display(52, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Track your nicotine-free days, grow your garden, watch your health return.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            primaryButton("Get Started") { step = 1 }
        }
    }

    private var startDateStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("When did your nicotine-free journey begin?")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.white)
            Spacer()
            primaryButton("Continue") { step = 2 }
        }
    }

    private var spendStep: some View {
        VStack(spacing: Theme.Space.m) {
            Text("How much were you using?")
                .font(Theme.display())
                .multilineTextAlignment(.center)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.l) {
                    VStack(spacing: Theme.Space.xs) {
                        Text("\(Int(pouchesPerDay)) pouches / day")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Slider(value: $pouchesPerDay, in: 0...40, step: 1)
                            .tint(.white)
                    }

                    VStack(spacing: Theme.Space.xs) {
                        Text("Cost per can")
                            .font(Theme.body())
                            .foregroundStyle(.white.opacity(0.85))
                        Text(formatCurrencyDecimal(costPerCan))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Slider(value: $costPerCan, in: 1...15, step: 0.5)
                            .tint(.white)
                    }

                    VStack(spacing: Theme.Space.xs) {
                        Text("Pouches per can")
                            .font(Theme.body())
                            .foregroundStyle(.white.opacity(0.85))
                        Picker("Pouches per can", selection: $pouchesPerCan) {
                            ForEach([15, 20, 24], id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(.dark)
                    }

                    savingsProjection
                }
                .padding(.vertical, Theme.Space.s)
            }

            primaryButton("Continue") { step = 3 }
        }
    }

    @ViewBuilder
    private var savingsProjection: some View {
        let pouches = Int(pouchesPerDay)
        let dailyCost = derivedCostPerDay
        if dailyCost > 0 || pouches > 0 {
            let yearlyDollars = Int((dailyCost * 365).rounded())
            let yearlyPouches = pouches * 365
            VStack(spacing: 4) {
                Text("That's about \(formatCurrencyDecimal(dailyCost)) / day")
                    .font(Theme.subhead(weight: .semibold))
                    .foregroundStyle(.white)
                Text("In a year, that's")
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.75))
                if yearlyDollars > 0 {
                    Text(formatCurrency(yearlyDollars))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }
                if pouches > 0 {
                    Text(yearlyDollars > 0
                         ? "plus \(yearlyPouches.formatted()) pouches you won't put in. That's the nicotine your body never has to process."
                         : "\(yearlyPouches.formatted()) pouches you won't put in — nicotine your body never has to process.")
                        .font(Theme.caption())
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.m)
            .padding(.horizontal, Theme.Space.m)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func formatCurrency(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    /// Currency with cents only when needed (e.g. "$6" vs "$6.50" vs "$0.40"),
    /// so the per-can price and derived daily spend read cleanly.
    private func formatCurrencyDecimal(_ amount: Double) -> String {
        let isWhole = amount == amount.rounded()
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = isWhole ? 0 : 2
        f.maximumFractionDigits = isWhole ? 0 : 2
        return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    private var reminderStep: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Text("Daily reminder time")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Picker("Hour", selection: $reminderHour) {
                ForEach(0..<24) { h in
                    Text(formatHour(h)).font(Theme.body()).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .colorScheme(.dark)
            Spacer()
            primaryButton("Continue") { step = 4 }
        }
    }

    /// Final step: a deliberate commitment. Recovery starts with a decision —
    /// asking the user to actively pledge (rather than tap a neutral "Done")
    /// gives them a moment to lock in before the journey begins. A quieter
    /// "Not now" path lets reluctant users continue without forcing a pledge
    /// they don't mean — the answer is also a signal we use to tune the tone
    /// of nudges throughout the app.
    private var commitStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .opacity(0.92)
            Text("Make it official")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Text("Recovery starts with a decision. This is yours, for today and the days that follow.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            VStack(spacing: Theme.Space.s) {
                primaryButton("I commit to getting better") { complete(committed: true) }
                Button { complete(committed: false) } label: {
                    Text("Not now")
                        .font(Theme.subhead(weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .underline()
                        .padding(.vertical, 6)
                }
                Text("Either way is fine. You can revisit this any time in Settings.")
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Space.m)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            Text(title)
                .font(Theme.body(weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
        }
        .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
    }

    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h
        let d = Calendar.current.date(from: comps) ?? .now
        return f.string(from: d)
    }

    private func complete(committed: Bool = true) {
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int((derivedCostPerDay * 100).rounded())
        settings.pouchesPerDay = Int(pouchesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.hasCompletedOnboarding = true
        settings.madeCommitment = committed

        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()

        // Queue the one-time post-onboarding paywall: motivation (and the
        // just-entered spend numbers that personalize the hero) peak right now.
        AppGroup.defaults.set(true, forKey: AppGroup.postOnboardingPaywallKey)

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour, committed: committed)
        }
        WidgetSnapshotPump.push(context: context)
    }
}
