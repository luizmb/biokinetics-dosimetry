import AppDomain
import CoreFP
import ReactiveConcurrency
import Domain
import Foundation
import Solver
import SwiftRex
import SwiftUI
import Localization
import SwiftRexArchitecture
import SwiftRexReactiveConcurrency

// MARK: - CalculatorFeature

@Feature
public enum CalculatorFeature {
    // MARK: - State

    public struct State: Sendable, Equatable {
        public var document: ModelDocument = .empty
        /// The screen's traits, from the world through the app's state (see `DeviceTraits`).
        public var traits: DeviceTraits = .initial
        /// The variant key to use for calculation (nil = base model).
        public var selectedVariant: String? = nil
        public var solver: SolverMethod = .birchall(composition: .perTime)
        /// Days run, in days like everything the state holds; shown in the field's time unit.
        public var finalDay: Double = 200
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
            // The defaults are 200 and 1 of whatever unit the field works in: 200 days, 200 hours.
            let time = document.field.units.time.iso
            finalDay = time.reverseGet(200)
            stepSize = time.reverseGet(1)
            visibleSeriesIds = Set(document.model.compartments.filter(\.follow).map(\.id))
        }
    }

    public enum CalcView: String, Sendable, Equatable {
        case chart, report, parameters
    }

    /// A one-tap way out of a failed run: changes the settings and runs again.
    /// A typed parameter field, formatted when editing ends.
    public enum ParameterField: Sendable, Equatable, Hashable {
        case reportEvery, integrationStep, tolerance, manualSteps
    }

    public enum Remedy: Sendable, Equatable, Hashable {
        case useAutomaticBudget
        case useBirchall

        public var title: LocalizedStringKey {
            switch self {
            case .useAutomaticBudget: L.Calc.useAutomaticBudget
            case .useBirchall: L.Calc.switchToBirchall
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
        /// The duration, in the field's time unit.
        case setDuration(Int)
        case setStepSize(Double)
        case setStepSizeText(String)
        case setTolerance(Double)
        case setToleranceText(String)
        case setIntegrationStepText(String)
        case setStepBudget(StepBudget)
        case setManualStepsText(String)
        case commitField(ParameterField)
        case fieldFormatted(ParameterField, String)
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
        public var formatScientific: @Sendable (Double, Int) -> String
        public var formatInteger: @Sendable (Int) -> String
        public var formatSignificant: @Sendable (Double) -> String

        public init(
            solve:        @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> Publisher<[[Double]], Error>,
            formatDouble: @escaping @Sendable (Double, Int) -> String,
            parseDouble:  @escaping @Sendable (String) -> Double?,
            formatScientific: @escaping @Sendable (Double, Int) -> String,
            formatInteger: @escaping @Sendable (Int) -> String,
            formatSignificant: @escaping @Sendable (Double) -> String
        ) {
            self.solve        = solve
            self.formatDouble = formatDouble
            self.parseDouble  = parseDouble
            self.formatScientific = formatScientific
            self.formatInteger = formatInteger
            self.formatSignificant = formatSignificant
        }
    }

    // MARK: - ViewModel

        /// A point of a series, its time in the field's time unit.
        public struct SeriesPoint: Sendable, Equatable {
            public var time: Double
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
            /// In the field's time unit.
            public var time: Double
            public var values: [Double]
            /// The row as the table shows it, written by the world where the view state is made.
            public var timeText: String
            public var valueTexts: [String]
        }

        /// A mark on one of the chart's axes: where it sits (in the axis's own terms, an exponent on
        /// a log axis) and what it says, written by the world.
        public struct AxisTick: Sendable, Equatable {
            public var value: Double
            public var label: String
        }

        public struct ViewState: Sendable, Equatable {
            public var documentName: String = ""
            public var lingo: FieldLingo = ModelField.generic.lingo
            /// The units every time and rate below is in: the field's.
            public var units: WorkingUnits = ModelField.generic.units
            public var halfLife: Double = 0
            public var compartmentNames: [String] = []
            /// Sorted variant keys available for this document (empty = no variants).
            public var variants: [String] = []
            /// The variant key currently selected for calculation (nil = base model).
            public var selectedVariant: String? = nil
            public var solver: SolverMethod = .birchall(composition: .perTime)
            /// The duration, in the field's time unit.
            public var duration: Int = 200
            public var stepSizeText:  String = "1"
            public var integrationStepText: String = "0.01"
            public var toleranceText: String = "1e-13"
            public var manualStepsText: String = ""
            /// Under the RK4 step field: the model's stability limit.
            public var integrationStepHint: LocalizedStringResource? = nil
            /// The RK4 step is at or past that limit: the field shows it and Calculate is off.
            public var integrationStepIsUnstable: Bool = false
            /// Under the RK45 budget: how many steps a day this model needs.
            public var stepBudgetHint: LocalizedStringResource? = nil
            /// A manual cap below that need: roughly where the run will stop.
            public var stepBudgetWarning: LocalizedStringResource? = nil
            /// The `.automatic` budget, per day (the solver's unit, passed back as is): what Manual
            /// starts from.
            public var automaticStepsPerDay: Int = 0
            /// Fixes offered with a failed run.
            public var remedies: [Remedy] = []
            /// Set when the results are a stopped run's: where the chart's valid part ends, in the
            /// field's time unit.
            public var stoppedAt: Double? = nil
            /// "Stopped at day 41.3", for the marker on the chart.
            public var stoppedLabel: LocalizedStringResource? = nil
            public var series: [Series] = []
            public var reportRows: [ReportRow] = []
            public var isCalculating: Bool = false
            public var error: LocalizedStringResource?
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
            public var calculateButtonTitle: LocalizedStringResource = L.Resource.Calc.calculate
            /// Log/Lin toggle label for the X axis.
            public var logXLabel: LocalizedStringResource = L.Resource.Calc.logX
            /// Log/Lin toggle label for the Y axis.
            public var logYLabel: LocalizedStringResource = L.Resource.Calc.logY
            /// Full duration-warning message pre-formatted for the banner, or nil when .none.
            public var durationWarningMessage: LocalizedStringResource? = nil
            /// What would be quicker, said after a slow estimate; nil when nothing is.
            public var fasterChoiceHint: LocalizedStringResource? = nil
            /// All structural and completeness issues detected in the current model.
            public var validationIssues: [CompartmentalModel.ValidationIssue] = []
            /// Non-nil when results are available — carries data for lazy CSV generation.
            public var csvExportInput: CSVExportInput? = nil
            /// Non-nil when results are available — carries data for lazy PDF generation.
            public var pdfExportInput: PDFExportInput? = nil

            /// The screen's appearance, read off the state's traits here, in the projection.
            public var colorScheme: ColorScheme
            /// A narrow (or short) screen, read off the state's traits here.
            public var isCompact: Bool
            /// Each validation issue's text, in step with `validationIssues`.
            public var validationIssueTexts: [LocalizedStringResource] = []
            /// The chart's axis marks, chosen and written here rather than by the chart.
            public var xTicks: [AxisTick] = []
            public var yTicks: [AxisTick] = []
            /// The duration as the stepper shows it, and each step it offers as VoiceOver says it.
            public var durationText: String = ""
            public var durationStepTexts: [Int: String] = [:]
        }

        public enum ViewAction: Sendable {
            case calculate
            case selectVariant(String?)
            case setSolver(SolverMethod)
            case setDuration(Int)
            case setStepSize(Double)
            case setStepSizeText(String)
            case setTolerance(Double)
            case setToleranceText(String)
            case setIntegrationStepText(String)
            case setStepBudget(StepBudget)
            case setManualStepsText(String)
            case commitField(ParameterField)
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
        // The state and the solver count in days; the screen in the field's units.
        let units = doc.field.units
        let time = units.time.iso.get
        let rate = units.rate.iso.get
        let duration = Int(time(state.finalDay).rounded())

        var series: [Series] = []
        if let results = state.results {
            let displayTrajectory = doc.model.displayTrajectory(from: results, step: state.stepSize)
            series = compartments.enumerated().compactMap { globalIdx, comp -> Series? in
                let compIdx = doc.model.compartments.firstIndex { $0.id == comp.id } ?? globalIdx
                let points = displayTrajectory.enumerated().map { stepIdx, row -> SeriesPoint in
                    SeriesPoint(time: time(Double(stepIdx) * state.stepSize), value: compIdx < row.count ? row[compIdx] : 0)
                }
                let tint = doc.visuals[comp.id]?.tint ?? .steel
                let visible = state.visibleSeriesIds.isEmpty || state.visibleSeriesIds.contains(comp.id)
                return Series(id: comp.id, name: comp.name, tint: tint,
                                        points: points, isVisible: visible)
            }
        }

        let issues = doc.model.validationIssues.filter { issue in
            if case .missingHalfLife = issue { return doc.field == .nuclear }
            return true
        }

        // Only tracked compartments in report — same filter as chart
        let trackedIndices = compartments.compactMap { comp in
            doc.model.compartments.firstIndex { $0.id == comp.id }
        }
        let reportRows: [ReportRow] = (state.results ?? []).enumerated().map { idx, row in
            ReportRow(
                id: idx,
                time: time(Double(idx) * state.stepSize),
                values: trackedIndices.map { $0 < row.count ? row[$0] : 0 },
                timeText: env.formatDouble(time(Double(idx) * state.stepSize), 0),
                valueTexts: trackedIndices.map { env.formatScientific($0 < row.count ? row[$0] : 0, 9) }
            )
        }

        let plan = BiokineticsSimulationPlan(
            step: state.stepSize,
            final: state.finalDay,
            solver: state.solver
        )
        let n = doc.model.compartments.count
        // Read off the model before anything runs: RK4's stable step, RK45's steps a day.
        let limits = (state.selectedVariant.flatMap { doc.variants[$0] } ?? doc.model).solverLimits
        let estimatedSeconds = plan.estimatedDuration(compartmentCount: n, rk45StepsPerDay: limits.rk45StepsPerDay)
        let durationWarning = plan.durationWarning(compartmentCount: n, rk45StepsPerDay: limits.rk45StepsPerDay)
        let unit = units.time.symbol
        let integrationStepIsUnstable: Bool = if case let .rungeKutta4(h) = state.solver { h >= limits.rk4StableStep } else { false }
        let integrationStepHint: LocalizedStringResource? = if case .rungeKutta4 = state.solver {
            L.Resource.Calc.stableBelow(env.formatDouble(time(limits.rk4StableStep), 3), unit)
        } else { nil }
        let stoppedAt: Double? = ((state.results?.isEmpty == false) ? state.solveFailure?.stoppedAtDay : nil).map(time)
        let partialNote: String? = stoppedAt.map {
            String(localized: L.Resource.Calc.partialRun(env.formatDouble($0, 1), env.formatDouble(Double(duration), 0), unit))
        }
        let neededSteps = Int(rate(limits.rk45StepsPerDay).rounded(.up))
        let stepBudgetHint: LocalizedStringResource? = if case .rungeKutta45 = state.solver {
            neededSteps == 1
                ? L.Resource.Calc.needsStepsOne(env.formatDouble(Double(neededSteps), 0), unit)
                : L.Resource.Calc.needsStepsOther(env.formatDouble(Double(neededSteps), 0), unit)
        } else { nil }
        let stepBudgetWarning: LocalizedStringResource? = if case let .rungeKutta45(_, .manual(cap)) = state.solver {
            limits.stoppingDay(stepsPerDay: cap, days: state.finalDay).map {
                L.Resource.Calc.willStopAround(env.formatDouble(rate(Double(cap)).rounded(.up), 0), unit, unit, env.formatDouble(time($0), 0))
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
            ? L.Resource.Common.calculating
            : L.Resource.Calc.calculateWithEstimate(estimatedDurationLabel)
        let logXLabel = state.logX ? L.Resource.Calc.logX : L.Resource.Calc.linX
        let logYLabel = state.logY ? L.Resource.Calc.logY : L.Resource.Calc.linY
        // Long runs say what would be quicker: semigroup is one exponential whatever the horizon.
        let fasterChoice: LocalizedStringResource? = switch state.solver {
        case .birchall(.semigroup): nil
        case .birchall(.perTime): L.Resource.Calc.semigroupHint
        case .rungeKutta4, .rungeKutta45: L.Resource.Calc.birchallHint
        }
        let durationWarningMessage: LocalizedStringResource? = switch durationWarning {
        case .none: nil
        case .brief: L.Resource.Calc.estimate(estimatedDurationLabel)
        case .slow: L.Resource.Calc.estimateSlow(estimatedDurationLabel)
        case .veryLong: L.Resource.Calc.estimateVeryLong(estimatedDurationLabel)
        }
        let fasterChoiceHint: LocalizedStringResource? = switch durationWarning {
        case .slow, .veryLong: fasterChoice
        case .none, .brief: nil
        }

        return ViewState(
            documentName: doc.name,
            lingo: doc.field.lingo,
            units: units,
            halfLife: doc.halfLife,
            compartmentNames: compartments.map(\.name),
            variants: doc.variants.keys.sorted(),
            selectedVariant: state.selectedVariant,
            solver: state.solver,
            duration: duration,
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
            stoppedAt: stoppedAt,
            stoppedLabel: stoppedAt.map { L.Resource.Calc.stoppedAt(env.formatDouble($0, 1), unit) },
            series: series,
            reportRows: reportRows,
            isCalculating: state.isCalculating,
            error: state.solveFailure.map { message(for: $0, format: env.formatDouble, units: units) }
                ?? state.error.map { LocalizedStringResource(String.LocalizationValue($0)) },
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
            fasterChoiceHint: fasterChoiceHint,
            validationIssues: issues,
            csvExportInput: reportRows.isEmpty ? nil : CSVExportInput(
                documentName: doc.name, lingo: doc.field.lingo, units: units,
                compartmentNames: compartments.map(\.name),
                rows: reportRows.map { ($0.time, $0.values) },
                note: partialNote
            ),
            pdfExportInput: reportRows.isEmpty ? nil : PDFExportInput(
                documentName: doc.name, lingo: doc.field.lingo, units: units,
                compartmentNames: compartments.map(\.name),
                rows: reportRows.map { ($0.time, $0.values) },
                note: partialNote
            ),
            colorScheme: state.traits.isDark ? .dark : .light,
            isCompact: state.traits.isCompactWidth,
            validationIssueTexts: issues.map { $0.text(env.formatSignificant) },
            xTicks: state.logX
                ? decades(from: 0.1, to: Double(duration)).map { AxisTick(value: $0, label: env.formatInteger(Int(pow(10, $0)))) }
                : niceTicks(upTo: Double(duration)).map { AxisTick(value: $0, label: env.formatInteger(Int($0))) },
            yTicks: state.logY
                ? decades(from: 1e-6, to: 1).map { AxisTick(value: $0, label: "10^" + env.formatInteger(Int($0))) }
                : niceTicks(upTo: series.filter(\.isVisible).flatMap(\.points).map(\.value).max() ?? 1).map {
                    AxisTick(value: $0, label: env.formatDouble($0, 2))
                },
            durationText: env.formatInteger(duration),
            durationStepTexts: Dictionary(uniqueKeysWithValues: [1, 20].map { ($0, env.formatInteger($0)) })
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
        case .setDuration(let d):       .setDuration(d)
        case .setStepSize(let s):       .setStepSize(s)
        case .setStepSizeText(let t):   .setStepSizeText(t)
        case .setTolerance(let t):      .setTolerance(t)
        case .setToleranceText(let t):  .setToleranceText(t)
        case .setIntegrationStepText(let t): .setIntegrationStepText(t)
        case .setStepBudget(let b):     .setStepBudget(b)
        case .setManualStepsText(let t): .setManualStepsText(t)
        case .commitField(let f):       .commitField(f)
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
            // Typed and shown in the field's units, held in days.
            let units = (context.stateBefore ?? State()).document.field.units
            return switch action {
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
                .reduce { $0.solver = s }
                .produce { ctx in
                    // The fields' text is written where the world's formatter runs, never in a reducer.
                    switch s {
                    case let .rungeKutta4(h):
                        return .just(.integrationStepResolved(h, ctx.environment.formatDouble(units.time.iso.get(h), 4)))
                    case let .rungeKutta45(tolerance, _):
                        return .just(.toleranceResolved(tolerance, Self.scientific(tolerance, ctx.environment)))
                    default:
                        return .empty
                    }
                }
            case .setDuration(let d):
                .reduce { $0.finalDay = units.time.iso.reverseGet(Double(max(1, d))) }
            case .setStepSize(let s):
                .produce { ctx in
                    let v = max(0.001, s)
                    return .just(.stepSizeResolved(v, ctx.environment.formatDouble(v, 6)))
                }
            case .setStepSizeText(let text):
                .produce { ctx in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    // Typed text is never rewritten: on the way to a value the text passes through
                    // "", "0" and "0,", and clamping those wrote "0,001000" back under the cursor.
                    // The value follows only text that reads as one in range.
                    if let v = ctx.environment.parseDouble(t) ?? Double(t), v >= 0.001 {
                        return .just(.stepSizeResolved(units.time.iso.reverseGet(v), t))
                    }
                    return .just(.stepSizeResolved(0, t))
                }
            case .stepSizeResolved(let v, let t):
                .reduce { $0.stepSize = v > 0 ? v : $0.stepSize; $0.stepSizeText = t }

            case .setTolerance(let t):
                .produce { ctx in
                    let v = max(1e-14, min(1e-2, t))
                    return .just(.toleranceResolved(v, Self.scientific(v, ctx.environment)))
                }
            case .setToleranceText(let text):
                .produce { ctx in
                    let t = text.trimmingCharacters(in: .whitespaces)
                    // `Double(_:)` reads exponent notation ("1e-13"), which the locale formatter doesn't.
                    // Never rewritten either: "1e-1" on the way to "1e-13" is out of range for a moment.
                    if let v = ctx.environment.parseDouble(t) ?? Double(t), (1e-14 ... 1e-2).contains(v) {
                        return .just(.toleranceResolved(v, t))
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
                        return .just(.integrationStepResolved(units.time.iso.reverseGet(v), t))
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
                    if case let .manual(cap) = budget { state.manualStepsText = "\(Int(units.rate.iso.get(Double(cap)).rounded(.up)))" }
                }
            case .setManualStepsText(let text):
                .reduce { state in
                    state.manualStepsText = text
                    if let cap = Int(text.trimmingCharacters(in: .whitespaces)), cap > 0,
                       case let .rungeKutta45(tolerance, .manual) = state.solver {
                        let perDay = Int(units.rate.iso.reverseGet(Double(cap)).rounded())
                        state.solver = .rungeKutta45(tolerance: tolerance, budget: .manual(stepsPerDay: perDay))
                    }
                }
            case .commitField(let field):
                commitFieldReaction(field, context: context)
            case .fieldFormatted(let field, let text):
                .reduce { state in
                    switch field {
                    case .reportEvery: state.stepSizeText = text
                    case .integrationStep: state.integrationStepText = text
                    case .tolerance: state.toleranceText = text
                    case .manualSteps: state.manualStepsText = text
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
            final: state.finalDay,
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

    /// Editing ended: the field shows the value it stands for, formatted. Text left invalid snaps
    /// back to the last good value.
    @MainActor
    private static func commitFieldReaction(
        _ field: ParameterField,
        context: PreReducerContext<State>
    ) -> Reaction<Action, State, Environment> {
        let state = context.stateBefore ?? State()
        let units = state.document.field.units
        return .produce { ctx in
            let format = { (days: Double) in Self.trimmed(ctx.environment.formatDouble(units.time.iso.get(days), 6)) }
            let text: String? = switch field {
            case .reportEvery: format(state.stepSize)
            case .integrationStep: if case let .rungeKutta4(h) = state.solver { format(h) } else { nil }
            case .tolerance: if case let .rungeKutta45(tolerance, _) = state.solver { Self.scientific(tolerance, ctx.environment) } else { nil }
            case .manualSteps:
                if case let .rungeKutta45(_, .manual(cap)) = state.solver {
                    ctx.environment.formatInteger(Int(units.rate.iso.get(Double(cap)).rounded(.up)))
                } else { nil }
            }
            return text.map { .just(.fieldFormatted(field, $0)) } ?? .empty
        }
    }

    /// A locale-formatted number without trailing zeros: "0,500000" → "0,5", "2.000000" → "2".
    public static func trimmed(_ formatted: String) -> String {
        guard formatted.contains(where: { $0 == "." || $0 == "," }) else { return formatted }
        let withoutZeros = formatted.reversed().drop { $0 == "0" }
        return String(withoutZeros.drop { $0 == "." || $0 == "," }.reversed())
    }

    /// "1e-13": tolerances span orders of magnitude, so they're shown by exponent, written by the
    /// world's formatter (called where effects run).
    static func scientific(_ value: Double, _ environment: Environment) -> String {
        environment.formatScientific(value, 0).replacingOccurrences(of: "e-0", with: "e-")
    }

    /// What a solver that couldn't finish tells the user, with numbers in their locale and times in
    /// the field's unit (the solver reports days).
    public static func message(
        for error: SolveError,
        format: (Double, Int) -> String,
        units: WorkingUnits
    ) -> LocalizedStringResource {
        func time(_ days: Double, _ places: Int) -> String { format(units.time.iso.get(days), places) }
        let unit = units.time.symbol
        return switch error {
        case let .unstableStep(step, limit):
            L.Resource.Calc.unstableStep(time(step, 4), unit, time(limit, 3), unit)
        case let .stepBudgetExhausted(reached, final, steps, partial):
            partial.isEmpty
                ? L.Resource.Calc.budgetExhausted(time(reached, 1), time(final, 0), unit, steps)
                : L.Resource.Calc.budgetExhaustedPartial(time(reached, 1), time(final, 0), unit, steps)
        case let .stepUnderflow(day, partial):
            partial.isEmpty
                ? L.Resource.Calc.underflow(time(day, 1), unit)
                : L.Resource.Calc.underflowPartial(time(day, 1), unit)
        }
    }

    public typealias Content = CalculatorView
}

// MARK: - Axis marks

/// Each power of ten from `low` to `high`, as its exponent: the marks of a log axis.
private func decades(from low: Double, to high: Double) -> [Double] {
    (Int(floor(log10(low))) ... Int(ceil(log10(high)))).map(Double.init)
}

/// Round-numbered marks from zero to `high`, about five of them, a step of 1, 2 or 5 times a power
/// of ten.
private func niceTicks(upTo high: Double) -> [Double] {
    guard high > 0, high.isFinite else { return [0] }
    let rough = high / 5
    let magnitude = pow(10, floor(log10(rough)))
    let normalised = rough / magnitude
    let step = (normalised < 1.5 ? 1 : normalised < 3 ? 2 : normalised < 7 ? 5 : 10) * magnitude
    return (0 ... Int((high / step).rounded(.down))).map { Double($0) * step }
}
