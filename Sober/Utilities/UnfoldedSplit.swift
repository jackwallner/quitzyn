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
/// needs nothing more.
struct PaneTabBarClearance: ViewModifier {
    @Environment(\.clearsPaneTabBar) private var isSplit
    @State private var insets = PaneInsets()

    private var padding: CGFloat {
        guard isSplit else { return 0 }
        return UnfoldedSplit.tabBarPadding(bottomInset: insets.bottom, sideInsets: insets.sides)
    }

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, padding)
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

struct PaneInsets: Equatable, Sendable {
    var bottom: CGFloat = 0
    var sides: CGFloat = 0
}

extension View {
    func paneTabBarClearance() -> some View {
        modifier(PaneTabBarClearance())
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
