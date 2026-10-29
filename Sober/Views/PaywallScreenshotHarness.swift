#if DEBUG
import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct PaywallScreenshotHarness: View {
    let mode: PaywallScreenshotMode
    @State private var subscriptions = SubscriptionService.shared

    var body: some View {
        Group {
            if mode == .trial {
                trialBackdrop {
                    TrialOfferSheet(
                        focus: nil,
                        hasTrial: trialPackage?.soberIntroOfferLabel != nil,
                        trialDays: trialPackage?.soberIntroOfferDays,
                        trialPriceSentence: trialPackage?.soberTrialThenPriceSentence,
                        priceOnlyLabel: trialPackage?.storeProduct.localizedPriceString,
                        directPurchase: true,
                        isPurchasing: false,
                        errorMessage: nil,
                        onStartTrial: {},
                        onSeeAllPlans: {},
                        onDismiss: {}
                    )
                }
            } else {
                PaywallView(displayCloseButton: false, impressionId: "snapshot")
            }
        }
        .environment(subscriptions)
        .preferredColorScheme(.light)
        .task {
            if subscriptions.packages.isEmpty { await subscriptions.fetchProducts() }
        }
    }

    #if canImport(RevenueCat)
    /// Mirrors what the onboarding CTA actually buys (see `preferredTrialKind`),
    /// so a screenshot can't advertise a plan the button doesn't purchase.
    private var trialPackage: Package? {
        subscriptions.packages.first { $0.soberPackageKind == .yearly } ?? subscriptions.packages.first
    }
    #endif

    private func trialBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack {
                Spacer()
                content()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.68)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
    }
}

struct WidgetScreenshotHarness: View {
    private let startDate = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
    private var snapshot: WidgetSnapshot {
        WidgetSnapshot(
            sobrietyStartDate: startDate,
            currentStreakDays: 35,
            longestStreakDays: 35,
            bonsaiStage: 3,
            bonsaiStyleID: "traditional",
            gardenVitality: 0.85,
            placedItemIDs: [],
            unlockedItemIDs: [],
            generatedAt: .now
        )
    }

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            SoberDayCounterView(snapshot: snapshot, days: 35, familyOverride: .systemMedium)
                .frame(width: 350, height: 160)
                .background(Theme.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .preferredColorScheme(.light)
    }
}
#endif
