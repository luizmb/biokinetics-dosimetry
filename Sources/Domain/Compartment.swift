import FPMacros

@Lenses(init: .public)
public struct Compartment: Hashable, Identifiable, Sendable {
    public let id: String
    /// The `Nuclide.id` this compartment belongs to.
    public let nuclideId: String
    public let name: String
    public let follow: Bool
    public let intake: Bool
    public let dispose: Bool
    public let fraction: Double
}
