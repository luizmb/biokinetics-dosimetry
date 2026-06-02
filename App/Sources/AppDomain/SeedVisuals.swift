import Domain

// MARK: - Hand-crafted canvas layouts for pre-shipped seed documents
//
// Intake compartments sit near the top (matching the upward-pointing intake arrows).
// Plasma/blood hubs are centred. Excretion sinks are at the bottom.
// Canvas logical size: 900 × 620  –  origin top-left, centre ≈ (450, 310).

/// Builds a `[String: CompartmentVisuals]` from a hand-crafted position map.
/// Compartments not present in the map fall back to the default circular layout.
func handcraftedVisuals(
    for model: CompartmentalModel,
    positions: [String: (x: Double, y: Double)],
    tints: [String: CompartmentTint] = [:]
) -> [String: CompartmentVisuals] {
    let allTints = CompartmentTint.allCases
    var result = defaultVisuals(for: model)
    for (id, pos) in positions {
        let tint = tints[id] ?? result[id]?.tint ?? allTints.randomElement() ?? .steel
        result[id] = CompartmentVisuals(x: pos.x, y: pos.y, tint: tint)
    }
    return result
}

// MARK: - Generic seed layouts

func twoCompartmentPKVisuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        "central":    (x: 320, y: 200),   // intake — top-left
        "peripheral": (x: 560, y: 310),   // right
        "clearance":  (x: 440, y: 460),   // sink — bottom
    ], tints: [
        "central":    .slate,
        "peripheral": .forest,
        "clearance":  .amber,
    ])
}

func codeineToMorphineVisuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        // Codeine — left column, intake at top
        "c_plasma":  (x: 260, y: 190),
        "c_tissue":  (x: 260, y: 370),
        // Morphine — right column
        "m_plasma":  (x: 580, y: 250),
        "m_tissue":  (x: 580, y: 410),
        "m_urine":   (x: 750, y: 460),   // sink — bottom-right
    ], tints: [
        "c_plasma":  .slate,
        "c_tissue":  .steel,
        "m_plasma":  .forest,
        "m_tissue":  .forest,
        "m_urine":   .amber,
    ])
}

func foodChainVisuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    // Horizontal chain — intake (Water) on the left
    handcraftedVisuals(for: model, positions: [
        "water":         (x: 120, y: 310),
        "algae":         (x: 270, y: 310),
        "invertebrates": (x: 440, y: 310),
        "fish":          (x: 610, y: 310),
        "elimination":   (x: 780, y: 310),
    ], tints: [
        "water":         .steel,
        "algae":         .forest,
        "invertebrates": .forest,
        "fish":          .slate,
        "elimination":   .amber,
    ])
}

func twoCompartmentGenericVisuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        "a":    (x: 310, y: 200),   // intake — top
        "b":    (x: 560, y: 310),
        "sink": (x: 450, y: 460),   // sink — bottom
    ], tints: [
        "a":    .slate,
        "b":    .forest,
        "sink": .amber,
    ])
}

// MARK: - ICRP nuclear layouts

func hydrogen3Visuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        "hto": (x: 450, y: 200),   // intake — top-centre
        "obt": (x: 270, y: 380),
        "urn": (x: 630, y: 380),   // sink — bottom-right
    ], tints: [
        "hto": .slate,
        "obt": .forest,
        "urn": .amber,
    ])
}

func caesium137Visuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        "bl":  (x: 450, y: 190),   // intake — top-centre
        "st0": (x: 620, y: 310),   // rapid exchange — right
        "st1": (x: 280, y: 310),   // slow exchange — left
        "urn": (x: 620, y: 460),   // sink — bottom-right
        "fae": (x: 280, y: 460),   // sink — bottom-left
    ], tints: [
        "bl":  .slate,
        "st0": .steel,
        "st1": .forest,
        "urn": .amber,
        "fae": .crimson,
    ])
}

func iodine131Visuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        "bl":  (x: 450, y: 190),   // intake — top-centre
        "thy": (x: 450, y: 330),   // thyroid — centre
        "oth": (x: 270, y: 330),   // other tissue — left
        "urn": (x: 640, y: 460),   // sink — bottom-right
    ], tints: [
        "bl":  .slate,
        "thy": .crimson,
        "oth": .forest,
        "urn": .amber,
    ])
}

