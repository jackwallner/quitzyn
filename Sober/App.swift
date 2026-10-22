import SwiftData
import SwiftUI
import UserNotifications

enum QuitZynScreenshotMode {
    static var isEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-QuitZynScreenshot")
        #else
        return false
        #endif
    }
}

extension Notification.Name {
    /// Posted when the user taps the daily-reminder notification — MainTabView
    /// switches to Home so the check-in button is right there.
    static let soberOpenCheckIn = Notification.Name("com.jackwallner.quitzyn.openCheckIn")
    /// Posted when the user taps the trial-ending reminder, so it lands on the
    /// Bloom+ tab where the plan and the cancel path are.
    static let soberOpenBloomPlus = Notification.Name("com.jackwallner.quitzyn.openBloomPlus")
}

/// Routes notification taps. Without a delegate, tapping the daily reminder
/// just foregrounds the app on whatever tab was last open. Stateless, so the
/// unchecked-Sendable shared instance is safe.
final class NotificationTapRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationTapRouter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let name: Notification.Name
        switch info[NotificationService.deepLinkKey] as? String {
        case NotificationService.deepLinkCheckIn: name = .soberOpenCheckIn
        case NotificationService.deepLinkBloomPlus: name = .soberOpenBloomPlus
        default: return
        }
        await MainActor.run {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}

@main
struct SoberApp: App {
    @State private var subscriptions = SubscriptionService.shared

    init() {
        SubscriptionService.shared.configure()
        #if DEBUG
        Self.loadPreviewStoreIfRequested()
        #endif
        WatchConnectivityService.shared.activate()
        ReviewPromptTracker.recordAppLaunch()
        ConversionDiagnostics.recordAppOpen()
        #if DEBUG
        if RevenueCatProbe.isEnabled {
            // Same entry point the real paywall screens call, so what this
            // proves is the actual path and not a parallel one.
            SubscriptionService.shared.trackPaywallImpression(id: RevenueCatProbe.impressionID)
            if RevenueCatProbe.wantsPurchase {
                Task {
                    await SubscriptionService.shared.fetchProducts()
                    // Logged rather than asserted: when the Test Store sheet
                    // never appears, this separates "no packages came back"
                    // from "purchase threw".
                    NSLog("RCPROBE packages=%d", SubscriptionService.shared.packages.count)
                    guard let package = SubscriptionService.shared.packages.first else { return }
                    do {
                        let outcome = try await SubscriptionService.shared.purchase(package)
                        NSLog("RCPROBE purchase outcome=%@", String(describing: outcome))
                    } catch {
                        NSLog("RCPROBE purchase error=%@", String(describing: error))
                    }
                }
            }
        }
        #endif
        UNUserNotificationCenter.current().delegate = NotificationTapRouter.shared
        // Before any view can run `fillJourney`, or this build's assumed rows
        // would be marked tended along with the legacy ones.
        CheckInService.migrateLegacyCheckInsIfNeeded(
            context: DataService.sharedModelContainer.mainContext
        )
    }

