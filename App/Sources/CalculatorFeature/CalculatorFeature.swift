import AppDomain
import CoreFP
import Domain
import Foundation
import Solver
import SwiftRex
import SwiftRexArchitecture
import SwiftRexConcurrency

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
        public var stepSize: Double = 1.0
        public var tolerance: Double = 1e-6
        public var results: [[Double]]?
        public var isCalculating: Bool = false
        public var error: String?
        public var logX: Bool = true
        public var logY: Bool = true
        public var visibleSeriesIds: Set<String> = []
        public var activeView: CalcView = .chart
        public var isParamPanelVisible: Bool = true
        /// iPhone: whether the params bottom sheet is open.
        public var isParamSheetOpen: Bool = false
        public var csvData: Data? = nil
        public var pdfData: Data? = nil

        public init() {}
    }

    public enum CalcView: String, Sendable, Equatable {
        case chart, report
    }

    // MARK: - Action

    @dynamicMemberLookup
    public enum Action: Sendable {
        case load(ModelDocument)
        case calculate
        case selectVariant(String?)
        case resultsReady([[Double]])
        case resultsFailed(String)
        case setSolver(SolverMethod)
        case setFinalDay(Int)
        case setStepSize(Double)
        case setTolerance(Double)
        case setLogX(Bool)
        case setLogY(Bool)
        case toggleSeries(String)
        case setActiveView(CalcView)
        case toggleParamPanel
        case setParamSheet(Bool)
        // Export
        case exportCSV
        case exportPDF
        case csvReady(Data)
        case pdfReady(Data)
        case exportFailed(String)
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        public var solve:       @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]>
        public var generateCSV: @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>
        public var renderPDF:   @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>

        public init(
            solve:       @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]>,
            generateCSV: @escaping @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>,
            renderPDF:   @escaping @Sendable (CalculatorExportData) -> DeferredTask<Result<Data, Error>>
        ) {
            self.solve       = solve
            self.generateCSV = generateCSV
            self.renderPDF   = renderPDF
        }
    }

    // MARK: - ViewModel

    public final class ViewModel {
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
            public var stepSize: Double = 1.0
            public var tolerance: Double = 1e-6
            public var series: [Series] = []
            public var reportRows: [ReportRow] = []
            public var isCalculating: Bool = false
            public var error: String?
            public var logX: Bool = true
            public var logY: Bool = true
            public var activeView: CalcView = .chart
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
            public var isParamSheetOpen: Bool = false
            /// All structural and completeness issues detected in the current model.
            public var validationIssues: [CompartmentalModel.ValidationIssue] = []
            /// Non-nil when a CSV export is ready — binds to ShareLink.
            public var csvShareable: CSVShareable? = nil
            /// Non-nil when a PDF export is ready — binds to ShareLink.
            public var pdfShareable: PDFShareable? = nil
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case calculate
            case selectVariant(String?)
            case setSolver(SolverMethod)
            case setFinalDay(Int)
            case setStepSize(Double)
            case setTolerance(Double)
            case setLogX(Bool)
            case setLogY(Bool)
            case toggleSeries(String)
            case setActiveView(CalcView)
            case exportCSV
            case exportPDF
            case toggleParamPanel
            case setParamSheet(Bool)
        }
    }

    // MARK: - Mappings

    public static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
        let doc = state.document
        let compartments = doc.model.compartments.filter { $0.follow }

        var series: [ViewModel.Series] = []
        if let results = state.results {
            let displayTrajectory = doc.model.displayTrajectory(from: results, step: state.stepSize)
            series = compartments.enumerated().compactMap { globalIdx, comp -> ViewModel.Series? in
                let compIdx = doc.model.compartments.firstIndex { $0.id == comp.id } ?? globalIdx
                let points = displayTrajectory.enumerated().map { stepIdx, row -> ViewModel.SeriesPoint in
                    ViewModel.SeriesPoint(day: Double(stepIdx) * state.stepSize, value: compIdx < row.count ? row[compIdx] : 0)
                }
                let tint = doc.visuals[comp.id]?.tint ?? .steel
                let visible = state.visibleSeriesIds.isEmpty || state.visibleSeriesIds.contains(comp.id)
                return ViewModel.Series(id: comp.id, name: comp.name, tint: tint,
                                        points: points, isVisible: visible)
            }
        }

        let reportRows: [ViewModel.ReportRow] = (state.results ?? []).enumerated().map { idx, row in
            ViewModel.ReportRow(id: idx, day: Double(idx) * state.stepSize, values: row)
        }

        let plan = BiokineticsSimulationPlan(
            step: state.stepSize,
            final: Double(state.finalDay),
            solver: state.solver
        )
        let n = doc.model.compartments.count
        let estimatedSeconds = plan.estimatedDuration(compartmentCount: n)
        let durationWarning = plan.durationWarning(compartmentCount: n)
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
        let durationWarningMessage: String? = {
            switch durationWarning {
            case .none:    nil
            case .brief:   "Est. \(estimatedDurationLabel)"
            case .slow:    "Est. \(estimatedDurationLabel) — may be slow"
            case .veryLong:"Est. \(estimatedDurationLabel) — this will take a long time"
            }
        }()

        return ViewModel.ViewState(
            documentName: doc.name,
            lingo: doc.field.lingo,
            halfLife: doc.halfLife,
            compartmentNames: doc.model.compartments.map(\.name),
            variants: doc.variants.keys.sorted(),
            selectedVariant: state.selectedVariant,
            solver: state.solver,
            finalDay: state.finalDay,
            stepSize: state.stepSize,
            tolerance: state.tolerance,
            series: series,
            reportRows: reportRows,
            isCalculating: state.isCalculating,
            error: state.error,
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
            isParamSheetOpen: state.isParamSheetOpen,
            validationIssues: doc.model.validationIssues.filter { issue in
                if case .missingHalfLife = issue { return doc.field == .nuclear }
                return true
            },
            csvShareable: state.csvData.map { CSVShareable(data: $0, filename: "\(doc.name).csv") },
            pdfShareable: state.pdfData.map { PDFShareable(data: $0, filename: "\(doc.name).pdf") }
        )
    }

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

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .calculate:                .calculate
        case .selectVariant(let k):     .selectVariant(k)
        case .setSolver(let s):         .setSolver(s)
        case .setFinalDay(let d):       .setFinalDay(d)
        case .setStepSize(let s):       .setStepSize(s)
        case .setTolerance(let t):      .setTolerance(t)
        case .setLogX(let v):           .setLogX(v)
        case .setLogY(let v):           .setLogY(v)
        case .toggleSeries(let id):     .toggleSeries(id)
        case .setActiveView(let v):     .setActiveView(v)
        case .toggleParamPanel:         .toggleParamPanel
        case .setParamSheet(let v):     .setParamSheet(v)
        case .exportCSV:                .exportCSV
        case .exportPDF:                .exportPDF
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        typealias C = Consequence<State, Environment, Action>
        return .handle { action, context in
            switch action {
            case .load(let doc):
                C.reduce { state in
                    state.document = doc
                    state.results = nil
                    state.error = nil
                    state.isCalculating = false
                    state.visibleSeriesIds = Set(doc.model.compartments.filter(\.follow).map(\.id))
                }
            case .selectVariant(let key):
                C.reduce { $0.selectedVariant = key }
            case .calculate:
                // Capture pre-mutation state in phase 1 (@MainActor — context.stateBefore is safe here)
                calculateConsequence(context: context)
            case .resultsReady(let data):
                C.reduce { $0.results = data; $0.isCalculating = false }
            case .resultsFailed(let msg):
                C.reduce { $0.error = msg; $0.isCalculating = false }
            case .setSolver(let s):
                C.reduce { $0.solver = s }
            case .setFinalDay(let d):
                C.reduce { $0.finalDay = max(1, d) }
            case .setStepSize(let s):
                C.reduce { $0.stepSize = max(0.001, s) }
            case .setTolerance(let t):
                C.reduce { $0.tolerance = max(1e-14, min(1e-2, t)) }
            case .setLogX(let v):
                C.reduce { $0.logX = v }
            case .setLogY(let v):
                C.reduce { $0.logY = v }
            case .toggleSeries(let id):
                C.reduce { state in
                    if state.visibleSeriesIds.contains(id) {
                        state.visibleSeriesIds.remove(id)
                    } else {
                        state.visibleSeriesIds.insert(id)
                    }
                }
            case .setActiveView(let v):
                C.reduce { $0.activeView = v }
            case .toggleParamPanel:
                C.reduce { $0.isParamPanelVisible.toggle() }

            case .setParamSheet(let v):
                C.reduce { $0.isParamSheetOpen = v }

            case .exportCSV:
                exportConsequence(kind: .csv, context: context)

            case .exportPDF:
                exportConsequence(kind: .pdf, context: context)

            case .csvReady(let data):
                C.reduce { $0.csvData = data }

            case .pdfReady(let data):
                C.reduce { $0.pdfData = data }

            case .exportFailed:
                C.reduce { _ in }
            }
        }
    }

    private enum ExportKind { case csv, pdf }

    @MainActor
    private static func exportConsequence(
        kind: ExportKind,
        context: PreReducerContext<State>
    ) -> Consequence<State, Environment, Action> {
        typealias C = Consequence<State, Environment, Action>
        let snapshot = context.stateBefore ?? State()
        let doc      = snapshot.document
        let results  = snapshot.results ?? []
        let step     = snapshot.stepSize
        let lingo    = doc.field.lingo

        let trackedCompartments = doc.model.compartments.filter { $0.follow }
        let trackedIndices = trackedCompartments.compactMap { comp in
            doc.model.compartments.firstIndex { $0.id == comp.id }
        }
        let names = trackedCompartments.map(\.name)
        let rows: [(day: Double, values: [Double])] = results.enumerated().map { idx, row in
            (day: Double(idx) * step,
             values: trackedIndices.map { $0 < row.count ? row[$0] : 0 })
        }
        let input = CalculatorExportData(
            documentName: doc.name, lingo: lingo, compartmentNames: names, rows: rows
        )

        return C.produce { ctx in
            switch kind {
            case .csv:
                return Effect.deferredTask(ctx.environment.generateCSV(input)) { result in
                    switch result {
                    case .success(let data): return .csvReady(data)
                    case .failure(let e):    return .exportFailed(e.localizedDescription)
                    }
                }
            case .pdf:
                return Effect.deferredTask(ctx.environment.renderPDF(input)) { result in
                    switch result {
                    case .success(let data): return .pdfReady(data)
                    case .failure(let e):    return .exportFailed(e.localizedDescription)
                    }
                }
            }
        }
    }

    /// Builds the consequence for `.calculate`, extracted so the switch arms in `behavior()` are
    /// all single expressions (required for Swift's implicit-return switch expression inference).
    @MainActor
    private static func calculateConsequence(
        context: PreReducerContext<State>
    ) -> Consequence<State, Environment, Action> {
        typealias C = Consequence<State, Environment, Action>
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
        return C.reduce { $0.isCalculating = true; $0.error = nil }
            .produce { ctx in
                .task { Action.resultsReady(await ctx.environment.solve(plan, model).run()) }
            }
    }

    public typealias Content = CalculatorView
}
