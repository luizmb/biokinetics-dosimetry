/// DEBUG-only fixture factory for `Compartment`.
///
/// Provides a convenience `fixture()` function with sensible defaults
/// for unit tests and previews. Use this instead of spelling out all
/// arguments whenever the exact values don't matter for the test.
#if DEBUG

public extension Compartment {

    /// Returns a `Compartment` with the given overrides and reasonable defaults
    /// for all other properties.
    static func fixture(
        id:        String = "A",
        nuclideId: String = "n0",
        name:      String = "Compartment A",
        follow:    Bool   = true,
        intake:    Bool   = true,
        dispose:   Bool   = false,
        fraction:  Double = 1.0
    ) -> Compartment {
        Compartment(id: id, nuclideId: nuclideId, name: name,
                    follow: follow, intake: intake, dispose: dispose, fraction: fraction)
    }
}

#endif
