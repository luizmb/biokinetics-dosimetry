import Style
import SwiftUI

// MARK: - GlassBackground

/// Layered specular glass surface — equivalent to the JS prototype's `Specular` component.
/// Applied as `.glassBackground(cornerRadius:intensity:)`.
///
/// Layers (bottom → top):
///   1. UltraThinMaterial backdrop blur
///   2. Semi-opaque tint overlay
///   3. Top-half gloss gradient (white sheen)
///   4. 0.5 px edge stroke with inner-shadow ring
public struct GlassBackground: ViewModifier {
    @Environment(\.glassTokens) private var g
    let cornerRadius: CGFloat
    let intensity: Double

    public func body(content: Content) -> some View {
        content
            .background(glassStack)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: g.shadowColor, radius: g.shadowRadius, y: g.shadowY)
    }

    @ViewBuilder
    private var glassStack: some View {
        ZStack {
            // 1. Solid base — ensures legible contrast even on colourful backgrounds.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(g.isDark ? Color(white: 0.11) : Color(white: 0.97))
                .opacity(0.45)

            // 2. Blur + material
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            // 3. Tint
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(g.tintColor)

            // 3. Top gloss sheen (covers ~58% of height)
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(g.sheen * intensity), location: 0),
                    .init(color: Color.white.opacity(g.sheenMid * intensity), location: 0.60),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // 4. Edge highlight + ring
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(g.edgeColor, lineWidth: 0.5)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: -0.5)
                .strokeBorder(g.ringColor, lineWidth: 0.5)
        }
    }
}

public extension View {
    func glassBackground(cornerRadius: CGFloat = 20, intensity: Double = 1.0) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, intensity: intensity))
    }

    /// Injects `GlassTokens` that automatically track the system color scheme.
    /// Apply once at the root of the scene; all descendants inherit the tokens.
    func glassEnvironment(style: GlassStyle = .liquid) -> some View {
        modifier(GlassEnvironmentModifier(style: style))
    }
}

// MARK: - GlassEnvironmentModifier

/// Reads `colorScheme` from the environment and injects matching `GlassTokens`
/// so every descendant automatically gets the correct dark/light surface recipe.
private struct GlassEnvironmentModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let style: GlassStyle

    func body(content: Content) -> some View {
        content.environment(\.glassTokens, GlassTokens(isDark: colorScheme == .dark, style: style))
    }
}

// MARK: - GlassDivider

public struct GlassDivider: View {
    @Environment(\.glassTokens) private var g
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(g.hair)
            .frame(height: 0.5)
    }
}

public struct GlassVDivider: View {
    @Environment(\.glassTokens) private var g
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(g.hair)
            .frame(width: 0.5)
    }
}
