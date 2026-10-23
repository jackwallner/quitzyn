import SwiftUI

/// Pane frames for the unfolded iPhone Duo: the tabs on the leading side of the
/// fold, Timeline on the trailing side, so no screen straddles the crease. `nil`
/// keeps the single-column layout (every ordinary iPhone, the folded Duo, and
/// the unfolded Duo held in portrait, where each half would be too narrow).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the compact Home and Timeline layouts.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }
}

extension UnfoldedSplit {
    /// From the pane's bottom edge to the top of the floating tab bar iOS 27.1
    /// draws in the unfolded pane: a 63 pt bar 20 pt above the edge, measured
    /// on the simulator, plus a hairline.
    static let tabBarClearance: CGFloat = 84

    /// The pane's bar adds no safe area, so its tabs need this much more. Any
    /// inset the system does supply counts toward it, so a later fix to the
    /// bar can't double the gap.
    static func tabBarPadding(systemInset: CGFloat) -> CGFloat {
        max(0, tabBarClearance - systemInset)
    }

    /// Side insets wider than this mean the system put the pane's bars in a
    /// vertical bar beside the content, so there is no bottom bar to clear.
    static let verticalBarInset: CGFloat = 40

    static func tabBarPadding(bottomInset: CGFloat, sideInsets: CGFloat) -> CGFloat {
        sideInsets > verticalBarInset ? 0 : tabBarPadding(systemInset: bottomInset)
    }

    /// Height of the fade where a scrolling screen ends above the bottom bar.
    static let edgeFadeHeight: CGFloat = 28

    static func edgeFade(padding: CGFloat, scrolls: Bool) -> CGFloat {
        scrolls && padding > 0 ? edgeFadeHeight : 0
    }

    /// The lowest point, in global space, a row may reach and still show:
    /// the top of the edge fade. `nil` (folded, unmeasured, or no fade)
    /// shows every row.
    static func rowLimit(clipEdge: CGFloat, fade: CGFloat) -> CGFloat? {
        guard fade > 0, clipEdge > 0 else { return nil }
        return clipEdge - fade
    }

    /// A row the pane's bottom edge would cut shows nothing rather than a
    /// sliced line or a card's top sliver; it fades in once it scrolls clear.
    static func rowFits(rowBottom: CGFloat, limit: CGFloat?) -> Bool {
        guard let limit else { return true }
        return rowBottom <= limit + 0.5
    }

    /// Extra top inset for the trailing pane, which runs to the display edge
    /// past the trailing safe area: iOS 27.1 stacks the clock and the battery
    /// ring around the camera in that corner, down to about 100 pt, and the
    /// pane's first card would otherwise start at 83 pt beneath them.
    static let trailingPaneTopClearance: CGFloat = 28
}

/// Whether a screen sits in the unfolded tab pane, under its bottom tab bar.
private struct ClearsPaneTabBarKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var clearsPaneTabBar: Bool {
        get { self[ClearsPaneTabBarKey.self] }
        set { self[ClearsPaneTabBarKey.self] = newValue }
    }
}

/// Keeps a screen clear of the pane's bottom tab bar while split. Apply it
/// inside the screen's `NavigationStack`: padding applied outside the stack
/// never reached its content. iOS 27.1 picks the pane's bar placement itself,
/// from one launch to the next: a bottom floating bar that adds no safe area,
/// or a vertical bar beside the content that does (as side insets), which
/// needs nothing more. The screen's frame ends above the bottom bar, rather
/// than insetting its scroll content, so no row ever shows through the glass;
/// the strip behind the bar keeps the screen's background. A scrolling
/// screen fades out over its last few points there, as under a phone's bar,
/// so the row cut at that edge never reads as sliced.
struct PaneTabBarClearance: ViewModifier {
    var fadesEdge: Bool
    @Environment(\.clearsPaneTabBar) private var isSplit
    @State private var insets = PaneInsets()
    @State private var clipEdge: CGFloat = 0

    private var padding: CGFloat {
        guard isSplit else { return 0 }
        return UnfoldedSplit.tabBarPadding(bottomInset: insets.bottom, sideInsets: insets.sides)
    }

    private var fade: CGFloat {
        UnfoldedSplit.edgeFade(padding: padding, scrolls: fadesEdge)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.paneRowLimit, UnfoldedSplit.rowLimit(clipEdge: clipEdge, fade: fade))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY
            } action: { clipEdge = $0 }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Theme.background.opacity(0), Theme.background], startPoint: .top, endPoint: .bottom)
                    .frame(height: fade)
                    .allowsHitTesting(false)
            }
            .padding(.bottom, padding)
            .background(Theme.background.ignoresSafeArea())
            // Read outside the padding, so the padding never feeds back into it.
            .onGeometryChange(for: PaneInsets.self) { proxy in
                let safe = proxy.safeAreaInsets
                return PaneInsets(bottom: safe.bottom, sides: safe.leading + safe.trailing)
            } action: { insets = $0 }
            #if DEBUG
            .onChange(of: padding, initial: true) { _, padding in
                guard QuitZynScreenshotMode.isEnabled else { return }
                NSLog("PANECLEAR split=%d bottom=%.1f sides=%.1f padding=%.1f", isSplit ? 1 : 0, insets.bottom, insets.sides, padding)
            }
            #endif
    }
}

private struct PaneRowLimitKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private struct PaneTopClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Set by `PaneTabBarClearance`: rows reaching below this hide.
    var paneRowLimit: CGFloat? {
        get { self[PaneRowLimitKey.self] }
        set { self[PaneRowLimitKey.self] = newValue }
    }

    /// Extra top inset for a pane's scroll content, clear of the status items.
    var paneTopClearance: CGFloat {
        get { self[PaneTopClearanceKey.self] }
        set { self[PaneTopClearanceKey.self] = newValue }
    }
}

/// Hides a row while the pane's bottom edge would cut it, so a resting screen
/// never ends on a sliced line. VoiceOver keeps every row, since it scrolls
/// to rows by focus and can't reach a hidden one.
struct PaneRowFit: ViewModifier {
    @Environment(\.paneRowLimit) private var limit
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var rowBottom: CGFloat = 0

    func body(content: Content) -> some View {
        let fits = voiceOver || UnfoldedSplit.rowFits(rowBottom: rowBottom, limit: limit)
        content
            .opacity(fits ? 1 : 0)
            .allowsHitTesting(fits)
            .animation(.easeOut(duration: 0.2), value: fits)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).maxY
            } action: { rowBottom = $0 }
    }
}

struct PaneInsets: Equatable, Sendable {
    var bottom: CGFloat = 0
    var sides: CGFloat = 0
}

extension View {
    /// - Parameter fadesEdge: false for a screen that doesn't scroll, whose
    ///   last card ends clear of the bar on its own.
    func paneTabBarClearance(fadesEdge: Bool = true) -> some View {
        modifier(PaneTabBarClearance(fadesEdge: fadesEdge))
    }

    /// For each row or card of a screen that applies `paneTabBarClearance`.
    func fitsAbovePaneEdge() -> some View {
        modifier(PaneRowFit())
    }
}

/// What the split is computed from, read off the container in one pass.
struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?
}

extension GeometryProxy {
    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}
