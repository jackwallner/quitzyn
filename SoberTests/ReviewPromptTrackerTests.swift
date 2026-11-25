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

    // MARK: - The good moment

    /// Only a result the user just achieved asks. A craving that was not ridden
    /// out never does, and neither does one left unanswered.
    @Test func onlyGoodResultsAreMoments() {
        #expect(ReviewMoment.dailyCheckIn.isGoodResult)
        #expect(ReviewMoment.welcomeBackCheckIn.isGoodResult)
        #expect(ReviewMoment.growthCelebration.isGoodResult)
        #expect(ReviewMoment.craving(.rodeItOut).isGoodResult)
        #expect(!ReviewMoment.craving(.gaveIn).isGoodResult)
        #expect(!ReviewMoment.craving(.unresolved).isGoodResult)
    }

    @Test func aGoodResultArmsTheAskAndABadOneDoesNot() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.hasPendingPositiveMoment = false
            #expect(!ReviewPromptTracker.recordPositiveMoment(.craving(.gaveIn)))
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            #expect(ReviewPromptTracker.recordPositiveMoment(.craving(.rodeItOut)))
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    @Test func noMomentNoAskEvenOnALaterLaunch() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.hasPendingPositiveMoment = false
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    @Test func aSkippedMomentIsSpentAndTheNextOneAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.recordPositiveMoment(.dailyCheckIn)
            ReviewPromptTracker.consumePendingPositiveMoment()
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            ReviewPromptTracker.recordPositiveMoment(.growthCelebration)
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    /// An unrelated sheet closing much later must not ask for a moment that
    /// was blocked long ago.
    @Test func aStaleMomentLapses() {
        withCleanTracker {
            ReviewPromptTracker.recordPositiveMoment(.dailyCheckIn)
            let now = Date.now
            #expect(ReviewPromptTracker.isPendingPositiveMomentFresh(now: now.addingTimeInterval(60)))
            #expect(!ReviewPromptTracker.isPendingPositiveMomentFresh(now: now.addingTimeInterval(11 * 60)))
        }
    }

    /// The cooldown is stamped when the call is made, so a second moment right
    /// after it waits the full 30 days.
    @Test func theCallStampsTheCooldown() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 2
            ReviewPromptTracker.recordPositiveMoment(.dailyCheckIn)
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            ReviewPromptTracker.markShown()
            ReviewPromptTracker.recordPositiveMoment(.dailyCheckIn)
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            let later = Date.now.addingTimeInterval(31 * 86_400)
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: later))
        }
    }

    @Test func neverBeforeOnboardingIsDone() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.recordPositiveMoment(.dailyCheckIn)
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: false))
        }
    }
}
