import SwiftUI
import VitralTokens

// MARK: - SwatchColor
//
// A palette of eight named colors used to visually distinguish node types on
// a canvas.  The type is intentionally generic — it describes a swatch, not
// a domain concept.  The mapping of swatch to compartment meaning lives in
// the application layer (AppDomain / feature targets).

public enum SwatchColor: String, CaseIterable, Codable, Hashable, Sendable {
    case steel, amber, crimson, forest, violet, slate, rose, ochre

    /// Perceptual hue angle in degrees (0–360).
    public var hue: Double {
        switch self {
        case .steel:   215
        case .amber:    35
        case .crimson:   2
        case .forest:  145
        case .violet:  275
        case .slate:   230
        case .rose:    350
        case .ochre:    55
        }
    }

    // MARK: - Generic color roles

    /// Filled background of a swatch chip / node body.
    public func background(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.14 : 0.10,
              brightness: dark ? 0.36 : 0.97)
    }

    /// Stroke / border around the swatch chip.
    public func border(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.30 : 0.32,
              brightness: dark ? 0.60 : 0.70)
    }

    /// Small indicator dot or badge fill.
    public func indicator(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.28 : 0.36,
              brightness: dark ? 0.52 : 0.50)
    }

    /// Text rendered on top of the `background` fill.
    public func foreground(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.04 : 0.22,
              brightness: dark ? 0.94 : 0.24)
    }

    /// Soft halo shown when this swatch is selected.
    public func selectionGlow(dark: Bool = false) -> Color {
        Color(hue: hue / 360, saturation: 0.45, brightness: dark ? 0.65 : 0.55)
            .opacity(0.35)
    }

    // MARK: - Canvas gradient

    /// Three-stop vertical gradient for a glass-tile node body.
    public func surfaceGradient(dark: Bool = false) -> LinearGradient {
        let top    = Color(hue: hue / 360, saturation: dark ? 0.18 : 0.06, brightness: dark ? 0.50 : 0.98)
        let middle = Color(hue: hue / 360, saturation: dark ? 0.16 : 0.10, brightness: dark ? 0.38 : 0.93)
        let bottom = Color(hue: hue / 360, saturation: dark ? 0.14 : 0.14, brightness: dark ? 0.26 : 0.86)
        return LinearGradient(
            stops: [.init(color: top, location: 0),
                    .init(color: middle, location: 0.55),
                    .init(color: bottom, location: 1)],
            startPoint: .top, endPoint: .bottom
        )
    }

}

// MARK: - Back-compat typealias
//
// All existing code that still says `CompartmentTint` continues to compile
// without source changes.  Migrate call sites to `SwatchColor` incrementally.

public typealias CompartmentTint = SwatchColor

// MARK: - Tokens
//
// The same roles as Vitral colour tokens, light and dark in one value, for Vitral components
// (swatches, swatch stacks) that take tokens rather than colours.

public extension SwatchColor {
    /// A swatch's fill, light and dark.
    var backgroundToken: ColorToken {
        ColorToken(light: hsb(saturation: 0.10, brightness: 0.97), dark: hsb(saturation: 0.14, brightness: 0.36))
    }

    /// A swatch's edge, light and dark.
    var borderToken: ColorToken {
        ColorToken(light: hsb(saturation: 0.32, brightness: 0.70), dark: hsb(saturation: 0.30, brightness: 0.60))
    }

    /// A dot or badge, light and dark.
    var indicatorToken: ColorToken {
        ColorToken(light: hsb(saturation: 0.36, brightness: 0.50), dark: hsb(saturation: 0.28, brightness: 0.52))
    }

    /// This swatch's hue at `saturation` and `brightness`, as RGB.
    func hsb(saturation: Double, brightness: Double) -> RGBA {
        rgb(sector: Int((hue / 60).rounded(.down)) % 6, along: hue / 60 - (hue / 60).rounded(.down), saturation: saturation, brightness: brightness)
    }

    func rgb(sector: Int, along: Double, saturation s: Double, brightness v: Double) -> RGBA {
        switch sector {
        case 0: RGBA(red: v, green: v * (1 - s * (1 - along)), blue: v * (1 - s))
        case 1: RGBA(red: v * (1 - s * along), green: v, blue: v * (1 - s))
        case 2: RGBA(red: v * (1 - s), green: v, blue: v * (1 - s * (1 - along)))
        case 3: RGBA(red: v * (1 - s), green: v * (1 - s * along), blue: v)
        case 4: RGBA(red: v * (1 - s * (1 - along)), green: v * (1 - s), blue: v)
        default: RGBA(red: v, green: v * (1 - s), blue: v * (1 - s * along))
        }
    }
}
