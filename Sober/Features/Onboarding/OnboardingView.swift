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
    @State private var restoreInFlight = false
    @State private var showPaywallFallback = false
    @State private var didShowOnboardingTrial = false
    @State private var madeCommitment = false

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
            .foregroundStyle(Color.white)
        }
        .sheet(isPresented: $showPaywallFallback, onDismiss: { finishOnboarding() }) {
            PaywallView(impressionId: "sober_onboarding_trial_fallback")
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
            bottomBar(primaryTitle: "Get Started") { step = 1 }
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
            bottomBar(primaryTitle: "Continue") { step = 2 }
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

            bottomBar(primaryTitle: "Continue") { step = 3 }
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
                         : "\(yearlyPouches.formatted()) pouches you won't put in. That's nicotine your body never has to process.")
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
            bottomBar(primaryTitle: "Continue") { step = 4 }
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
            bottomBar(
                primaryTitle: "I commit to getting better",
                above: {
                    VStack(spacing: Theme.Space.s) {
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
            ) { commit(committed: true) }
        }
    }

    /// Trial step — shown right after the commitment while motivation (and the
    /// just-entered spend numbers) peak. Styled as the next onboarding step
    /// (same moss chrome, type scale, and CTA slot as steps 0-4), not a
    /// paywall: short pitch + three benefit bullets, soft "Get Started" free
    /// exit above the primary, and the Apple 3.1.2 disclosure adjacent to the
    /// button. Only reached when a free trial is actually on the table;
    /// otherwise we skip straight to finishing onboarding.
    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Image(systemName: trialEligible ? "gift.fill" : "checkmark.circle.fill")
                .font(.system(size: 72))
                .opacity(0.92)
            Text(trialEligible ? "Make your commitment count" : "You're all set")
                .font(Theme.display())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.m)
            Text(trialEligible
                 ? "You just committed. Try every tool that keeps you nicotine-free, free for \(trialDays) days."
                 : "Your garden is planted. Let's begin.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.m)

            if trialEligible {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    trialBullet(icon: "heart.text.square.fill", text: "Full health timeline with 13 nicotine-recovery milestones")
                    trialBullet(icon: "book.closed.fill", text: "Daily journal prompts for the hard days")
                    trialBullet(icon: "dollarsign.circle.fill", text: savingsBulletText)
                }
                .padding(.horizontal, Theme.Space.m)
                .padding(.top, Theme.Space.s)
            }

            Spacer(minLength: Theme.Space.s)

            if trialEligible {
                bottomBar(
                    primaryTitle: trialCTATitle,
                    busy: trialInFlight,
                    showLegalFooter: true,
                    above: { trialAboveButton }
                ) { startOnboardingTrial() }
            } else {
                bottomBar(primaryTitle: "Start growing") { finishOnboarding() }
            }
        }
        .onAppear {
            #if canImport(RevenueCat)
            // The trial-first onboarding step is a paywall surface, so measure it
            // like the others (sober_bloom_tab / sober_trial_sheet) so
            // view->trial-start conversion for the new step shows up in RevenueCat.
            if trialEligible {
                subscriptions.trackPaywallImpression(id: "sober_onboarding_trial", oncePerSession: true)
                // Start the passive-nudge cooldown at this pitch. Without it the
                // gate is empty on first run and the Home passive nudge could
                // re-pitch TrialOfferSheet ~6s after the user just declined here.
                TrialNudgeGate.markShown()
            }
            #endif
        }
    }

    private func trialBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(Theme.body(weight: .semibold))
                .frame(width: 24)
                .opacity(0.92)
            Text(text)
                .font(Theme.body())
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// One small savings mention inside a benefit bullet (the timeline hero and
    /// savings card read too paywall-ish for an onboarding step).
    private var savingsBulletText: String {
        let dollars = Int((derivedCostPerDay * 365).rounded())
        if dollars > 0 {
            return "Money and pouches avoided, on pace for \(formatCurrency(dollars)) a year"
        }
        return "Money and pouches avoided, tracked automatically"
    }

    /// Trial-only content that sits ABOVE the primary CTA (absorbed by the
    /// Spacer so it never shifts the button): soft free exit, billing
    /// disclosure, error.
    @ViewBuilder
    private var trialAboveButton: some View {
        VStack(spacing: Theme.Space.s) {
            // Soft free exit sits ABOVE the primary so the trial button lands in
            // the exact spot the user has been tapping Continue. Rev A: labeled
            // "Get Started" (StatScout soft-exit label), visually secondary.
            Button { finishOnboarding() } label: {
                Text("Get Started")
                    .font(Theme.subhead(weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .underline()
                    .padding(.vertical, 6)
            }
            .disabled(trialInFlight)

            // No disclosure until the package (and its real price) loads, never
            // a placeholder price (Apple 3.1.2).
            if let disclosure = trialDisclosureText {
                Text(disclosure)
                    .font(Theme.caption())
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.m)
            }

            if let trialError {
                Text(trialError)
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.68))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Shared bottom CTA bar rendered on EVERY step so the primary button's
    /// frame is pixel-identical across the whole flow (Rev A zero-shift bar):
    /// variable content goes ABOVE the button, and a fixed-height legal-footer
    /// slot below it is rendered on every step (real Terms/Privacy/Restore on
    /// the trial step, the exact same view invisible elsewhere) so the
    /// distance from the button to the screen bottom never changes.
    private func bottomBar<Above: View>(
        primaryTitle: String,
        busy: Bool = false,
        showLegalFooter: Bool = false,
        @ViewBuilder above: () -> Above = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Theme.Space.s) {
            above()
            Button(action: { withAnimation { action() } }) {
                ZStack {
                    Text(primaryTitle)
                        .font(Theme.body(weight: .semibold))
                        .opacity(busy ? 0 : 1)
                    if busy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
            }
            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            .disabled(busy)

            legalFooter
                .opacity(showLegalFooter ? 1 : 0)
                .allowsHitTesting(showLegalFooter)
                .accessibilityHidden(!showLegalFooter)
        }
    }

    /// Terms / Privacy / Restore. Rendered on every onboarding step (invisible
    /// off the trial step) so its height reserves the same space under the CTA.
    private var legalFooter: some View {
        HStack(spacing: 12) {
            Button { restorePurchasesFromOnboarding() } label: {
                Text(restoreInFlight ? "Restoring…" : "Restore")
                    .underline()
            }
            .disabled(restoreInFlight)
            Text("·")
            Link("Terms of Use", destination: PaywallLinks.standardEULA)
            Text("·")
            Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
        }
        .font(Theme.caption())
        .foregroundStyle(.white.opacity(0.75))
        .tint(.white)
    }

    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "h a"
        var comps = DateComponents(); comps.hour = h
        let d = Calendar.current.date(from: comps) ?? .now
        return f.string(from: d)
    }

    // MARK: - Trial step plumbing

    private var trialEligible: Bool {
        #if canImport(RevenueCat)
        return !subscriptions.isProSubscriber && subscriptions.hasTrialOfferAvailable
        #else
        return false
        #endif
    }

    /// Apple 3.1.2 disclosure adjacent to the primary CTA: trial length, real
    /// loaded price, auto-renew + cancel path. Nil until the package loads.
    private var trialDisclosureText: String? {
        #if canImport(RevenueCat)
        return subscriptions.directTrialCTADisclosureText
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

    /// Trial length in days, parsed from the offer label ("7-day free trial").
    private var trialDays: Int {
        #if canImport(RevenueCat)
        if let label = subscriptions.directTrialPackage?.soberIntroOfferLabel {
            let digits = String(label.drop { !$0.isNumber }.prefix { $0.isNumber })
            if let n = Int(digits) { return n }
        }
        #endif
        return 7
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
        // Products failing to load falls back to the full paywall rather than a
        // dead button; dismissing that paywall finishes onboarding.
        guard let package = subscriptions.directTrialPackage else {
            showPaywallFallback = true
            return
        }
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

    /// Restore from the trial step's legal footer. Success (an active
    /// entitlement) finishes onboarding (the user is already Pro).
    private func restorePurchasesFromOnboarding() {
        #if canImport(RevenueCat)
        guard !restoreInFlight else { return }
        restoreInFlight = true
        Task { @MainActor in
            defer { restoreInFlight = false }
            await subscriptions.restorePurchases()
            if subscriptions.isProSubscriber { finishOnboarding() }
        }
        #endif
    }

    /// Save everything except the onboarding-complete flag, so the trial step can
    /// still render before RootView swaps to the main app. Notifications are
    /// requested after the trial step so the permission prompt doesn't interrupt
    /// the paywall flow.
    private func persistSetup(committed: Bool) {
        madeCommitment = committed
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int((derivedCostPerDay * 100).rounded())
        settings.pouchesPerDay = Int(pouchesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.madeCommitment = committed

        _ = SobrietyService(context: context).startJourney(at: min(startDate, .now))
        _ = GardenService(context: context).current()
        try? context.save()
    }

    /// Flip onboarding complete (swaps RootView to the main app) and queue the
    /// lighter post-onboarding popup. That popup auto-skips when the user already
    /// started the trial here (they're Pro), so they never see it twice.
    private func finishOnboarding() {
        let settings = SettingsService(context: context).current()
        settings.hasCompletedOnboarding = true
        try? context.save()

        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: reminderHour, committed: madeCommitment)
        }

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
