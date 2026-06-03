import Domain
import Foundation

/// Pre-shipped example models, one per scientific field.
///
/// Written to the documents directory on first launch when no user documents exist.
/// After seeding they behave as regular user documents — editable and deletable.
public enum SeedDocuments {
    public static func all(idFor: @Sendable (String) -> UUID) -> [ModelDocument] {
        [
            twoCompartmentPK(idFor: idFor),
            codeineToMorphine(idFor: idFor),
            foodChainBioaccumulation(idFor: idFor),
            twoCompartmentGeneric(idFor: idFor),
        ]
    }
}

// MARK: - Pharmacology: 2-Compartment IV Bolus

private func twoCompartmentPK(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let drug = Nuclide(id: "drug", name: "Drug", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "central",      nuclideId: "drug", name: "Central (Plasma)",    follow: true,  intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "peripheral",   nuclideId: "drug", name: "Peripheral (Tissue)", follow: true,  intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "clearance",    nuclideId: "drug", name: "Clearance",           follow: true,  intake: false, dispose: true,  fraction: 0.0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "central",    to: "peripheral", rate: 2.0),
        CompartmentConnection(from: "peripheral", to: "central",    rate: 1.0),
        CompartmentConnection(from: "central",    to: "clearance",  rate: 0.5),
    ]
    let model = CompartmentalModel(nuclides: [drug], compartments: compartments, connections: connections)
    return ModelDocument(
        id: idFor("generic.2comp.pk"),
        name: "2-Compartment PK (IV Bolus)",
        description: "Classic two-compartment pharmacokinetic model for an intravenous bolus dose. Central ⇄ Peripheral with first-order elimination from central.",
        field: .pharmacology,
        model: model,
        visuals: twoCompartmentPKVisuals(for: model)
    )
}

// MARK: - Pharmacology: Codeine → Morphine

private func codeineToMorphine(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let codeine  = Nuclide(id: "codeine",  name: "Codeine",  halfLife: 0)
    let morphine = Nuclide(id: "morphine", name: "Morphine", halfLife: 0)

    let compartments: [Compartment] = [
        // Codeine
        Compartment(id: "c_plasma",  nuclideId: "codeine",  name: "Codeine Plasma",     follow: true,  intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "c_tissue",  nuclideId: "codeine",  name: "Codeine Tissue",      follow: false, intake: false, dispose: false, fraction: 0.0),
        // Morphine (produced by hepatic conversion of codeine)
        Compartment(id: "m_plasma",  nuclideId: "morphine", name: "Morphine Plasma",     follow: true,  intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "m_tissue",  nuclideId: "morphine", name: "Morphine Tissue",     follow: false, intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "m_urine",   nuclideId: "morphine", name: "Urine",               follow: true,  intake: false, dispose: true,  fraction: 0.0),
    ]
    let connections: [CompartmentConnection] = [
        // Codeine kinetics
        CompartmentConnection(from: "c_plasma", to: "c_tissue",  rate: 1.2),
        CompartmentConnection(from: "c_tissue", to: "c_plasma",  rate: 0.6),
        // ~15 % of codeine converts to morphine via CYP2D6
        CompartmentConnection(from: "c_plasma", to: "m_plasma",  rate: 0.21),
        // Morphine kinetics
        CompartmentConnection(from: "m_plasma", to: "m_tissue",  rate: 0.9),
        CompartmentConnection(from: "m_tissue", to: "m_plasma",  rate: 0.45),
        CompartmentConnection(from: "m_plasma", to: "m_urine",   rate: 0.6),
    ]
    let model = CompartmentalModel(nuclides: [codeine, morphine], compartments: compartments, connections: connections)
    return ModelDocument(
        id: idFor("generic.codeine.morphine"),
        name: "Codeine → Morphine",
        description: "Two-substance pharmacokinetic model. Codeine is absorbed into plasma and partially converted to morphine via CYP2D6 metabolism (~15 %). Both substances distribute into tissue. Morphine is eliminated via urine.",
        field: .pharmacology,
        model: model,
        visuals: codeineToMorphineVisuals(for: model)
    )
}

// MARK: - Ecology: Food-Chain Bioaccumulation

private func foodChainBioaccumulation(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let pollutant = Nuclide(id: "pollutant", name: "Pollutant", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "water",         nuclideId: "pollutant", name: "Water",         follow: true,  intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "algae",         nuclideId: "pollutant", name: "Algae",         follow: true,  intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "invertebrates", nuclideId: "pollutant", name: "Invertebrates", follow: true,  intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "fish",          nuclideId: "pollutant", name: "Fish",          follow: true,  intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "elimination",   nuclideId: "pollutant", name: "Elimination",   follow: true,  intake: false, dispose: true,  fraction: 0.0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "water",         to: "algae",         rate: 0.5),
        CompartmentConnection(from: "algae",         to: "water",         rate: 0.3),
        CompartmentConnection(from: "algae",         to: "invertebrates", rate: 0.2),
        CompartmentConnection(from: "invertebrates", to: "algae",         rate: 0.1),
        CompartmentConnection(from: "invertebrates", to: "fish",          rate: 0.1),
        CompartmentConnection(from: "fish",          to: "invertebrates", rate: 0.05),
        CompartmentConnection(from: "fish",          to: "elimination",   rate: 0.05),
    ]
    let model = CompartmentalModel(nuclides: [pollutant], compartments: compartments, connections: connections)
    return ModelDocument(
        id: idFor("generic.food.chain"),
        name: "Food-Chain Bioaccumulation",
        description: "Aquatic food-chain bioaccumulation of a persistent pollutant. Substance enters the water column and biomagnifies through algae → invertebrates → fish, with slow elimination at the apex.",
        field: .ecology,
        model: model,
        visuals: foodChainVisuals(for: model)
    )
}

// MARK: - Generic: Simple Two-Compartment

private func twoCompartmentGeneric(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let substance = Nuclide(id: "substance", name: "Substance", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "a",    nuclideId: "substance", name: "Compartment A", follow: true,  intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "b",    nuclideId: "substance", name: "Compartment B", follow: true,  intake: false, dispose: false, fraction: 0.0),
        Compartment(id: "sink", nuclideId: "substance", name: "Sink",          follow: true,  intake: false, dispose: true,  fraction: 0.0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "a",    to: "b",    rate: 0.5),
        CompartmentConnection(from: "b",    to: "a",    rate: 0.3),
        CompartmentConnection(from: "b",    to: "sink", rate: 0.1),
    ]
    let model = CompartmentalModel(nuclides: [substance], compartments: compartments, connections: connections)
    return ModelDocument(
        id: idFor("generic.2comp"),
        name: "Simple Two-Compartment",
        description: "Minimal two-compartment model. Substance enters A, distributes bidirectionally into B, and is slowly eliminated via Sink. A starting point for any field.",
        field: .generic,
        model: model,
        visuals: twoCompartmentGenericVisuals(for: model)
    )
}
