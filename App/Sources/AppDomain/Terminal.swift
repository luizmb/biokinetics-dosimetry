import DataStructure

// MARK: - Singleton

/// A type with exactly one inhabitant.
///
/// The protocol supplies every conformance a singleton type needs:
/// - `Equatable` (via `Hashable`): `==` is `const(true)` — all instances are equal.
/// - `Hashable`: `hash(into:)` is a no-op — all instances share the same hash.
/// - `Codable`: `encode(to:)` writes nothing; `init(from:)` calls `self.init()`.
/// - `Sendable`: singleton values carry no mutable state.
///
/// The only requirement a conforming type must satisfy is a no-arg `init()`.
public protocol Singleton: Hashable, Sendable, Codable {
    init()
}

public extension Singleton {
    static func == (_: Self, _: Self) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
    func encode(to encoder: any Encoder) throws {}
    init(from decoder: any Decoder) throws { self.init() }
}

// MARK: - Terminal

/// The canonical terminal object — a concrete `Singleton` isomorphic to `Void`.
///
/// Named after the terminal object (terminal element) in category theory:
/// a type with exactly one inhabitant, unique up to unique isomorphism.
/// Use `Terminal` anywhere `Void` is needed as a generic type argument — e.g.
/// `Loading<Terminal, Never>` instead of `Loading<Void, Never>`.
public struct Terminal: Singleton {
    public init() {}
}

// MARK: - Loading convenience

public extension Loading where Success == Terminal {
    /// Transition to `.loaded` without requiring an explicit `Terminal()` argument.
    static func loaded() -> Self { .loaded(Terminal()) }
}

// MARK: - Void interop

/// Lift `()` into `Terminal`.
public func toTerminal(_: Void) -> Terminal { Terminal() }

/// Lower `Terminal` back to `()`.
public func toVoid(_: Terminal) -> Void { () }
