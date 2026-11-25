import SwiftData
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var step: Int = 0
    @State private var paneGeometry = PaneGeometry()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    @State private var costPerCan: Double = SpendScale.current.defaultCanPrice
    @State private var pouchesPerCan: Int = 15
    @State private var reminderHour: Int = 9
    @State private var trialInFlight = false
    @State private var trialResolutionInFlight = false
    @State private var trialResolutionError: String?
    @State private var trialError: String?
    /// An Ask to Buy waiting on approval: a calm line, not an error.
    @State private var trialPendingApproval = false
    @State private var restoreInFlight = false
    @State private var showPaywallFallback = false
    @State private var didShowOnboardingTrial = false
    @State private var madeCommitment = false

    /// Cost is *derived* from real-world purchase units (a can/tin has a fixed
    /// pouch count at a fixed price) so the dollars and pouches the user sees can
    /// never disagree — unlike two free sliders. Per-pouch price = $/can ÷
    /// pouches/can; daily spend = pouches/day × per-pouch price.
    private let spendScale = SpendScale.current

    private var derivedCostPerDay: Double {
        guard pouchesPerCan > 0 else { return 0 }
        return pouchesPerDay * costPerCan / Double(pouchesPerCan)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.brandGradient.ignoresSafeArea()
            if let split {
                gardenPreview
                    .frame(width: split.primaryWidth)
                    .frame(maxHeight: .infinity)
            }
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
            .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
            // Unfolded, the steps keep to the pane right of the fold.
            .frame(maxWidth: split?.secondaryWidth ?? .infinity, maxHeight: .infinity)
            .padding(.leading, split?.secondaryX ?? 0)
        }
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .sheet(isPresented: $showPaywallFallback, onDismiss: { completeOnboarding() }) {
            PaywallView(impressionId: "quitzyn_onboarding_trial_fallback")
        }
        .task {
            ConversionDiagnostics.record(.onboardingReached)
            restoreSavedSetup()
            #if canImport(RevenueCat)
            if subscriptions.isConfigured, subscriptions.packages.isEmpty {
                await subscriptions.fetchProducts()
            }
            #endif
            #if DEBUG
            if let launchStep = Self.launchStep {
                step = launchStep
            }
            #endif
        }
    }

    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// The pane left of the fold shows where the steps lead: a grown tree.
    private var gardenPreview: some View {
        VStack(spacing: Theme.Space.m) {
            GardenSceneView(
                days: 120,
                vitality: 1.0,
                activeBonsaiStyleID: GardenItemCatalog.freeSpeciesID,
                isPro: false,
                showsChrome: false
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            Text("Every nicotine-free day grows your tree.")
                .font(Theme.body(weight: .semibold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Space.l)
    }

    private var welcome: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 96))
            Text(AppBranding.displayName).font(Theme.display(52, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Track your nicotine-free days, grow your garden, watch your health return.")
                .multilineTextAlignment(.center)
                .font(Theme.body())
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            bottomBar(primaryTitle: String(localized: "Get Started")) { withAnimation { step = 1 } }
        }
    }

    private var startDateStep: some View {
        VStack(spacing: Theme.Space.l) {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    Text("When did your nicotine-free journey begin?")
                        .font(Theme.display())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    DatePicker("", selection: $startDate, in: ...Date.now, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .tint(.white)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            bottomBar(primaryTitle: String(localized: "Continue")) { withAnimation { step = 2 } }
        }
    }

    /// Two inputs, not three sliders: the daily amount the user knows by heart,
    /// and one compact "can" card (price + count) that defines the unit. The old
    /// triple-slider scroll was the clunky part — folding the can's price and
    /// count into a single card keeps the math exact while reading as one step.
    ///
    /// The cards scroll rather than compress: the dock below reserves the trial
    /// step's disclosure height on every step, which leaves less room here than
    /// three cards need on a small phone.
    private var spendStep: some View {
        VStack(spacing: Theme.Space.l) {
            ScrollView {
                spendCards
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)

            bottomBar(primaryTitle: String(localized: "Continue")) { withAnimation { step = 3 } }
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
                    .foregroundStyle(Theme.onGradientText)
                Slider(value: $pouchesPerDay, in: 0...40, step: 1)
                    .tint(.white)
                    .padding(.horizontal, Theme.Space.s)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Space.l)
            .background(Theme.onGradientPanel, in: RoundedRectangle(cornerRadius: 18))

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
                        .foregroundStyle(Theme.onGradientText)
                    HStack(spacing: Theme.Space.m) {
                        stepButton("minus") {
                            costPerCan = spendScale.clampedCanPrice(costPerCan - spendScale.canPriceStep)
                        }
                        Text(formatCurrencyDecimal(costPerCan))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(minWidth: 56)
                        stepButton("plus") {
                            costPerCan = spendScale.clampedCanPrice(costPerCan + spendScale.canPriceStep)
                        }
                    }
                }
                // Room goes to the price before the spacer: "120 CZK" wrapped
                // when the two split it evenly.
                .layoutPriority(1)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pouches")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.onGradientText)
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
        .background(Theme.onGradientPanel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.body(weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.2), in: Circle())
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
                    .foregroundStyle(Theme.onGradientText)
                if yearlyDollars > 0 {
                    Text(formatCurrency(yearlyDollars))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                }
                if pouches > 0 {
                    Text(yearlyDollars > 0
                         ? String(localized: "Plus \(yearlyPouches.formatted()) pouches you won't put in. That's the nicotine your body never has to process.")
                         : String(localized: "\(yearlyPouches.formatted()) pouches you won't put in. That's nicotine your body never has to process."))
                        .font(Theme.caption())
                        .foregroundStyle(Theme.onGradientText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.m)
            .padding(.horizontal, Theme.Space.m)
            .background(Theme.onGradientPanel, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func formatCurrency(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? Decimal(amount).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    /// Currency with cents only when needed (e.g. "$6" vs "$6.50" vs "$0.40"),
    /// so the per-can price and derived daily spend read cleanly.
    private func formatCurrencyDecimal(_ amount: Double) -> String {
        let isWhole = amount == amount.rounded()
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        f.minimumFractionDigits = isWhole ? 0 : 2
        f.maximumFractionDigits = isWhole ? 0 : 2
        return f.string(from: NSNumber(value: amount)) ?? Decimal(amount).formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
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
                    completeOnboarding()
                }
                .font(Theme.subhead(weight: .semibold))
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Trial step (Quit Zyn's own page, restored 2026-11-24)

    /// The trial is pitched after the pledge, while the commitment is fresh. This
    /// is the page Quit Zyn ran from Aug 11 to Oct 6 (8.0% of new customers
    /// started a trial, $0.52 per customer); Sober's offer step replaced it in
    /// 1.2.7 and trials fell to 2.9%, then 5.0% with the free-forever row, with
    /// no paying trial since. The billed amount stays the boldest price on the
    /// screen (3.1.2(c)) and the auto-renew terms sit under the button.
    /// Only reached when this Apple ID can start a free trial.
    private var trialStep: some View {
        VStack(spacing: Theme.Space.l) {
            // The pitch gives way so the dock never moves: the glyph goes
            // first, then the pitch scrolls, so the CTA and legal row stay on
            // screen on a 375x667 SE.
            ViewThatFits(in: .vertical) {
                trialPitch(showsGlyph: true)
                trialPitch(showsGlyph: false)
                ScrollView {
                    trialPitch(showsGlyph: false)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicatorsFlash(onAppear: true)
            }
            .frame(maxHeight: .infinity)

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
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            // An Ask to Buy approval lands here after the purchase call returned.
            if isPro { completeOnboarding() }
        }
        .onAppear {
            didShowOnboardingTrial = true
            ConversionDiagnostics.record(.trialOfferReached)
            #if canImport(RevenueCat)
            // v4: the restored page. v2 and v3 were Sober's offer step.
            subscriptions.trackPaywallImpression(
                id: "quitzyn_onboarding_trial_v4",
                package: subscriptions.directTrialPackage,
                oncePerSession: true
            )
            #endif
            // Start the passive-nudge cooldown at this pitch, so Home does not
            // re-pitch the trial seconds after the user declined it here.
            TrialNudgeGate.markShown()
        }
    }

    private func trialPitch(showsGlyph: Bool) -> some View {
        VStack(spacing: Theme.Space.l) {
            if showsGlyph {
                Image(systemName: "gift.fill")
                    .font(.system(size: 72))
                    .opacity(0.92)
            }
            Text("Make your commitment count")
                .font(Theme.display())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.m)
            Text(trialPitchLine)
                .font(Theme.body())
                .foregroundStyle(Theme.onGradientText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.m)

            VStack(alignment: .leading, spacing: Theme.Space.m) {
                trialBenefit(icon: "heart.text.square.fill", text: String(localized: "Full health timeline with 13 nicotine-recovery milestones"))
                trialBenefit(icon: "book.closed.fill", text: String(localized: "Daily journal prompts for the hard days"))
                trialBenefit(icon: "dollarsign.circle.fill", text: savingsBulletText)
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.top, Theme.Space.s)
        }
    }

    private var trialPitchLine: String {
        guard let trialDays else {
            return String(localized: "You just committed. Try every tool that keeps you nicotine-free, free.")
        }
        return String(localized: "You just committed. Try every tool that keeps you nicotine-free, free for \(trialDays) days.")
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

    /// One small savings mention inside a bullet, in the units the user set on
    /// the spend step.
    private var savingsBulletText: String {
        let yearlyDollars = Int((derivedCostPerDay * 365).rounded())
        guard yearlyDollars > 0 else { return String(localized: "Money and pouches avoided, tracked automatically") }
        return String(localized: "Money and pouches avoided, on pace for \(formatCurrency(yearlyDollars)) a year")
    }

    /// Soft free exit above the primary, so the trial button lands where the
    /// user has been tapping Continue. Visually secondary, and it leaves
    /// straight away: no confirm.
    private var skipTrialLink: some View {
        Button {
            ConversionDiagnostics.record(.freeVersionChosen)
            completeOnboarding()
        } label: {
            Text("Get Started")
                .font(Theme.caption(weight: .semibold))
                .foregroundStyle(Theme.onGradientText)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(trialInFlight)
    }

    /// Dock order, top to bottom: Get Started, the billed amount, any error,
    /// then the trial CTA.
    private var trialAboveButton: some View {
        VStack(spacing: Theme.Space.s) {
            skipTrialLink

            // The billed amount, the most conspicuous price on the screen
            // (3.1.2(c)), read from StoreKit. Nil until the package loads:
            // never a placeholder price.
            if let priceHeadline = trialPriceHeadline {
                Text(priceHeadline)
                    .font(Theme.body(weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            if let trialError {
                errorLine(trialError)
            } else if trialPendingApproval {
                pendingLine(SubscriptionService.pendingApprovalMessage)
            }
        }
    }

    private static let trialFailureCopy = String(localized: "Couldn't start your trial. Please try again.")

    private func pendingLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption(weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
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
            .foregroundStyle(Theme.onGradientText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Space.s)
    }

    // MARK: - Reminder and pledge (before the trial)

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
            bottomBar(primaryTitle: String(localized: "Continue")) { withAnimation { step = 4 } }
        }
    }

    /// Last setup step: a deliberate commitment. Recovery starts with a decision, so
    /// the user actively pledges rather than tapping a neutral "Done". A quieter
    /// "Not now" path lets reluctant users finish without a pledge they don't
    /// mean; the answer also tunes the tone of nudges throughout the app. Either
    /// answer checks trial eligibility and leads to the trial step when a free
    /// trial is on the table, else straight into the app.
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
                .foregroundStyle(Theme.onGradientText)
                .padding(.horizontal, Theme.Space.m)
            Spacer()
            bottomBar(
                primaryTitle: trialResolutionInFlight ? String(localized: "Checking trial availability…") : String(localized: "I commit to getting better"),
                busy: trialResolutionInFlight,
                above: {
                    VStack(spacing: Theme.Space.s) {
                        Button { commit(committed: false) } label: {
                            Text("Not now")
                                .font(Theme.subhead(weight: .medium))
                                .foregroundStyle(Theme.onGradientText)
                                .underline()
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .disabled(trialResolutionInFlight)
                        Text("Either way is fine. You can revisit this any time in Settings.")
                            .font(Theme.caption())
                            .foregroundStyle(Theme.onGradientText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Space.m)
                        resolutionError
                    }
                }
            ) { commit(committed: true) }
        }
    }

    // MARK: - Dock

    /// The tallest thing any step puts under its primary button: the trial
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
            .background(Theme.onGradientControl, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.55), lineWidth: 1))
            .disabled(busy)

            ZStack(alignment: .top) {
                subDockReserve
                VStack(spacing: Theme.Space.s) {
                    below()
                    if showLegalFooter { legalFooter }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var legalFooter: some View {
        HStack(spacing: 0) {
            Button { restorePurchasesFromOnboarding() } label: {
                Text(restoreInFlight ? "Restoring…" : "Restore")
                    .underline()
                    .legalTarget()
            }
            .disabled(restoreInFlight)
            Text("·")
            Link(destination: PaywallLinks.standardEULA) {
                Text("Terms of Use").legalTarget()
            }
            Text("·")
            Link(destination: PaywallLinks.privacyPolicy) {
                Text("Privacy Policy").legalTarget()
            }
        }
        .font(Theme.caption(weight: .medium))
        .foregroundStyle(.white)
        .tint(.white)
    }

    private func formatHour(_ h: Int) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.setLocalizedDateFormatFromTemplate("j")
        var comps = DateComponents(); comps.hour = h
        let d = Calendar.current.date(from: comps) ?? .now
        return f.string(from: d)
    }

    // MARK: - Trial plumbing

    /// Save the setup with the pledge answer, then wait for a real RevenueCat
    /// eligibility decision. A loading or network failure is never treated as
    /// a consumed trial; tapping either answer again retries.
    private func commit(committed: Bool) {
        guard !trialResolutionInFlight else { return }
        madeCommitment = committed
        persistSetup()
        trialResolutionError = nil
        trialResolutionInFlight = true
        Task { @MainActor in
            defer { trialResolutionInFlight = false }
            #if canImport(RevenueCat)
            guard subscriptions.isConfigured else {
                trialResolutionError = String(localized: "Bloom+ plans are temporarily unavailable. You can retry or continue free.")
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
                withAnimation { step = 5 }
            case .ineligible:
                completeOnboarding()
            case .unavailable, .failed:
                trialResolutionError = String(localized: "Bloom+ plans are temporarily unavailable. You can retry or continue free.")
            }
            #else
            completeOnboarding()
            #endif
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
        ConversionDiagnostics.record(.trialCTATapped)
        trialError = nil
        trialPendingApproval = false
        trialInFlight = true
        Task { @MainActor in
            defer { trialInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    ConversionDiagnostics.record(.purchaseSucceeded)
                    completeOnboarding()
                case .pending:
                    ConversionDiagnostics.record(.purchasePending)
                    // Not finishing: leaving here made an Ask to Buy look like a
                    // trial that never started. The isProSubscriber change
                    // finishes once approved, and the free option stays available.
                    trialPendingApproval = true
                case .cancelled:
                    // Backing out of Apple's sheet returns the same screen.
                    ConversionDiagnostics.record(.purchaseCancelled)
                }
            } catch {
                ConversionDiagnostics.record(.purchaseFailed)
                trialError = SubscriptionService.purchaseFailureMessage(for: error, fallback: Self.trialFailureCopy)
            }
        }
        #else
        completeOnboarding()
        #endif
    }

    /// Restore from the trial step's legal footer. An active entitlement
    /// finishes onboarding (the user is already a member).
    private func restorePurchasesFromOnboarding() {
        #if canImport(RevenueCat)
        guard !restoreInFlight else { return }
        restoreInFlight = true
        Task { @MainActor in
            defer { restoreInFlight = false }
            trialError = nil
            trialPendingApproval = false
            await subscriptions.restorePurchases()
            if subscriptions.isProSubscriber {
                completeOnboarding()
            } else {
                trialError = subscriptions.lastError
                    ?? String(localized: "No active Bloom+ purchase was found for this Apple ID.")
            }
        }
        #endif
    }

    /// A setup saved before the app was killed mid-onboarding fills the
    /// steps again, so tapping through never turns a saved quit date into today.
    private func restoreSavedSetup() {
        guard let journey = SobrietyService(context: context).activeJourney() else { return }
        let settings = SettingsService(context: context).current()
        guard !settings.hasCompletedOnboarding else { return }
        startDate = journey.startDate
        if settings.pouchesPerDay > 0 {
            pouchesPerDay = Double(settings.pouchesPerDay)
            let perCan = Double(settings.costPerDayCents) / 100 * Double(pouchesPerCan) / pouchesPerDay
            costPerCan = spendScale.clampedCanPrice(perCan)
        }
        reminderHour = settings.dailyReminderHour
    }

    /// Save everything except the onboarding-complete flag, so the trial step
    /// can still render before RootView swaps to the main app. It can run more
    /// than once (a retried pledge, then completion), so the journey is started
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

    /// Every exit lands here: purchased, skipped, restored, ineligible, or the
    /// store never answered. Flip onboarding complete (swaps RootView to the
    /// main app), then ask for notifications. The permission prompt comes after
    /// the trial step so it never interrupts the paid decision.
    private func completeOnboarding() {
        let committed = madeCommitment
        persistSetup()
        let settings = SettingsService(context: context).current()
        guard !settings.hasCompletedOnboarding else { return }
        ConversionDiagnostics.record(.onboardingCompleted)
        settings.hasCompletedOnboarding = true
        context.saveOrReport()

        let hour = reminderHour
        let journeyStart = SobrietyService(context: context).activeJourney()?.startDate
        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(
                hour: hour, committed: committed, journeyStart: journeyStart
            )
        }

        // Only queue the Home popup when the trial step never ran, or the user
        // would see the same pitch twice within a second.
        if !didShowOnboardingTrial {
            AppGroup.defaults.set(true, forKey: AppGroup.postOnboardingPaywallKey)
        }
        WidgetSnapshotPump.push(context: context)
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

    /// The wording arm comes from RevenueCat offering metadata (`trial_cta`);
    /// the control is this page's own "Start my N-day free trial".
    private var trialCTATitle: String {
        #if canImport(RevenueCat)
        subscriptions.trialCTAArm.title(.onboarding, days: trialDays)
        #else
        TrialCTA.myDays.title(.onboarding, days: trialDays)
        #endif
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
}
