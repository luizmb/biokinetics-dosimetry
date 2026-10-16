import SwiftUI

// MARK: - EdgeFade

/// A soft fade where content runs under a bar: a thin blur, strongest at the screen edge and gone
/// `depth` points in, like a scroll view's edge effect for content that isn't a scroll view. Draws
/// into the safe area and never takes touches.
public struct EdgeFade: View {
    let edge: VerticalEdge
    let depth: CGFloat

    public init(_ edge: VerticalEdge, depth: CGFloat) {
        self.edge = edge
        self.depth = depth
    }

    public var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.6), location: 0.45), .init(color: .clear, location: 1)],
                    startPoint: edge == .top ? .top : .bottom,
                    endPoint: edge == .top ? .bottom : .top
                )
            )
            .frame(height: depth)
            .frame(maxHeight: .infinity, alignment: edge == .top ? .top : .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
