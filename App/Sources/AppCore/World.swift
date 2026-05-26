import Core
import Domain

// MARK: - World

/// App-level dependencies injected once at startup.
///
/// Features receive a narrow slice via `lift(environment:)` — nothing here leaks
/// concrete third-party types. Live construction lives in `World+Live.swift`.
public struct World: Sendable {
    public let xmlDecoder: Sendable & DataDecoderFactory
    public let solver: @Sendable (BiokineticsSimulationPlan, CompartmentalModel) async -> [[Double]]

    public init(
        xmlDecoder: Sendable & DataDecoderFactory,
        solver: @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) async -> [[Double]]
    ) {
        self.xmlDecoder = xmlDecoder
        self.solver = solver
    }
}
