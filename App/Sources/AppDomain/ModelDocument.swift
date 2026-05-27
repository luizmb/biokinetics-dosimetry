import Foundation
import Domain

/// Visual layout metadata for one compartment node on the editor canvas.
public struct CompartmentVisuals: Hashable, Codable, Sendable {
    /// Canvas X coordinate in logical points (base canvas: 900 wide).
    public var x: Double
    /// Canvas Y coordinate in logical points (base canvas: 620 tall).
    public var y: Double
    /// Semantic color identity.
    public var tint: CompartmentTint

    public init(x: Double, y: Double, tint: CompartmentTint) {
        self.x = x
        self.y = y
        self.tint = tint
    }
}

/// A saved biokinetic model document, combining the mathematical model with
/// visual canvas layout and document-level metadata.
///
/// `ModelDocument` is the canonical unit of persistence and navigation.
/// The editor and calculator each receive a snapshot; mutations are dispatched
/// back to `HomeFeature.State.documents` via the app coordinator.
public struct ModelDocument: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    /// Radioactive half-life in days. `0` = stable (no radioactive decay).
    public var halfLife: Double
    /// Mathematical compartmental model (compartments + transfer rates).
    public var model: CompartmentalModel
    /// Per-compartment visual info, keyed by `Compartment.id`.
    public var visuals: [String: CompartmentVisuals]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        halfLife: Double = 0,
        model: CompartmentalModel,
        visuals: [String: CompartmentVisuals] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.halfLife = halfLife
        self.model = model
        self.visuals = visuals
    }

    public static var empty: Self {
        .init(name: "Untitled", model: .init(compartments: [], connections: []))
    }
}
