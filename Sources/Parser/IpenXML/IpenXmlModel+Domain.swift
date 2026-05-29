import Domain
import FP

extension IpenXmlModel {
    /// Maps this IPEN XML model to the domain `CompartmentalModel`.
    ///
    /// IPEN XML files are always single-nuclide: a synthetic `Nuclide` with `id "n0"`
    /// and `halfLife 0` is created and assigned to every compartment. Set the
    /// nuclide's half-life after loading via the document inspector, and set the
    /// intake compartment via `CompartmentalModel.updatingCompartment(id:_:)`.
    public func toCompartmentalModel() -> CompartmentalModel {
        let nuclide = Nuclide(id: "n0", name: "Imported", halfLife: 0)
        return CompartmentalModel(
            nuclides: [nuclide],
            compartments: compartments.map { $0.toDomain(nuclideId: nuclide.id) },
            connections: connections.flatMap(\.toDomain)
        )
    }
}

extension IpenXmlCompartment {
    func toDomain(nuclideId: String) -> Compartment {
        Compartment(
            id: String(number),
            nuclideId: nuclideId,
            name: name,
            follow: follow,
            intake: false,
            dispose: dispose,
            fraction: 0
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
