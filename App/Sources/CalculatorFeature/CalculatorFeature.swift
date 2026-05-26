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
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        public var solve: @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]>

        public init(solve: @escaping @Sendable (BiokineticsSimulationPlan, CompartmentalModel) -> DeferredTask<[[Double]]>) {
            self.solve = solve
        }

        public static var live: Self {
            .init { plan, model in Solver.solve(plan: plan, model: model) }
        }

        public static var preview: Self {
            .init { plan, model in
                // Return plausible fake data for previews
                let n = model.compartments.count
                let steps = plan.stepCount + 1
                return DeferredTask {
                    (0..<steps).map { step in
                        let t = Double(step * plan.step)
                        return (0..<n).map { idx in
                            let k = 0.05 + Double(idx) * 0.03
                            return max(0, exp(-k * t) - Double(idx) * 0.1)
                        }
                    }
                }
            }
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
            public var halfLife: Double = 0
            public var compartmentNames: [String] = []
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
        }

        @dynamicMemberLookup
        public enum ViewAction: Sendable {
            case calculate
            case setSolver(SolverMethod)
            case setFinalDay(Int)
            case setStepSize(Double)
            case setTolerance(Double)
            case setLogX(Bool)
            case setLogY(Bool)
            case toggleSeries(String)
            case setActiveView(CalcView)
            case toggleParamPanel
        }
    }

    // MARK: - Mappings

    public static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
        let doc = state.document
        let compartments = doc.model.compartments.filter { $0.follow }

        var series: [ViewModel.Series] = []
        if let results = state.results {
            series = compartments.enumerated().compactMap { globalIdx, comp -> ViewModel.Series? in
                let compIdx = doc.model.compartments.firstIndex { $0.id == comp.id } ?? globalIdx
                let points = results.enumerated().map { stepIdx, row -> ViewModel.SeriesPoint in
                    ViewModel.SeriesPoint(day: Double(stepIdx), value: compIdx < row.count ? row[compIdx] : 0)
                }
                let tint = doc.visuals[comp.id]?.tint ?? .steel
                let visible = state.visibleSeriesIds.isEmpty || state.visibleSeriesIds.contains(comp.id)
                return ViewModel.Series(id: comp.id, name: comp.name, tint: tint,
                                        points: points, isVisible: visible)
            }
        }

        let reportRows: [ViewModel.ReportRow] = (state.results ?? []).enumerated().map { idx, row in
            ViewModel.ReportRow(id: idx, day: Double(idx), values: row)
        }

        return ViewModel.ViewState(
            documentName: doc.name,
            halfLife: doc.halfLife,
            compartmentNames: doc.model.compartments.map(\.name),
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
            isParamPanelVisible: state.isParamPanelVisible
        )
    }

    public static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
        switch va {
        case .calculate:              .calculate
        case .setSolver(let s):       .setSolver(s)
        case .setFinalDay(let d):     .setFinalDay(d)
        case .setStepSize(let s):     .setStepSize(s)
        case .setTolerance(let t):    .setTolerance(t)
        case .setLogX(let v):         .setLogX(v)
        case .setLogY(let v):         .setLogY(v)
        case .toggleSeries(let id):   .toggleSeries(id)
        case .setActiveView(let v):   .setActiveView(v)
        case .toggleParamPanel:       .toggleParamPanel
        }
    }

    // MARK: - Lifecycle

    public static func initialState() -> State { .init() }

    public static func behavior() -> Behavior<Action, State, Environment> {
        typealias C = Consequence<State, Environment, Action>
        return .handle { action, stateAccess in
            switch action.action {
            case .load(let doc):
                C.reduce { state in
                    state.document = doc
                    state.results = nil
                    state.error = nil
                    state.isCalculating = false
                    state.visibleSeriesIds = Set(doc.model.compartments.filter(\.follow).map(\.id))
                }
            case .calculate:
                // Capture pre-mutation state in phase 1 (@MainActor — stateAccess.state is safe here)
                calculateConsequence(stateAccess: stateAccess)
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
            }
        }
    }

    /// Builds the consequence for `.calculate`, extracted so the switch arms in `behavior()` are
    /// all single expressions (required for Swift's implicit-return switch expression inference).
    @MainActor
    private static func calculateConsequence(
        stateAccess: StateAccess<State>
    ) -> Consequence<State, Environment, Action> {
        typealias C = Consequence<State, Environment, Action>
        let snapshot = stateAccess.state
        let doc = snapshot?.document ?? State().document
        let plan = BiokineticsSimulationPlan(
            step: 1,
            halfLife: doc.halfLife,
            final: snapshot?.finalDay ?? 200,
            solver: snapshot?.solver ?? .rungeKutta45(tolerance: 1e-6)
        )
        return C.reduce { $0.isCalculating = true; $0.error = nil }
            .produce { env in
                .task { Action.resultsReady(await env.solve(plan, doc.model).run()) }
            }
    }

    public typealias Content = CalculatorView
}

// MARK: - Module convenience

import SwiftRexArchitecture

extension Module
where Action == CalculatorFeature.Action,
      State == CalculatorFeature.State,
      Environment == CalculatorFeature.Environment,
      Content == CalculatorFeature.Content {
    public static var calculator: Self { .init(CalculatorFeature.self) }
}
