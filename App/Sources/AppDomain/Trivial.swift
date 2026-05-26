import DataStructure

/// A concrete single-value type isomorphic to `Void`.
///
/// Unlike `Void` (which is a tuple `()`), `Trivial` is a proper struct and can
/// therefore conform to protocols like `Equatable`, `Hashable`, and `Codable`.
/// Use `Trivial` anywhere you need `Void` as a generic type argument — for example,
/// `Loading<Trivial, Never>` instead of `Loading<Void, Never>`.
///
/// The name comes from category theory: the terminal object (unit type) is
/// the trivial object — it carries no information beyond its existence.
public struct Trivial: Equatable, Hashable, Sendable, Codable {
    public init() {}
}

// MARK: - Loading convenience

public extension Loading where Success == Trivial {
    /// Transition to `.loaded` without requiring an explicit `Trivial()` argument.
    static func loaded() -> Self { .loaded(Trivial()) }
}

// MARK: - Void interop

/// Lift `()` into `Trivial`.
public func toTrivial(_: Void) -> Trivial { Trivial() }

/// Lower `Trivial` back to `()`.
public func toVoid(_: Trivial) -> Void { () }
