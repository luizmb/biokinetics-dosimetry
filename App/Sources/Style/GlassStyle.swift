import SwiftUI

// MARK: - Glass Style

/// The three selectable glass aesthetics from the design (Aqua = glossy candy,
/// Liquid = iOS 26 liquid glass, Frost = soft frosted).
public enum GlassStyle: String, Sendable, CaseIterable {
    case aqua, liquid, frost
}

// MARK: - Glass Tokens

/// Pre-computed color and surface values for a given dark-mode + style combination.
/// Matches the `glassTokens(dark, style)` function in the JS prototype.
public struct GlassTokens: Sendable {

    // MARK: Ink

    public let isDark: Bool
    public let style: GlassStyle

    public let ink:   Color   // primary text
    public let muted: Color   // secondary text
    public let faint: Color   // tertiary / labels
    public let hair:  Color   // ultra-thin dividers

    // MARK: Accent (iOS blue)

    public let accent:     Color
    public let accentTop:  Color
    public let accentBot:  Color
    public let accentGlow: Color  // box-shadow color for accent buttons

    // MARK: Per-style surface

    public let tintColor:  Color   // semi-opaque tint applied over material
    public let sheen:      Double  // top-gloss opacity (full strength)
    public let sheenMid:   Double  // top-gloss opacity at 60% height
    public let edgeColor:  Color   // 0.5px border stroke
    public let ringColor:  Color   // outer ring (very faint)
    public let innerTop:   Color   // inset top highlight
    public let innerBot:   Color   // inset bottom highlight

    // MARK: Shadow (lift)

    public let shadowRadius: CGFloat
    public let shadowY:      CGFloat
    public let shadowColor:  Color

    // MARK: Page background gradient colors

    public let bgStart: Color
    public let bgEnd:   Color

    // MARK: - Init

    public init(isDark: Bool, style: GlassStyle) {
        self.isDark = isDark
        self.style  = style

        ink   = isDark ? Color(hex: 0xF3F1EC) : Color(hex: 0x16140F)
        muted = isDark ? Color(hex: 0xF3F1EC).opacity(0.62) : Color(hex: 0x16140F).opacity(0.55)
        faint = isDark ? Color(hex: 0xF3F1EC).opacity(0.40) : Color(hex: 0x16140F).opacity(0.36)
        hair  = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)

        accent     = isDark ? Color(hex: 0x3B9BFF) : Color(hex: 0x0A74F0)
        accentTop  = isDark ? Color(hex: 0x5FB0FF) : Color(hex: 0x46A3FF)
        accentBot  = isDark ? Color(hex: 0x1F6FD6) : Color(hex: 0x0A63D8)
        accentGlow = isDark ? Color(hex: 0x2882FF).opacity(0.55) : Color(hex: 0x0A74F0).opacity(0.45)

        // Dark mode: warm indigo/purple instead of cold steel-blue.
        bgStart = isDark ? Color(hex: 0x1D1632) : Color(hex: 0xEAF2FF)   // deep warm indigo
        bgEnd   = isDark ? Color(hex: 0x0E0B18) : Color(hex: 0xE7E9EF)   // warm near-black

        switch style {
        case .aqua:
            tintColor  = isDark ? Color(hex: 0x3A3248).opacity(0.58) : Color.white.opacity(0.62)
            sheen      = isDark ? 0.32 : 0.85
            sheenMid   = isDark ? 0.08 : 0.30
            edgeColor  = isDark ? Color.white.opacity(0.24) : Color.white.opacity(0.95)
            ringColor  = isDark ? Color.black.opacity(0.40) : Color.black.opacity(0.10)
            innerTop   = isDark ? Color.white.opacity(0.22) : Color.white.opacity(0.95)
            innerBot   = isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.45)
            shadowRadius = isDark ? 18 : 16; shadowY = 6
            shadowColor  = isDark ? Color(hex: 0x0E0A1A).opacity(0.55) : Color(hex: 0x141E3C).opacity(0.16)

        case .liquid:
            tintColor  = isDark ? Color(hex: 0x302946).opacity(0.44) : Color.white.opacity(0.48)  // warm purple glass
            sheen      = isDark ? 0.18 : 0.55
            sheenMid   = isDark ? 0.04 : 0.16
            edgeColor  = isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.75)
            ringColor  = isDark ? Color.black.opacity(0.35) : Color.black.opacity(0.07)
            innerTop   = isDark ? Color.white.opacity(0.16) : Color.white.opacity(0.70)
            innerBot   = isDark ? Color(hex: 0xB088FF).opacity(0.06) : Color.white.opacity(0.30)  // subtle lavender glow
            shadowRadius = isDark ? 26 : 24; shadowY = 8
            shadowColor  = isDark ? Color(hex: 0x0E0A1A).opacity(0.50) : Color(hex: 0x141E3C).opacity(0.12)

        case .frost:
            tintColor  = isDark ? Color(hex: 0x2A2440).opacity(0.68) : Color(hex: 0xF8F8FA).opacity(0.72)  // warm deep purple
            sheen      = isDark ? 0.12 : 0.30
            sheenMid   = isDark ? 0.03 : 0.08
            edgeColor  = isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.55)
            ringColor  = isDark ? Color.black.opacity(0.30) : Color.black.opacity(0.05)
            innerTop   = isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.50)
            innerBot   = isDark ? Color(hex: 0xB088FF).opacity(0.04) : Color.white.opacity(0.20)
            shadowRadius = isDark ? 24 : 22; shadowY = 8
            shadowColor  = isDark ? Color(hex: 0x0E0A1A).opacity(0.44) : Color(hex: 0x141E3C).opacity(0.10)
        }
    }
}

// MARK: - Environment Key

private struct GlassTokensKey: EnvironmentKey {
    static let defaultValue = GlassTokens(isDark: false, style: .liquid)
}

public extension EnvironmentValues {
    var glassTokens: GlassTokens {
        get { self[GlassTokensKey.self] }
        set { self[GlassTokensKey.self] = newValue }
    }
}

public extension View {
    func glassStyle(_ style: GlassStyle, isDark: Bool) -> some View {
        environment(\.glassTokens, GlassTokens(isDark: isDark, style: style))
    }
}

// MARK: - Color Helpers

public extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func blended(with other: Color) -> Color { self }  // placeholder: CSS mix not needed
}

// MARK: - App background

/// Full-screen page background that matches the design's radial gradient.
/// Use as the bottom layer of a ZStack inside each screen view.
public struct GlassAppBackground: View {
    @Environment(\.glassTokens) private var g

    public init() {}

    public var body: some View {
        ZStack {
            // Solid base.
            g.bgEnd.ignoresSafeArea()
            // Top-left bloom.
            RadialGradient(
                colors: [g.bgStart, .clear],
                center: .init(x: 0.18, y: -0.04),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()
            // Extra warm accent glow in dark mode (bottom-right corner) —
            // adds depth and counteracts the cold look of plain dark backgrounds.
            if g.isDark {
                RadialGradient(
                    colors: [Color(hex: 0x2A1845).opacity(0.55), .clear],
                    center: .init(x: 0.85, y: 0.90),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }
        }
    }
}
