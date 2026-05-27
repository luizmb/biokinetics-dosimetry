/// DEBUG-only fixture factory for `CompartmentConnection`.
///
/// Provides a convenience `fixture()` function with sensible defaults
/// for unit tests and previews. Use this instead of spelling out all
/// arguments whenever the exact values don't matter for the test.
#if DEBUG

public extension CompartmentConnection {

    /// Returns a `CompartmentConnection` with the given overrides and
    /// reasonable defaults for all other properties.
    static func fixture(
        from: String = "A",
        to:   String = "B",
        rate: Double = 0.1
    ) -> CompartmentConnection {
        CompartmentConnection(from: from, to: to, rate: rate)
    }
}

#endif
