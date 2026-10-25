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
    /// Height of the tab strip that heads the leading pane while split.
    static let paneTabStripHeight: CGFloat = 60
}

private struct IsTimelinePaneKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True for the Timeline in its own unfolded pane, not its tab.
    var isTimelinePane: Bool {
        get { self[IsTimelinePaneKey.self] }
        set { self[IsTimelinePaneKey.self] = newValue }
    }
}

private struct IsLeadingPaneKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True for the tabs while they hold the leading pane.
    var isLeadingPane: Bool {
        get { self[IsLeadingPaneKey.self] }
        set { self[IsLeadingPaneKey.self] = newValue }
    }
}

/// The system's 84pt status column inset reaches the leading pane's
/// NavigationStacks too, though the column sits past the fold, so a tab's
/// root drops it there. Home keeps it: its toolbar stands in that column.
/// An inset-grouped List left without the inset has no trailing margin, so
/// a list root sets both margins itself.
private struct LeadingPaneEdge: ViewModifier {
    let isList: Bool
    @Environment(\.isLeadingPane) private var isLeadingPane

    func body(content: Content) -> some View {
        content
            .ignoresSafeArea(.container, edges: isLeadingPane ? .trailing : [])
            .contentMargins(.horizontal, isLeadingPane && isList ? 20 : nil, for: .scrollContent)
    }
}

extension View {
    func leadingPaneEdge(isList: Bool = false) -> some View {
        modifier(LeadingPaneEdge(isList: isList))
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

/// The leading pane's tabs while split, in place of the system tab bar.
struct PaneTabStrip: View {
    struct Item: Identifiable {
        let tag: Int
        let title: String
        let systemImage: String
        var id: Int { tag }
    }

    @Binding var selection: Int
    let items: [Item]

    var body: some View {
        // Every tab named when they all fit; else only the open tab is.
        ViewThatFits(in: .horizontal) {
            row(namesAll: true)
            row(namesAll: false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(height: UnfoldedSplit.paneTabStripHeight, alignment: .top)
    }

    private func row(namesAll: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                button(item, showsTitle: namesAll || selection == item.tag)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.textPrimary.opacity(0.08), lineWidth: 1))
        .fixedSize()
    }

    private func button(_ item: Item, showsTitle: Bool) -> some View {
        let isSelected = selection == item.tag
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selection = item.tag }
        } label: {
            Label(item.title, systemImage: item.systemImage)
                .labelStyle(PaneTabLabelStyle(showsTitle: showsTitle))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Theme.brandPrimary : Theme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(isSelected ? Theme.brandPrimary.opacity(0.12) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PaneTabLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            if showsTitle { configuration.title }
        }
    }
}
