import Domain
import Math

extension CompartmentalModel {
    /// Converts this domain model into the `LinearSystem` primitive the solvers accept.
    ///
    /// Compartment order in the output vectors matches `compartments` array order.
    /// - Parameter decay: Radioactive decay constant `λ`. Use `decayConstant(halfLife:)`.
    public func linearSystem(decay: Double) -> LinearSystem {
        let indexOf = Dictionary(
            uniqueKeysWithValues: compartments.enumerated().map { ($1.id, $0) }
        )
        let connections: [(fromIndex: Int, toIndex: Int, rate: Double)] = self.connections
            .compactMap { c in
                guard let from = indexOf[c.from], let to = indexOf[c.to] else { return nil }
                return (fromIndex: from, toIndex: to, rate: c.rate)
            }
        let initialConditions = compartments.map { $0.intake ? $0.fraction : 0 }
        return LinearSystem(
            matrix: buildCoefficientMatrix(
                count: compartments.count,
                connections: connections,
                decay: decay
            ),
            initialConditions: initialConditions
        )
    }
}
