import Domain
import Foundation

// MARK: - Extended ICRP Nuclear Models
//
// Sources: ICRP Publications 56, 67, 69, 137.
// Where exact transfer rates are uncertain, values are noted as approximate
// and follow the general structure of the ICRP systemic models.

public extension SeedDocuments {
    static func extendedNuclearModels(idFor: @Sendable (String) -> UUID) -> [ModelDocument] {
        [plutonium239(idFor: idFor), americium241(idFor: idFor), cobalt60(idFor: idFor), technetium99m(idFor: idFor), thorium232(idFor: idFor), lead210polonium210(idFor: idFor)]
    }
}

// MARK: - Pu-239 (ICRP 67 simplified)

private func plutonium239(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let n = Nuclide(id: "pu239", name: "Pu-239", halfLife: 2.4110e4 * 365.25)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",              true, true,  false, 1.0),
        ("bn",  "Bone",               false, false, false, 0),
        ("li",  "Liver",              false, false, false, 0),
        ("st",  "Other Tissue",       false, false, false, 0),
        ("urn", "Urine",              true,  false, true,  0),
        ("fae", "Faeces",             false, false, true,  0),
    ]
    typealias K = (String, String, Double)
    // ICRP 67 approximate rates (day⁻¹)
    let conns: [K] = [
        ("bl","bn",0.034), ("bn","bl",0.000693),
        ("bl","li",0.035), ("li","bl",0.00693),
        ("bl","st",0.030), ("st","bl",0.00693),
        ("bl","urn",0.010),("bl","fae",0.005),
    ]
    let model = buildSimpleModel(nuclide: n, comps: comps, conns: conns)
    return ModelDocument(
        id: idFor("icrp.pu239"),
        name: "Pu-239 Systemic (ICRP 67)",
        description: "Simplified ICRP 67 systemic model for Pu-239. Plutonium is a bone and liver seeker with extremely slow bone resorption. Rates are approximate; consult ICRP 67 Annex B for exact values. Physical T½ = 24,110 y.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Am-241 (ICRP 67 simplified, similar to Pu)

private func americium241(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let n = Nuclide(id: "am241", name: "Am-241", halfLife: 432.7 * 365.25)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",        true,  true,  false, 1.0),
        ("bn",  "Bone",         false, false, false, 0),
        ("li",  "Liver",        false, false, false, 0),
        ("st",  "Other Tissue", false, false, false, 0),
        ("urn", "Urine",        true,  false, true,  0),
        ("fae", "Faeces",       false, false, true,  0),
    ]
    typealias K = (String, String, Double)
    let conns: [K] = [
        ("bl","bn",0.034), ("bn","bl",0.000693),
        ("bl","li",0.060), ("li","bl",0.00693),
        ("bl","st",0.030), ("st","bl",0.00693),
        ("bl","urn",0.010),("bl","fae",0.005),
    ]
    let model = buildSimpleModel(nuclide: n, comps: comps, conns: conns)
    return ModelDocument(
        id: idFor("icrp.am241"),
        name: "Am-241 Systemic (ICRP 67)",
        description: "Simplified ICRP 67 systemic model for Am-241. Americium behaves similarly to Pu — bone and liver seeker — but with slightly higher liver uptake. Physical T½ = 432.7 y.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Co-60 (ICRP 56 simplified)

private func cobalt60(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let n = Nuclide(id: "co60", name: "Co-60", halfLife: 5.272 * 365.25)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",        true,  true,  false, 1.0),
        ("li",  "Liver",        false, false, false, 0),
        ("st",  "Other Tissue", false, false, false, 0),
        ("urn", "Urine",        true,  false, true,  0),
    ]
    typealias K = (String, String, Double)
    // ICRP 56 cobalt rates (day⁻¹); cobalt resembles vitamin B12 metabolism
    let conns: [K] = [
        ("bl","li",0.100), ("li","bl",0.040),
        ("bl","st",0.050), ("st","bl",0.010),
        ("bl","urn",0.020),
    ]
    let model = buildSimpleModel(nuclide: n, comps: comps, conns: conns)
    return ModelDocument(
        id: idFor("icrp.co60"),
        name: "Co-60 Systemic (ICRP 56)",
        description: "Simplified ICRP 56 Part 3 model for Co-60. Cobalt follows a vitamin B12-like distribution: rapid liver uptake followed by gradual redistribution. Physical T½ = 5.27 y.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Tc-99m (nuclear medicine, simplified)

private func technetium99m(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let n = Nuclide(id: "tc99m", name: "Tc-99m", halfLife: 6.01 / 24.0)  // 6.01 h in days
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    // Whole-body pertechnetate model (unbound Tc-99m)
    let comps: [C] = [
        ("bl",  "Blood",        true,  true,  false, 1.0),
        ("st",  "Soft Tissue",  false, false, false, 0),
        ("thy", "Thyroid",      false, false, false, 0),
        ("urn", "Urine",        true,  false, true,  0),
    ]
    typealias K = (String, String, Double)
    // Pertechnetate distributes rapidly; excreted mainly via kidney
    let conns: [K] = [
        ("bl","st",0.500),  ("st","bl",0.300),
        ("bl","thy",0.020), ("thy","bl",0.005),
        ("bl","urn",0.200),
    ]
    let model = buildSimpleModel(nuclide: n, comps: comps, conns: conns)
    return ModelDocument(
        id: idFor("icrp.tc99m"),
        name: "Tc-99m Whole Body (Pertechnetate)",
        description: "Simplified whole-body model for unbound Tc-99m pertechnetate, the most common nuclear medicine tracer. Rapid distribution followed by predominant renal excretion. Physical T½ = 6.01 h. Agent-specific biodistribution (e.g. labelled with HMPAO or MDP) is not modelled here.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Th-232 (simplified, same structure as Th-234)

private func thorium232(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let n = Nuclide(id: "th232", name: "Th-232", halfLife: 1.405e10 * 365.25)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",        true,  true,  false, 1.0),
        ("bn",  "Bone",         false, false, false, 0),
        ("li",  "Liver",        false, false, false, 0),
        ("st",  "Soft Tissue",  false, false, false, 0),
        ("ex",  "Excretion",    true,  false, true,  0),
    ]
    typealias K = (String, String, Double)
    let conns: [K] = [
        ("bl","bn",14.6), ("bn","bl",0.0693),
        ("bl","li",4.88), ("li","bl",0.0693),
        ("bl","st",2.0),  ("st","bl",0.0693),
        ("bl","ex",3.65),
    ]
    let model = buildSimpleModel(nuclide: n, comps: comps, conns: conns)
    return ModelDocument(
        id: idFor("icrp.th232"),
        name: "Th-232 Systemic (ICRP 67)",
        description: "Simplified ICRP 67 systemic model for Th-232 (naturally occurring thorium). Same compartmental structure as Th-234 with effectively infinite physical half-life (T½ = 14.05 Gy). Thorium is a bone seeker with slow urinary excretion.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Pb-210 / Po-210 standalone chain

private func lead210polonium210(idFor: @Sendable (String) -> UUID) -> ModelDocument {
    let pb210 = Nuclide(id: "pb210s", name: "Pb-210", halfLife: 22.3 * 365.25)
    let po210 = Nuclide(id: "po210s", name: "Po-210", halfLife: 138.4)

    let λPb210 = log(2) / (22.3 * 365.25)

    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let pb210comps: [C] = [
        ("pbl",  "Pb210 Blood",       true,  true,  false, 1.0),
        ("pbn",  "Pb210 Bone",        false, false, false, 0),
        ("pst",  "Pb210 Soft Tissue", false, false, false, 0),
        ("pex",  "Pb210 Excretion",   true,  false, true,  0),
    ]
    let po210comps: [C] = [
        ("obl",  "Po210 Blood",       true,  false, false, 0),
        ("oli",  "Po210 Liver",       false, false, false, 0),
        ("oki",  "Po210 Kidney",      false, false, false, 0),
        ("oex",  "Po210 Excretion",   true,  false, true,  0),
    ]

    typealias K = (String, String, Double)
    let conns: [K] =
        // Pb-210 systemic (Rabinowitz-inspired)
        [("pbl","pbn",0.0111),("pbn","pbl",6.95e-5),
         ("pbl","pst",0.0111),("pst","pbl",0.0111),
         ("pbl","pex",0.0174)] +
        // Po-210 systemic
        [("obl","oli",0.250),("oli","obl",0.050),
         ("obl","oki",0.100),("oki","obl",0.020),
         ("obl","oex",0.100)] +
        // Cross-nuclide: each Pb-210 compartment → Po-210 blood
        ["pbl","pbn","pst","pex"].map { ($0, "obl", λPb210) }

    let model = CompartmentalModel(
        nuclides: [pb210, po210],
        compartments: (pb210comps + po210comps).map { c in
            Compartment(id: c.id, nuclideId: c.id.hasPrefix("p") ? "pb210s" : "po210s",
                        name: c.name, follow: c.follow, intake: c.intake,
                        dispose: c.dispose, fraction: c.fraction)
        },
        connections: conns.map { CompartmentConnection(from: $0.0, to: $0.1, rate: $0.2) }
    )
    return ModelDocument(
        id: idFor("icrp.pb210.po210"),
        name: "Pb-210 → Po-210 Chain (ICRP 67)",
        description: "Two-nuclide chain for Pb-210 (T½ = 22.3 y) and its daughter Po-210 (T½ = 138.4 d). Relevant for naturally occurring radioactivity (smoking, fish consumption, polonium poisoning). Pb-210 systemic model based on Rabinowitz et al. (1976). Po-210 distributes to blood, liver, and kidney with relatively rapid clearance.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Builder helper

private func buildSimpleModel(
    nuclide: Nuclide,
    comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)],
    conns: [(String, String, Double)]
) -> CompartmentalModel {
    CompartmentalModel(
        nuclides: [nuclide],
        compartments: comps.map { c in
            Compartment(id: c.id, nuclideId: nuclide.id, name: c.name,
                        follow: c.follow, intake: c.intake, dispose: c.dispose, fraction: c.fraction)
        },
        connections: conns.map { CompartmentConnection(from: $0.0, to: $0.1, rate: $0.2) }
    )
}
