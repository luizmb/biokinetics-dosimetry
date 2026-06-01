import Domain
import FP

extension IpenXmlModel {
    /// Maps this IPEN XML model to the domain `CompartmentalModel`.
    ///
    /// **Intake detection (three cases):**
    ///
    /// 1. *Newer XML* — `Incorporacao = true` present on one or more compartments.
    ///    Their `Fracao` values are used verbatim as initial fractions (these encode
    ///    physical deposition fractions and may sum to less than 1 for lung models).
    ///
    /// 2. *Older XML, clear source node* — no `Incorporacao` field.
    ///    Graph-topology heuristic: compartments with no real incoming edges are
    ///    intake compartments. Equal fractions are assigned so they sum to 1.
    ///    Elimination sinks (zero-rate orphans) are excluded.
    ///
    /// 3. *Older XML, fully-cyclic graph* — every node has incoming edges.
    ///    Falls back to the highest-degree (hub) compartment, e.g. Plasma.
    ///
    /// The nuclide's half-life comes from the `<meiaVida>` field (0 if absent).
    public func toCompartmentalModel() -> CompartmentalModel {
        let halfLife = modelo?.halfLife ?? 0
        let nuclide = Nuclide(id: "n0", name: "Imported", halfLife: halfLife)

        // ── Case 1: explicit Incorporacao + Fracao ────────────────────────────
        let explicitIntakes = compartments.filter { $0.intake }
        if !explicitIntakes.isEmpty {
            return CompartmentalModel(
                nuclides: [nuclide],
                compartments: compartments.map { comp in
                    Compartment(
                        id: String(comp.number), nuclideId: nuclide.id,
                        name: comp.name, follow: comp.follow,
                        intake: comp.intake, dispose: comp.dispose,
                        fraction: comp.intake ? (comp.fraction ?? 1.0) : 0
                    )
                },
                connections: connections.flatMap(\.toDomain)
            )
        }

        // ── Cases 2 & 3: topology heuristic ──────────────────────────────────
        let destNumbers: Set<Int> = connections.reduce(into: []) { set, conn in
            if conn.rateAtoB > 0 { set.insert(conn.toCompartmentNumber) }
            if conn.rateBtoA > 0 { set.insert(conn.fromCompartmentNumber) }
        }
        let sourceComps = compartments.filter { !destNumbers.contains($0.number) && !$0.dispose }

        let intakeNumbers: Set<Int>
        if !sourceComps.isEmpty {
            // Case 2: one or more clear source nodes — all are intake compartments.
            intakeNumbers = Set(sourceComps.map(\.number))
        } else {
            // Case 3: fully-cyclic — hub (highest-degree non-elimination) compartment.
            let degrees = connectionDegrees(connections: connections)
            let maxDeg  = degrees.values.max() ?? 0
            intakeNumbers = compartments
                .filter { !$0.dispose && (degrees[$0.number] ?? 0) == maxDeg }
                .min(by: { $0.number < $1.number })
                .map { [$0.number] }.map(Set.init) ?? []
        }

        // Divide activity equally so fractions always sum to 1.
        let equalFraction = intakeNumbers.isEmpty ? 0.0 : 1.0 / Double(intakeNumbers.count)

        return CompartmentalModel(
            nuclides: [nuclide],
            compartments: compartments.map { comp in
                let isIntake = intakeNumbers.contains(comp.number)
                return Compartment(
                    id: String(comp.number), nuclideId: nuclide.id,
                    name: comp.name, follow: comp.follow,
                    intake: isIntake, dispose: comp.dispose,
                    fraction: isIntake ? equalFraction : 0
                )
            },
            connections: connections.flatMap(\.toDomain)
        )
    }
}

// MARK: - Helpers

private func connectionDegrees(connections: [IpenXmlConnection]) -> [Int: Int] {
    var neighbors: [Int: Set<Int>] = [:]
    for conn in connections {
        let from = conn.fromCompartmentNumber, to = conn.toCompartmentNumber
        if conn.rateAtoB > 0 { neighbors[from, default: []].insert(to); neighbors[to, default: []].insert(from) }
        if conn.rateBtoA > 0 { neighbors[to, default: []].insert(from); neighbors[from, default: []].insert(to) }
    }
    return neighbors.mapValues(\.count)
}

extension IpenXmlConnection {
    var toDomain: [CompartmentConnection] {
        let from = String(fromCompartmentNumber)
        let to   = String(toCompartmentNumber)
        let aToB = rateAtoB == 0 ? [] : [CompartmentConnection(from: from, to: to, rate: rateAtoB)]
        let bToA = rateBtoA == 0 ? [] : [CompartmentConnection(from: to, to: from, rate: rateBtoA)]
        return aToB <> bToA
    }
}
