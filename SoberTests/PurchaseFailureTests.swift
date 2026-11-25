import Foundation
import RevenueCat
import Testing
@testable import Sober

/// A pending Ask to Buy is a wait, a lost connection reads as the translated
/// connection line, and every other error is left for the surface to word.
@Suite("Purchase failure mapping")
@MainActor
struct PurchaseFailureTests {
    @Test func askToBuyIsPending() {
        #expect(PurchaseFailure.classify(RevenueCat.ErrorCode.paymentPendingError) == .pending)
    }

    @Test func connectionErrorsAreUnreachable() {
        #expect(PurchaseFailure.classify(RevenueCat.ErrorCode.networkError) == .unreachable)
        #expect(PurchaseFailure.classify(RevenueCat.ErrorCode.offlineConnectionError) == .unreachable)
    }

    @Test func otherErrorsAreUnchanged() {
        #expect(PurchaseFailure.classify(RevenueCat.ErrorCode.purchaseNotAllowedError) == .other)
        #expect(PurchaseFailure.classify(RevenueCat.ErrorCode.productAlreadyPurchasedError) == .other)
        #expect(PurchaseFailure.classify(PurchaseError.notConfigured) == .other)
        #expect(PurchaseFailure.classify(URLError(.notConnectedToInternet)) == .other)
    }

    @Test func unreachableShowsTheTranslatedLineAndOthersKeepTheirOwn() {
        let fallback = "Couldn't complete the purchase. Please try again."
        #expect(
            SubscriptionService.purchaseFailureMessage(for: RevenueCat.ErrorCode.networkError, fallback: fallback)
                == SubscriptionService.unreachableMessage
        )
        #expect(
            SubscriptionService.purchaseFailureMessage(for: RevenueCat.ErrorCode.purchaseNotAllowedError, fallback: fallback)
                == fallback
        )
    }

    @Test func pendingCopyIsCalmAndNotAnError() {
        let text = SubscriptionService.pendingApprovalMessage
        #expect(text == "Waiting for approval. Your purchase unlocks once it is approved.")
        #expect(!text.lowercased().contains("error"))
        #expect(!text.lowercased().contains("failed"))
    }
}
