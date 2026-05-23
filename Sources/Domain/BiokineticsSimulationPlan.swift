/// Configuration for a biokinetic simulation run.
///
/// A pure value type — no computation, no math. Describes *what* to simulate
/// and *how*; the actual solving is done by the `Solver` module.
public struct BiokineticsSimulationPlan: Equatable, Hashable, Sendable {
    /// Output interval in days.
    public let step: Int
    /// Radionuclide half-life in days. Pass `0` for stable substances.
    public let halfLife: Double
    /// Total integration horizon in days.
    public let final: Int
    /// Numerical method to use.
    public let solver: SolverMethod

    public init(
        step: Int,
        halfLife: Double,
        final: Int,
        solver: SolverMethod = .birchall
    ) {
        self.step = step
        self.halfLife = halfLife
        self.final = final
        self.solver = solver
    }

    /// Number of output rows (excluding the two boundary points).
    public var stepCount: Int { final / step }
}
