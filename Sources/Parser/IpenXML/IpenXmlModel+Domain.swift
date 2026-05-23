import Domain
import FP

extension IpenXmlModel {
    /// Maps this IPEN XML model to the domain `CompartmentalModel`.
    ///
    /// All compartments start with `intake = false` and `fraction = 0`.
    /// Set the intake compartment after loading via
    /// `CompartmentalModel.updatingCompartment(id:_:)`.
    public func toCompartmentalModel() -> CompartmentalModel {
        CompartmentalModel(
            compartments: compartments.map(\.toDomain),
            connections: connections.flatMap(\.toDomain)
        )
    }
}

extension IpenXmlCompartment {
    var toDomain: Compartment {
        Compartment(
            id: String(number),
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
