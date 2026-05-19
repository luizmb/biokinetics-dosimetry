import XCTest
@testable import MultiCompartmentModel

final class MatrixTests: XCTestCase {
    private let tolerance = 1e-12

    private let A = Matrix(rows: 2, columns: 2, storage: [1, 2, 3, 4])
    private let B = Matrix(rows: 2, columns: 2, storage: [5, 6, 7, 8])
    private let C = Matrix(rows: 2, columns: 2, storage: [9, 8, 7, 6])

    func testSubscriptRowMajor() {
        XCTAssertEqual(A[0, 0], 1)
        XCTAssertEqual(A[0, 1], 2)
        XCTAssertEqual(A[1, 0], 3)
        XCTAssertEqual(A[1, 1], 4)
    }

    func testIdentityIsDiagonalOnes() {
        let I = Matrix.identity(size: 3)
        XCTAssertEqual(I.storage, [1, 0, 0, 0, 1, 0, 0, 0, 1])
    }

    func testZeroIsAllZeros() {
        XCTAssertEqual(Matrix.zero(size: 3).storage, Array(repeating: 0, count: 9))
    }

    func testAddIsCommutative() {
        assertEqual(A + B, B + A)
    }

    func testAddIsAssociative() {
        assertEqual((A + B) + C, A + (B + C))
    }

    func testAddZeroIsIdentity() {
        assertEqual(A + Matrix.zero(size: 2), A)
    }

    func testScalarMultiplyDistributesOverAddition() {
        let k = 3.0
        assertEqual(k * (A + B), k * A + k * B)
    }

    func testScalarMultiplyByOneIsIdentity() {
        assertEqual(1.0 * A, A)
    }

    func testScalarMultiplyByZeroIsZero() {
        assertEqual(0.0 * A, Matrix.zero(size: 2))
    }

    func testMatrixMultiplyByIdentityIsIdentity() {
        let I = Matrix.identity(size: 2)
        assertEqual(A * I, A)
        assertEqual(I * A, A)
    }

    func testMatrixMultiplyByZeroIsZero() {
        let Z = Matrix.zero(size: 2)
        assertEqual(A * Z, Z)
        assertEqual(Z * A, Z)
    }

    func testMatrixMultiplyIsAssociative() {
        assertEqual((A * B) * C, A * (B * C))
    }

    func testMatrixMultiplyDistributesOverAddition() {
        assertEqual(A * (B + C), A * B + A * C)
        assertEqual((A + B) * C, A * C + B * C)
    }

    func testMatrixMultiplyConcreteCase() {
        let product = A * B
        XCTAssertEqual(product[0, 0], 1 * 5 + 2 * 7)
        XCTAssertEqual(product[0, 1], 1 * 6 + 2 * 8)
        XCTAssertEqual(product[1, 0], 3 * 5 + 4 * 7)
        XCTAssertEqual(product[1, 1], 3 * 6 + 4 * 8)
    }

    func testApplyToVectorMatchesMultiplyByColumnMatrix() {
        let v = [10.0, 20.0]
        let result = A.apply(to: v)
        XCTAssertEqual(result[0], 1 * 10 + 2 * 20, accuracy: tolerance)
        XCTAssertEqual(result[1], 3 * 10 + 4 * 20, accuracy: tolerance)
    }

    func testApplyIdentityIsVector() {
        let v = [1.0, 2.0, 3.0]
        XCTAssertEqual(Matrix.identity(size: 3).apply(to: v), v)
    }

    func testNonSquareMatrixMultiply() {
        let M = Matrix(rows: 2, columns: 3, storage: [1, 2, 3, 4, 5, 6])
        let N = Matrix(rows: 3, columns: 2, storage: [7, 8, 9, 10, 11, 12])
        let product = M * N
        XCTAssertEqual(product.rows, 2)
        XCTAssertEqual(product.columns, 2)
        XCTAssertEqual(product[0, 0], Double(1 * 7 + 2 * 9 + 3 * 11))
        XCTAssertEqual(product[1, 1], Double(4 * 8 + 5 * 10 + 6 * 12))
    }

    func testWithReplacesCellWithoutMutatingOriginal() {
        let updated = A.with(row: 0, column: 1, value: 99)
        XCTAssertEqual(updated[0, 1], 99)
        XCTAssertEqual(A[0, 1], 2, "original is unchanged")
    }

    private func assertEqual(_ lhs: Matrix, _ rhs: Matrix, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.rows, rhs.rows, file: file, line: line)
        XCTAssertEqual(lhs.columns, rhs.columns, file: file, line: line)
        for (l, r) in zip(lhs.storage, rhs.storage) {
            XCTAssertEqual(l, r, accuracy: tolerance, file: file, line: line)
        }
    }
}
