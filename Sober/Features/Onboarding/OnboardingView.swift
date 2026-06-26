import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var step: Int = 0
    @State private var startDate: Date = .now
    @State private var pouchesPerDay: Double = 8
    @State private var costPerCan: Double = 6
    @State private var pouchesPerCan: Int = 15
    @State private var reminderHour: Int = 9
    @State private var trialInFlight = false
    @State private var trialError: String?
    @State private var glowPulse = false
    @State private var didShowOnboardingTrial = false

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
                case 5: trialStep
                default: welcome
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.l)
            .foregroundStyle(.white)
        }
        .task {
            #if canImport(RevenueCat)
            if subscriptions.isConfigured, subscriptions.packages.isEmpty {
                await subscriptions.fetchProducts()
            }
            #endif
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

    /// Two inputs, not three sliders: the daily amount the user knows by heart,
    /// and one compact "can" card (price + count) that defines the unit. The old
    /// triple-slider scroll was the clunky part — folding the can's price and
    /// count into a single card keeps the math exact while reading as one step.
    private var spendStep: some View {
        VStack(spacing: Theme.Space.l) {
            Text("How much were you using?")
                .font(Theme.display())
                .multilineTextAlignment(.center)

            VStack(spacing: Theme.Space.s) {
                Text("\(Int(pouchesPerDay))")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("pouches a day")
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.85))
                Slider(value: $pouchesPerDay, in: 0...40, step: 1)
                    .tint(.white)
                    .padding(.horizontal, Theme.Space.s)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Space.l)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

            canCard

            savingsProjection

            Spacer(minLength: 0)

            primaryButton("Continue") { step = 3 }
        }
    }

    /// "Your usual can" — price stepper on the left, pouch count on the right.
    /// One card, two taps, no fiddly slider for a number people know precisely.
    private var canCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Your usual can")
                .font(Theme.subhead(weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price")
                        .font(Theme.caption())
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: Theme.Space.m) {
                        stepButton("minus") {
                            costPerCan = max(1, costPerCan - 0.5)
                        }
                        Text(formatCurrencyDecimal(costPerCan))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(minWidth: 56)
                        stepButton("plus") {
                            costPerCan = min(20, costPerCan + 0.5)
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pouches")
                        .font(Theme.caption())
                        .foregroundStyle(.white.opacity(0.75))
                    Picker("Pouches per can", selection: $pouchesPerCan) {
                        ForEach([15, 20, 24], id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .colorScheme(.dark)
                    .frame(width: 132)
                }
            }
        }
        .padding(Theme.Space.l)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.body(weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
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
                primaryButton("I commit to getting better") { commit(committed: true) }
                Button { commit(committed: false) } label: {
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

    /// Trial step — shown right after the commitment while motivation (and the
    /// just-entered spend numbers) peak. Doubling down here, where the user has
    /// actively pledged, converts far better than a cold paywall later. Only
    /// reached when a free trial is actually on the table; otherwise we skip
    /// straight to finishing onboarding.
    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .scaleEffect(glowPulse ? 1.08 : 0.85)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowPulse)
                Image(systemName: "gift.fill")
                    .font(.system(size: 64))
            }
            Text(trialEligible ? "Make your commitment count" : "You're all set")
                .font(Theme.display())
                .multilineTextAlignment(.center)
            Text(trialEligible
                 ? "You just committed. Lock in every tool that keeps you nicotine-free — free for your whole trial."
                 : "Your garden is planted. Let's begin.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, Theme.Space.m)

            if trialEligible, let price = trialPriceLabel {
                SavingsAnchorCard(
                    yearlySavings: projectedYearlySavings,
                    priceLabel: price,
                    priceCaption: "after your free trial",
                    onBrand: true
                )
                .padding(.horizontal, Theme.Space.xs)
            }

            if let trialError {
                Text(trialError)
                    .font(Theme.caption())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: Theme.Space.s) {
                if trialEligible {
                    Button(action: startOnboardingTrial) {
                        ZStack {
                            Text(trialCTATitle)
                                .font(Theme.body(weight: .bold))
                                .foregroundStyle(Theme.brandPrimary)
                                .opacity(trialInFlight ? 0 : 1)
                            if trialInFlight { ProgressView().tint(Theme.brandPrimary) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.l)
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .disabled(trialInFlight)

                    Button { finishOnboarding() } label: {
                        Text("Maybe later")
                            .font(Theme.subhead(weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .underline()
                            .padding(.vertical, 6)
                    }
                    .disabled(trialInFlight)

                    Text("No charge now. Cancel anytime before the trial ends.")
                        .font(Theme.caption())
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Space.m)
                } else {
                    primaryButton("Start growing") { finishOnboarding() }
                }
            }
        }
        .onAppear { glowPulse = true }
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

    // MARK: - Trial step plumbing

    private var projectedYearlySavings: Int { Int((derivedCostPerDay * 365).rounded()) }

    private var trialEligible: Bool {
        #if canImport(RevenueCat)
        return !subscriptions.isProSubscriber && subscriptions.hasTrialOfferAvailable
        #else
        return false
        #endif
    }

    /// Clean plan price ("$29.99 / year" -> "$29.99") for the savings anchor.
    private var trialPriceLabel: String? {
        #if canImport(RevenueCat)
        guard let raw = subscriptions.directTrialPackage?.soberPriceLabel else { return nil }
        return raw.components(separatedBy: " /").first?.trimmingCharacters(in: .whitespaces)
        #else
        return nil
        #endif
    }

    private var trialCTATitle: String {
        #if canImport(RevenueCat)
        if let label = subscriptions.directTrialPackage?.soberIntroOfferLabel {
            return "Start my \(label)"
        }
        #endif
        return "Start my free trial"
    }

    /// Commit button: persist setup, then double down with the trial step when
    /// one is available. Falls through to finishing when it isn't (no RC key,
    /// already Pro, or trial already consumed).
    private func commit(committed: Bool) {
        persistSetup(committed: committed)
        if trialEligible {
            didShowOnboardingTrial = true
            withAnimation { step = 5 }
        } else {
            finishOnboarding()
        }
    }

    private func startOnboardingTrial() {
        #if canImport(RevenueCat)
        guard let package = subscriptions.directTrialPackage else { finishOnboarding(); return }
        trialError = nil
        trialInFlight = true
        Task { @MainActor in
            defer { trialInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased, .pending:
                    finishOnboarding()
                case .cancelled:
                    trialError = "Trial start cancelled. Tap again to begin."
                }
            } catch {
                trialError = "Couldn't start your trial. Please try again."
            }
        }
        #else
        finishOnboarding()
        #endif
    }

    /// Save everything except the onboarding-complete flag, so the trial step can
    /// still render before RootView swaps to the main app. Notifications are
    /// requested here too (the commit is a natural permission moment).
    private func persistSetup(committed: Bool) {
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int((derivedCostPerDay * 100).rounded())
        settings.pouchesPerDay = Int(pouchesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.madeCommitment = committed

        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour, committed: committed)
        }
    }

    /// Flip onboarding complete (swaps RootView to the main app) and queue the
    /// lighter post-onboarding popup. That popup auto-skips when the user already
    /// started the trial here (they're Pro), so they never see it twice.
    private func finishOnboarding() {
        let settings = SettingsService(context: context).current()
        settings.hasCompletedOnboarding = true
        try? context.save()

        // Only queue the immediate Home popup when we *didn't* already pitch the
        // trial in onboarding — otherwise the user would see the same sheet twice
        // within a second. When the onboarding step ran, the "quick popup later"
        // is the cooldown-gated Health nudge instead.
        if !didShowOnboardingTrial {
            AppGroup.defaults.set(true, forKey: AppGroup.postOnboardingPaywallKey)
        }
        WidgetSnapshotPump.push(context: context)
    }
}
