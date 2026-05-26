import DataStructure

/// A concrete single-value type isomorphic to `Void`.
///
/// Unlike `Void` (which is a tuple `()`), `Unit` is a proper struct and can
/// therefore conform to protocols like `Equatable`, `Hashable`, and `Codable`.
/// Use `Unit` anywhere you need `Void` as a generic type argument — for example,
/// `Loading<Unit, Never>` instead of `Loading<Void, Never>`.
public struct Unit: Equatable, Hashable, Sendable, Codable {
    public init() {}
}

// MARK: - Loading convenience

public extension Loading where Success == Unit {
    /// Transition to `.loaded` without requiring an explicit `Unit()` argument.
    static func loaded() -> Self { .loaded(Unit()) }
}

// MARK: - Void interop

/// Lift `()` into `Unit`.
public func toUnit(_: Void) -> Unit { Unit() }

/// Lower `Unit` back to `()`.
public func toVoid(_: Unit) -> Void { () }
