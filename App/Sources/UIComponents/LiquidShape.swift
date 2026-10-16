import SwiftUI

// MARK: - LiquidShape

/// Liquid filling a container from the bottom: `level` 0…1 of the height, with a surface tilted by
/// `tilt` radians (so it can stay level while the device turns) and a slight meniscus. Clip it to
/// the container's shape. Both values animate.
public struct LiquidShape: Shape {
    public var level: Double
    public var tilt: Double

    public init(level: Double, tilt: Double = 0) {
        self.level = level
        self.tilt = tilt
    }

    public var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, tilt) }
        set { (level, tilt) = (newValue.first, newValue.second) }
    }

    public func path(in rect: CGRect) -> Path {
        let surface = rect.maxY - rect.height * min(max(level, 0), 1)
        let rise = tan(tilt) * rect.width / 2
        let meniscus = rect.height * 0.035
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: surface + rise))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: surface - rise),
            control: CGPoint(x: rect.midX, y: surface + meniscus)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
