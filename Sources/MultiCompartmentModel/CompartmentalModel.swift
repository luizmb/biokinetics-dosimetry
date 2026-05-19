import Foundation
import FP
import FPMacros
import Math
import RealNumber

@Lenses(init: .public)
public struct CompartmentalModel: Hashable, Sendable {
    public let compartments: [Compartment]
    public let connections: [CompartmentConnection]
}

extension CompartmentalModel {
    public func updatingCompartment(
        id: Compartment.ID,
        _ transform: @escaping @Sendable (Compartment) -> Compartment
    ) -> CompartmentalModel {
        with(compartments: [Compartment].ix(id: id).over(transform)(compartments))
    }
}

extension CompartmentalModel {
    public func coefficientMatrix(decay lambda: Double) -> Matrix<Double> {
        let n = compartments.count
        let indexOf = Dictionary(uniqueKeysWithValues: compartments.enumerated().map { ($1.id, $0) })

        let inflows: [(row: Int, col: Int, value: Double)] = connections.compactMap { c in
            indexOf[c.from].flatMap { i in
                indexOf[c.to].map { j in (row: j, col: i, value: c.rate) }
            }
        }

        let outflowByCompartment: [Int: Double] = Dictionary(
            connections.compactMap { c in indexOf[c.from].map { ($0, c.rate) } },
            uniquingKeysWith: +
        )

        let diagonals: [(row: Int, col: Int, value: Double)] = (0 ..< n).map { i in
            (row: i, col: i, value: -lambda - (outflowByCompartment[i] ?? 0))
        }

        let empty = [Double](repeating: 0, count: n * n)
        let storage = (inflows <> diagonals).reduce(into: empty) { s, assignment in
            s[assignment.row * n + assignment.col] = assignment.value
        }
        return Matrix(rows: n, columns: n, storage: storage)
    }

    public func initialConditions() -> [Double] {
        compartments.map { $0.intake ? $0.fraction : 0 }
    }
}
