/// Configuration for a biokinetic simulation run.
///
/// A pure value type — no computation, no math. Describes *what* to simulate
/// and *how*; the actual solving is done by the `Solver` module.
///
/// Half-life is **not** part of the plan — it lives on each `Nuclide` inside
/// the `CompartmentalModel`, allowing decay-chain models to carry per-nuclide
/// decay constants and supporting sub-day precision for radiopharmaceuticals.
public struct BiokineticsSimulationPlan: Equatable, Hashable, Sendable {
    /// Output recording interval in days (may be fractional — e.g. 0.1 for
    /// 2.4-hour steps when modelling short-lived radiopharmaceuticals).
    public let step: Double
    /// Total integration horizon in days (may be fractional).
    public let final: Double
    /// Numerical method to use.
    public let solver: SolverMethod

    public init(
        step: Double,
        final: Double,
        solver: SolverMethod = .birchall
    ) {
        self.step = step
        self.final = final
        self.solver = solver
    }

    /// Number of output intervals. Total row count is `stepCount + 2`
    /// (t = 0 boundary, `stepCount` interior steps, and one extra step at t = final + step).
    public var stepCount: Int { Int((final / step).rounded()) }
}
