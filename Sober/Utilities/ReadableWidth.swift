import SwiftUI

extension View {
    /// Caps a full-width column at a readable width and centres it, so rows and
    /// buttons stay phone-sized on an iPad instead of stretching edge to edge.
    func readableWidth(_ maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }

    /// A taller, wider sheet on iPad, where the default form sheet is small
    /// enough to cut a long form off. No effect on iPhone, which is full width.
    @ViewBuilder
    func pageSheetOnPad() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
