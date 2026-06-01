// MARK: - ValidationIssue

extension CompartmentalModel {

    /// A structural or completeness problem detected in the model.
    public enum ValidationIssue: Sendable, Equatable {

        // MARK: Errors — solver cannot produce meaningful results

        /// No intake compartment has a positive fraction — the solver would start
        /// with all-zero initial conditions and produce a flat result.
        case noIntakeCompartment

        /// The sum of intake fractions exceeds 1.0, which is physically impossible
        /// (you cannot receive more activity than was administered).
        case intakeFractionExceedsOne(totalFraction: Double)

        /// No compartment has `follow = true`; nothing would appear in the chart.
        case noTrackedCompartment

        // MARK: Warnings — solver runs but results may be inaccurate or incomplete

        /// A nuclide has `halfLife = 0`. Zero means no radioactive decay; set the
        /// correct physical half-life if this model is used for dosimetry.
        case missingHalfLife(nuclideId: String, nuclideName: String)

        /// A compartment has no connections to any other compartment.
        case orphanedCompartment(compartmentId: String, compartmentName: String)

        // MARK: Data quality — model structure is suspect

        /// A connection references a compartment ID that does not exist in the model.
        case danglingConnectionEndpoint(missingId: String)

        /// A connection has a zero or negative rate (no material flows along it).
        case zeroRateConnection(fromName: String, toName: String)

        // MARK: Derived properties

        public enum Severity: Sendable, Comparable {
            case error, warning, info
        }

        public var severity: Severity {
            switch self {
            case .noIntakeCompartment, .noTrackedCompartment,
                 .intakeFractionExceedsOne:                        .error
            case .missingHalfLife, .orphanedCompartment:          .warning
            case .danglingConnectionEndpoint, .zeroRateConnection: .info
            }
        }

        /// Short human-readable description of what is wrong.
        public var issueDescription: String {
            switch self {
            case .noIntakeCompartment:
                "No intake compartment — enable the Intake flag on the compartment that receives the administered activity."
            case .intakeFractionExceedsOne(let total):
                String(format: "Intake fractions sum to %.4g, which exceeds 1.0 — you cannot receive more activity than was administered. Reduce individual fractions.", total)
            case .noTrackedCompartment:
                "No tracked compartments — enable Track on at least one compartment to see results in the chart."
            case .missingHalfLife(_, let name):
                "Nuclide \"\(name)\" has no half-life — set it in the Document inspector."
            case .orphanedCompartment(_, let name):
                "Compartment \"\(name)\" has no connections and will not interact with the rest of the model."
            case .danglingConnectionEndpoint(let id):
                "A connection references compartment \"\(id)\" which does not exist."
            case .zeroRateConnection(let from, let to):
                "Transfer \(from) → \(to) has a zero rate and moves no material."
            }
        }

        public var systemImageName: String {
            switch self {
            case .noIntakeCompartment:            "arrow.down.to.line"
            case .intakeFractionExceedsOne:       "exclamationmark.arrow.triangle.2.circlepath"
            case .noTrackedCompartment:           "eye.slash"
            case .missingHalfLife:                "clock.badge.exclamationmark"
            case .orphanedCompartment:            "square.dashed"
            case .danglingConnectionEndpoint:     "link.badge.plus"
            case .zeroRateConnection:             "arrow.left.and.right.slash"
            }
        }
    }

    // MARK: - Validation

    /// All structural and completeness issues in this model, sorted by severity (errors first).
    public var validationIssues: [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let byId = Dictionary(uniqueKeysWithValues: compartments.map { ($0.id, $0) })

        // ── Errors ──────────────────────────────────────────────────────────────────

        let intakeCompartments = compartments.filter(\.intake)
        let totalFraction = intakeCompartments.reduce(0) { $0 + $1.fraction }

        if !intakeCompartments.contains(where: { $0.fraction > 0 }) {
            issues.append(.noIntakeCompartment)
        }

        if totalFraction > 1.0 + 1e-9 {   // small epsilon for floating-point noise
            issues.append(.intakeFractionExceedsOne(totalFraction: totalFraction))
        }

        if !compartments.contains(where: \.follow) {
            issues.append(.noTrackedCompartment)
        }

        // ── Warnings ─────────────────────────────────────────────────────────────────

        for nuclide in nuclides where nuclide.halfLife == 0 {
            issues.append(.missingHalfLife(nuclideId: nuclide.id, nuclideName: nuclide.name))
        }

        let connectedIds = Set(connections.flatMap { [$0.from, $0.to] })
        for comp in compartments where !connectedIds.contains(comp.id) {
            issues.append(.orphanedCompartment(compartmentId: comp.id, compartmentName: comp.name))
        }

        // ── Data quality ─────────────────────────────────────────────────────────────

        var reportedMissingIds = Set<String>()
        for conn in connections {
            for endpointId in [conn.from, conn.to] where byId[endpointId] == nil {
                if reportedMissingIds.insert(endpointId).inserted {
                    issues.append(.danglingConnectionEndpoint(missingId: endpointId))
                }
            }
        }

        for conn in connections where conn.rate <= 0 {
            let fromName = byId[conn.from]?.name ?? conn.from
            let toName   = byId[conn.to]?.name   ?? conn.to
            issues.append(.zeroRateConnection(fromName: fromName, toName: toName))
        }

        return issues.sorted { $0.severity < $1.severity }
    }
}
