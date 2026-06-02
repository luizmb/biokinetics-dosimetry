import Domain

// MARK: - ICRP Nuclear Seed Models
//
// Transfer rates (day⁻¹) transcribed from:
//   • U-234: ICRP 137 / Leggett (1994), as encoded in the IPEN reference XML
//   • H-3:   ICRP 56 Part 1 (1989)
//   • Cs-137: ICRP 67 (1993)
//   • I-131:  ICRP 67 (1993)
//   • Sr-90:  ICRP 67 (1993)
//
// Physical half-lives (days):
//   U-234 = 89,060,000 d   Cs-137 = 11,012 d   I-131 = 8.02 d
//   H-3   = 4,499 d        Sr-90  = 10,512 d

public extension SeedDocuments {
    static var icrpModels: [ModelDocument] {
        [uranium234, hydrogen3, caesium137, iodine131, strontium90]
    }
}

// MARK: - U-234 (Type S / M / F)

private var uranium234: ModelDocument {
    let nuclide = Nuclide(id: "u234", name: "U-234", halfLife: 89_060_000)

    // ── Compartments ────────────────────────────────────────────────────
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        // Systemic
        ("pl",  "Plasma",                          true,  false, false, 0),
        ("st0", "Rapid Turnover (ST0)",            false, false, false, 0),
        ("st1", "Intermediate Turnover (ST1)",     false, false, false, 0),
        ("st2", "Slow Turnover (ST2)",             false, false, false, 0),
        ("rbc", "RBC",                             false, false, false, 0),
        ("cs",  "Cortical Surface",                false, false, false, 0),
        ("cve", "Cortical Volume Exchange",        false, false, false, 0),
        ("cvn", "Cortical Volume NoExchange",      false, false, false, 0),
        ("ts",  "Trabecular Surface",              false, false, false, 0),
        ("tve", "Trabecular Volume Exchange",      false, false, false, 0),
        ("tvn", "Trabecular Volume NoExchange",    false, false, false, 0),
        ("li1", "Liver 1",                         false, false, false, 0),
        ("li2", "Liver 2",                         false, false, false, 0),
        ("okt", "Other Kidney Tissue",             false, false, false, 0),
        ("urp", "Urinary Path",                    false, false, false, 0),
        ("ubc", "Urinary Bladder Contents",        false, false, false, 0),
        ("sto", "Stomach (ST)",                    true,  false, false, 0),
        ("si",  "Small Intestine (SI)",            false, false, false, 0),
        ("uli", "Upper Large Intestine (ULI)",     false, false, false, 0),
        ("lli", "Lower Large Intestine (LLI)",     false, false, false, 0),
        ("fae", "Faeces",                          false, false, true,  0),
        ("urn", "Urina",                           true,  false, true,  0),
        // Lung — fast-dissolving fraction
        ("ai1", "AI1",    false, true,  false, 0.0159),
        ("ai2", "AI2",    false, true,  false, 0.0318),
        ("ai3", "AI3",    false, true,  false, 0.0053),
        ("bb1", "bb1",    false, true,  false, 0.006556),
        ("bb2", "bb2",    false, true,  false, 0.004367),
        ("bbs", "bbseq",  false, true,  false, 0.000077),
        ("BB1", "BB1",    false, true,  false, 0.01188),
        ("BB2", "BB2",    false, true,  false, 0.005994),
        ("BBS", "BBseq",  false, true,  false, 0.000126),
        ("et2", "ET2",    false, true,  false, 0.3998),
        ("ets", "ETseq",  false, true,  false, 0.0002),
        // Lung — slow-dissolving (sequestered) fraction
        ("ai1t","AI1t",   false, false, false, 0),
        ("ai2t","AI2t",   false, false, false, 0),
        ("ai3t","AI3t",   false, false, false, 0),
        ("bb1t","bb1t",   false, false, false, 0),
        ("bb2t","bb2t",   false, false, false, 0),
        ("bbst","bbseqt", false, false, false, 0),
        ("BB1t","BB1t",   false, false, false, 0),
        ("BB2t","BB2t",   false, false, false, 0),
        ("BBSt","BBseqt", false, false, false, 0),
        ("et2t","ET2t",   false, false, false, 0),
        ("etst","ETseqt", false, false, false, 0),
        // Lymph nodes
        ("lnth","LNth",   false, false, false, 0),
        ("lntt","LNtht",  false, false, false, 0),
        ("lnet","LNet",   false, false, false, 0),
        ("lnett","LNett", false, false, false, 0),
    ]

    // ── Connections ─────────────────────────────────────────────────────
    typealias K = (String, String, Double)
    let conns: [K] = [
        // Plasma ⇄ systemic
        ("pl","st0",10.5), ("st0","pl",8.32),
        ("pl","st1",1.63), ("st1","pl",0.0347),
        ("pl","st2",0.0735),("st2","pl",1.9e-5),
        ("pl","rbc",0.245), ("rbc","pl",0.347),
        ("pl","li1",0.367), ("li1","pl",0.092),
        ("pl","okt",0.0122),("okt","pl",0.00038),
        // Bone — cortical
        ("pl","cs",1.63),  ("cs","pl",0.0693),
        ("cs","cve",0.0693),("cve","cs",0.0173),
        ("cve","cvn",0.00578),("cvn","pl",8.21e-5),
        // Bone — trabecular
        ("pl","ts",2.04),  ("ts","pl",0.0693),
        ("ts","tve",0.0693),("tve","ts",0.0173),
        ("tve","tvn",0.00578),("tvn","pl",0.000493),
        // Liver
        ("li1","li2",0.00693),("li2","pl",0.00019),
        // Urinary path
        ("pl","urp",2.94), ("urp","ubc",0.099),
        ("pl","ubc",15.43),("ubc","urn",12),
        // GI tract
        ("pl","uli",0.122),
        ("sto","si",24), ("si","pl",0.012),
        ("si","uli",6),  ("uli","lli",1.8),("lli","fae",1),
        // Lung → plasma (Type S: s_p = 0.1 day⁻¹)
        ("ai1","pl",0.1), ("ai2","pl",0.1), ("ai3","pl",0.1),
        ("bb1","pl",0.1), ("bb2","pl",0.1), ("bbs","pl",0.1),
        ("BB1","pl",0.1), ("BB2","pl",0.1), ("BBS","pl",0.1),
        ("et2","pl",0.1), ("ets","pl",0.1),
        // Lung mechanical clearance
        ("ai1","bb1",0.02),  ("ai2","bb1",0.001), ("ai3","bb1",0.0001),
        ("ai3","lnth",2e-5),
        ("bb1","BB1",2),     ("bb2","BB1",0.03),
        ("bbs","lnth",0.01), ("BBS","lnth",0.01),
        ("BB1","et2",10),    ("BB2","et2",0.03),
        ("et2","sto",100),
        // Lung transformation to sequestered form (rate 100 means fast initial sequestration)
        ("ai1","ai1t",100),("ai2","ai2t",100),("ai3","ai3t",100),
        ("bb1","bb1t",100),("bb2","bb2t",100),("bbs","bbst",100),
        ("BB1","BB1t",100),("BB2","BB2t",100),("BBS","BBSt",100),
        ("et2","et2t",100),("ets","etst",100),
        // Sequestered → plasma (Type S: s_pt = 0.0001 day⁻¹)
        ("ai1t","pl",0.0001),("ai2t","pl",0.0001),("ai3t","pl",0.0001),
        ("bb1t","pl",0.0001),("bb2t","pl",0.0001),("bbst","pl",0.0001),
        ("BB1t","pl",0.0001),("BB2t","pl",0.0001),("BBSt","pl",0.0001),
        ("et2t","pl",0.0001),("etst","pl",0.0001),
        // Sequestered mechanical clearance
        ("ai1t","bb1t",0.02),("ai2t","bb1t",0.001),("ai3t","bb1t",0.0001),
        ("ai3t","lntt",2e-5),
        ("bb1t","BB1t",2),  ("bb2t","BB1t",0.03),
        ("BB1t","et2t",10), ("BB2t","et2t",0.03),
        ("et2t","sto",100),
        ("bbst","lntt",0.01),("BBSt","lntt",0.01),
        // Sequestered → lymph nodes
        ("ets","lnet",0.001),("etst","lnett",0.001),
        // Lymph nodes
        ("lnth","pl",0.1),  ("lnth","lntt",100),
        ("lntt","pl",0.0001),
        ("lnet","pl",0.1),  ("lnet","lnett",100),
        ("lnett","pl",0.0001),
        // ETseq path
        ("ets","etst",100),
    ]

    let model = buildModel(nuclide: nuclide, comps: comps, conns: conns)

    // Build Type F and M variants by scaling lung absorption rates
    let typeF = lungVariant(of: model, nuclide: nuclide, plasmaRate: 100, seqRate: 10)
    let typeM = lungVariant(of: model, nuclide: nuclide, plasmaRate: 10,  seqRate: 0.001)

    return ModelDocument(
        name: "U-234 Inhalation (ICRP 137)",
        description: "ICRP 137 systemic model with ICRP 66 respiratory tract model for U-234 inhalation intake. Base model is Type S (slow lung absorption). Type M and Type F variants alter the lung-to-blood transfer rates. Physical T½ = 89,060,000 d.",
        field: .nuclear,
        model: model,
        variants: ["Type F": typeF, "Type M": typeM],
        visuals: defaultVisuals(for: model)
    )
}

