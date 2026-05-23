import FPMacros

@Lenses(init: .public)
public struct CompartmentConnection: Hashable, Sendable {
    public let from: String
    public let to: String
    public let rate: Double
}