    #if DEBUG
    /// `-previewStore [-previewTrialDays N]` loads a local offering so the real
    /// paywall renders on a headless simulator. Without it the simulator has no
    /// RevenueCat packages at all (see `PaywallPreviewStore`) and every
    /// store-derived string falls back to the dev placeholder, which is how a
    /// hardcoded "7 days free" survived in the yearly card for three releases.
    private static func loadPreviewStoreIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-previewStore") else { return }
        var days = 7
        if let index = args.firstIndex(of: "-previewTrialDays"),
           index + 1 < args.count,
           let parsed = Int(args[index + 1]) {
            days = parsed
        }
        SubscriptionService.shared.loadPreviewStore(
            trialDays: days,
            introEligible: !args.contains("-previewTrialUsed")
        )
    }
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let mode = PaywallScreenshotMode.current {
                PaywallScreenshotHarness(mode: mode)
                    .environment(subscriptions)
            } else {
                RootView()
                    .environment(subscriptions)
            }
            #else
            RootView()
                .environment(subscriptions)
            #endif
        }
        .modelContainer(DataService.sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var saveFailures = SaveFailureReporter.shared
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [UserSettings]

    var body: some View {
        let settings = settingsRows.first
        let onboarded = settings?.hasCompletedOnboarding ?? false
        Group {
            if onboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.brandPrimary)
        // The D1 "Slow morning" theme is a fixed warm-light brand: surfaces are
        // hardcoded cream/ink, so system dark mode only darkens the chrome
        // (lists, pickers, sheets, tab bar) and clashes. Lock to light.
        .preferredColorScheme(.light)
        .alert(
            "Not saved",
            isPresented: Binding(
                get: { saveFailures.message != nil },
                set: { if !$0 { saveFailures.message = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveFailures.message = nil }
        } message: {
            Text(saveFailures.message ?? "")
        }
        .task { WidgetSnapshotPump.push(context: context) }
        #if DEBUG
        .task { seedDemoIfRequested() }
        #endif
        // Re-check entitlements on every foreground (not just cold launch) so a
        // renewal, restore, or server-delayed grant flips the app to Pro
        // promptly — matches Vitals' willEnterForeground refresh.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await SubscriptionService.shared.refreshFromServer() }
            case .background:
                // Sync on the way out, not on the way in: the funnel events that
                // matter (trial step seen, CTA tapped, free version chosen) all
                // happen after launch, so a foreground-only push would always be
                // one session stale, and for a user who never comes back it
                // would never arrive at all.
                #if canImport(RevenueCat)
                Task { await SubscriptionService.shared.syncConversionAttributes() }
                #endif
            default:
                break
            }
        }
    }

    #if DEBUG
    /// Launch-argument seeding for screenshots and to bypass UI-automation
    /// blockers (the onboarding wheel picker wedges the AX bridge). DEBUG only,
    /// never compiled into Release — no path to end users.
    ///   -seedDemo : skip onboarding with a ~3.5-week nicotine-free journey
    ///   -demoPro  : flip the local Pro override on
    private func seedDemoIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demoPro") {
            SubscriptionService.shared.setLocalOverride(isPro: true)
        }
        guard args.contains("-seedDemo") else { return }

        let settings = SettingsService(context: context).current()
        if !settings.hasCompletedOnboarding {
            settings.costPerDayCents = 320
            settings.pouchesPerDay = 8
            settings.madeCommitment = true
            settings.hasCompletedOnboarding = true

            // Optional "-seedDays N" controls the journey length (default ~3.5 weeks);
            // screenshots use a longer run for a mature tree and bigger numbers.
            var seedDays = 24
            if let i = args.firstIndex(of: "-seedDays"), i + 1 < args.count, let n = Int(args[i + 1]) {
                seedDays = max(1, n)
            }
            let start = Calendar.current.date(byAdding: .day, value: -seedDays, to: .now) ?? .now
            _ = SobrietyService(context: context).startJourney(at: start)
            _ = GardenService(context: context).current()
            CheckInService(context: context).fillJourney(start: start, through: .now)
        }

        if args.contains("-QuitZynScreenshot"), (try? context.fetch(FetchDescriptor<JournalEntry>()))?.isEmpty ?? true {
            let entries: [(daysAgo: Int, hour: Int, feeling: String, text: String)] = [
                (1, 21, "excellent", "Went a full workday without reaching for my pocket once. The afternoon slump is shorter now."),
                (4, 20, "good", "Craving hit after lunch. Walked around the block and it passed before I got back."),
                (9, 22, "good", "Sleeping through the night again. Mornings feel clearer than they have in years."),
                (17, 19, "neutral", "Rough start to the week, but I didn't use. Counting that as a win.")
            ]
            for entry in entries {
                let day = Calendar.current.date(byAdding: .day, value: -entry.daysAgo, to: .now) ?? .now
                let createdAt = Calendar.current.date(bySettingHour: entry.hour, minute: 10, second: 0, of: day) ?? day
                context.insert(JournalEntry(createdAt: createdAt, kind: .freeform, text: entry.text, feeling: entry.feeling))
            }
            let moods: [(daysAgo: Int, mood: Int, note: String?)] = [
                (0, 5, "Feeling steady. Garden keeps growing."), (1, 4, nil), (2, 4, nil),
                (3, 5, nil), (5, 3, nil), (6, 4, nil), (8, 5, nil)
            ]
            let checkIns = CheckInService(context: context)
            for item in moods {
                checkIns.checkIn(for: DateHelpers.daysAgo(item.daysAgo), wasSober: true, mood: item.mood, note: item.note)
            }
        }

        if args.contains("-QuitZynScreenshot"), (try? context.fetch(FetchDescriptor<CravingEpisode>()))?.isEmpty ?? true {
            let calendar = Calendar.current
            let service = CravingService(context: context)
            let samples: [(daysAgo: Int, hour: Int, seconds: Int, trigger: String)] = [
                (14, 11, 70, "Stress"),
                (10, 16, 95, "Stress"),
                (6, 12, 60, "Boredom"),
                (3, 16, 80, "Stress")
            ]
            for sample in samples {
                let day = calendar.date(byAdding: .day, value: -sample.daysAgo, to: .now) ?? .now
                let startedAt = calendar.date(bySettingHour: sample.hour, minute: 0, second: 0, of: day) ?? day
                service.record(
                    startedAt: startedAt,
                    secondsElapsed: sample.seconds,
                    outcome: .rodeItOut,
                    intensity: 3,
                    trigger: sample.trigger
                )
            }
        }

        try? context.save()
        WidgetSnapshotPump.push(context: context)
    }
    #endif
}

