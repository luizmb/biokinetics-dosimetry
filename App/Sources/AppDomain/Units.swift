import CoreFP
import CoreFPOperators

// MARK: - Units
//
// Documents and the solver hold every quantity in one canonical unit per dimension: time in days,
// rates in day⁻¹. The unit a field works in is only how those numbers are shown and typed: each
// unit the app offers carries the iso from the canonical unit to itself, applied where the view
// state is made (`get`) and where typed text is read (`reverseGet`). Nothing persisted changes.

/// A unit out of a table the app offers: what it's written as, and how to get to it from the
/// canonical unit of its dimension and back.
public protocol MeasurementUnit: Hashable, Sendable {
    /// The unit's symbol in English, a key into the app's strings ("h", "day⁻¹").
    var symbol: String { get }
    /// Canonical value ⇄ value in this unit.
    var iso: Iso<Double, Double> { get }
}

/// The units time is offered in. Canonical: days.
public enum TimeUnit: String, Codable, CaseIterable, MeasurementUnit {
    case hours
    case days

    public var symbol: String {
        switch self {
        case .hours: "h"
        case .days: "d"
        }
    }

    /// Full word, capitalised, for labels (e.g. "Days", "Hours").
    public var displayName: String {
        switch self {
        case .hours: "Hours"
        case .days: "Days"
        }
    }

    public var iso: Iso<Double, Double> {
        switch self {
        case .hours: scaled(by: 24)
        case .days: .id
        }
    }
}

/// Something per unit of time: transfer rates, steps a solver takes. Canonical: day⁻¹. Never a
/// unit of its own, always the inverse of a time unit, so a field's rates can't disagree with its
/// times.
public struct RateUnit: MeasurementUnit {
    public let per: TimeUnit

    public init(per: TimeUnit) {
        self.per = per
    }

    public var symbol: String {
        switch per {
        case .hours: "h⁻¹"
        case .days: "day⁻¹"
        }
    }

    /// The time unit's iso seen through the reciprocal: 48 day⁻¹ is one per half an hour, 2 h⁻¹.
    /// Holds for every time unit that is a multiple of a day, which all of them are.
    public var iso: Iso<Double, Double> {
        reciprocal >>> per.iso >>> reciprocal
    }
}

/// The units a field shows and takes its quantities in.
public struct WorkingUnits: Hashable, Sendable {
    public let time: TimeUnit

    public init(time: TimeUnit) {
        self.time = time
    }

    public var rate: RateUnit { RateUnit(per: time) }
}

public extension ModelField {
    /// Pharmacokinetics thinks in hours; everything else in days.
    var units: WorkingUnits {
        switch self {
        case .pharmacology: WorkingUnits(time: .hours)
        case .nuclear, .toxicology, .ecology, .generic: WorkingUnits(time: .days)
        }
    }
}

private func scaled(by factor: Double) -> Iso<Double, Double> {
    Iso(get: { $0 * factor }, reverseGet: { $0 / factor })
}

private let reciprocal = Iso<Double, Double>(get: { 1 / $0 }, reverseGet: { 1 / $0 })
