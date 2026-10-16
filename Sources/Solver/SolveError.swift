/// Why a simulation produced no trajectory. A solver that can't finish reports it; it never
/// returns values for days it didn't reach.
public enum SolveError: Error, Equatable, Sendable {
    /// RK4's integration step is past the model's stability limit, where the result grows without
    /// bound instead of decaying.
    case unstableStep(step: Double, stableLimit: Double)
    /// RK45 used its whole step budget and stopped at `reachedDay`.
    case stepBudgetExhausted(reachedDay: Double, finalDay: Double, steps: Int)
    /// RK45's step size underflowed at `day`.
    case stepUnderflow(day: Double)
}
