import Foundation
import FPMacros

@Lenses(init: .public)
public struct Compartment: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let follow: Bool
    public let intake: Bool
    public let dispose: Bool
    public let fraction: Double
}
