import Domain
import Foundation

// MARK: - Pharmacokinetic Seed Models
//
// Rate units: day⁻¹  (field = .pharmacology, time unit = hours → displayed as h⁻¹ in UI)
// All rates converted to day⁻¹ for the solver; divide by 24 for h⁻¹ display.
//
// 1-comp oral: k_a = 2 day⁻¹ (t½_abs ≈ 8 h), k_el = 1 day⁻¹ (t½_elim ≈ 17 h)
// 2-comp oral: same absorption + distribution/elimination
// Digoxin:     classic 2-compartment IV, textbook values (Sheiner et al. 1979)

public extension SeedDocuments {
    static var pharmacologyModels: [ModelDocument] {
        [oneCompartmentOral, twoCompartmentOral, digoxinIV]
    }
}

// MARK: - 1-Compartment Oral

private var oneCompartmentOral: ModelDocument {
    let drug = Nuclide(id: "drug1", name: "Drug", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "gi",   nuclideId: "drug1", name: "GI Tract",   follow: false, intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "ctrl", nuclideId: "drug1", name: "Central",    follow: true,  intake: false, dispose: false, fraction: 0),
        Compartment(id: "clr",  nuclideId: "drug1", name: "Clearance",  follow: true,  intake: false, dispose: true,  fraction: 0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "gi",   to: "ctrl", rate: 48.0),   // k_a = 2 h⁻¹ = 48 day⁻¹
        CompartmentConnection(from: "ctrl", to: "clr",  rate: 24.0),   // k_el = 1 h⁻¹ = 24 day⁻¹
    ]
    let model = CompartmentalModel(nuclides: [drug], compartments: compartments, connections: connections)
    return ModelDocument(
        id: UUID(uuidString: "00000000-PHRM-0000-0000-000000000001")!,
        name: "1-Compartment Oral PK",
        description: "Generic one-compartment oral pharmacokinetic model. Drug absorbs from GI to central compartment (k_a = 2 h⁻¹, t½_abs ≈ 8 h) and is eliminated from central (k_el = 1 h⁻¹, t½_elim ≈ 17 h). Bioavailability assumed 100%. Adjust rates in the editor for your specific drug.",
        field: .pharmacology,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - 2-Compartment Oral

private var twoCompartmentOral: ModelDocument {
    let drug = Nuclide(id: "drug2", name: "Drug", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "gi",   nuclideId: "drug2", name: "GI Tract",    follow: false, intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "ctrl", nuclideId: "drug2", name: "Central",     follow: true,  intake: false, dispose: false, fraction: 0),
        Compartment(id: "peri", nuclideId: "drug2", name: "Peripheral",  follow: true,  intake: false, dispose: false, fraction: 0),
        Compartment(id: "clr",  nuclideId: "drug2", name: "Clearance",   follow: true,  intake: false, dispose: true,  fraction: 0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "gi",   to: "ctrl", rate: 48.0),   // k_a  = 2 h⁻¹
        CompartmentConnection(from: "ctrl", to: "peri", rate: 48.0),   // k_12 = 2 h⁻¹
        CompartmentConnection(from: "peri", to: "ctrl", rate: 24.0),   // k_21 = 1 h⁻¹
        CompartmentConnection(from: "ctrl", to: "clr",  rate: 12.0),   // k_10 = 0.5 h⁻¹
    ]
    let model = CompartmentalModel(nuclides: [drug], compartments: compartments, connections: connections)
    return ModelDocument(
        id: UUID(uuidString: "00000000-PHRM-0000-0000-000000000002")!,
        name: "2-Compartment Oral PK",
        description: "Generic two-compartment oral pharmacokinetic model with absorption. Central ⇄ peripheral distribution with first-order elimination from central. Generic rates (k_a = k_12 = 2 h⁻¹, k_21 = 1 h⁻¹, k_10 = 0.5 h⁻¹). Adjust for your drug.",
        field: .pharmacology,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Digoxin 2-Compartment IV (Sheiner et al. 1979)

private var digoxinIV: ModelDocument {
    // Rates from Sheiner et al. Clin Pharmacol Ther 1979; confirmed in Rowland & Tozer
    // k_12 = 0.44 day⁻¹,  k_21 = 0.09 day⁻¹,  k_10 = 0.14 day⁻¹ (renal+non-renal)
    // t½ terminal ≈ 40 h = 1.67 d
    let drug = Nuclide(id: "digoxin", name: "Digoxin", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "ctrl", nuclideId: "digoxin", name: "Central (Plasma)", follow: true,  intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "peri", nuclideId: "digoxin", name: "Peripheral",       follow: true,  intake: false, dispose: false, fraction: 0),
        Compartment(id: "clr",  nuclideId: "digoxin", name: "Clearance",        follow: true,  intake: false, dispose: true,  fraction: 0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "ctrl", to: "peri", rate: 0.44),
        CompartmentConnection(from: "peri", to: "ctrl", rate: 0.09),
        CompartmentConnection(from: "ctrl", to: "clr",  rate: 0.14),
    ]
    let model = CompartmentalModel(nuclides: [drug], compartments: compartments, connections: connections)
    return ModelDocument(
        id: UUID(uuidString: "00000000-PHRM-0000-0000-000000000003")!,
        name: "Digoxin 2-Compartment IV (Sheiner 1979)",
        description: "Classic two-compartment IV model for digoxin. Rates: k_12 = 0.44 day⁻¹, k_21 = 0.09 day⁻¹, k_10 = 0.14 day⁻¹ (Sheiner et al. Clin Pharmacol Ther 1979). Terminal t½ ≈ 40 h. Digoxin has a large volume of distribution and slow equilibration — the two-compartment behaviour is critical for dosing decisions.",
        field: .pharmacology,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}
