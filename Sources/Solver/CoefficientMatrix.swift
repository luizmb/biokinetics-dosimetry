import Math
import RealNumber

/// Builds the coefficient matrix `A` for the linear ODE `dx/dt = A·x`.
///
/// - Parameters:
///   - count: Number of compartments `n`.
///   - connections: Directed transfer rates as index pairs `(fromIndex, toIndex, rate)`.
///   - decay: Radioactive decay constant `λ`. Use `decayConstant(halfLife:)` to compute it.
///
/// Matrix layout:
/// - Off-diagonal `A[j, i] = rate` — inflow into compartment `j` from `i`.
/// - Diagonal `A[i, i] = −λ − Σ outflow rates from i`.
public func buildCoefficientMatrix(
    count n: Int,
    connections: [(fromIndex: Int, toIndex: Int, rate: Double)],
    decay: Double
) -> Matrix<Double> {
    let inflows: [(row: Int, col: Int, value: Double)] = connections.map {
        (row: $0.toIndex, col: $0.fromIndex, value: $0.rate)
    }
    let outflowByCompartment = connections.reduce(into: [Int: Double]()) {
        $0[$1.fromIndex, default: 0] += $1.rate
    }
    let diagonals: [(row: Int, col: Int, value: Double)] = (0 ..< n).map { i in
        (row: i, col: i, value: -decay - (outflowByCompartment[i] ?? 0))
    }
    let storage = (inflows + diagonals).reduce(into: [Double](repeating: 0, count: n * n)) {
        $0[$1.row * n + $1.col] = $1.value
    }
    return Matrix(rows: n, columns: n, storage: storage)
}