func strontium90Visuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    handcraftedVisuals(for: model, positions: [
        "bl":  (x: 450, y: 190),   // intake — top-centre
        "bs":  (x: 450, y: 310),   // bone surface — centre
        "bv1": (x: 620, y: 310),   // bone volume exchange — right
        "bv2": (x: 770, y: 310),   // bone volume non-exchg — far-right
        "oth": (x: 270, y: 380),   // other tissue — left
        "urn": (x: 630, y: 470),   // sink — bottom-right
        "fae": (x: 290, y: 500),   // sink — bottom-left
    ], tints: [
        "bl":  .slate,
        "bs":  .steel,
        "bv1": .steel,
        "bv2": .steel,
        "oth": .forest,
        "urn": .amber,
        "fae": .crimson,
    ])
}

func uranium234Visuals(for model: CompartmentalModel) -> [String: CompartmentVisuals] {
    // Plasma at centre. Lung/intake at top. Bone right. Soft tissue left.
    // Excretion bottom-right. GI bottom-left. t-compartments far-right (compact).
    let pos: [String: (x: Double, y: Double)] = [
        // ── Plasma (hub) ────────────────────────────────────────
        "pl":   (450, 330),

        // ── Soft tissue & blood (left of plasma) ────────────────
        "st0":  (290, 295),
        "st1":  (290, 360),
        "st2":  (180, 390),
        "rbc":  (230, 230),

        // ── Bone (right of plasma) ───────────────────────────────
        "cs":   (600, 240),
        "cve":  (710, 240),
        "cvn":  (810, 240),
        "ts":   (600, 330),
        "tve":  (710, 330),
        "tvn":  (810, 330),

        // ── Liver ────────────────────────────────────────────────
        "li1":  (600, 415),
        "li2":  (710, 415),

        // ── Kidney / urinary ────────────────────────────────────
        "okt":  (540, 490),
        "urp":  (630, 490),
        "ubc":  (720, 490),
        "urn":  (820, 490),   // sink

        // ── GI tract ────────────────────────────────────────────
        "sto":  (420, 430),
        "si":   (340, 510),
        "uli":  (250, 510),
        "lli":  (160, 510),
        "fae":  ( 80, 450),   // sink

        // ── Lung — fast-dissolving (top, left→right by region) ──
        "et2":  (300, 80),
        "ets":  (400, 80),
        "BB1":  (270, 150),
        "BB2":  (360, 150),
        "BBS":  (450, 150),
        "bb1":  (260, 220),
        "bb2":  (350, 220),
        "bbs":  (440, 220),
        "ai1":  (250, 295),
        "ai2":  (340, 295),
        "ai3":  (430, 295),

        // ── Lymph nodes ──────────────────────────────────────────
        "lnth": (530, 155),
        "lnet": (530,  80),

        // ── Sequestered t-compartments (compact cluster, far right) ─
        "et2t": (700,  60),
        "etst": (790,  60),
        "BB1t": (700, 120),
        "BB2t": (790, 120),
        "BBSt": (870, 120),
        "bb1t": (700, 180),
        "bb2t": (790, 180),
        "bbst": (870, 180),
        "ai1t": (700, 240),
        "ai2t": (790, 240),
        "ai3t": (870, 240),
        "lntt": (620, 120),
        "lnett":(620,  60),
    ]

    let tintMap: [String: CompartmentTint] = [
        "pl": .slate,
        // soft tissue
        "st0": .steel, "st1": .steel, "st2": .steel, "rbc": .steel,
        // bone
        "cs": .steel, "cve": .steel, "cvn": .steel,
        "ts": .steel, "tve": .steel, "tvn": .steel,
        // liver
        "li1": .forest, "li2": .forest,
        // kidney/urinary
        "okt": .forest, "urp": .forest, "ubc": .forest, "urn": .amber,
        // GI
        "sto": .crimson, "si": .crimson, "uli": .crimson, "lli": .crimson, "fae": .amber,
        // lung
        "et2": .violet, "ets": .violet,
        "BB1": .violet, "BB2": .violet, "BBS": .violet,
        "bb1": .violet, "bb2": .violet, "bbs": .violet,
        "ai1": .violet, "ai2": .violet, "ai3": .violet,
        "lnth": .forest, "lnet": .forest,
        // t-compartments
        "et2t": .steel, "etst": .steel,
        "BB1t": .steel, "BB2t": .steel, "BBSt": .steel,
        "bb1t": .steel, "bb2t": .steel, "bbst": .steel,
        "ai1t": .steel, "ai2t": .steel, "ai3t": .steel,
        "lntt": .steel, "lnett": .steel,
    ]

    return handcraftedVisuals(for: model, positions: pos, tints: tintMap)
}
