import Domain
import Foundation

// MARK: - U-238 Full Decay Chain
//
// Transfer rates from ICRP 137 / Leggett (1994) for uranium systemic model.
// Daughter systemic models simplified from ICRP 67/137 (3–5 compartments each).
// Cross-nuclide production rates = λ_parent (radioactive decay constant).
//
// Progeny modelled: U-238 → Th-234 → U-234 → Th-230 → Ra-226 → Pb-210 → Po-210
// Omitted: Pa-234m (T½ 1.2 min, instantaneous), Rn-222 (gas, mostly exhaled),
//          short-lived daughters between Rn-222 and Pb-210.
// Note: 85% of Ra-226 decays to Rn-222 which is exhaled; only 15% contributes
//       to the Pb-210 systemic burden (reflected in connection rate).

public extension SeedDocuments {
    static var nuclearChainModels: [ModelDocument] { [uranium238Chain] }
}

// MARK: - Decay constants (day⁻¹)

private let λU238  = log(2) / (4.468e9   * 365.25)   // 4.24e-13
private let λTh234 = log(2) / 24.1                    // 0.02876
private let λU234  = log(2) / (2.455e5   * 365.25)   // 7.73e-9
private let λTh230 = log(2) / (7.54e4    * 365.25)   // 2.52e-8
private let λRa226 = log(2) / (1600.0    * 365.25)   // 1.19e-6
private let λPb210 = log(2) / (22.3      * 365.25)   // 8.51e-5
private let λPo210 = log(2) / 138.4                   // 5.01e-3

// MARK: - Full chain model

