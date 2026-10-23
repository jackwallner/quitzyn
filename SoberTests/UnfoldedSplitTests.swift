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

@Suite("Home stack space")
struct StackSpaceTests {
    @Test func unmeasuredLeavesTheFloorAlone() {
        #expect(StackSpace().gardenRoom == nil)
    }

    @Test func roomIsWhatTheRestOfTheStackLeaves() {
        // The unfolded pane: 549 pt under the bars, 250 pt of other content.
        let space = StackSpace(available: 549, stack: 610, garden: 360)
        #expect(space.gardenRoom == 299)
    }

    @Test func roomIsStableOnceTheGardenFits() {
        // The same pane after the floor drops to 299: the answer doesn't move.
        let space = StackSpace(available: 549, stack: 549, garden: 299)
        #expect(space.gardenRoom == 299)
    }

    @Test func roomOnAPhoneThatFitsIsTheGardensOwnHeight() {
        let space = StackSpace(available: 640, stack: 640, garden: 390)
        #expect(space.gardenRoom == 390)
    }
}

@Suite("Pane tab bar clearance")
struct PaneTabBarClearanceTests {
    @Test func noSystemInsetGetsTheFullClearance() {
        #expect(UnfoldedSplit.tabBarPadding(systemInset: 0) == UnfoldedSplit.tabBarClearance)
    }

    @Test func aHomeIndicatorInsetCountsTowardIt() {
        #expect(UnfoldedSplit.tabBarPadding(systemInset: 20) == UnfoldedSplit.tabBarClearance - 20)
    }

    @Test func aSystemInsetForTheBarAddsNothing() {
        #expect(UnfoldedSplit.tabBarPadding(systemInset: 100) == 0)
    }

    @Test func aBottomBarPaneGetsTheClearance() {
        #expect(UnfoldedSplit.tabBarPadding(bottomInset: 0, sideInsets: 0) == UnfoldedSplit.tabBarClearance)
    }

    @Test func aVerticalBarBesideTheContentNeedsNoBottomPadding() {
        #expect(UnfoldedSplit.tabBarPadding(bottomInset: 0, sideInsets: 96) == 0)
    }
}

@Suite("Duo screen launch argument")
struct DuoScreenTests {
    @Test func eachScreenOpensItsTab() {
        #expect(DuoScreen.launchTab(arguments: ["app", "-DuoScreen", "home"]) == 0)
        #expect(DuoScreen.launchTab(arguments: ["app", "-DuoScreen", "timeline"]) == 1)
        #expect(DuoScreen.launchTab(arguments: ["app", "-DuoScreen", "health"]) == 2)
        #expect(DuoScreen.launchTab(arguments: ["app", "-DuoScreen", "journal"]) == 3)
        #expect(DuoScreen.launchTab(arguments: ["app", "-seedDemo", "-DuoScreen", "Bloom"]) == 4)
    }

    @Test func missingOrUnknownScreenOpensNothing() {
        #expect(DuoScreen.launchTab(arguments: ["app"]) == nil)
        #expect(DuoScreen.launchTab(arguments: ["app", "-DuoScreen"]) == nil)
        #expect(DuoScreen.launchTab(arguments: ["app", "-DuoScreen", "settings"]) == nil)
    }
}

@Suite("Pane edge fade")
struct PaneEdgeFadeTests {
    @Test func scrollingScreenFadesAboveTheBottomBar() {
        let padding = UnfoldedSplit.tabBarPadding(bottomInset: 0, sideInsets: 0)
        #expect(UnfoldedSplit.edgeFade(padding: padding, scrolls: true) == UnfoldedSplit.edgeFadeHeight)
    }

    @Test func noFadeWithoutABottomBar() {
        let padding = UnfoldedSplit.tabBarPadding(bottomInset: 0, sideInsets: 84)
        #expect(UnfoldedSplit.edgeFade(padding: padding, scrolls: true) == 0)
        #expect(UnfoldedSplit.edgeFade(padding: 0, scrolls: true) == 0)
    }

    @Test func fixedScreenNeverFades() {
        #expect(UnfoldedSplit.edgeFade(padding: 84, scrolls: false) == 0)
    }
}

@Suite("Pane row fit")
struct PaneRowFitTests {
    @Test func rowsStopAboveTheFade() {
        // The leading pane's clip edge on the unfolded Duo: 669 - 84.
        #expect(UnfoldedSplit.rowLimit(clipEdge: 585, fade: 28) == 557)
    }

    @Test func noLimitFoldedOrBeforeTheEdgeIsMeasured() {
        #expect(UnfoldedSplit.rowLimit(clipEdge: 585, fade: 0) == nil)
        #expect(UnfoldedSplit.rowLimit(clipEdge: 0, fade: 28) == nil)
    }

    @Test func aRowTheEdgeWouldCutHides() {
        #expect(!UnfoldedSplit.rowFits(rowBottom: 580, limit: 557))
        #expect(!UnfoldedSplit.rowFits(rowBottom: 700, limit: 557))
    }

    @Test func aRowEndingAboveTheFadeShows() {
        #expect(UnfoldedSplit.rowFits(rowBottom: 540, limit: 557))
        #expect(UnfoldedSplit.rowFits(rowBottom: 557.3, limit: 557))
    }

    @Test func everyRowShowsWithoutALimit() {
        #expect(UnfoldedSplit.rowFits(rowBottom: 5_000, limit: nil))
    }
}

@Suite("Trailing pane")
struct TrailingPaneTests {
    @Test func contentSitsCentredBesideTheStatusColumn() throws {
        // The unfolded Duo: fold 455.7...495.7, a 64 pt trailing safe area.
        let split = try #require(UnfoldedSplit.make(
            width: 951, isRegularWidth: true, fold: 455.7...495.7, trailingInset: 64
        ))
        #expect(split.secondaryLeadingInset == 64)
        // Equal space from the fold and from the display edge.
        let fromFold = split.secondaryLeadingInset
        let fromEdge = 951 - (split.secondaryX + split.secondaryWidth) + 64
        #expect(abs(fromFold - fromEdge) < 0.001)
    }

    @Test func runsToTheDisplayEdgeAsWideAsTheLeadingPane() throws {
        let split = try #require(UnfoldedSplit.make(
            width: 951, isRegularWidth: true, fold: 455.7...495.7, trailingInset: 64
        ))
        #expect(abs(split.secondaryX + split.secondaryWidth - 951) < 0.001)
        #expect(abs(split.secondaryWidth - split.primaryWidth) < 1)
    }

    @Test func balancesWhenTheWidthStopsAtTheSafeArea() throws {
        // The same display laid out inside the safe area: 887 pt wide.
        let split = try #require(UnfoldedSplit.make(
            width: 887, isRegularWidth: true, fold: 455.7...495.7, trailingInset: 64
        ))
        #expect(split.secondaryLeadingInset == 64)
    }

    @Test func noTrailingInsetNeedsNoBalance() {
        let split = UnfoldedSplit.make(width: 951, isRegularWidth: true, fold: 455.7...495.7)
        #expect(split?.secondaryLeadingInset == 0)
    }

    @Test func aPaneTooNarrowToBalanceKeepsItsWidth() {
        // 360 pt panes less 2 x 64 would leave the calendar 232 pt.
        let split = UnfoldedSplit.make(width: 720, isRegularWidth: true, fold: nil, trailingInset: 64)
        #expect(split?.secondaryLeadingInset == 0)
    }
}
