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

/// The time unit a model's rates and durations are expressed in.
///
/// The solver is dimensionless — `TimeUnit` is purely a display convention.
/// A model whose rates are defined in h⁻¹ should use `.hours`; one with day⁻¹ rates should use `.days`.
public enum TimeUnit: String, Codable, Hashable, Sendable {
    case days
    case hours

    /// Short abbreviation used as a suffix in the UI (e.g. "3 d", "8 h").
    public var label: String {
        switch self {
        case .days:  "d"
        case .hours: "h"
        }
    }

    /// Full word, capitalised, for labels (e.g. "Days", "Hours").
    public var displayName: String {
        switch self {
        case .days:  "Days"
        case .hours: "Hours"
        }
    }
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
    /// Transfer rate unit shown next to rate fields (e.g. "day⁻¹", "h⁻¹").
    public let rateUnit: String
    /// Human-readable field name shown in pickers.
    public let fieldName: String
    /// Default time unit for this field.
    public let timeUnit: TimeUnit
    /// Whether a non-zero half-life is required for the model to be meaningful.
    /// `true` for nuclear (halfLife=0 means "not yet set").
    /// `false` for all other fields (halfLife=0 means "stable / no spontaneous elimination").
    public let isHalfLifeRequired: Bool
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
                fieldName:        "Nuclear / Dosimetry",
                timeUnit:         .days,
                isHalfLifeRequired: true
            )
        case .pharmacology:
            FieldLingo(
                substanceName:    "Substance",
                substancesLabel:  "Substances",
                halfLifeLabel:    "Elim. T½",
                intakeLabel:      "Dose",
                eliminationLabel: "Clearance",
                rateUnit:         "h⁻¹",
                fieldName:        "Pharmacology / PK",
                timeUnit:         .hours,
                isHalfLifeRequired: false
            )
        case .toxicology:
            FieldLingo(
                substanceName:    "Compound",
                substancesLabel:  "Compounds",
                halfLifeLabel:    "Half-life",
                intakeLabel:      "Exposure",
                eliminationLabel: "Excretion",
                rateUnit:         "day⁻¹",
                fieldName:        "Toxicology",
                timeUnit:         .days,
                isHalfLifeRequired: false
            )
        case .ecology:
            FieldLingo(
                substanceName:    "Species",
                substancesLabel:  "Species",
                halfLifeLabel:    "Degrad. T½",
                intakeLabel:      "Source",
                eliminationLabel: "Sink",
                rateUnit:         "day⁻¹",
                fieldName:        "Ecology",
                timeUnit:         .days,
                isHalfLifeRequired: false
            )
        case .generic:
            FieldLingo(
                substanceName:    "Substance",
                substancesLabel:  "Substances",
                halfLifeLabel:    "Half-life",
                intakeLabel:      "Intake",
                eliminationLabel: "Elimination",
                rateUnit:         "day⁻¹",
                fieldName:        "Generic",
                timeUnit:         .days,
                isHalfLifeRequired: false
            )
        }
    }
}
