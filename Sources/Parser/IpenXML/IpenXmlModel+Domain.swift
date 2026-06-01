import Domain
import FP

extension IpenXmlModel {
    /// Maps this IPEN XML model to the domain `CompartmentalModel`.
    ///
    /// The IPEN XML format encodes the transfer network only — it has no field
    /// for which compartment receives the administered activity or what the
    /// initial fraction is. All compartments are imported with `intake = false`
    /// and `fraction = 0`.
    ///
    /// After importing, open the model in the Editor, select the compartment
    /// that receives the intake (e.g. Plasma), and enable the **Intake** flag.
    /// The Calculator will show a banner if no intake compartment is set.
    ///
    /// The nuclide's half-life defaults to 0 — set it via the Document inspector.
    public func toCompartmentalModel() -> CompartmentalModel {
        let halfLife = modelo?.halfLife ?? 0
        let nuclide = Nuclide(id: "n0", name: "Imported", halfLife: halfLife)
        return CompartmentalModel(
            nuclides: [nuclide],
            compartments: compartments.map { $0.toDomain(nuclideId: nuclide.id) },
            connections: connections.flatMap(\.toDomain)
        )
    }
}

extension IpenXmlCompartment {
    func toDomain(nuclideId: String, isIntake: Bool = false) -> Compartment {
        // Prefer the XML field if present; fall back to the graph-topology heuristic.
        let effectiveIntake = intake || isIntake
        return Compartment(
            id: String(number),
            nuclideId: nuclideId,
            name: name,
            follow: follow,
            intake: effectiveIntake,
            dispose: dispose,
            fraction: effectiveIntake ? 1.0 : 0
        )
    }
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
