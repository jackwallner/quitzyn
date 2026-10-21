import CoreGraphics
import Testing
@testable import Sober

@Suite("Unfolded split")
struct UnfoldedSplitTests {
    @Test func compactWidthNeverSplits() {
        #expect(UnfoldedSplit.make(width: 951, isRegularWidth: false, fold: nil) == nil)
    }

    @Test func foldedOuterDisplayKeepsOneColumn() {
        #expect(UnfoldedSplit.make(width: 466, isRegularWidth: true, fold: nil) == nil)
    }

    @Test func unfoldedPortraitIsTooNarrowForTwoPanes() {
        #expect(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil) == nil)
    }

    @Test func panesMeetTheFoldEdges() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: 470...481)
        #expect(split == UnfoldedSplit(primaryWidth: 470, secondaryX: 481, secondaryWidth: 470))
    }

    @Test func noReportedFoldSplitsEvenly() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: nil)
        #expect(split == UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    @Test func foldThatLeavesANarrowPaneFallsBackToEvenSplit() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: 300...310)
        #expect(split == UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    @Test func exactlyTwoMinimumPanesStillSplits() {
        let split = UnfoldedSplit.make(width: 720, isRegularWidth: true, fold: nil)
        #expect(split?.primaryWidth == 360)
        #expect(split?.secondaryWidth == 360)
    }

    @Test func panesAndFoldCoverTheWidthWithoutOverlap() throws {
        let split = try #require(UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: 468...483))
        #expect(split.primaryWidth <= split.secondaryX)
        #expect(split.secondaryX + split.secondaryWidth == 951)
        #expect(split.primaryWidth >= UnfoldedSplit.minimumPaneWidth)
        #expect(split.secondaryWidth >= UnfoldedSplit.minimumPaneWidth)
    }
}

@Suite("Timeline selection")
@MainActor
struct TimelineSelectionTests {
    @Test func survivesBeingHandedToANewTimeline() {
        let selection = TimelineSelection()
        selection.draftNote = "half-typed"
        let tabTimeline = TimelineView(selection: selection)
        let paneTimeline = TimelineView(selection: selection)
        #expect(tabTimeline.selection === paneTimeline.selection)
        #expect(paneTimeline.selection.draftNote == "half-typed")
    }
}
