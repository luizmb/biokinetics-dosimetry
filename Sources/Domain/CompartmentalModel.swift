import FP
import FPMacros

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
