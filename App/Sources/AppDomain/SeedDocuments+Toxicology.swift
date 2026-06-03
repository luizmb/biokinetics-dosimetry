import Domain
import Foundation

// MARK: - Toxicokinetic Seed Models
//
// Sources:
//   Lead:    Rabinowitz et al., Science 1976; ATSDR Toxicological Profile for Lead
//   Mercury: WHO/IPCS Environmental Health Criteria 101 (1990)
//   Cadmium: ATSDR Toxicological Profile for Cadmium; Jarup et al. 1998
//
// All substances are stable (no radioactive decay) → halfLife = 0.
// Rate units: day⁻¹. Field = .toxicology.

public extension SeedDocuments {
    static var toxicologyModels: [ModelDocument] {
        [leadRabinowitz, methylmercury, cadmium]
    }
}

// MARK: - Lead — Rabinowitz 3-Pool Model (Rabinowitz et al. Science 1976)

private var leadRabinowitz: ModelDocument {
    // The Rabinowitz model uses three pools: blood, soft tissue, and bone.
    // Bone has two sub-pools: trabecular (fast exchange) and cortical (very slow).
    // Rates are from Rabinowitz et al. Science 192:81-83, 1976.
    let pb = Nuclide(id: "pb", name: "Lead (Pb)", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "bl",  nuclideId: "pb", name: "Blood",              follow: true, intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "st",  nuclideId: "pb", name: "Soft Tissue",        follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "btn", nuclideId: "pb", name: "Trabecular Bone",    follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "bcx", nuclideId: "pb", name: "Cortical Bone",      follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "urn", nuclideId: "pb", name: "Urine",              follow: true, intake: false, dispose: true,  fraction: 0),
        Compartment(id: "fae", nuclideId: "pb", name: "Faeces/Other",       follow: false,intake: false, dispose: true,  fraction: 0),
    ]
    // Rabinowitz 1976 transfer rates (day⁻¹), validated against blood/bone/urine data
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "bl",  to: "st",  rate: 0.0111),
        CompartmentConnection(from: "st",  to: "bl",  rate: 0.0111),
        CompartmentConnection(from: "bl",  to: "btn", rate: 0.0069),
        CompartmentConnection(from: "btn", to: "bl",  rate: 0.0139),  // t½_trabecular ≈ 50 d
        CompartmentConnection(from: "bl",  to: "bcx", rate: 0.0042),
        CompartmentConnection(from: "bcx", to: "bl",  rate: 6.95e-5), // t½_cortical ≈ 10,000 d
        CompartmentConnection(from: "bl",  to: "urn", rate: 0.0116),
        CompartmentConnection(from: "bl",  to: "fae", rate: 0.0058),
    ]
    let model = CompartmentalModel(nuclides: [pb], compartments: compartments, connections: connections)
    return ModelDocument(
        id: UUID(uuidString: "00000006-0000-0000-0000-000000000001")!,
        name: "Lead — Rabinowitz 3-Pool (1976)",
        description: "Classical 3-pool lead toxicokinetic model: blood, soft tissue, and bone (trabecular fast + cortical slow). Rates from Rabinowitz et al. Science 1976 — validated against stable Pb tracer data. Cortical bone has extremely slow resorption (t½ ≈ 27 y), making it a long-term repository. Use this model to assess chronic low-level lead exposure. halfLife = 0 (stable Pb).",
        field: .toxicology,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Methylmercury (WHO/IPCS 1990)

private var methylmercury: ModelDocument {
    // Methylmercury from fish: ~90% GI absorption, distributes to blood, brain, tissue.
    // Biological t½ whole body ≈ 70 d; brain t½ ≈ 70 d.
    // Hair acts as a biomarker compartment (effectively one-way).
    // Rates approximate from WHO/IPCS Environmental Health Criteria 101.
    let hg = Nuclide(id: "mehg", name: "Methylmercury", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "bl",   nuclideId: "mehg", name: "Blood",          follow: true, intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "br",   nuclideId: "mehg", name: "Brain",          follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "st",   nuclideId: "mehg", name: "Other Tissue",   follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "hair", nuclideId: "mehg", name: "Hair",           follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "ex",   nuclideId: "mehg", name: "Excretion",      follow: true, intake: false, dispose: true,  fraction: 0),
    ]
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "bl",   to: "br",   rate: 0.050),  // BBB penetration
        CompartmentConnection(from: "br",   to: "bl",   rate: 0.010),  // t½_brain ≈ 70 d
        CompartmentConnection(from: "bl",   to: "st",   rate: 0.100),
        CompartmentConnection(from: "st",   to: "bl",   rate: 0.050),
        CompartmentConnection(from: "bl",   to: "hair", rate: 0.001),  // hair incorporation
        CompartmentConnection(from: "bl",   to: "ex",   rate: 0.050),  // fecal + renal
    ]
    let model = CompartmentalModel(nuclides: [hg], compartments: compartments, connections: connections)
    return ModelDocument(
        id: UUID(uuidString: "00000006-0000-0000-0000-000000000002")!,
        name: "Methylmercury Toxicokinetics (WHO 1990)",
        description: "Methylmercury (organic mercury) toxicokinetic model based on WHO/IPCS EHC 101 (1990). ~90% GI absorption; distributes to blood, brain (BBB penetration), and soft tissue. Brain accumulation drives neurotoxicity. Hair acts as a biomarker: [hair] ∝ blood concentration over exposure history. Whole-body biological t½ ≈ 70 d. Rates are approximate.",
        field: .toxicology,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Cadmium (ATSDR / Jarup et al. 1998)

private var cadmium: ModelDocument {
    // Cadmium: ~5% GI absorption; liver as initial depot, redistributes to kidney.
    // Kidney cortex accumulates Cd bound to metallothionein with t½ ≈ 10-30 years.
    // Rates approximate from ATSDR Toxicological Profile and Jarup et al. Occup Environ Med 1998.
    let cd = Nuclide(id: "cd", name: "Cadmium (Cd)", halfLife: 0)
    let compartments: [Compartment] = [
        Compartment(id: "bl",  nuclideId: "cd", name: "Blood",         follow: true, intake: true,  dispose: false, fraction: 1.0),
        Compartment(id: "li",  nuclideId: "cd", name: "Liver",         follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "ki",  nuclideId: "cd", name: "Kidney Cortex", follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "st",  nuclideId: "cd", name: "Other Tissue",  follow: true, intake: false, dispose: false, fraction: 0),
        Compartment(id: "urn", nuclideId: "cd", name: "Urine",         follow: true, intake: false, dispose: true,  fraction: 0),
    ]
    // Rates approximate; kidney accumulation is key feature
    let connections: [CompartmentConnection] = [
        CompartmentConnection(from: "bl",  to: "li",  rate: 0.200),   // rapid liver uptake
        CompartmentConnection(from: "li",  to: "bl",  rate: 0.010),   // t½_liver ≈ 70 d
        CompartmentConnection(from: "li",  to: "ki",  rate: 0.005),   // liver → kidney redistribution
        CompartmentConnection(from: "bl",  to: "ki",  rate: 0.020),   // direct kidney uptake
        CompartmentConnection(from: "ki",  to: "urn", rate: 0.0001),  // t½_kidney ≈ 7,000 d ≈ 19 y
        CompartmentConnection(from: "bl",  to: "st",  rate: 0.050),
        CompartmentConnection(from: "st",  to: "bl",  rate: 0.010),
        CompartmentConnection(from: "bl",  to: "urn", rate: 0.010),
    ]
    let model = CompartmentalModel(nuclides: [cd], compartments: compartments, connections: connections)
    return ModelDocument(
        id: UUID(uuidString: "00000006-0000-0000-0000-000000000003")!,
        name: "Cadmium Toxicokinetics (ATSDR)",
        description: "Cadmium toxicokinetic model: initial liver accumulation, followed by slow redistribution to kidney cortex where Cd binds metallothionein. Kidney cortex t½ ≈ 10–30 years — cadmium is effectively irreversibly accumulated over a lifetime. Rates approximate; GI intake assumes ~5% absorption from a chronic dietary exposure scenario.",
        field: .toxicology,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}