struct MainTabView: View {
    @Environment(SubscriptionService.self) private var subscriptions
    @StateObject private var trialCoordinator = TrialOfferCoordinator.shared
    @State private var tab = 0
    @State private var showTrialOffer = false
    @State private var showTrialPaywall = false
    @State private var pendingPaywallAfterTrialDismiss = false
    @State private var trialOfferFocus: BloomFeature?
    @State private var trialPurchaseInFlight = false
    @State private var trialPurchaseError: String?
    @State private var timeline = TimelineSelection()
    @State private var paneGeometry = PaneGeometry()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Unfolded, Timeline has its own pane beside the tabs, so it is never a tab.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// Each unfolded pane is phone-width, so its screen lays out as on a phone.
    /// Applied to the tab contents, not the `TabView`: overriding the bar's own
    /// size class flipped the Duo's vertical bar to a bottom bar on the first
    /// tab switch. Unfolded, iOS 27.1 may draw a bottom bar here with no safe
    /// area for it, so each screen applies `PaneTabBarClearance` inside its
    /// stack.
    private var paneSizeClass: UserInterfaceSizeClass? {
        split == nil ? horizontalSizeClass : .compact
    }

    var body: some View {
        // Opening or closing the Duo only moves these frames, so the tabs are
        // never rebuilt; Timeline's state lives in `timeline` for its move.
        ZStack(alignment: .topLeading) {
            tabs
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)
            if let split {
                TimelineView(selection: timeline)
                    .environment(\.horizontalSizeClass, .compact)
                    .frame(width: split.secondaryWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .onGeometryChange(for: PaneGeometry.self) { proxy in
            PaneGeometry(width: proxy.size.width, fold: proxy.verticalFold())
        } action: { paneGeometry = $0 }
        .onChange(of: split != nil) { _, isSplit in
            if isSplit, tab == 1 { tab = 0 }
        }
        #if DEBUG
        .task { await runScreenshotTour() }
        #endif
    }

    #if DEBUG
    /// `-screenshotTour`: cycles Home, Health, Journal, Bloom+ and (folded)
    /// Timeline, 16s each, for headless capture runs, which can't tap and
    /// whose `simctl openurl` stops on a confirmation alert. gh-sim's shot
    /// times vary by tens of seconds between runners, so rather than aim at
    /// them the tour keeps cycling and the run takes a shot about every 8 to
    /// 12s (`--wait 5` and a dozen `--url` triggers): every screen gets at
    /// least one. Unfolded, Timeline is the right pane, so it skips that step.
    private func runScreenshotTour() async {
        guard ProcessInfo.processInfo.arguments.contains("-screenshotTour") else { return }
        let order = [0, 2, 3, 4, 1]
        var index = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(16))
            guard !Task.isCancelled else { return }
            index = (index + 1) % order.count
            if order[index] == 1, split != nil { index = 0 }
            withAnimation(.easeInOut(duration: 0.3)) { tab = order[index] }
        }
    }
    #endif

