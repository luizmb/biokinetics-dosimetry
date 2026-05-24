import AppDomain
import Domain
import Foundation
import Parser
import XMLCoder

/// Parses an IPEN XML `Data` buffer into a `ModelDocument`, assigning default
/// visual layouts to each imported compartment.
///
/// Called from `AppEnvironment.live.parseXML` so that neither `EditorFeature`
/// nor `CalculatorFeature` need to import `XMLCoder` or `Parser`.
func parseIpenXMLData(_ data: Data) -> Result<ModelDocument, ParseError> {
    loadIpenXml(using: XMLDecoder())(data)
        .map { xml in
            let model = xml.toCompartmentalModel()
            let visuals = defaultVisuals(for: model)
            return ModelDocument(
                name: "Imported Model",
                description: "",
                halfLife: 0,
                model: model,
                visuals: visuals
            )
        }
        .mapError { ParseError($0.localizedDescription) }
}

/// Assigns a circular layout and cycling tints to freshly imported compartments.
private func defaultVisuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    let tints = CompartmentTint.allCases
    let count = model.compartments.count
    let cx = 450.0, cy = 310.0, radius = 220.0
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