/// Replaces all lung-compartment → Plasma connections with the given rates,
/// leaving the systemic model unchanged.
private let lungIDs: Set<String> = [
    "ai1","ai2","ai3","bb1","bb2","bbs","BB1","BB2","BBS","et2","ets",
    "ai1t","ai2t","ai3t","bb1t","bb2t","bbst","BB1t","BB2t","BBSt","et2t","etst",
    "lnth","lntt","lnet","lnett"
]

private func lungVariant(
    of base: CompartmentalModel,
    nuclide: Nuclide,
    plasmaRate: Double,
    seqRate: Double
) -> CompartmentalModel {
    let seqIDs = Set(["ai1t","ai2t","ai3t","bb1t","bb2t","bbst",
                      "BB1t","BB2t","BBSt","et2t","etst","lntt","lnett"])
    let modified = base.connections.map { conn -> CompartmentConnection in
        guard conn.to == "pl", lungIDs.contains(conn.from) else { return conn }
        let rate = seqIDs.contains(conn.from) ? seqRate : plasmaRate
        return CompartmentConnection(from: conn.from, to: conn.to, rate: rate)
    }
    return CompartmentalModel(nuclides: base.nuclides,
                              compartments: base.compartments,
                              connections: modified)
}

// MARK: - H-3 (Tritium) — ICRP 56

