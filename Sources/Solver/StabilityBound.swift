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

extension StepBudget {
    /// The RK45 step allowance (accepted + rejected) for `days` of a model whose eigenvalues are
    /// bounded by `rateBound`, plus a fixed allowance for the start, where the controller is still
    /// finding its step.
    func steps(rateBound: Double, days: Double) -> Int {
        let perDay: Double = switch self {
        case .automatic: 4 * rateBound / dormandPrinceStabilityInterval
        case .loose: 50
        case .stiff: 5_000
        }
        return Int((perDay * days).rounded(.up)) + 2_000
    }
}
