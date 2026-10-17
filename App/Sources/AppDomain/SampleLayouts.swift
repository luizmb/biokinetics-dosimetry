/// Computed layouts for the samples a hand-made layout couldn't keep readable: positions from
/// `tidyLayout`, recorded into `SampleLayouts+Generated.swift` (computing them at launch would
/// take seconds for the large ICRP 137 models).
public enum SampleLayouts {
    /// The samples laid out by `tidyLayout`; the others keep their hand-made layouts.
    public static let keys = [
        "icrp.u234.type.s", "icrp.u238.chain", "icrp.cs137", "icrp.sr90", "icrp.pb210.po210", "tox.cadmium",
    ]

    /// The seed the recorded layouts were computed with.
    public static let seed: UInt64 = 0x5EED
}

/// `visuals` with the recorded positions of sample `key`, tints kept.
func withSampleLayout(_ key: String, _ visuals: [String: CompartmentVisuals]) -> [String: CompartmentVisuals] {
    let positions = SampleLayouts.positions[key] ?? [:]
    return visuals.reduce(into: [:]) { result, entry in
        let position = positions[entry.key]
        result[entry.key] = CompartmentVisuals(x: position?.x ?? entry.value.x, y: position?.y ?? entry.value.y, tint: entry.value.tint)
    }
}
