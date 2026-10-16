import Style
import SwiftUI

// MARK: - GlassBackdrop

/// What sits under the glass. Liquid Glass bends and reflects whatever is behind it, and over a flat
/// colour there is nothing to see; fine graph-paper lines visibly bend at a glass edge, and a few
/// large, very soft colour fields give it something to pick up.
///
/// The lines follow the canvas (`origin` is where canvas `(0, 0)` lands on screen, `scale` its
/// zoom), so panning slides them under the glass. The colour fields stay put.
public struct GlassBackdrop: View {
    let origin: CGPoint
    let scale: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public init(origin: CGPoint = .zero, scale: CGFloat = 1) {
        self.origin = origin
        self.scale = scale
    }

    public var body: some View {
        ZStack {
            MeshGradient(width: 3, height: 3, points: Self.points, colors: palette)
            Canvas { context, size in
                drawGrid(in: &context, size: size)
            }
        }
    }

    private static let points: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.58, 0.42], [1, 0.5],
        [0, 1], [0.45, 1], [1, 1]
    ]

    /// Swatch hues at very low saturation: tinted daylight, not colour.
    private var palette: [Color] {
        let dark = colorScheme == .dark
        let field: (SwatchColor, Double) -> Color = { swatch, lift in
            Color(hue: swatch.hue / 360, saturation: dark ? 0.32 : 0.16, brightness: dark ? 0.16 + lift : 0.93 + lift)
        }
        return [
            field(.steel, 0.04), field(.slate, 0.02), field(.violet, 0.03),
            field(.forest, 0.0), field(.steel, 0.06), field(.rose, 0.01),
            field(.amber, 0.02), field(.violet, 0.0), field(.steel, 0.03)
        ]
    }

    /// Minor lines every 28 canvas units, a stronger line every fifth. Below ~10 pt apart only the
    /// major lines are drawn, so zooming out doesn't turn the grid into a grey wash.
    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        let step = 28 * scale
        let ink: Color = colorScheme == .dark ? .white : .black
        let minor = GraphicsContext.Shading.color(ink.opacity(colorScheme == .dark ? 0.05 : 0.045))
        let major = GraphicsContext.Shading.color(ink.opacity(colorScheme == .dark ? 0.09 : 0.08))
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
