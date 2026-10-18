import AppDomain
import Domain
import Foundation
import Testing

@Suite("Sample models in the reader's language")
struct SampleLocalizationTests {
    let words = ["Blood": "Sangue", "Plasma": "Plasma (pt)", "Lead (Pb)": "Chumbo (Pb)", "A model": "Um modelo"]
    var translate: (String) -> String { { words[$0] ?? $0 } }

    let document = ModelDocument(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        name: "A model",
        description: "Not known",
        model: CompartmentalModel(
            nuclides: [Nuclide(id: "n0", name: "Lead (Pb)", halfLife: 0)],
            compartments: [
                Compartment(id: "bl", nuclideId: "n0", name: "Blood", follow: true, intake: true, dispose: false, fraction: 1),
                Compartment(id: "pl", nuclideId: "n0", name: "U238 Plasma", follow: false, intake: false, dispose: false, fraction: 0),
                Compartment(id: "bb", nuclideId: "n0", name: "BB1", follow: false, intake: false, dispose: false, fraction: 0),
            ],
            connections: []
        )
    )

    @Test("names, nuclides and compartments are translated; unknown texts stay")
    func translated() {
        let localized = document.localized(by: translate)
        #expect(localized.name == "Um modelo")
        #expect(localized.description == "Not known")
        #expect(localized.model.nuclides.map(\.name) == ["Chumbo (Pb)"])
        #expect(localized.model.compartments.map(\.name) == ["Sangue", "U238 Plasma (pt)", "BB1"])
        #expect(localized.id == document.id)
    }
}
