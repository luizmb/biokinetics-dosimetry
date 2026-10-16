import SwiftUI

// MARK: - EdgeFade

/// A soft fade where content runs under a bar: a thin blur, strongest at the screen edge and gone
/// `beyond` points past the safe area, like a scroll view's edge effect for content that isn't a
/// scroll view. Its depth is the measured safe-area inset on that edge (bars, home indicator, any
/// device-specific inset), never a fixed height. Draws into the safe area and never takes touches.
public struct EdgeFade: View {
    let edge: VerticalEdge
    let beyond: CGFloat

    public init(_ edge: VerticalEdge, beyond: CGFloat = 28) {
        self.edge = edge
        self.beyond = beyond
    }

    public var body: some View {
        GeometryReader { geo in
            let inset = edge == .top ? geo.safeAreaInsets.top : geo.safeAreaInsets.bottom
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.6), location: 0.45), .init(color: .clear, location: 1)],
                        startPoint: edge == .top ? .top : .bottom,
                        endPoint: edge == .top ? .bottom : .top
                    )
                )
                .frame(height: inset + beyond)
                .frame(maxHeight: .infinity, alignment: edge == .top ? .top : .bottom)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}
