import SwiftUI

// MARK: - GlassBackdrop

/// What sits under the glass: a graph-paper grid that moves with the canvas (`origin` is where
/// canvas `(0, 0)` lands on screen, `scale` its zoom), so panning slides it under the glass and the
/// glass has straight lines to bend.
public struct GlassBackdrop: View {
    let origin: CGPoint
    let scale: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(origin: CGPoint = .zero, scale: CGFloat = 1) {
        self.origin = origin
        self.scale = scale
    }

    public var body: some View {
        Canvas { context, size in
            let ink: Color = colorScheme == .dark ? .white : .black
            drawGrid(in: &context, size: size, ink: ink)
        }
        .background(colorScheme == .dark ? Color(white: 0.09) : Color(white: 0.965))
    }

    /// Minor lines every 28 canvas units, a stronger line every fifth. Below ~10 pt apart only the
    /// major lines are drawn, so zooming out doesn't turn the grid into a grey wash.
    private func drawGrid(in context: inout GraphicsContext, size: CGSize, ink: Color) {
        let step = 28 * scale
        let minor = GraphicsContext.Shading.color(ink.opacity(colorScheme == .dark ? 0.06 : 0.05))
        let major = GraphicsContext.Shading.color(ink.opacity(colorScheme == .dark ? 0.11 : 0.09))
        let drawMinor = step >= 10

        for axis in [Axis.horizontal, .vertical] {
            let length = axis == .horizontal ? size.width : size.height
            let start = axis == .horizontal ? origin.x : origin.y
            let first = Int((-start / step).rounded(.down))
            let last = Int(((length - start) / step).rounded(.up))
            for index in first ... max(first, last) {
                let isMajor = index.isMultiple(of: 5)
                guard isMajor || drawMinor else { continue }
                let position = start + CGFloat(index) * step
                var line = Path()
                if axis == .horizontal {
                    line.move(to: CGPoint(x: position, y: 0))
                    line.addLine(to: CGPoint(x: position, y: size.height))
                } else {
                    line.move(to: CGPoint(x: 0, y: position))
                    line.addLine(to: CGPoint(x: size.width, y: position))
                }
                context.stroke(line, with: isMajor ? major : minor, lineWidth: isMajor ? 1 : 0.5)
            }
        }
    }
}
