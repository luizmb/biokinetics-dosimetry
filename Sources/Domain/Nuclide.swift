import FPMacros

/// A radionuclide identity with its physical half-life.
///
/// Each `Compartment` in a `CompartmentalModel` is assigned to exactly one nuclide
/// via `Compartment.nuclideId`. The solver uses `Nuclide.halfLife` to derive the
/// per-compartment radioactive decay constant `λ = ln(2) / halfLife`.
///
/// Single-nuclide models (I-131, Cs-137, …) contain one `Nuclide`.
/// Decay-chain models (U-238 → Th-234 → …) contain one entry per member of
/// the chain; cross-nuclide `CompartmentConnection`s encode the production rates.
@Lenses(init: .public)
public struct Nuclide: Hashable, Identifiable, Sendable {
    /// Stable identifier used to link compartments to this nuclide.
    public let id: String
    /// Human-readable nuclide name (e.g. "I-131", "U-238").
    public let name: String
    /// Physical half-life in days. `0` means stable (no radioactive decay).
    public let halfLife: Double
}