private var uranium238Chain: ModelDocument {

    // ── Nuclides ────────────────────────────────────────────────────────
    let u238  = Nuclide(id: "u238",  name: "U-238",  halfLife: 4.468e9   * 365.25)
    let th234 = Nuclide(id: "th234", name: "Th-234", halfLife: 24.1)
    let u234  = Nuclide(id: "u234",  name: "U-234",  halfLife: 2.455e5   * 365.25)
    let th230 = Nuclide(id: "th230", name: "Th-230", halfLife: 7.54e4    * 365.25)
    let ra226 = Nuclide(id: "ra226", name: "Ra-226", halfLife: 1600.0    * 365.25)
    let pb210 = Nuclide(id: "pb210", name: "Pb-210", halfLife: 22.3      * 365.25)
    let po210 = Nuclide(id: "po210", name: "Po-210", halfLife: 138.4)

    // ── U-238 systemic compartments (same structure as IPEN U-234 Type S)
    let u238comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("u238_pl",  "U238 Plasma",                   true,  false, false, 0),
        ("u238_st0", "U238 Rapid Turnover",            false, false, false, 0),
        ("u238_st1", "U238 Intermediate Turnover",     false, false, false, 0),
        ("u238_st2", "U238 Slow Turnover",             false, false, false, 0),
        ("u238_rbc", "U238 RBC",                       false, false, false, 0),
        ("u238_cs",  "U238 Cortical Surface",          false, false, false, 0),
        ("u238_cve", "U238 Cortical Vol Exchange",     false, false, false, 0),
        ("u238_cvn", "U238 Cortical Vol NoExchange",   false, false, false, 0),
        ("u238_ts",  "U238 Trabecular Surface",        false, false, false, 0),
        ("u238_tve", "U238 Trabecular Vol Exchange",   false, false, false, 0),
        ("u238_tvn", "U238 Trabecular Vol NoExchange", false, false, false, 0),
        ("u238_li1", "U238 Liver 1",                   false, false, false, 0),
        ("u238_li2", "U238 Liver 2",                   false, false, false, 0),
        ("u238_okt", "U238 Other Kidney Tissue",       false, false, false, 0),
        ("u238_ubc", "U238 Urinary Bladder",           false, false, false, 0),
        ("u238_urn", "U238 Urine",                     true,  false, true,  0),
        ("u238_fae", "U238 Faeces",                    false, false, true,  0),
        ("u238_sto", "U238 Stomach",                   false, false, false, 0),
        // Lung intake (Type S fractions — inhalation scenario)
        ("u238_et2", "U238 ET2",   false, true,  false, 0.3998),
        ("u238_BB1", "U238 BB1",   false, true,  false, 0.01188),
        ("u238_bb1", "U238 bb1",   false, true,  false, 0.006556),
        ("u238_ai1", "U238 AI1",   false, true,  false, 0.0159),
        ("u238_ai2", "U238 AI2",   false, true,  false, 0.0318),
    ]

    // Th-234 simplified systemic (thorium: bone seeker, ICRP 67 simplified)
    let th234comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("th234_bl", "Th234 Blood",      true,  false, false, 0),
        ("th234_bn", "Th234 Bone",       false, false, false, 0),
        ("th234_li", "Th234 Liver",      false, false, false, 0),
        ("th234_st", "Th234 Soft Tissue",false, false, false, 0),
        ("th234_ex", "Th234 Excretion",  true,  false, true,  0),
    ]

    // U-234 simplified systemic
    let u234comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("u234_pl",  "U234 Plasma",       true,  false, false, 0),
        ("u234_bn",  "U234 Bone",         false, false, false, 0),
        ("u234_li",  "U234 Liver",        false, false, false, 0),
        ("u234_okt", "U234 Kidney",       false, false, false, 0),
        ("u234_urn", "U234 Urine",        true,  false, true,  0),
    ]

    // Th-230 (same structure as Th-234)
    let th230comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("th230_bl", "Th230 Blood",      true,  false, false, 0),
        ("th230_bn", "Th230 Bone",       false, false, false, 0),
        ("th230_li", "Th230 Liver",      false, false, false, 0),
        ("th230_st", "Th230 Soft Tissue",false, false, false, 0),
        ("th230_ex", "Th230 Excretion",  true,  false, true,  0),
    ]

    // Ra-226 (same structure as our Sr-90/Ra-226 seed)
    let ra226comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("ra226_bl",  "Ra226 Blood",                  true,  false, false, 0),
        ("ra226_bs",  "Ra226 Bone Surface",            false, false, false, 0),
        ("ra226_bv1", "Ra226 Bone Vol Exchange",       false, false, false, 0),
        ("ra226_bv2", "Ra226 Bone Vol Non-Exchange",   false, false, false, 0),
        ("ra226_st",  "Ra226 Other Tissue",            false, false, false, 0),
        ("ra226_urn", "Ra226 Urine",                   true,  false, true,  0),
        ("ra226_fae", "Ra226 Faeces",                  false, false, true,  0),
    ]

    // Pb-210 simplified (lead model, ICRP 67 / Rabinowitz inspired)
    let pb210comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("pb210_bl", "Pb210 Blood",       true,  false, false, 0),
        ("pb210_bn", "Pb210 Bone",        false, false, false, 0),
        ("pb210_st", "Pb210 Soft Tissue", false, false, false, 0),
        ("pb210_ex", "Pb210 Excretion",   true,  false, true,  0),
    ]

    // Po-210 simplified (polonium: distributes to blood, liver, kidney, spleen)
    let po210comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)] = [
        ("po210_bl", "Po210 Blood",       true,  false, false, 0),
        ("po210_li", "Po210 Liver",       false, false, false, 0),
        ("po210_ki", "Po210 Kidney",      false, false, false, 0),
        ("po210_ex", "Po210 Excretion",   true,  false, true,  0),
    ]

    // ── Build compartments with nuclideId ────────────────────────────────
    func build(_ list: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)],
               nuclide: Nuclide) -> [Compartment] {
        list.map { Compartment(id: $0.id, nuclideId: nuclide.id, name: $0.name,
                               follow: $0.follow, intake: $0.intake, dispose: $0.dispose, fraction: $0.fraction) }
    }

    let allCompartments =
        build(u238comps, nuclide: u238) +
        build(th234comps, nuclide: th234) +
        build(u234comps, nuclide: u234) +
        build(th230comps, nuclide: th230) +
        build(ra226comps, nuclide: ra226) +
        build(pb210comps, nuclide: pb210) +
        build(po210comps, nuclide: po210)

    // ── U-238 systemic connections ────────────────────────────────────────
    typealias K = (String, String, Double)
    let u238conns: [K] = [
        ("u238_pl","u238_st0",10.5), ("u238_st0","u238_pl",8.32),
        ("u238_pl","u238_st1",1.63), ("u238_st1","u238_pl",0.0347),
        ("u238_pl","u238_st2",0.0735),("u238_st2","u238_pl",1.9e-5),
        ("u238_pl","u238_rbc",0.245), ("u238_rbc","u238_pl",0.347),
        ("u238_pl","u238_li1",0.367), ("u238_li1","u238_pl",0.092),
        ("u238_pl","u238_okt",0.0122),("u238_okt","u238_pl",0.00038),
        ("u238_pl","u238_cs",1.63),   ("u238_cs","u238_pl",0.0693),
        ("u238_cs","u238_cve",0.0693),("u238_cve","u238_cs",0.0173),
        ("u238_cve","u238_cvn",0.00578),("u238_cvn","u238_pl",8.21e-5),
        ("u238_pl","u238_ts",2.04),   ("u238_ts","u238_pl",0.0693),
        ("u238_ts","u238_tve",0.0693),("u238_tve","u238_ts",0.0173),
        ("u238_tve","u238_tvn",0.00578),("u238_tvn","u238_pl",0.000493),
        ("u238_li1","u238_li2",0.00693),("u238_li2","u238_pl",0.00019),
        ("u238_pl","u238_ubc",15.43),("u238_ubc","u238_urn",12),
        ("u238_sto","u238_pl",0.012),
        ("u238_et2","u238_pl",0.1),("u238_et2","u238_sto",100),
        ("u238_BB1","u238_pl",0.1),("u238_BB1","u238_et2",10),
        ("u238_bb1","u238_pl",0.1),("u238_bb1","u238_BB1",2),
        ("u238_ai1","u238_pl",0.1),("u238_ai1","u238_bb1",0.02),
        ("u238_ai2","u238_pl",0.1),("u238_ai2","u238_bb1",0.001),
    ]

    // ── Th-234 systemic connections (thorium, bone seeker) ────────────────
    let th234conns: [K] = [
        ("th234_bl","th234_bn",14.6),("th234_bn","th234_bl",0.0693),
        ("th234_bl","th234_li",4.88),("th234_li","th234_bl",0.0693),
        ("th234_bl","th234_st",2.0), ("th234_st","th234_bl",0.0693),
        ("th234_bl","th234_ex",3.65),
    ]

    // ── U-234 simplified systemic ─────────────────────────────────────────
    let u234conns: [K] = [
        ("u234_pl","u234_bn",3.67), ("u234_bn","u234_pl",0.0693),
        ("u234_pl","u234_li",0.367),("u234_li","u234_pl",0.092),
        ("u234_pl","u234_okt",0.0122),("u234_okt","u234_pl",0.00038),
        ("u234_pl","u234_urn",15.43),
    ]

    // ── Th-230 (same as Th-234) ───────────────────────────────────────────
    let th230conns: [K] = [
        ("th230_bl","th230_bn",14.6),("th230_bn","th230_bl",0.0693),
        ("th230_bl","th230_li",4.88),("th230_li","th230_bl",0.0693),
        ("th230_bl","th230_st",2.0), ("th230_st","th230_bl",0.0693),
        ("th230_bl","th230_ex",3.65),
    ]

    // ── Ra-226 systemic (same rates as Sr-90) ─────────────────────────────
    let ra226conns: [K] = [
        ("ra226_bl","ra226_bs",14.6), ("ra226_bs","ra226_bl",0.693),
        ("ra226_bs","ra226_bv1",0.0693),("ra226_bv1","ra226_bs",0.0173),
        ("ra226_bv1","ra226_bv2",0.000493),
        ("ra226_bl","ra226_st",4.88), ("ra226_st","ra226_bl",0.347),
        ("ra226_bl","ra226_urn",3.65),("ra226_bl","ra226_fae",0.366),
    ]

    // ── Pb-210 simplified ──────────────────────────────────────────────────
    let pb210conns: [K] = [
        ("pb210_bl","pb210_bn",0.0111),("pb210_bn","pb210_bl",6.95e-5),
        ("pb210_bl","pb210_st",0.0111),("pb210_st","pb210_bl",0.0111),
        ("pb210_bl","pb210_ex",0.0174),
    ]

    // ── Po-210 simplified ──────────────────────────────────────────────────
    let po210conns: [K] = [
        ("po210_bl","po210_li",0.25), ("po210_li","po210_bl",0.05),
        ("po210_bl","po210_ki",0.10), ("po210_ki","po210_bl",0.02),
        ("po210_bl","po210_ex",0.10),
    ]

    // ── Cross-nuclide production connections ──────────────────────────────
    // Each compartment of parent → blood of daughter at rate λ_parent
    let u238ids  = u238comps.map(\.id)
    let th234ids = th234comps.map(\.id)
    let u234ids  = u234comps.map(\.id)
    let th230ids = th230comps.map(\.id)
    let ra226ids = ra226comps.map(\.id)
    let pb210ids = pb210comps.map(\.id)

    let chainConns: [K] =
        u238ids.map  { ($0, "th234_bl", λU238) } +    // U238 → Th234
        th234ids.map { ($0, "u234_pl",  λTh234) } +   // Th234 → U234
        u234ids.map  { ($0, "th230_bl", λU234) } +    // U234 → Th230
        th230ids.map { ($0, "ra226_bl", λTh230) } +   // Th230 → Ra226
        // Ra-226 → Pb-210 via Rn-222; 85% exhaled, 15% stays
        ra226ids.map { ($0, "pb210_bl", λRa226 * 0.15) } +
        pb210ids.map { ($0, "po210_bl", λPb210) }     // Pb210 → Po210

    // ── Assemble model ────────────────────────────────────────────────────
    let allConns = (u238conns + th234conns + u234conns + th230conns +
                   ra226conns + pb210conns + po210conns + chainConns)
        .map { CompartmentConnection(from: $0.0, to: $0.1, rate: $0.2) }

    let model = CompartmentalModel(
        nuclides: [u238, th234, u234, th230, ra226, pb210, po210],
        compartments: allCompartments,
        connections: allConns
    )

    return ModelDocument(
        id: UUID(uuidString: "00000003-0000-0000-0000-000000000001")!,
        name: "U-238 Decay Chain (ICRP 137)",
        description: "Multi-nuclide model for U-238 inhalation (Type S) with full progeny tracking: U-238 → Th-234 → U-234 → Th-230 → Ra-226 → Pb-210 → Po-210. Pa-234m and short-lived Rn daughters are omitted (effectively instantaneous). 85% of Ra-226 decays to exhaled Rn-222; only 15% contributes to the Pb-210 burden. Daughter systemic models are simplified (5–7 compartments); U-238 uses the full ICRP 137 / Leggett lung+systemic model (Type S).",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}
