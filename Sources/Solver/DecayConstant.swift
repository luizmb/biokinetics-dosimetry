import Foundation

/// Returns the radioactive decay constant `λ = ln(2) / halfLife`.
///
/// Pass `halfLife ≤ 0` for stable substances; returns `0`.
public func decayConstant(halfLife: Double) -> Double {
    halfLife > 0 ? log(2) / halfLife : 0
}
