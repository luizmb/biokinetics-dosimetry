import AppDomain
import CoreFP
import ReactiveConcurrency
import Domain
import Foundation
import Solver
import SwiftRex
import SwiftUI
import SwiftRexArchitecture
import SwiftRexReactiveConcurrency

// MARK: - CalculatorFeature

@Feature
public enum CalculatorFeature {
    // MARK: - State

    public struct State: Sendable, Equatable {
        public var document: ModelDocument = .empty
        /// The variant key to use for calculation (nil = base model).
        public var selectedVariant: String? = nil
        public var solver: SolverMethod = .birchall(composition: .perTime)
        public var finalDay: Int = 200
        /// Days between reported rows. Independent of the solver: RK4's integration step lives in
        /// `solver`, and RK45 picks its own.
        public var stepSize:     Double = 1.0
        public var stepSizeText: String = "1"
        /// Text of the RK4 integration-step and RK45 tolerance fields; the values are in `solver`.
        public var integrationStepText: String = "0.01"
        public var toleranceText: String = "1e-13"
        public var manualStepsText: String = ""
        public var results: [[Double]]?
        public var isCalculating: Bool = false
        public var error: String?
        /// Set when the solver couldn't finish: drives the message and the one-tap fixes.
        public var solveFailure: SolveError?
        public var logX: Bool = true
        public var logY: Bool = true
        public var visibleSeriesIds: Set<String> = []
        public var activeView: CalcView = .parameters
        public var isParamPanelVisible: Bool = true

        public init() {}

        /// A fresh calculator for `document`.
        ///
        /// Seeding is construction, so a re-push can never show the previous document's results: the
        /// `results`/`error`/`isCalculating` defaults are already empty. Mirrors `.load`, which the
        /// app no longer needs to dispatch.
        public init(document: ModelDocument) {
            self.init()
            self.document = document
            visibleSeriesIds = Set(document.model.compartments.filter(\.follow).map(\.id))
        }
    }

    public enum CalcView: String, Sendable, Equatable {
        case chart, report, parameters
    }

    /// A one-tap way out of a failed run: changes the settings and runs again.
    public enum Remedy: Sendable, Equatable, Hashable {
        case useAutomaticBudget
        case useBirchall

        public var title: String {
            switch self {
            case .useAutomaticBudget: "Use automatic budget"
            case .useBirchall: "Switch to Birchall"
            }
        }

        static func `for`(_ failure: SolveError, solver: SolverMethod) -> [Remedy] {
            switch failure {
            case .stepBudgetExhausted:
                if case .rungeKutta45(_, .manual) = solver { [.useAutomaticBudget, .useBirchall] } else { [.useBirchall] }
            case .unstableStep, .stepUnderflow:
                [.useBirchall]
            }
        }
    }

    // MARK: - Action

    public enum Action: Sendable {
        case load(ModelDocument)
        case calculate
        case selectVariant(String?)
        case resultsReady([[Double]])
        case resultsFailed(String)
        case solveFailed(SolveError)
        case applyRemedy(Remedy)
        case setSolver(SolverMethod)
        case setFinalDay(Int)
        case setStepSize(Double)
        case setStepSizeText(String)
        case setTolerance(Double)
        case setToleranceText(String)
        case setIntegrationStepText(String)
        case setStepBudget(StepBudget)
        case setManualStepsText(String)
        case stepSizeResolved(Double, String)
        case toleranceResolved(Double, String)
        case integrationStepResolved(Double, String)
        case setLogX(Bool)
        case setLogY(Bool)
        case toggleSeries(String)
        case setActiveView(CalcView)
        case toggleParamPanel
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        public var solve:        @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> Publisher<[[Double]], Error>
        public var formatDouble: @Sendable (Double, Int) -> String
        public var parseDouble:  @Sendable (String) -> Double?

        public init(
            solve:        @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> Publisher<[[Double]], Error>,
            formatDouble: @escaping @Sendable (Double, Int) -> String = { v, dp in String(format: "%.\(dp)f", v) },
            parseDouble:  @escaping @Sendable (String) -> Double?     = { Double($0) }
        ) {
            self.solve        = solve
            self.formatDouble = formatDouble
            self.parseDouble  = parseDouble
        }
    }

