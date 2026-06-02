import Domain
import Foundation

public extension CompartmentalModel {
    func asModelDocument(id: UUID) -> ModelDocument {
        ModelDocument(
            id: id,
            name: "Imported CSV Model",
            description: "",
            model: self,
            visuals: defaultVisuals(for: self)
        )
    }
}

/// Assigns a circular layout and cycling tints to freshly imported compartments.
func defaultVisuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    let tints = CompartmentTint.allCases
    let count = model.compartments.count
    // radius 165: the full circle fits inside the iPhone visible canvas
    // window (canvas x ∈ [255, 645] at default scale=1, offset=0).
    let cx = 450.0, cy = 310.0, radius = 165.0
    return model.compartments.enumerated().reduce(into: [String: CompartmentVisuals]()) { dict, pair in
        let (idx, compartment) = pair
        let angle = 2 * Double.pi * Double(idx) / Double(max(count, 1)) - Double.pi / 2
        dict[compartment.id] = CompartmentVisuals(
            x: cx + radius * cos(angle),
            y: cy + radius * sin(angle),
            tint: tints[idx % tints.count]
        )
    }
}
