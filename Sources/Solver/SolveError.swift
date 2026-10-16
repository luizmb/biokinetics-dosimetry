/// Why a simulation didn't produce the whole trajectory. A solver that can't finish reports it,
/// with what it computed before stopping; it never returns values for days it didn't reach.
public enum SolveError: Error, Equatable, Sendable {
    /// RK4's integration step is past the model's stability limit, where the result grows without
    /// bound instead of decaying.
    case unstableStep(step: Double, stableLimit: Double)
    /// RK45 used its whole step budget and stopped at `reachedDay`. `partial` holds the rows it
    /// did compute, one per output step up to `reachedDay`, as accurate as a finished run's.
    case stepBudgetExhausted(reachedDay: Double, finalDay: Double, steps: Int, partial: [[Double]])
    /// RK45's step size underflowed at `day`; `partial` as above.
    case stepUnderflow(day: Double, partial: [[Double]])
}

public extension SolveError {
    /// The rows computed before the stop: empty when nothing ran.
    var partial: [[Double]] {
        switch self {
        case .unstableStep: []
        case let .stepBudgetExhausted(_, _, _, partial): partial
        case let .stepUnderflow(_, partial): partial
        }
    }

    /// The day the computed rows reach, when the run got anywhere.
    var stoppedAtDay: Double? {
        switch self {
        case .unstableStep: nil
        case let .stepBudgetExhausted(reachedDay, _, _, _): reachedDay
        case let .stepUnderflow(day, _): day
        }
    }
}