    // MARK: - ViewModel

        public struct SeriesPoint: Sendable, Equatable {
            public var day: Double
            public var value: Double
        }
        public struct Series: Identifiable, Sendable, Equatable {
            public var id: String
            public var name: String
            public var tint: CompartmentTint
            public var points: [SeriesPoint]
            public var isVisible: Bool
        }
        public struct ReportRow: Identifiable, Sendable, Equatable {
            public var id: Int  // step index
            public var day: Double
            public var values: [Double]
        }

        public struct ViewState: Sendable, Equatable {
            public var documentName: String = ""
            public var lingo: FieldLingo = ModelField.generic.lingo
            public var halfLife: Double = 0
            public var compartmentNames: [String] = []
            /// Sorted variant keys available for this document (empty = no variants).
            public var variants: [String] = []
            /// The variant key currently selected for calculation (nil = base model).
            public var selectedVariant: String? = nil
            public var solver: SolverMethod = .birchall(composition: .perTime)
            public var finalDay: Int = 200
            public var stepSizeText:  String = "1"
            public var integrationStepText: String = "0.01"
            public var toleranceText: String = "1e-13"
            public var manualStepsText: String = ""
            /// Under the RK4 step field: the model's stability limit.
            public var integrationStepHint: String? = nil
            /// The RK4 step is at or past that limit: the field shows it and Calculate is off.
            public var integrationStepIsUnstable: Bool = false
            /// Under the RK45 budget: how many steps a day this model needs.
            public var stepBudgetHint: String? = nil
            /// A manual cap below that need: roughly where the run will stop.
            public var stepBudgetWarning: String? = nil
            /// The `.automatic` budget, per day: what Manual starts from.
            public var automaticStepsPerDay: Int = 0
            /// Fixes offered with a failed run.
            public var remedies: [Remedy] = []
            /// Set when the results are a stopped run's: where the chart's valid part ends.
            public var stoppedAtDay: Double? = nil
            /// "Stopped at day 41.3", for the marker on the chart.
            public var stoppedLabel: String? = nil
            public var series: [Series] = []
            public var reportRows: [ReportRow] = []
            public var isCalculating: Bool = false
            public var error: String?
            public var logX: Bool = true
            public var logY: Bool = true
            public var activeView: CalcView = .parameters
            public var isParamPanelVisible: Bool = true
            /// Estimated solve time for the current parameters and model.
            public var durationWarning: BiokineticsSimulationPlan.DurationWarning = .none
            /// Human-readable estimate string, e.g. "~45 s" or "< 1 s".
            public var estimatedDurationLabel: String = ""

            // MARK: Pre-computed label strings

            /// Short name of the current solver method (e.g. "Birchall", "RK4", "RK45").
            public var solverShortName: String = "Birchall"
            /// Calculate button title including estimate (e.g. "Calculate · < 1 s").
            public var calculateButtonTitle: String = "Calculate"
            /// Log/Lin toggle label for the X axis.
            public var logXLabel: String = "Log X"
            /// Log/Lin toggle label for the Y axis.
            public var logYLabel: String = "Log Y"
            /// Full duration-warning message pre-formatted for the banner, or nil when .none.
            public var durationWarningMessage: String? = nil
            /// All structural and completeness issues detected in the current model.
            public var validationIssues: [CompartmentalModel.ValidationIssue] = []
            /// Non-nil when results are available — carries data for lazy CSV generation.
            public var csvExportInput: CSVExportInput? = nil
            /// Non-nil when results are available — carries data for lazy PDF generation.
            public var pdfExportInput: PDFExportInput? = nil
        }

