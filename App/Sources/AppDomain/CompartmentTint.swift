import SwiftUI

/// Visual color identity for a compartment node on the canvas.
///
/// Maps to the eight semantic body-compartment colors from the design,
/// approximating the OKLCH palette via HSB. Each tint provides `fill`,
/// `stroke`, `badge`, and `text` roles for both light and dark appearance.
public enum CompartmentTint: String, CaseIterable, Codable, Hashable, Sendable {
    case steel, amber, crimson, forest, violet, slate, rose, ochre

    /// Hue angle in degrees (0–360), shared between light and dark.
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

    // MARK: - Color roles

    public func fillColor(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.14 : 0.10,
              brightness: dark ? 0.36 : 0.97)
    }

    public func strokeColor(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.30 : 0.32,
              brightness: dark ? 0.60 : 0.70)
    }

    public func badgeColor(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.28 : 0.36,
              brightness: dark ? 0.52 : 0.50)
    }

    public func textColor(dark: Bool = false) -> Color {
        Color(hue: hue / 360,
              saturation: dark ? 0.04 : 0.22,
              brightness: dark ? 0.94 : 0.24)
    }

    /// Accent ring shown when a compartment is selected.
    public func selectionGlow(dark: Bool = false) -> Color {
        Color(hue: hue / 360, saturation: 0.45, brightness: dark ? 0.65 : 0.55)
            .opacity(0.35)
    }
}
