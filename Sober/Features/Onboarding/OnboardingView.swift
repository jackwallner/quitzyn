import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var step: Int = 0
    #if DEBUG
    /// `-onboardingStep N` jumps straight to a step. The start-date picker
    /// wedges the accessibility bridge, so this is the only way to inspect the
    /// trial screen on a headless simulator.
    private static var launchStep: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-onboardingStep"),
              index + 1 < args.count else { return nil }
        return Int(args[index + 1])
    }
    #endif
    @State private var startDate: Date = .now
    @State private var pouchesPerDay: Double = 8
    @State private var costPerCan: Double = 6
    @State private var pouchesPerCan: Int = 15
    @State private var reminderHour: Int = 9
    @State private var trialInFlight = false
    @State private var trialResolutionInFlight = false
    @State private var trialResolutionError: String?
    @State private var trialError: String?
    @State private var restoreInFlight = false
    @State private var showPaywallFallback = false
    @State private var didShowOnboardingTrial = false
    @State private var madeCommitment = false
    /// False once the store confirms this Apple ID has already used its intro
    /// offer. The offer step still runs; it just sells the plan instead of a
    /// trial, and never says the word "free".
    @State private var offerIncludesTrial = true
    @State private var showSkipTrialConfirm = false

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
                case 3: trialStep
                case 4: reminderStep
                case 5: commitStep
                default: welcome
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.l)
            .foregroundStyle(Color.white)
        }
        .sheet(isPresented: $showPaywallFallback, onDismiss: { finishOfferStep() }) {
            PaywallView(impressionId: "quitzyn_onboarding_trial_fallback")
        }
        .task {
            ConversionDiagnostics.record(.onboardingReached)
            #if canImport(RevenueCat)
            if subscriptions.isConfigured, subscriptions.packages.isEmpty {
                await subscriptions.fetchProducts()
            }
            #endif
            #if DEBUG
            if let launchStep = Self.launchStep {
                #if canImport(RevenueCat)
                offerIncludesTrial = subscriptions.directTrialPackage != nil
                #endif
                step = launchStep
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
            bottomBar(primaryTitle: "Get Started") { withAnimation { step = 1 } }
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
            bottomBar(primaryTitle: "Continue") { withAnimation { step = 2 } }
        }
    }

    /// Two inputs, not three sliders: the daily amount the user knows by heart,
    /// and one compact "can" card (price + count) that defines the unit. The old
    /// triple-slider scroll was the clunky part — folding the can's price and
    /// count into a single card keeps the math exact while reading as one step.
    ///
    /// The cards scroll rather than compress: the dock below reserves the offer
    /// step's disclosure height on every step, which leaves less room here than
    /// three cards need on a small phone or with a resolution error showing.
    private var spendStep: some View {
        VStack(spacing: Theme.Space.l) {
            ScrollView {
                spendCards
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)

            bottomBar(
                primaryTitle: trialResolutionInFlight ? "Checking trial availability…" : "Continue",
                busy: trialResolutionInFlight,
                above: { resolutionError }
            ) { resolveTrialAndContinue() }
        }
    }

    private var spendCards: some View {
        VStack(spacing: Theme.Space.l) {
            Text("How much were you using?")
                .font(Theme.display())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

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
                        .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private var resolutionError: some View {
        if let trialResolutionError {
            VStack(spacing: Theme.Space.s) {
                Text(trialResolutionError)
                    .font(Theme.caption(weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.68))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Continue free") {
                    ConversionDiagnostics.record(.freeVersionChosen)
                    finishOfferStep()
                }
                .font(Theme.subhead(weight: .semibold))
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Offer step (ported from Sober 2026-10-06)

    /// Sober's offer step, carried over whole: the trial is pitched straight
    /// after the spend step, while the numbers the user just entered are on
    /// screen, and the reminder and pledge steps follow it. Same layout and copy
    /// structure as Sober so the two forks can be compared on audience alone.
    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer(minLength: Theme.Space.s)
            Image(systemName: "sparkles")
                .font(.system(size: 64, weight: .semibold))
            VStack(spacing: Theme.Space.s) {
                Text(trialHeadline)
                    .font(Theme.display(42, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trialSubhead)
                    .font(Theme.body())
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Theme.Space.m) {
                trialBenefit(icon: "tree.fill", text: "Grow and switch every bonsai species")
                trialBenefit(icon: "heart.text.square.fill", text: "Follow 13 sourced nicotine-recovery milestones")
                trialBenefit(icon: "chart.line.uptrend.xyaxis", text: trialSavingsText)
                trialBenefit(icon: "book.closed.fill", text: "Journal privately through the hard days")
            }
            .padding(Theme.Space.m)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: Theme.Space.s)
            bottomBar(
                primaryTitle: trialCTATitle,
                busy: trialInFlight,
                showLegalFooter: true,
                above: { trialAboveButton },
                below: { trialRenewalDisclosure }
            ) { startOnboardingTrial() }
        }
        .animation(nil, value: trialInFlight)
        .animation(nil, value: trialError)
        // Cancel role sits on "stay", not on "skip": an alert dismissed by
        // gesture resolves to the cancel action, and that must not be the path
        // that silently gives up the trial.
        .alert("Keep the free version?", isPresented: $showSkipTrialConfirm) {
            Button("Get started") {
                ConversionDiagnostics.record(.freeVersionChosen)
                finishOfferStep()
            }
            Button(offerIncludesTrial ? "Keep my free trial" : "Go back", role: .cancel) {}
        } message: {
            Text("You'll keep the day counter, the calendar, craving mode, and your tree. Your year-ahead projection, the full health timeline, the journal, and the other species stay locked.")
        }
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            // An Ask to Buy approval lands here after the purchase call returned.
            if isPro { finishOfferStep() }
        }
        .onAppear {
            didShowOnboardingTrial = true
            ConversionDiagnostics.record(.trialOfferReached)
            #if canImport(RevenueCat)
            subscriptions.trackPaywallImpression(
                id: offerIncludesTrial
                    ? "quitzyn_onboarding_trial_v2"
                    : "quitzyn_onboarding_offer_no_trial",
                package: subscriptions.directOfferPackage,
                oncePerSession: true
            )
            #endif
            // Start the passive-nudge cooldown at this pitch, so Home does not
            // re-pitch the trial seconds after the user declined it here.
            TrialNudgeGate.markShown()
        }
    }

    /// The objection at this moment is "am I about to be charged", not "what do
    /// I get"; the benefit card already answers the second one.
    private var trialSubhead: String {
        guard offerIncludesTrial else {
            return "Every tool that keeps the streak visible, unlocked today."
        }
        guard let trialDays else {
            return "Every tool that keeps the streak visible. Nothing is charged today."
        }
        return "Every tool that keeps the streak visible. Nothing is charged for \(trialDays) days."
    }

    /// A real date beats a duration: "free until 13 Oct" is checkable in a way
    /// that "7 days free" is not. `TrialLifecycle` schedules the reminder this
    /// promises once the trial starts.
    private var trialChargeDateLine: String? {
        guard offerIncludesTrial,
              let trialDays,
              let end = Calendar.current.date(byAdding: .day, value: trialDays, to: .now) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "MMMd", options: 0, locale: .current
        )
        return "Free until \(formatter.string(from: end)). We'll remind you before it ends."
    }

    /// Notification permission is asked when the trial starts, not here, so the
    /// promise above is made before the user has had the chance to decline it.
    private var trialReminderCaveat: String? {
        trialChargeDateLine == nil ? nil : "Reminder needs notifications turned on."
    }

    private func trialBenefit(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: icon)
                .font(Theme.body(weight: .semibold))
                .frame(width: 24)
            Text(text)
                .font(Theme.body())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var trialSavingsText: String {
        let yearlyDollars = Int((derivedCostPerDay * 365).rounded())
        guard yearlyDollars > 0 else { return "Project the year ahead, not just the days behind" }
        return "Project the \(formatCurrency(yearlyDollars)) you'd keep over the next year"
    }

    /// Quiet opt-out directly above the trial button. Same weight as the other
    /// small links so it stays the alternative, not a second CTA.
    private var skipTrialLink: some View {
        Button { showSkipTrialConfirm = true } label: {
            Text("Get started")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 2)
        }
        .disabled(trialInFlight)
    }

    /// Dock order, top to bottom: the habit argument, the price, the reminder,
    /// then Get started, then the trial CTA.
    private var trialAboveButton: some View {
        VStack(spacing: Theme.Space.s) {
            if let habitLine = habitComparisonText {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(habitLine)
                        .font(Theme.subhead(weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
            }

            // The billed amount, the most conspicuous price on the screen
            // (3.1.2(c)). Nil until the package loads: never a placeholder price.
            if let priceHeadline = trialPriceHeadline {
                Text(priceHeadline)
                    .font(Theme.body(weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            trialStatusSlot
            skipTrialLink
        }
    }

    /// Reminder copy and a purchase error share one slot, sized to whichever is
    /// taller, so an error never shoves the hero up and back down again.
    @ViewBuilder
    private var trialStatusSlot: some View {
        if let reassurance = trialReassuranceText {
            ZStack(alignment: .top) {
                reassuranceLine(reassurance).hidden()
                errorLine(Self.trialFailureCopy).hidden()
                if let trialError {
                    errorLine(trialError)
                } else {
                    reassuranceLine(reassurance)
                }
            }
        } else if let trialError {
            errorLine(trialError)
        }
    }

    private static let trialFailureCopy = "Couldn't start your trial. Please try again."

    private var trialReassuranceText: String? {
        guard let reassurance = trialChargeDateLine else { return nil }
        return trialReminderCaveat.map { "\(reassurance) \($0)" } ?? reassurance
    }

    private func reassuranceLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(Theme.caption())
        .foregroundStyle(.white.opacity(0.72))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func errorLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption(weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.68))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    /// Auto-renew terms sit under the button, between the CTA and the legal
    /// footer, so the price above is not swallowed by the boilerplate.
    @ViewBuilder
    private var trialRenewalDisclosure: some View {
        if let renewal = trialRenewalText {
            disclosureLine(renewal)
        }
    }

    private func disclosureLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption())
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Space.s)
    }

    // MARK: - Reminder and pledge (after the offer)

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
            bottomBar(primaryTitle: "Continue") { withAnimation { step = 5 } }
        }
    }

    /// Final step: a deliberate commitment. Recovery starts with a decision, so
    /// the user actively pledges rather than tapping a neutral "Done". A quieter
    /// "Not now" path lets reluctant users finish without a pledge they don't
    /// mean; the answer also tunes the tone of nudges throughout the app.
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
                        Button { completeOnboarding(committed: false) } label: {
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
            ) { completeOnboarding(committed: true) }
        }
    }

    // MARK: - Dock

    /// The tallest thing any step puts under its primary button: the offer
    /// step's auto-renew disclosure and legal footer. Laid out hidden on every
    /// step so the button itself never moves between taps. Built from the real
    /// views and string, so it cannot drift when the copy or type size changes.
    private var subDockReserve: some View {
        VStack(spacing: Theme.Space.s) {
            disclosureLine(SubscriptionService.autoRenewDisclosure)
            legalFooter
        }
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Every step docks its primary button on the same pixel: variable content
    /// goes above it, and `subDockReserve` holds the space below it. Purchase
    /// taps are not wrapped in `withAnimation`, which used to animate the error
    /// line in and out and slide the whole screen.
    private func bottomBar<Above: View, Below: View>(
        primaryTitle: String,
        busy: Bool = false,
        showLegalFooter: Bool = false,
        @ViewBuilder above: () -> Above = { EmptyView() },
        @ViewBuilder below: () -> Below = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Theme.Space.s) {
            above()
            Button(action: action) {
                ZStack {
                    Text(primaryTitle)
                        .font(Theme.body(weight: .semibold))
                        .opacity(busy ? 0 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if busy { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
            }
            .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
            .disabled(busy)

            ZStack(alignment: .top) {
                subDockReserve
                VStack(spacing: Theme.Space.s) {
                    below()
                    if showLegalFooter { legalFooter }
                }
            }
        }
    }

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

    // MARK: - Offer plumbing

    /// Persist the setup, then wait for a real RevenueCat eligibility decision.
    /// A loading or network failure is never treated as a consumed trial.
    private func resolveTrialAndContinue() {
        guard !trialResolutionInFlight else { return }
        persistSetup()
        trialResolutionError = nil
        trialResolutionInFlight = true
        Task { @MainActor in
            defer { trialResolutionInFlight = false }
            #if canImport(RevenueCat)
            guard subscriptions.isConfigured else {
                trialResolutionError = "Bloom+ plans are temporarily unavailable. You can retry or continue free."
                return
            }
            var resolution = await subscriptions.resolveOnboardingTrial()
            if resolution == .failed || resolution == .unavailable {
                // Give the network a beat: retrying in the same tick against a
                // flaky connection just reproduces the failure.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                resolution = await subscriptions.resolveOnboardingTrial()
            }
            switch resolution {
            case .eligible:
                offerIncludesTrial = true
                withAnimation { step = 3 }
            case .ineligible:
                // Mostly "already used the trial on this Apple ID", not "has
                // nothing to buy": show the same step without trial language.
                // Only a real subscriber, or a store with no plan, skips it.
                if subscriptions.isProSubscriber || subscriptions.directOfferPackage == nil {
                    finishOfferStep()
                } else {
                    offerIncludesTrial = false
                    withAnimation { step = 3 }
                }
            case .unavailable, .failed:
                trialResolutionError = "Bloom+ plans are temporarily unavailable. You can retry or continue free."
            }
            #else
            finishOfferStep()
            #endif
        }
    }

    private func startOnboardingTrial() {
        #if canImport(RevenueCat)
        // Products failing to load falls back to the full paywall rather than a
        // dead button; dismissing that paywall moves on.
        guard let package = subscriptions.directOfferPackage else {
            showPaywallFallback = true
            return
        }
        ConversionDiagnostics.record(.trialCTATapped)
        trialError = nil
        trialInFlight = true
        Task { @MainActor in
            defer { trialInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    ConversionDiagnostics.record(.purchaseSucceeded)
                    finishOfferStep()
                case .pending:
                    ConversionDiagnostics.record(.purchasePending)
                    // Not moving on: leaving here made an Ask to Buy look like a
                    // trial that never started. The isProSubscriber change moves
                    // on once approved, and the free option stays available.
                    trialError = SubscriptionService.pendingApprovalMessage
                case .cancelled:
                    // Backing out of Apple's sheet returns the same screen.
                    ConversionDiagnostics.record(.purchaseCancelled)
                }
            } catch {
                ConversionDiagnostics.record(.purchaseFailed)
                trialError = Self.trialFailureCopy
            }
        }
        #else
        finishOfferStep()
        #endif
    }

    /// Restore from the offer step's legal footer. An active entitlement moves
    /// on (the user is already a member).
    private func restorePurchasesFromOnboarding() {
        #if canImport(RevenueCat)
        guard !restoreInFlight else { return }
        restoreInFlight = true
        Task { @MainActor in
            defer { restoreInFlight = false }
            trialError = nil
            await subscriptions.restorePurchases()
            if subscriptions.isProSubscriber {
                finishOfferStep()
            } else {
                trialError = subscriptions.lastError
                    ?? "No active Bloom+ purchase was found for this Apple ID."
            }
        }
        #endif
    }

    /// Save everything except the onboarding-complete flag. Runs more than once
    /// (before the offer and again at the pledge), so the journey is started
    /// once and only moved after that: a second `startJourney` would close the
    /// first as a zero-length journey.
    private func persistSetup() {
        let settings = SettingsService(context: context).current()
        settings.costPerDayCents = Int((derivedCostPerDay * 100).rounded())
        settings.pouchesPerDay = Int(pouchesPerDay)
        settings.dailyReminderHour = reminderHour
        settings.madeCommitment = madeCommitment

        let sobriety = SobrietyService(context: context)
        if sobriety.activeJourney() == nil {
            _ = sobriety.startJourney(at: min(startDate, .now))
        } else {
            sobriety.updateStartDate(startDate)
        }
        _ = GardenService(context: context).current()
        context.saveOrReport()
    }

    /// Every exit from the offer step lands here: purchased, skipped, restored,
    /// or the store never answered. It advances to the reminder step; the
    /// pledge is what completes onboarding.
    private func finishOfferStep() {
        guard step < 4 else { return }
        persistSetup()
        withAnimation { step = 4 }
    }

    /// Flip onboarding complete (swaps RootView to the main app), then ask for
    /// notifications. The permission prompt comes after the offer so it never
    /// interrupts the paid decision.
    private func completeOnboarding(committed: Bool) {
        madeCommitment = committed
        persistSetup()
        let settings = SettingsService(context: context).current()
        guard !settings.hasCompletedOnboarding else { return }
        ConversionDiagnostics.record(.onboardingCompleted)
        settings.hasCompletedOnboarding = true
        context.saveOrReport()

        let hour = reminderHour
        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: hour, committed: committed)
        }

        // Only queue the Home popup when the offer step never ran, or the user
        // would see the same pitch twice within a second.
        if !didShowOnboardingTrial {
            AppGroup.defaults.set(true, forKey: AppGroup.postOnboardingPaywallKey)
        }
        WidgetSnapshotPump.push(context: context)
    }

    /// The closing argument, in the units the user set one screen ago: what the
    /// plan costs measured against what they were spending on pouches. Never
    /// quotes an amount; the price line right below it carries the real one.
    private var habitComparisonText: String? {
        #if canImport(RevenueCat)
        guard let package = subscriptions.directOfferPackage else { return nil }
        return package.soberHabitComparisonSentence(
            costPerDayCents: Int((derivedCostPerDay * 100).rounded())
        )
        #else
        return nil
        #endif
    }

    private var trialPriceHeadline: String? {
        #if canImport(RevenueCat)
        subscriptions.directTrialPriceHeadline
        #else
        nil
        #endif
    }

    private var trialRenewalText: String? {
        #if canImport(RevenueCat)
        subscriptions.directTrialRenewalDisclosure
        #else
        nil
        #endif
    }

    private var trialCTATitle: String {
        guard offerIncludesTrial else { return "Unlock Bloom+" }
        guard let trialDays else { return "Start my free trial" }
        return "Start my \(trialDays)-day free trial"
    }

    /// Nil until the store says how long the trial is. A literal fallback would
    /// advertise an offer that no longer exists the moment App Store Connect
    /// changes the trial length, so the copy degrades to a length-free line.
    private var trialDays: Int? {
        #if canImport(RevenueCat)
        subscriptions.trialOfferDayCount
        #else
        nil
        #endif
    }

    private var trialHeadline: String {
        guard offerIncludesTrial else { return "Unlock Bloom+" }
        guard let trialDays else { return "Bloom+, free to try" }
        return "\(trialDays) days of Bloom+ free"
    }
}
