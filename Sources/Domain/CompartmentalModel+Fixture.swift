/// DEBUG-only fixture factory for `CompartmentalModel`.
///
/// Provides a convenience `fixture()` function with a minimal single-nuclide,
/// single-compartment model by default. Use this in tests that exercise model-level
/// behaviour without caring about the exact compartment or connection topology.
#if DEBUG

public extension CompartmentalModel {

    /// Returns a `CompartmentalModel` with the given nuclides, compartments, and connections.
    ///
    /// Defaults to a single stable nuclide, one compartment, and no connections — sufficient
    /// for tests that only check that a model is present, not its internal structure.
    static func fixture(
        nuclides:     [Nuclide]               = [.fixture()],
        compartments: [Compartment]           = [.fixture()],
        connections:  [CompartmentConnection] = []
    ) -> CompartmentalModel {
        CompartmentalModel(nuclides: nuclides, compartments: compartments, connections: connections)
    }
}

#endif
