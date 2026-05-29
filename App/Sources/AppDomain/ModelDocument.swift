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
///
/// Half-life lives on each `Nuclide` inside `model` — `ModelDocument` no longer
/// carries a top-level `halfLife` field. For single-nuclide documents the
/// primary nuclide is `model.nuclides.first`.
public struct ModelDocument: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    /// Mathematical compartmental model (nuclides + compartments + transfer rates).
    public var model: CompartmentalModel
    /// Named parameter variants (e.g. "Type F", "Type M", "Type S" for uranium).
    /// The base `model` is used when no variant is selected.
    public var variants: [String: CompartmentalModel]
    /// Per-compartment visual info, keyed by `Compartment.id`.
    public var visuals: [String: CompartmentVisuals]

    public init(
        id:       UUID                          = UUID(),
        name:     String,
        description: String                     = "",
        model:    CompartmentalModel,
        variants: [String: CompartmentalModel]  = [:],
        visuals:  [String: CompartmentVisuals]  = [:]
    ) {
        self.id          = id
        self.name        = name
        self.description = description
        self.model       = model
        self.variants    = variants
        self.visuals     = visuals
    }

    /// A blank document with no nuclides, compartments, or connections.
    /// Used by the app as the "new document" placeholder — available in all build configurations.
    public static var empty: ModelDocument {
        ModelDocument(
            name: "Untitled",
            model: CompartmentalModel(nuclides: [], compartments: [], connections: [])
        )
    }
}

// MARK: - Convenience

public extension ModelDocument {
    /// Half-life of the primary (first) nuclide, or `0` if the model has no nuclides.
    ///
    /// Convenience for single-nuclide documents. For decay-chain models, inspect
    /// `model.nuclides` directly.
    var halfLife: Double { model.nuclides.first?.halfLife ?? 0 }
}
