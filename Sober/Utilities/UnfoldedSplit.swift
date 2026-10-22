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
}

/// Keeps a pane's tab content clear of the bottom tab bar while split.
struct PaneTabBarClearance: ViewModifier {
    var isSplit: Bool
    @State private var systemInset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, isSplit ? UnfoldedSplit.tabBarPadding(systemInset: systemInset) : 0)
            // Read outside the padding, so the padding never feeds back into it.
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { systemInset = $0 }
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