private var hydrogen3: ModelDocument {
    let nuclide = Nuclide(id: "h3", name: "H-3 (Tritium)", halfLife: 4499)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("hto", "Body Water (HTO)",  true, true,  false, 0.97),
        ("obt", "Organic Bound (OBT)", false, true, false, 0.03),
        ("urn", "Urine",             true, false, true,  0),
    ]
    typealias K = (String, String, Double)
    let conns: [K] = [
        ("hto","urn",0.0693),   // T½ bio = 10 d
        ("obt","hto",0.0173),   // T½ bio = 40 d → recycles back to body water
    ]
    let model = buildModel(nuclide: nuclide, comps: comps, conns: conns)
    return ModelDocument(
        name: "H-3 Tritiated Water (ICRP 56)",
        description: "ICRP 56 Part 1 model for HTO inhalation or ingestion. 97% as body water (T½ bio ≈ 10 d), 3% as organically bound tritium (T½ bio ≈ 40 d). Physical T½ = 4499 d (12.32 y).",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Cs-137 — ICRP 67

private var caesium137: ModelDocument {
    let nuclide = Nuclide(id: "cs137", name: "Cs-137", halfLife: 11012)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",              true, true,  false, 1.0),
        ("st0", "Rapid Tissue (ST0)", false, false, false, 0),
        ("st1", "Slow Tissue (ST1)",  false, false, false, 0),
        ("urn", "Urine",              true, false,  true, 0),
        ("fae", "Faeces",             false, false,  true, 0),
    ]
    typealias K = (String, String, Double)
    // ICRP 67 Table B.1 for Cs — simplified 2-pool model.
    // Fast pool (muscle/soft tissue): T½ bio ≈ 2 d  → k = 0.347
    // Slow pool (skeleton):           T½ bio ≈ 110 d → k = 0.00630
    let conns: [K] = [
        ("bl","st0",1.98),  ("st0","bl",0.347),   // rapid exchange
        ("bl","st1",0.22),  ("st1","bl",0.00630),  // slow exchange
        ("bl","urn",0.231),                         // urinary excretion
        ("bl","fae",0.0116),                        // faecal excretion
    ]
    let model = buildModel(nuclide: nuclide, comps: comps, conns: conns)
    return ModelDocument(
        name: "Cs-137 Systemic (ICRP 67)",
        description: "ICRP 67 simplified systemic model for Cs-137. Fast soft-tissue pool (T½ bio ≈ 2 d) and slow skeletal pool (T½ bio ≈ 110 d). Physical T½ = 11,012 d (30.2 y).",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - I-131 — ICRP 67

private var iodine131: ModelDocument {
    let nuclide = Nuclide(id: "i131", name: "I-131", halfLife: 8.02)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",         true,  true,  false, 1.0),
        ("thy", "Thyroid",       true,  false, false, 0),
        ("oth", "Other Tissue",  false, false, false, 0),
        ("urn", "Urine",         true,  false, true,  0),
    ]
    typealias K = (String, String, Double)
    // ICRP 67: thyroid uptake 30%, biological T½ in thyroid ≈ 80 d.
    // Thyroid: T½ bio = 80 d → k_thy = ln2/80 = 0.00866
    // Other:   T½ bio = 12 d → k_oth = ln2/12 = 0.0578
    let conns: [K] = [
        ("bl","thy",0.0693),     // 30% uptake, fast transfer
        ("bl","oth",0.162),      // 70% to other tissue
        ("bl","urn",0.0231),     // direct urinary excretion
        ("thy","bl",0.00866),    // thyroid hormone secretion
        ("oth","bl",0.0578),     // tissue return to blood
    ]
    let model = buildModel(nuclide: nuclide, comps: comps, conns: conns)
    return ModelDocument(
        name: "I-131 Thyroid (ICRP 67)",
        description: "ICRP 67 model for I-131. 30% thyroid uptake (T½ bio = 80 d), remainder in other tissue (T½ bio = 12 d). Physical T½ = 8.02 d.",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Sr-90 — ICRP 67

private var strontium90: ModelDocument {
    let nuclide = Nuclide(id: "sr90", name: "Sr-90", halfLife: 10512)
    typealias C = (id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)
    let comps: [C] = [
        ("bl",  "Blood",                     true,  true,  false, 1.0),
        ("bs",  "Bone Surface",              false, false, false, 0),
        ("bv1", "Bone Volume (Exchangeable)",false, false, false, 0),
        ("bv2", "Bone Volume (Non-exchg.)",  false, false, false, 0),
        ("oth", "Other Tissue",              false, false, false, 0),
        ("urn", "Urine",                     true,  false, true,  0),
        ("fae", "Faeces",                    false, false, true,  0),
    ]
    typealias K = (String, String, Double)
    // ICRP 67 Sr model (simplified):
    // Blood → Bone Surface: fast deposition (Ca-like)
    // Bone Surface ⇄ Bone Volume Exchange: slow
    // Bone Volume Exchange → Non-exchangeable: remodelling rate ≈ 0.000493 day⁻¹
    // Physical T½ = 28.8 y = 10512 d
    let conns: [K] = [
        ("bl","bs",14.6),    ("bs","bl",0.693),
        ("bs","bv1",0.0693), ("bv1","bs",0.0173),
        ("bv1","bv2",0.000493),
        ("bl","oth",4.88),   ("oth","bl",0.347),
        ("bl","urn",3.65),
        ("bl","fae",0.366),
    ]
    let model = buildModel(nuclide: nuclide, comps: comps, conns: conns)
    return ModelDocument(
        name: "Sr-90 Bone Seeker (ICRP 67)",
        description: "ICRP 67 simplified model for Sr-90, a calcium-analogue bone seeker. Deposition on bone surface followed by volume incorporation and slow skeletal remodelling. Physical T½ = 10,512 d (28.8 y).",
        field: .nuclear,
        model: model,
        visuals: defaultVisuals(for: model)
    )
}

// MARK: - Builder helpers

private func buildModel(
    nuclide: Nuclide,
    comps: [(id: String, name: String, follow: Bool, intake: Bool, dispose: Bool, fraction: Double)],
    conns: [(String, String, Double)]
) -> CompartmentalModel {
    let compartments = comps.map { c in
        Compartment(id: c.id, nuclideId: nuclide.id, name: c.name,
                    follow: c.follow, intake: c.intake, dispose: c.dispose, fraction: c.fraction)
    }
    let connections = conns.map { CompartmentConnection(from: $0.0, to: $0.1, rate: $0.2) }
    return CompartmentalModel(nuclides: [nuclide], compartments: compartments, connections: connections)
}