    private var tabs: some View {
        TabView(selection: $tab) {
            HomeView()
                .paneTab(sizeClass: paneSizeClass, isSplit: split != nil)
                .tabItem { Label("Home", systemImage: "leaf.fill") }
                .tag(0)
            if split == nil {
                TimelineView(selection: timeline)
                    .paneTab(sizeClass: paneSizeClass, isSplit: false)
                    .tabItem { Label("Timeline", systemImage: "calendar") }
                    .tag(1)
            }
            HealthView()
                .paneTab(sizeClass: paneSizeClass, isSplit: split != nil)
                .tabItem { Label("Health", systemImage: "heart.fill") }
                .tag(2)
            JournalView()
                .paneTab(sizeClass: paneSizeClass, isSplit: split != nil)
                .tabItem { Label("Journal", systemImage: "book.fill") }
                .tag(3)
            BloomPlusTabView()
                .paneTab(sizeClass: paneSizeClass, isSplit: split != nil)
                .tabItem {
                    Label(
                        QuitZynScreenshotMode.isEnabled
                            ? "Support"
                            : (subscriptions.isProSubscriber ? "Bloom+" : "Upgrade"),
                        systemImage: QuitZynScreenshotMode.isEnabled
                            ? "sparkles"
                            : (subscriptions.isProSubscriber ? "sparkles" : "lock.fill")
                    )
                }
                .tag(4)
        }
        .onChange(of: trialCoordinator.pendingRequest) { _, request in
            guard let request else { return }
            trialCoordinator.clear()
            handleTrialPitch(request)
        }
        .onChange(of: showTrialOffer) { _, _ in syncPresentationFlag() }
        .onChange(of: showTrialPaywall) { _, _ in syncPresentationFlag() }
        .onReceive(NotificationCenter.default.publisher(for: .soberOpenCheckIn)) { _ in
            tab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .soberOpenBloomPlus)) { _ in
            tab = 4
        }
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            if isPro { showTrialOffer = false }
        }
        .onChange(of: tab) { _, newTab in
            if newTab == 4, !subscriptions.isProSubscriber {
                subscriptions.trackPaywallImpression(id: "quitzyn_bloom_tab", oncePerSession: true)
            }
        }
        .sheet(isPresented: $showTrialOffer, onDismiss: {
            trialPurchaseInFlight = false
            trialPurchaseError = nil
            if pendingPaywallAfterTrialDismiss {
                pendingPaywallAfterTrialDismiss = false
                showTrialPaywall = true
            }
        }) {
            TrialOfferSheet(
                focus: trialOfferFocus,
                offerLabel: trialOfferLabelText,
                priceLabel: trialOfferPriceText,
                directPurchase: hasDirectTrialPackage,
                isPurchasing: trialPurchaseInFlight,
                errorMessage: trialPurchaseError,
                onStartTrial: startDirectTrialPurchase,
                onSeeAllPlans: {
                    pendingPaywallAfterTrialDismiss = true
                    showTrialOffer = false
                },
                onDismiss: { showTrialOffer = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(trialPurchaseInFlight)
        }
        .sheet(isPresented: $showTrialPaywall, onDismiss: {
            trialOfferFocus = nil
        }) {
            PaywallView(focus: trialOfferFocus, impressionId: "quitzyn_trial_sheet")
        }
    }

    private func syncPresentationFlag() {
        trialCoordinator.isPresentingSheet = showTrialOffer || showTrialPaywall
    }

    #if canImport(RevenueCat)
    private var hasDirectTrialPackage: Bool { subscriptions.directTrialPackage != nil }
    private var trialOfferLabelText: String? { subscriptions.directTrialPackage?.soberIntroOfferLabel }
    private var trialOfferPriceText: String? { subscriptions.directTrialPackage?.soberPriceLabel }

    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        guard !subscriptions.isProSubscriber, !QuitZynScreenshotMode.isEnabled else { return }
        let focus = request.intent.focusFeature

        switch request.policy {
        case .initial, .explicitUpgrade:
            presentTrialOffer(focus: focus)
        case .subsequentLocked:
            let count = TrialSubsequentPitchGate.recordAction(for: request.intent)
            if count >= TrialSubsequentPitchGate.lockedFeatureThreshold,
               subscriptions.hasTrialOfferAvailable,
               TrialSubsequentPitchGate.canPresentTrialPitch(for: request.intent) {
                TrialSubsequentPitchGate.markTrialPitchPresented(for: request.intent)
                presentTrialOffer(focus: focus)
            } else {
                trialOfferFocus = focus
                showTrialPaywall = true
            }
        case .subsequentPassive:
            guard subscriptions.hasTrialOfferAvailable,
                  TrialSubsequentPitchGate.canPresentTrialPitch(for: request.intent)
            else {
                trialOfferFocus = focus
                showTrialPaywall = true
                return
            }
            TrialSubsequentPitchGate.markTrialPitchPresented(for: request.intent)
            presentTrialOffer(focus: focus)
        }
    }

    private func presentTrialOffer(focus: BloomFeature?) {
        guard !subscriptions.isProSubscriber, subscriptions.hasTrialOfferAvailable else {
            trialOfferFocus = focus
            showTrialPaywall = true
            return
        }
        trialOfferFocus = focus
        showTrialOffer = true
    }

    private func startDirectTrialPurchase() {
        guard let package = subscriptions.directTrialPackage else {
            pendingPaywallAfterTrialDismiss = true
            showTrialOffer = false
            return
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = true
        ConversionDiagnostics.record(.trialCTATapped)
        Task { @MainActor in
            defer { trialPurchaseInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    ConversionDiagnostics.record(.purchaseSucceeded)
                    showTrialOffer = false
                case .pending:
                    ConversionDiagnostics.record(.purchasePending)
                    // Keep the sheet up so the tap has a visible answer. The
                    // isProSubscriber change below closes it once approved.
                    trialPurchaseError = SubscriptionService.pendingApprovalMessage
                case .cancelled:
                    ConversionDiagnostics.record(.purchaseCancelled)
                    trialPurchaseError = "Trial start cancelled. Tap again to continue."
                }
            } catch {
                ConversionDiagnostics.record(.purchaseFailed)
                trialPurchaseError = "Couldn't start your trial. Please try again."
            }
        }
    }
    #else
    private var hasDirectTrialPackage: Bool { false }
    private var trialOfferLabelText: String? { nil }
    private var trialOfferPriceText: String? { nil }

    private func handleTrialPitch(_ request: TrialOfferCoordinator.PendingRequest) {
        trialOfferFocus = request.intent.focusFeature
        showTrialPaywall = true
    }

    private func presentTrialOffer(focus: BloomFeature?) {
        trialOfferFocus = focus
        showTrialPaywall = true
    }

    private func startDirectTrialPurchase() {}
    #endif
}

private extension View {
    /// One tab's screen: the phone layout in a pane, clear of the pane's
    /// bottom tab bar while split.
    func paneTab(sizeClass: UserInterfaceSizeClass?, isSplit: Bool) -> some View {
        environment(\.horizontalSizeClass, sizeClass)
            .environment(\.clearsPaneTabBar, isSplit)
    }
}
