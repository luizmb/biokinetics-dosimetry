import FPMacros

@Lenses(init: .public)
public struct CompartmentConnection: Hashable, Codable, Sendable {
    public let from: String
    public let to: String
    public let rate: Double
}
