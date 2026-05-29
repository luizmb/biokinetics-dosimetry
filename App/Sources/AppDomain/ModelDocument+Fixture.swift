/// DEBUG-only named fixtures for `ModelDocument`.
///
/// Use these static properties in unit tests and SwiftUI previews.
/// For the app's "new document" placeholder see `ModelDocument.empty`,
/// which lives in the main `ModelDocument.swift` file and is available
/// in all build configurations.
#if DEBUG
import Domain
import Foundation

public extension ModelDocument {

    /// A convenience fixture with the given overrides and sensible defaults.
    ///
    /// Use when a test needs a `ModelDocument` but doesn't care about
    /// specific compartment topology — prefer the named fixtures below when
    /// a particular model shape matters.
    static func fixture(
        id:          UUID                         = UUID(),
        name:        String                       = "Fixture",
        description: String                       = "",
        model:       CompartmentalModel           = .fixture(),
        variants:    [String: CompartmentalModel] = [:],
        visuals:     [String: CompartmentVisuals] = [:]
    ) -> ModelDocument {
        ModelDocument(id: id, name: name, description: description,
                      model: model, variants: variants, visuals: visuals)
    }

    // MARK: - Named domain fixtures

    /// Iodine-131 fast biokinetic model used for demonstrations and previews.
    static let iodo131: ModelDocument = {
        let nuclide = Nuclide(id: "I131", name: "I-131", halfLife: 8.02)
        let compartments: [(String, String, Bool, Bool, Bool, Double)] = [
            ("plasma",  "Plasma",       true,  true,  false, 1.0),
            ("thyroid", "Thyroid",      true,  false, false, 0),
            ("stomach", "Stomach",      false, false, false, 0),
            ("si",      "Small Int.",   false, false, false, 0),
            ("uli",     "Upper LI",     false, false, false, 0),
            ("lli",     "Lower LI",     false, false, false, 0),
            ("rob",     "Rest of Body", true,  false, false, 0),
            ("urine",   "Urine",        false, false, true,  0),
            ("faeces",  "Faeces",       false, false, true,  0),
        ]
        let connections: [(String, String, Double)] = [
            ("plasma",  "thyroid", 8.66e-1),
            ("plasma",  "urine",   1.94),
            ("plasma",  "stomach", 1.00e2),
            ("plasma",  "rob",     8.32e-1),
            ("stomach", "si",      2.00e1),
            ("si",      "plasma",  1.00e1),
            ("si",      "uli",     6.00),
            ("uli",     "lli",     1.80e1),
            ("lli",     "faeces",  1.00),
            ("rob",     "plasma",  4.62e-2),
            ("thyroid", "plasma",  8.66e-3),
        ]
        let model = CompartmentalModel(
            nuclides: [nuclide],
            compartments: compartments.map { id, name, follow, intake, dispose, fraction in
                Compartment(id: id, nuclideId: nuclide.id, name: name,
                            follow: follow, intake: intake, dispose: dispose, fraction: fraction)
            },
            connections: connections.map { from, to, rate in
                CompartmentConnection(from: from, to: to, rate: rate)
            }
        )
        let tints: [String: CompartmentTint] = [
            "plasma": .steel, "thyroid": .crimson, "stomach": .amber,
            "si": .forest, "uli": .forest, "lli": .forest,
            "rob": .slate, "urine": .rose, "faeces": .ochre,
        ]
        let positions: [String: (Double, Double)] = [
            "plasma":  (450, 360), "thyroid": (320, 510), "stomach": (690, 240),
            "si":      (720, 410), "uli":     (770, 540), "lli":     (690, 580),
            "rob":     (180, 360), "urine":   (450, 540), "faeces":  (580, 580),
        ]
        let visuals: [String: CompartmentVisuals] = tints.keys.reduce(into: [:]) { dict, id in
            let (x, y) = positions[id] ?? (450, 310)
            dict[id] = CompartmentVisuals(x: x, y: y, tint: tints[id] ?? .steel)
        }
        return ModelDocument(
            name: "Iodo 131 F",
            description: "Iodine fast model",
            model: model,
            visuals: visuals
        )
    }()

    /// A minimal three-compartment cascade model used for software validation.
    static let validation: ModelDocument = {
        let nuclide = Nuclide(id: "val", name: "Validation", halfLife: 5.0)
        let model = CompartmentalModel(
            nuclides: [nuclide],
            compartments: [
                Compartment(id: "A", nuclideId: nuclide.id, name: "A",
                            follow: true, intake: true, dispose: false, fraction: 1.0),
                Compartment(id: "B", nuclideId: nuclide.id, name: "B",
                            follow: true, intake: false, dispose: false, fraction: 0),
                Compartment(id: "C", nuclideId: nuclide.id, name: "C",
                            follow: true, intake: false, dispose: false, fraction: 0),
            ],
            connections: [
                CompartmentConnection(from: "A", to: "B", rate: 0.1),
                CompartmentConnection(from: "B", to: "C", rate: 0.2),
                CompartmentConnection(from: "C", to: "B", rate: 1.0),
            ]
        )
        return ModelDocument(
            name: "Validation",
            description: "Model to validate the software",
            model: model,
            visuals: [
                "A": CompartmentVisuals(x: 280, y: 200, tint: .steel),
                "B": CompartmentVisuals(x: 480, y: 320, tint: .forest),
                "C": CompartmentVisuals(x: 320, y: 460, tint: .crimson),
            ]
        )
    }()
}
#endif
