import Domain
import Math

extension CompartmentalModel {
    /// Converts this domain model into the `LinearSystem` primitive the solvers accept.
    ///
    /// Compartment order in the output vectors matches `compartments` array order.
    /// Each compartment's radioactive decay constant is derived from the `Nuclide`
    /// it belongs to via `Compartment.nuclideId`.
    public func linearSystem() -> LinearSystem {
        let nuclideById = Dictionary(uniqueKeysWithValues: nuclides.map { ($0.id, $0) })

        let indexOf = Dictionary(
            uniqueKeysWithValues: compartments.enumerated().map { ($1.id, $0) }
        )
        let connections: [(fromIndex: Int, toIndex: Int, rate: Double)] = self.connections
            .compactMap { c in
                guard let from = indexOf[c.from], let to = indexOf[c.to] else { return nil }
                return (fromIndex: from, toIndex: to, rate: c.rate)
            }
        let decays: [Double] = compartments.map { c in
            decayConstant(halfLife: nuclideById[c.nuclideId]?.halfLife ?? 0)
        }
        let initialConditions = compartments.map { $0.intake ? $0.fraction : 0 }
        return LinearSystem(
            matrix: buildCoefficientMatrix(
                count: compartments.count,
                connections: connections,
                decays: decays
            ),
            initialConditions: initialConditions
        )
    }
}
