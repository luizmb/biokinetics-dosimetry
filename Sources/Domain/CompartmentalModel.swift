import FP
import FPMacros

@Lenses(init: .public)
public struct CompartmentalModel: Hashable, Sendable {
    /// All nuclides present in this model (one for single-nuclide, many for decay chains).
    public let nuclides: [Nuclide]
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
