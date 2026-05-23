public enum SolverMethod: Equatable, Hashable, Sendable {
    case birchall(composition: BirchallComposition)
    case rungeKutta4(stepSize: Double)
    case rungeKutta45(tolerance: Double)
}

extension SolverMethod {
    /// Convenience: Birchall with the default `.perTime` composition.
    public static var birchall: SolverMethod { .birchall(composition: .perTime) }
}
