import Domain
import Math

// The explicit solvers are limited by the model's fastest rate: RK4 is stable only for
// h·|λ| < 2.785 on the negative real axis (compartmental eigenvalues sit there), Dormand–Prince
// for about 3.3. `spectralBound` bounds |λ| from above with the smaller of the matrix's row- and
// column-sum norms, both valid bounds on the spectral radius and cheap to read off the matrix.

/// RK4's stability interval on the negative real axis.
let rk4StabilityInterval = 2.785

/// Dormand–Prince's, roughly.
let dormandPrinceStabilityInterval = 3.3

/// An upper bound on the magnitude of every eigenvalue of `A`.
func spectralBound(_ A: Matrix<Double>) -> Double {
    let n = A.rows
    let rows = (0 ..< n).map { i in (0 ..< n).reduce(0.0) { $0 + abs(A[i, $1]) } }.max() ?? 0
    let columns = (0 ..< n).map { j in (0 ..< n).reduce(0.0) { $0 + abs(A[$1, j]) } }.max() ?? 0
    return min(rows, columns)
}

/// What a model allows the explicit solvers, read off its matrix before anything runs.
public struct SolverLimits: Equatable, Sendable {
    /// RK4 grows without bound at or above this integration step (days).
    public let rk4StableStep: Double
    /// Steps per simulated day RK45 is expected to need: its stability limit, which on a stiff model
    /// sets the step whatever the tolerance.
    public let rk45StepsPerDay: Double

    /// The `.automatic` budget, per day: four times the expectation.
    public var automaticStepsPerDay: Int { Int((4 * rk45StepsPerDay).rounded(.up)) }

    /// Roughly where a run capped at `stepsPerDay` stops, or `nil` when the cap covers `days`.
    public func stoppingDay(stepsPerDay: Int, days: Double) -> Double? {
        let allowed = Double(stepsPerDay) * days + Double(StepBudget.startAllowance)
        let needed = rk45StepsPerDay * days
        return allowed >= needed ? nil : allowed / rk45StepsPerDay
    }
}

public extension CompartmentalModel {
    /// The explicit solvers' limits for this model.
    var solverLimits: SolverLimits {
        let bound = spectralBound(linearSystem().matrix)
        return SolverLimits(
            rk4StableStep: rk4StabilityInterval / bound,
            rk45StepsPerDay: bound / dormandPrinceStabilityInterval
        )
    }
}

extension StepBudget {
    /// Steps the controller may spend finding its step at the start, on top of the per-day budget.
    static let startAllowance = 2_000

    /// The RK45 step allowance (accepted + rejected) for `days` of a model with these limits.
    func steps(limits: SolverLimits, days: Double) -> Int {
        let perDay = switch self {
        case .automatic: limits.automaticStepsPerDay
        case let .manual(stepsPerDay): max(1, stepsPerDay)
        }
        return Int((Double(perDay) * days).rounded(.up)) + Self.startAllowance
    }
}
