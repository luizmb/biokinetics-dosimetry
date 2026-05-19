import Foundation

public func matrixExponential(
    _ A: Matrix,
    tolerance: Double = 1e-10,
    maxIterations: Int = 10_000
) -> Matrix {
    let n = A.rows
    let minDiagonal = (0 ..< n).map { A[$0, $0] }.min() ?? 0
    let scalingPower = scalingPower(forMinDiagonal: minDiagonal)
    let scaled = (1.0 / exp(log(2) * Double(scalingPower))) * A

    let exponentiated = taylorExponential(of: scaled, tolerance: tolerance, maxIterations: maxIterations)
    return repeatedSquare(exponentiated, times: scalingPower)
}

func scalingPower(forMinDiagonal minDiagonal: Double, threshold: Double = 0.2) -> Int {
    (0 ... 1000).first { -minDiagonal / exp(log(2) * Double($0)) < threshold } ?? 1000
}

func taylorExponential(of A: Matrix, tolerance: Double, maxIterations: Int) -> Matrix {
    let identity = Matrix.identity(size: A.rows)
    var sum = identity
    var term = identity
    for ir in 1 ... maxIterations {
        term = (1.0 / Double(ir)) * (term * A)
        sum = sum + term
        if converged(term: term, sum: sum, tolerance: tolerance) { return sum }
    }
    return sum
}

func converged(term: Matrix, sum: Matrix, tolerance: Double) -> Bool {
    zip(term.storage, sum.storage).allSatisfy { termValue, sumValue in
        sumValue == 0 || abs(termValue / sumValue) <= tolerance
    }
}

func repeatedSquare(_ A: Matrix, times: Int) -> Matrix {
    (0 ..< times).reduce(A) { acc, _ in acc * acc }
}
