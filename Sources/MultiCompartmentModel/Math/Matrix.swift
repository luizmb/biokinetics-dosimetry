import Foundation

public struct Matrix: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    public let storage: [Double]

    public init(rows: Int, columns: Int, storage: [Double]) {
        self.rows = rows
        self.columns = columns
        self.storage = storage
    }

    public subscript(row: Int, column: Int) -> Double {
        storage[row * columns + column]
    }

    public static func zero(size n: Int) -> Matrix {
        Matrix(rows: n, columns: n, storage: Array(repeating: 0, count: n * n))
    }

    public static func identity(size n: Int) -> Matrix {
        Matrix(
            rows: n,
            columns: n,
            storage: (0 ..< n * n).map { $0 / n == $0 % n ? 1 : 0 }
        )
    }

    public func with(row: Int, column: Int, value: Double) -> Matrix {
        var s = storage
        s[row * columns + column] = value
        return Matrix(rows: rows, columns: columns, storage: s)
    }

    public func apply(to vector: [Double]) -> [Double] {
        (0 ..< rows).map { i in
            (0 ..< columns).reduce(0) { acc, j in acc + self[i, j] * vector[j] }
        }
    }
}

public func + (lhs: Matrix, rhs: Matrix) -> Matrix {
    Matrix(
        rows: lhs.rows,
        columns: lhs.columns,
        storage: zip(lhs.storage, rhs.storage).map(+)
    )
}

public func * (scalar: Double, matrix: Matrix) -> Matrix {
    Matrix(
        rows: matrix.rows,
        columns: matrix.columns,
        storage: matrix.storage.map { scalar * $0 }
    )
}

public func * (lhs: Matrix, rhs: Matrix) -> Matrix {
    let storage = (0 ..< lhs.rows).flatMap { i in
        (0 ..< rhs.columns).map { j in
            (0 ..< lhs.columns).reduce(0) { acc, k in acc + lhs[i, k] * rhs[k, j] }
        }
    }
    return Matrix(rows: lhs.rows, columns: rhs.columns, storage: storage)
}
