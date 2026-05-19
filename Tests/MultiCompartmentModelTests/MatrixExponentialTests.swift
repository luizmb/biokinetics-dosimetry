import XCTest
@testable import MultiCompartmentModel

final class MatrixExponentialTests: XCTestCase {
    private let tolerance = 1e-10

    func testExpOfZeroIsIdentity() {
        let result = matrixExponential(Matrix.zero(size: 4))
        assertEqual(result, Matrix.identity(size: 4))
    }

    func testExpOfDiagonalMatrix() {
        // exp(diag(d_1, d_2, ...)) = diag(e^{d_1}, e^{d_2}, ...)
        let D = Matrix(rows: 3, columns: 3, storage: [
            -0.5, 0, 0,
            0, -1.0, 0,
            0, 0, -2.0
        ])
        let result = matrixExponential(D)
        let expected = Matrix(rows: 3, columns: 3, storage: [
            exp(-0.5), 0, 0,
            0, exp(-1.0), 0,
            0, 0, exp(-2.0)
        ])
        assertEqual(result, expected)
    }

    func testExpOfNilpotentMatrix() {
        // For N nilpotent with N² = 0, exp(N) = I + N exactly.
        let N = Matrix(rows: 3, columns: 3, storage: [
            0, 1, 0,
            0, 0, 0,
            0, 0, 0
        ])
        let result = matrixExponential(N)
        let expected = Matrix.identity(size: 3)
            + Matrix(rows: 3, columns: 3, storage: [
                0, 1, 0,
                0, 0, 0,
                0, 0, 0
            ])
        assertEqual(result, expected)
    }

    func testExpOfTwoCompartmentDecay() {
        // A = [[-k, 0], [k, 0]] is the matrix for da/dt = -k a, db/dt = k a.
        // exp(A*t) = [[e^{-kt}, 0], [1 - e^{-kt}, 1]].
        let k = 0.3
        let t = 5.0
        let A = Matrix(rows: 2, columns: 2, storage: [
            -k * t, 0,
            k * t, 0
        ])
        let result = matrixExponential(A)
        let expected = Matrix(rows: 2, columns: 2, storage: [
            exp(-k * t), 0,
            1 - exp(-k * t), 1
        ])
        assertEqual(result, expected)
    }

    func testExpOfNegativeIdentityIsScaledIdentity() {
        // exp(-cI) = e^{-c} I
        let c = 0.7
        let A = -c * Matrix.identity(size: 4)
        let result = matrixExponential(A)
        let expected = exp(-c) * Matrix.identity(size: 4)
        assertEqual(result, expected)
    }

    func testRepeatedSquare() {
        let A = Matrix(rows: 2, columns: 2, storage: [1, 1, 0, 1])
        let squaredOnce = repeatedSquare(A, times: 1)
        let squaredTwice = repeatedSquare(A, times: 2)
        XCTAssertEqual(squaredOnce, A * A)
        XCTAssertEqual(squaredTwice, A * A * (A * A))
    }

    func testRepeatedSquareZeroTimesIsIdentityFunction() {
        let A = Matrix(rows: 3, columns: 3, storage: (1...9).map(Double.init))
        XCTAssertEqual(repeatedSquare(A, times: 0), A)
    }

    func testScalingPowerForBelowThreshold() {
        XCTAssertEqual(scalingPower(forMinDiagonal: 0), 0)
        XCTAssertEqual(scalingPower(forMinDiagonal: -0.1), 0)
        XCTAssertEqual(scalingPower(forMinDiagonal: -0.19), 0)
    }

    func testScalingPowerScalesUntilUnderThreshold() {
        XCTAssertEqual(scalingPower(forMinDiagonal: -0.2), 1)
        XCTAssertEqual(scalingPower(forMinDiagonal: -0.4), 2)
        // 100 / 2^9 ≈ 0.195 < 0.2; 100 / 2^8 ≈ 0.391 > 0.2 → iz = 9.
        XCTAssertEqual(scalingPower(forMinDiagonal: -100), 9)
    }

    func testConvergedTrueWhenAllRatiosTiny() {
        let sum = Matrix.identity(size: 2)
        let term = 1e-15 * Matrix.identity(size: 2)
        XCTAssertTrue(converged(term: term, sum: sum, tolerance: 1e-10))
    }

    func testConvergedFalseWhenAnyRatioAboveTolerance() {
        let sum = Matrix.identity(size: 2)
        let term = 1e-5 * Matrix.identity(size: 2)
        XCTAssertFalse(converged(term: term, sum: sum, tolerance: 1e-10))
    }

    func testConvergedTrueOnNegativeRatiosWhenBelowTolerance() {
        // The original C# omitted abs() — this test guards the fix.
        let sum = Matrix(rows: 1, columns: 1, storage: [1.0])
        let term = Matrix(rows: 1, columns: 1, storage: [-1e-15])
        XCTAssertTrue(converged(term: term, sum: sum, tolerance: 1e-10))
    }

    func testConvergedFalseOnLargeNegativeRatios() {
        // Without abs(), -0.5 < 1e-10 would be (incorrectly) treated as converged.
        let sum = Matrix(rows: 1, columns: 1, storage: [1.0])
        let term = Matrix(rows: 1, columns: 1, storage: [-0.5])
        XCTAssertFalse(converged(term: term, sum: sum, tolerance: 1e-10))
    }

    private func assertEqual(_ lhs: Matrix, _ rhs: Matrix, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.rows, rhs.rows, file: file, line: line)
        XCTAssertEqual(lhs.columns, rhs.columns, file: file, line: line)
        for (l, r) in zip(lhs.storage, rhs.storage) {
            XCTAssertEqual(l, r, accuracy: tolerance, file: file, line: line)
        }
    }
}