        public enum ViewAction: Sendable {
            case calculate
            case selectVariant(String?)
            case setSolver(SolverMethod)
            case setFinalDay(Int)
            case setStepSize(Double)
            case setStepSizeText(String)
            case setTolerance(Double)
            case setToleranceText(String)
            case setIntegrationStepText(String)
            case setStepBudget(StepBudget)
            case setManualStepsText(String)
            case applyRemedy(Remedy)
            case setLogX(Bool)
            case setLogY(Bool)
            case toggleSeries(String)
            case setActiveView(CalcView)
            case toggleParamPanel
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { env in { state in
        let doc = state.document
        let compartments = doc.model.compartments.filter { $0.follow }

        var series: [Series] = []
        if let results = state.results {
            let displayTrajectory = doc.model.displayTrajectory(from: results, step: state.stepSize)
            series = compartments.enumerated().compactMap { globalIdx, comp -> Series? in
                let compIdx = doc.model.compartments.firstIndex { $0.id == comp.id } ?? globalIdx
                let points = displayTrajectory.enumerated().map { stepIdx, row -> SeriesPoint in
                    SeriesPoint(day: Double(stepIdx) * state.stepSize, value: compIdx < row.count ? row[compIdx] : 0)
                }
                let tint = doc.visuals[comp.id]?.tint ?? .steel
                let visible = state.visibleSeriesIds.isEmpty || state.visibleSeriesIds.contains(comp.id)
                return Series(id: comp.id, name: comp.name, tint: tint,
                                        points: points, isVisible: visible)
            }
        }

        // Only tracked compartments in report — same filter as chart
        let trackedIndices = compartments.compactMap { comp in
            doc.model.compartments.firstIndex { $0.id == comp.id }
        }
        let reportRows: [ReportRow] = (state.results ?? []).enumerated().map { idx, row in
            ReportRow(
                id: idx,
                day: Double(idx) * state.stepSize,
                values: trackedIndices.map { $0 < row.count ? row[$0] : 0 }
            )
        }

        let plan = BiokineticsSimulationPlan(
            step: state.stepSize,
            final: Double(state.finalDay),
            solver: state.solver
        )
        let n = doc.model.compartments.count
        // Read off the model before anything runs: RK4's stable step, RK45's steps a day.
        let limits = (state.selectedVariant.flatMap { doc.variants[$0] } ?? doc.model).solverLimits
        let estimatedSeconds = plan.estimatedDuration(compartmentCount: n, rk45StepsPerDay: limits.rk45StepsPerDay)
        let durationWarning = plan.durationWarning(compartmentCount: n, rk45StepsPerDay: limits.rk45StepsPerDay)
        let unit = doc.field.lingo.timeUnit.label
        let integrationStepIsUnstable: Bool = if case let .rungeKutta4(h) = state.solver { h >= limits.rk4StableStep } else { false }
        let integrationStepHint: String? = if case .rungeKutta4 = state.solver {
            "Stable below \(env.formatDouble(limits.rk4StableStep, 3)) \(unit) for this model"
        } else { nil }
        let stoppedAtDay: Double? = (state.results?.isEmpty == false) ? state.solveFailure?.stoppedAtDay : nil
        let partialNote: String? = stoppedAtDay.map {
            "Partial run: stopped at \(unit) \(env.formatDouble($0, 1)) of \(state.finalDay)"
        }
        let neededSteps = Int(limits.rk45StepsPerDay.rounded(.up))
        let stepBudgetHint: String? = if case .rungeKutta45 = state.solver {
            "This model needs about \(env.formatDouble(Double(neededSteps), 0)) \(neededSteps == 1 ? "step" : "steps") per \(unit)"
        } else { nil }
        let stepBudgetWarning: String? = if case let .rungeKutta45(_, .manual(cap)) = state.solver {
            limits.stoppingDay(stepsPerDay: cap, days: Double(state.finalDay)).map {
                "At \(cap) per \(unit) it will stop around \(unit) \(env.formatDouble($0, 0))."
            }
        } else { nil }
        let estimatedDurationLabel = Self.formatDuration(estimatedSeconds)

        let solverShortName: String = {
            switch state.solver {
            case .birchall:    "Birchall"
            case .rungeKutta4: "RK4"
            case .rungeKutta45: "RK45"
            }
        }()
        let calculateButtonTitle = state.isCalculating
            ? "Calculating…"
            : "Calculate · \(estimatedDurationLabel)"
        let logXLabel = state.logX ? "Log X" : "Lin X"
        let logYLabel = state.logY ? "Log Y" : "Lin Y"
        // Long runs say what would be quicker: semigroup is one exponential whatever the horizon.
        let fasterChoice: String = switch state.solver {
        case .birchall(.semigroup): ""
        case .birchall(.perTime): ". Semigroup is one exponential whatever the horizon."
        case .rungeKutta4, .rungeKutta45: ". Birchall is exact for this model."
        }
        let durationWarningMessage: String? = {
            switch durationWarning {
            case .none:    nil
            case .brief:   "Est. \(estimatedDurationLabel)"
            case .slow:    "Est. \(estimatedDurationLabel) — may be slow\(fasterChoice)"
            case .veryLong:"Est. \(estimatedDurationLabel) — this will take a long time\(fasterChoice)"
            }
        }()

        return ViewState(
            documentName: doc.name,
            lingo: doc.field.lingo,
            halfLife: doc.halfLife,
            compartmentNames: compartments.map(\.name),
            variants: doc.variants.keys.sorted(),
            selectedVariant: state.selectedVariant,
            solver: state.solver,
            finalDay: state.finalDay,
            stepSizeText:  state.stepSizeText,
            integrationStepText: state.integrationStepText,
            toleranceText: state.toleranceText,
            manualStepsText: state.manualStepsText,
            integrationStepHint: integrationStepHint,
            integrationStepIsUnstable: integrationStepIsUnstable,
            stepBudgetHint: stepBudgetHint,
            stepBudgetWarning: stepBudgetWarning,
            automaticStepsPerDay: limits.automaticStepsPerDay,
            remedies: state.solveFailure.map { Remedy.for($0, solver: state.solver) } ?? [],
            stoppedAtDay: stoppedAtDay,
            stoppedLabel: stoppedAtDay.map { "Stopped at \(env.formatDouble($0, 1)) \(unit)" },
            series: series,
            reportRows: reportRows,
            isCalculating: state.isCalculating,
            error: state.solveFailure.map { message(for: $0, format: env.formatDouble) } ?? state.error,
            logX: state.logX,
            logY: state.logY,
            activeView: state.activeView,
            isParamPanelVisible: state.isParamPanelVisible,
            durationWarning: durationWarning,
            estimatedDurationLabel: estimatedDurationLabel,
            solverShortName: solverShortName,
            calculateButtonTitle: calculateButtonTitle,
            logXLabel: logXLabel,
            logYLabel: logYLabel,
            durationWarningMessage: durationWarningMessage,
            validationIssues: doc.model.validationIssues.filter { issue in
                if case .missingHalfLife = issue { return doc.field == .nuclear }
                return true
            },
            csvExportInput: reportRows.isEmpty ? nil : CSVExportInput(
                documentName: doc.name, lingo: doc.field.lingo,
                compartmentNames: compartments.map(\.name),
                rows: reportRows.map { ($0.day, $0.values) },
                note: partialNote
            ),
            pdfExportInput: reportRows.isEmpty ? nil : PDFExportInput(
                documentName: doc.name, lingo: doc.field.lingo,
                compartmentNames: compartments.map(\.name),
                rows: reportRows.map { ($0.day, $0.values) },
                note: partialNote
            )
        )
    } }

