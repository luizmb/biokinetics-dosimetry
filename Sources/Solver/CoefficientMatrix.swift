import Math
import RealNumber

/// Builds the coefficient matrix `A` for the linear ODE `dx/dt = A·x`.
///
/// - Parameters:
///   - count: Number of compartments `n`.
///   - connections: Directed transfer rates as index pairs `(fromIndex, toIndex, rate)`.
///   - decays: Per-compartment radioactive decay constants `λᵢ`. Use `decayConstant(halfLife:)`
///     to compute each value; pass `0` for stable compartments.
///
/// Matrix layout:
/// - Off-diagonal `A[j, i] = rate` — inflow into compartment `j` from `i`.
/// - Diagonal `A[i, i] = −λᵢ − Σ outflow rates from i`.
public func buildCoefficientMatrix(
    count n: Int,
    connections: [(fromIndex: Int, toIndex: Int, rate: Double)],
    decays: [Double]
) -> Matrix<Double> {
    let inflows: [(row: Int, col: Int, value: Double)] = connections.map {
        (row: $0.toIndex, col: $0.fromIndex, value: $0.rate)
    }
    let outflowByCompartment = connections.reduce(into: [Int: Double]()) {
        $0[$1.fromIndex, default: 0] += $1.rate
    }
    let diagonals: [(row: Int, col: Int, value: Double)] = (0 ..< n).map { i in
        (row: i, col: i, value: -(decays[i]) - (outflowByCompartment[i] ?? 0))
    }
    let storage = (inflows + diagonals).reduce(into: [Double](repeating: 0, count: n * n)) {
        $0[$1.row * n + $1.col] = $1.value
    }
    return Matrix(rows: n, columns: n, storage: storage)
}
