/// The scientific field a model belongs to.
///
/// Choosing a field does not affect the underlying math or stored data — it only
/// changes the label strings shown in the UI (substance name, half-life label,
/// intake/elimination terminology, rate unit).
public enum ModelField: String, Codable, CaseIterable, Hashable, Sendable {
    case nuclear
    case pharmacology
    case toxicology
    case ecology
    case generic
}

/// UI label strings for a given `ModelField`.
public struct FieldLingo: Sendable, Equatable {
    /// The concept of a tracked substance (e.g. "Nuclide", "Substance", "Compound").
    public let substanceName: String
    /// Plural form of `substanceName` (e.g. "Nuclides", "Substances").
    public let substancesLabel: String
    /// Label for the spontaneous-loss half-life field (e.g. "T½", "Elimination T½").
    public let halfLifeLabel: String
    /// Label for the intake/source flag on a compartment.
    public let intakeLabel: String
    /// Label for the elimination/sink flag on a compartment.
    public let eliminationLabel: String
    /// Transfer rate unit shown next to rate fields.
    public let rateUnit: String
    /// Human-readable field name shown in pickers.
    public let fieldName: String
}

public extension ModelField {
    var lingo: FieldLingo {
        switch self {
        case .nuclear:
            FieldLingo(
                substanceName:    "Nuclide",
                substancesLabel:  "Nuclides",
                halfLifeLabel:    "T½",
                intakeLabel:      "Intake",
                eliminationLabel: "Elimination",
                rateUnit:         "day⁻¹",
                fieldName:        "Nuclear / Dosimetry"
            )
        case .pharmacology:
            FieldLingo(
                substanceName:    "Substance",
                substancesLabel:  "Substances",
                halfLifeLabel:    "Elim. T½",
                intakeLabel:      "Dose",
                eliminationLabel: "Clearance",
                rateUnit:         "day⁻¹",
                fieldName:        "Pharmacology / PK"
            )
        case .toxicology:
            FieldLingo(
                substanceName:    "Compound",
                substancesLabel:  "Compounds",
                halfLifeLabel:    "Half-life",
                intakeLabel:      "Exposure",
                eliminationLabel: "Excretion",
                rateUnit:         "day⁻¹",
                fieldName:        "Toxicology"
            )
        case .ecology:
            FieldLingo(
                substanceName:    "Species",
                substancesLabel:  "Species",
                halfLifeLabel:    "Degrad. T½",
                intakeLabel:      "Source",
                eliminationLabel: "Sink",
                rateUnit:         "day⁻¹",
                fieldName:        "Ecology"
            )
        case .generic:
            FieldLingo(
                substanceName:    "Substance",
                substancesLabel:  "Substances",
                halfLifeLabel:    "Half-life",
                intakeLabel:      "Intake",
                eliminationLabel: "Elimination",
                rateUnit:         "day⁻¹",
                fieldName:        "Generic"
            )
        }
    }
}
