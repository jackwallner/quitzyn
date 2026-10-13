import Foundation
import Testing
@testable import Sober

/// The rating-ask rules from the fleet policy: ask from the second launch,
/// wait out a 30-day cooldown, stop only when the user opened the review page,
/// and never let feedback stop or restart the asks.
@Suite("Review prompt gates", .serialized)
@MainActor
struct ReviewPromptTrackerTests {
    /// Snapshots and restores the shared app-group state the tracker persists,
    /// so running the suite doesn't leave a simulator install mid-ask.
    private func withCleanTracker(_ body: () -> Void) {
        let launches = ReviewPromptTracker.appLaunchCount
        let firstOpen = ReviewPromptTracker.firstAppOpenDate
        let lastShown = ReviewPromptTracker.lastShownDate
        let outcome = ReviewPromptTracker.outcome
        let moments = ReviewPromptTracker.positiveMomentCount
        let pending = ReviewPromptTracker.hasPendingPositiveMoment
        defer {
            ReviewPromptTracker.appLaunchCount = launches
            ReviewPromptTracker.firstAppOpenDate = firstOpen
            ReviewPromptTracker.lastShownDate = lastShown
            ReviewPromptTracker.outcome = outcome
            ReviewPromptTracker.positiveMomentCount = moments
            ReviewPromptTracker.hasPendingPositiveMoment = pending
        }
        ReviewPromptTracker.outcome = nil
        ReviewPromptTracker.lastShownDate = nil
        body()
    }

    @Test func asksFromTheSecondSession() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 2
            ReviewPromptTracker.firstAppOpenDate = .now
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func neverAsksInTheFirstSession() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 1
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func openingTheReviewPageEndsTheAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.outcome = .openedWriteReview
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func sendingFeedbackStillLeavesARatingAsk() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.outcome = .submittedFeedback
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-31 * 86_400)
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func waitsOutTheCooldown() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-10 * 86_400)
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    /// A check-in's ask often finds its note sheet still open. The moment must
    /// survive that skip so the sheet's dismissal can still ask.
    @Test func blockedAskKeepsTheMomentPending() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.recordPositiveMoment()
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            ReviewPromptTracker.markShown()
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    @Test func stillRequiresFinishedOnboarding() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: false))
        }
    }

    @Test func feedbackAfterTheReviewPageKeepsTheAsksEnded() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markOpenedWriteReview()
            ReviewPromptTracker.markFeedbackSubmitted()
            #expect(ReviewPromptTracker.outcome == .openedWriteReview)
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func feedbackNeverEndsTheAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markFeedbackSubmitted()
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }
}
