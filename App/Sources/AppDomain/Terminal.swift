import DataStructure

// MARK: - Singleton

/// A type with exactly one inhabitant.
///
/// All instances are trivially equal — the protocol provides `Equatable` via
/// a default `==` that ignores both arguments and returns `true` (`const(true)`).
/// Conform any unit/terminal type to `Singleton` to get `Equatable` for free.
public protocol Singleton: Equatable {}

public extension Singleton {
    static func == (_: Self, _: Self) -> Bool { true }
}

// MARK: - Terminal

/// The canonical terminal object — a concrete `Singleton` isomorphic to `Void`.
///
/// Named after the terminal object (terminal element) in category theory:
/// a type with exactly one inhabitant, unique up to unique isomorphism.
/// Use `Terminal` anywhere `Void` is needed as a generic type argument — e.g.
/// `Loading<Terminal, Never>` instead of `Loading<Void, Never>`.
public struct Terminal: Singleton, Hashable, Sendable, Codable {
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