    // MARK: - Duration formatting

    static func formatDuration(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<1:    "< 1 s"
        case ..<10:   "~\(Int(seconds.rounded())) s"
        case ..<60:   "~\(Int((seconds / 5).rounded()) * 5) s"
        case ..<3600: "~\(Int((seconds / 60).rounded())) min"
        default:      "> 1 h"
        }
    }

    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { va in
        switch va {
        case .calculate:                .calculate
        case .selectVariant(let k):     .selectVariant(k)
        case .setSolver(let s):         .setSolver(s)
        case .setFinalDay(let d):       .setFinalDay(d)
        case .setStepSize(let s):       .setStepSize(s)
        case .setStepSizeText(let t):   .setStepSizeText(t)
        case .setTolerance(let t):      .setTolerance(t)
        case .setToleranceText(let t):  .setToleranceText(t)
        case .setIntegrationStepText(let t): .setIntegrationStepText(t)
        case .setStepBudget(let b):     .setStepBudget(b)
        case .setManualStepsText(let t): .setManualStepsText(t)
        case .applyRemedy(let r):       .applyRemedy(r)
        case .setLogX(let v):           .setLogX(v)
        case .setLogY(let v):           .setLogY(v)
        case .toggleSeries(let id):     .toggleSeries(id)
        case .setActiveView(let v):     .setActiveView(v)
        case .toggleParamPanel:         .toggleParamPanel
        }
    } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            switch action {
            case .load(let doc):
                .reduce { state in
                    state.document = doc
                    state.results = nil
                    state.error = nil
                    state.isCalculating = false
                    state.activeView = .parameters
                    state.visibleSeriesIds = Set(doc.model.compartments.filter(\.follow).map(\.id))
                }
            case .selectVariant(let key):
                .reduce { $0.selectedVariant = key }
            case .calculate:
                // Capture pre-mutation state in phase 1 (@MainActor — context.stateBefore is safe here)
                calculateReaction(context: context)
            case .resultsReady(let data):
                .reduce { $0.results = data; $0.isCalculating = false }
            case .resultsFailed(let msg):
                .reduce { $0.error = msg; $0.isCalculating = false }
            case .solveFailed(let failure):
                // What ran before the stop is valid: keep it as the results, marked by the failure.
                .reduce { state in
                    state.solveFailure = failure
                    state.results = failure.partial.isEmpty ? nil : failure.partial
                    state.isCalculating = false
                }
            case .applyRemedy(let remedy):
                .reduce { state in
                    switch remedy {
                    case .useAutomaticBudget:
                        if case let .rungeKutta45(tolerance, _) = state.solver {
                            state.solver = .rungeKutta45(tolerance: tolerance, budget: .automatic)
                        }
                    case .useBirchall:
                        state.solver = .birchall(composition: .perTime)
                    }
                }
                .produce { _ in .just(.calculate) }
            case .setSolver(let s):
                // Picking a method resets its parameters to the ones it carries, fields included.
                .reduce { state in
                    state.solver = s
                    if case let .rungeKutta45(tolerance, _) = s { state.toleranceText = Self.scientific(tolerance) }
                }
                .produce { ctx in
                    guard case let .rungeKutta4(h) = s else { return .empty }
                    return .just(.integrationStepResolved(h, ctx.environment.formatDouble(h, 4)))
                }
            case .setFinalDay(let d):
                .reduce { $0.finalDay = max(1, d) }
            case .setStepSize(let s):
                .produce { ctx in
                    let v = max(0.001, s)
                    return .just(.stepSizeResolved(v, ctx.environment.formatDouble(v, 6)))
                }
            case .setStepSizeText(let text):
                .produce { ctx in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    if let v = ctx.environment.parseDouble(t) {
                        let clamped = max(0.001, v)
                        return .just(.stepSizeResolved(clamped, ctx.environment.formatDouble(clamped, 6)))
                    }
                    return .just(.stepSizeResolved(0, t))  // store raw text; stepSize unchanged until valid
                }
            case .stepSizeResolved(let v, let t):
                .reduce { $0.stepSize = v > 0 ? v : $0.stepSize; $0.stepSizeText = t }

            case .setTolerance(let t):
                .produce { _ in
                    let v = max(1e-14, min(1e-2, t))
                    return .just(.toleranceResolved(v, Self.scientific(v)))
                }
            case .setToleranceText(let text):
                .produce { ctx in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    // `Double(_:)` reads exponent notation ("1e-13"), which the locale formatter doesn't.
                    if let v = ctx.environment.parseDouble(t) ?? Double(t) {
                        let clamped = max(1e-14, min(1e-2, v))
                        return .just(.toleranceResolved(clamped, clamped == v ? t : Self.scientific(clamped)))
                    }
                    return .just(.toleranceResolved(0, t))
                }
            case .toleranceResolved(let v, let t):
                .reduce { state in
                    state.toleranceText = t
                    if v > 0, case let .rungeKutta45(_, budget) = state.solver {
                        state.solver = .rungeKutta45(tolerance: v, budget: budget)
                    }
                }
            case .setIntegrationStepText(let text):
                .produce { ctx in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    if let v = ctx.environment.parseDouble(t) ?? Double(t), v > 0 {
                        return .just(.integrationStepResolved(v, t))
                    }
                    return .just(.integrationStepResolved(0, t))
                }
            case .integrationStepResolved(let v, let t):
                .reduce { state in
                    state.integrationStepText = t
                    if v > 0, case .rungeKutta4 = state.solver { state.solver = .rungeKutta4(stepSize: v) }
                }
            case .setStepBudget(let budget):
                .reduce { state in
                    if case let .rungeKutta45(tolerance, _) = state.solver {
                        state.solver = .rungeKutta45(tolerance: tolerance, budget: budget)
                    }
                    if case let .manual(cap) = budget { state.manualStepsText = "\(cap)" }
                }
            case .setManualStepsText(let text):
                .reduce { state in
                    state.manualStepsText = text
                    if let cap = Int(text.trimmingCharacters(in: .whitespaces)), cap > 0,
                       case let .rungeKutta45(tolerance, .manual) = state.solver {
                        state.solver = .rungeKutta45(tolerance: tolerance, budget: .manual(stepsPerDay: cap))
                    }
                }
            case .setLogX(let v):
                .reduce { $0.logX = v }
            case .setLogY(let v):
                .reduce { $0.logY = v }
            case .toggleSeries(let id):
                .reduce { state in
                    if state.visibleSeriesIds.contains(id) {
                        state.visibleSeriesIds.remove(id)
                    } else {
                        state.visibleSeriesIds.insert(id)
                    }
                }
            case .setActiveView(let v):
                .reduce { $0.activeView = v }
            case .toggleParamPanel:
                .reduce { $0.isParamPanelVisible.toggle() }
            }
        }
    }

    /// Builds the consequence for `.calculate`, extracted so the switch arms in `behavior()` are
    /// all single expressions (required for Swift's implicit-return switch expression inference).
    @MainActor
    private static func calculateReaction(
        context: PreReducerContext<State>
    ) -> Reaction<Action, State, Environment> {
        let snapshot = context.stateBefore
        let state = snapshot ?? State()
        let doc = state.document
        // Resolve variant model: use named variant if selected, else base model.
        let model = state.selectedVariant.flatMap { doc.variants[$0] } ?? doc.model
        let plan = BiokineticsSimulationPlan(
            step: state.stepSize,
            final: Double(state.finalDay),
            solver: state.solver
        )
        return .reduce { $0.isCalculating = true; $0.error = nil; $0.solveFailure = nil }
            .produce { ctx in
                (ctx.environment.solve(plan, model)).asEffect { result in
                    switch result {
                    case .success(let data): return .resultsReady(data)
                    case .failure(let e):
                        return (e as? SolveError).map(Action.solveFailed) ?? .resultsFailed(e.localizedDescription)
                    }
                }
            }
    }

    /// "1e-13": tolerances span orders of magnitude, so they're shown by exponent.
    static func scientific(_ value: Double) -> String {
        String(format: "%.0e", value).replacingOccurrences(of: "e-0", with: "e-")
    }

    /// What a solver that couldn't finish tells the user, with numbers in their locale.
    public static func message(for error: SolveError, format: (Double, Int) -> String) -> String {
        switch error {
        case let .unstableStep(step, limit):
            "An RK4 step of \(format(step, 4)) d is unstable for this model. Use a step below \(format(limit, 3)) d, or Birchall."
        case let .stepBudgetExhausted(reached, final, steps, partial):
            "RK45 stopped at day \(format(reached, 1)) of \(format(final, 0)) after \(steps) steps\(partial.isEmpty ? "" : "; the results cover the days it reached"). Raise the step budget, or use Birchall."
        case let .stepUnderflow(day, partial):
            "RK45 could not take a step at day \(format(day, 1))\(partial.isEmpty ? "" : "; the results cover the days before it"). Use Birchall for this model."
        }
    }

    public typealias Content = CalculatorView
}
