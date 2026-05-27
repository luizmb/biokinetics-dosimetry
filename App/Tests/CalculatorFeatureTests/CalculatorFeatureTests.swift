import AppDomain
import CalculatorFeature
import Domain
import SnapshotTesting
import SwiftRexTesting
import Testing

// MARK: - Behavior tests

/// Tests that verify the CalculatorFeature state machine in isolation (no UI),
/// using the real behavior and a mock environment that returns fixed results.
@Suite("CalculatorFeature Behavior")
@MainActor
struct CalculatorFeatureBehaviorTests {

    // MARK: - Test fixtures

    private let doc = ModelDocument.validation
    private let mockResults: [[Double]] = [
        [1.0, 0.0, 0.0],
        [0.905, 0.090, 0.005],
        [0.820, 0.162, 0.018],
    ]
    private var env: CalculatorFeature.Environment {
        .succeeds(with: mockResults)
    }
    private func store(
        initial: CalculatorFeature.State = CalculatorFeature.initialState()
    ) -> TestStore<CalculatorFeature.Action, CalculatorFeature.State, CalculatorFeature.Environment> {
        TestStore(initial: initial, behavior: CalculatorFeature.behavior(), environment: env)
    }

    // MARK: - Initial state

    @Test func initialState() {
        let s = CalculatorFeature.initialState()
        #expect(s.results == nil)
        #expect(!s.isCalculating)
        #expect(s.error == nil)
        #expect(s.logX == true)
        #expect(s.logY == true)
        #expect(s.activeView == .chart)
        #expect(s.isParamPanelVisible == true)
        #expect(s.visibleSeriesIds.isEmpty)
    }

    // MARK: - .load

    @Test func loadSetsDocumentAndClearsResultsAndError() {
        var initial = CalculatorFeature.initialState()
        initial.results = mockResults
        initial.error = "previous error"
        initial.isCalculating = true

        store(initial: initial).dispatch(.load(doc)) { state in
            state.document = doc
            state.results = nil
            state.error = nil
            state.isCalculating = false
            state.visibleSeriesIds = Set(doc.model.compartments.filter(\.follow).map(\.id))
        }
    }

    @Test func loadSetsVisibleSeriesFromFollowedCompartments() {
        store().dispatch(.load(doc)) { state in
            let followed = Set(doc.model.compartments.filter(\.follow).map(\.id))
            state.document = doc
            state.results = nil
            state.error = nil
            state.isCalculating = false
            state.visibleSeriesIds = followed
        }
    }

    // MARK: - .calculate

    @Test func calculateSetsIsCalculatingThenDeliversResultsViaEffect() async {
        var initial = CalculatorFeature.initialState()
        initial.document = doc
        let s = store(initial: initial)

        s.dispatch(.calculate) { $0.isCalculating = true; $0.error = nil }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.resultsReady) { results, state in
            state.results = results
            state.isCalculating = false
        }
    }

    @Test func calculateClearsExistingError() async {
        var initial = CalculatorFeature.initialState()
        initial.document = doc
        initial.error = "stale error"
        let s = store(initial: initial)

        s.dispatch(.calculate) { $0.isCalculating = true; $0.error = nil }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.resultsReady) { results, state in
            state.results = results
            state.isCalculating = false
        }
    }

    // MARK: - .resultsReady / .resultsFailed

    @Test func resultsReadyStoresDataAndClearsIsCalculating() {
        var initial = CalculatorFeature.initialState()
        initial.isCalculating = true
        store(initial: initial).dispatch(.resultsReady(mockResults)) { state in
            state.results = mockResults
            state.isCalculating = false
        }
    }

    @Test func resultsFailedStoresErrorAndClearsIsCalculating() {
        var initial = CalculatorFeature.initialState()
        initial.isCalculating = true
        store(initial: initial).dispatch(.resultsFailed("solver overflow")) { state in
            state.error = "solver overflow"
            state.isCalculating = false
        }
    }

    // MARK: - Parameter setters

    @Test func setSolverToBirchall() {
        store().dispatch(.setSolver(.birchall(composition: .perTime))) {
            $0.solver = .birchall(composition: .perTime)
        }
    }

    @Test func setSolverToRungeKutta4() {
        store().dispatch(.setSolver(.rungeKutta4(stepSize: 0.5))) {
            $0.solver = .rungeKutta4(stepSize: 0.5)
        }
    }

    @Test func setSolverToRungeKutta45() {
        store().dispatch(.setSolver(.rungeKutta45(tolerance: 1e-8))) {
            $0.solver = .rungeKutta45(tolerance: 1e-8)
        }
    }

    @Test func setFinalDayWithValidValueUpdatesDirectly() {
        store().dispatch(.setFinalDay(365)) { $0.finalDay = 365 }
    }

    @Test func setFinalDayWithZeroClampsToOne() {
        store().dispatch(.setFinalDay(0)) { $0.finalDay = 1 }
    }

    @Test func setFinalDayWithNegativeClampsToOne() {
        store().dispatch(.setFinalDay(-10)) { $0.finalDay = 1 }
    }

    @Test func setStepSizeWithValidValueUpdatesDirectly() {
        store().dispatch(.setStepSize(0.5)) { $0.stepSize = 0.5 }
    }

    @Test func setStepSizeBelowMinimumClampsTo0_001() {
        store().dispatch(.setStepSize(0.0)) { $0.stepSize = 0.001 }
    }

    @Test func setToleranceWithValidValue() {
        store().dispatch(.setTolerance(1e-8)) { $0.tolerance = 1e-8 }
    }

    @Test func setToleranceBelowMinimumClampsTo1e_14() {
        store().dispatch(.setTolerance(1e-20)) { $0.tolerance = 1e-14 }
    }

    @Test func setToleranceAboveMaximumClampsTo1e_2() {
        store().dispatch(.setTolerance(1.0)) { $0.tolerance = 1e-2 }
    }

    // MARK: - Log scale toggles

    @Test func setLogXFalse() {
        store().dispatch(.setLogX(false)) { $0.logX = false }
    }

    @Test func setLogXTrueNoChange() {
        store().dispatch(.setLogX(true)) { $0.logX = true }
    }

    @Test func setLogYFalse() {
        store().dispatch(.setLogY(false)) { $0.logY = false }
    }

    // MARK: - Series visibility

    @Test func toggleSeriesAddsIdWhenAbsent() {
        store().dispatch(.toggleSeries("plasma")) { $0.visibleSeriesIds.insert("plasma") }
    }

    @Test func toggleSeriesRemovesIdWhenPresent() {
        var initial = CalculatorFeature.initialState()
        initial.visibleSeriesIds = ["plasma", "thyroid"]
        store(initial: initial).dispatch(.toggleSeries("plasma")) {
            $0.visibleSeriesIds.remove("plasma")
        }
    }

    @Test func toggleSeriesRoundTrip() {
        let s = store()
        s.dispatch(.toggleSeries("A")) { $0.visibleSeriesIds = ["A"] }
        s.dispatch(.toggleSeries("A")) { $0.visibleSeriesIds = [] }
    }

    // MARK: - View / panel toggles

    @Test func setActiveViewToReport() {
        store().dispatch(.setActiveView(.report)) { $0.activeView = .report }
    }

    @Test func setActiveViewBackToChart() {
        var initial = CalculatorFeature.initialState()
        initial.activeView = .report
        store(initial: initial).dispatch(.setActiveView(.chart)) { $0.activeView = .chart }
    }

    @Test func toggleParamPanelHidesIt() {
        store().dispatch(.toggleParamPanel) { $0.isParamPanelVisible = false }
    }

    @Test func toggleParamPanelTwiceRestores() {
        let s = store()
        s.dispatch(.toggleParamPanel) { $0.isParamPanelVisible = false }
        s.dispatch(.toggleParamPanel) { $0.isParamPanelVisible = true }
    }
}

// MARK: - mapState tests

@Suite("CalculatorFeature mapState")
@MainActor
struct CalculatorFeatureMapStateTests {

    @Test func emptyResultsProducesEmptySeriesAndReportRows() {
        let state = CalculatorFeature.initialState()
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.series.isEmpty)
        #expect(vs.reportRows.isEmpty)
    }

    @Test func documentNameAndHalfLifeForwardedCorrectly() {
        var state = CalculatorFeature.initialState()
        state.document = .validation
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.documentName == ModelDocument.validation.name)
        #expect(vs.halfLife == ModelDocument.validation.halfLife)
    }

    @Test func seriesCountMatchesFollowedCompartments() {
        var state = CalculatorFeature.initialState()
        state.document = .validation
        // validation has A(follow), B(follow), C(follow) → 3 followed compartments
        state.results = Array(
            repeating: [1.0, 0.5, 0.0],
            count: 10
        )
        state.visibleSeriesIds = ["A", "B", "C"]
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.series.count == 3)
    }

    @Test func reportRowCountMatchesStepCount() {
        var state = CalculatorFeature.initialState()
        state.document = .validation
        state.results = [[1.0, 0.5, 0.0], [0.9, 0.45, 0.05], [0.8, 0.4, 0.1]]
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.reportRows.count == 3)
        #expect(vs.reportRows[0].id == 0)
        #expect(vs.reportRows[2].id == 2)
    }

    @Test func seriesVisibilityRespectsVisibleIds() {
        var state = CalculatorFeature.initialState()
        state.document = .validation
        state.results = [[1.0, 0.5, 0.0]]
        state.visibleSeriesIds = ["A"]  // Only A visible
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.series.first { $0.id == "A" }?.isVisible == true)
        #expect(vs.series.first { $0.id == "B" }?.isVisible == false)
    }

    @Test func emptyVisibleIdsShowsAllSeries() {
        var state = CalculatorFeature.initialState()
        state.document = .validation
        state.results = [[1.0, 0.5, 0.0]]
        state.visibleSeriesIds = []  // Empty → show all
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.series.allSatisfy { $0.isVisible })
    }

    @Test func parametersForwardedToViewState() {
        var state = CalculatorFeature.initialState()
        state.solver = .rungeKutta45(tolerance: 1e-8)
        state.finalDay = 365
        state.stepSize = 0.5
        state.tolerance = 1e-8
        state.logX = false
        state.logY = false
        state.activeView = .report
        state.isParamPanelVisible = false
        let vs = CalculatorFeature.mapState(state)
        #expect(vs.solver == .rungeKutta45(tolerance: 1e-8))
        #expect(vs.finalDay == 365)
        #expect(vs.stepSize == 0.5)
        #expect(vs.tolerance == 1e-8)
        #expect(vs.logX == false)
        #expect(vs.logY == false)
        #expect(vs.activeView == .report)
        #expect(vs.isParamPanelVisible == false)
    }
}

// MARK: - mapAction tests

@Suite("CalculatorFeature mapAction")
struct CalculatorFeatureMapActionTests {

    @Test func allViewActionsMapWithoutCrash() {
        let viewActions: [CalculatorFeature.ViewModel.ViewAction] = [
            .calculate,
            .selectVariant(nil),
            .selectVariant("Type F"),
            .setSolver(.birchall(composition: .perTime)),
            .setFinalDay(100),
            .setStepSize(0.5),
            .setTolerance(1e-8),
            .setLogX(false),
            .setLogY(true),
            .toggleSeries("plasma"),
            .setActiveView(.report),
            .setActiveView(.chart),
            .toggleParamPanel,
        ]
        // Mapping should compile and run cleanly — correctness covered by behavior tests.
        for va in viewActions {
            _ = CalculatorFeature.mapAction(va)
        }
    }
}

// MARK: - Snapshot tests

// SwiftUI .image(layout:) strategy is only available on iOS/tvOS simulators.
// Run snapshot tests via `xcodebuild test -destination 'platform=iOS Simulator,...'`.
#if os(iOS) || os(tvOS)
import SwiftRexArchitecture
import SwiftUI

@Suite("CalculatorFeature Snapshots")
@MainActor
struct CalculatorFeatureSnapshotTests {

    /// `solve` is never actually called since all snapshot tests
    /// pre-seed `State.results` directly.
    private let env: CalculatorFeature.Environment = .alwaysFails
    private static let snapshotLayout = SwiftUISnapshotLayout.fixed(width: 800, height: 600)

    /// Helper that wraps snapshot capture in `ignoringActions` to suppress
    /// lifecycle-triggered view actions (`.onAppear` etc.) from polluting the test queue.
    private func snap<F: Feature>(
        _ feature: TestFeature<F>,
        named name: String,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where F.Content: View {
        await feature.ignoringActions {
            assertSnapshot(
                of: feature.view,
                as: .image(layout: Self.snapshotLayout),
                named: name,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func snapshotIdleState() async {
        let feature = TestFeature<CalculatorFeature>(environment: env)
        await snap(feature, named: "idle")
    }

    @Test func snapshotWithDocument() async {
        var initial = CalculatorFeature.initialState()
        initial.document = .validation
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snap(feature, named: "loaded-validation")
    }

    @Test func snapshotAfterCalculate() async {
        var initial = CalculatorFeature.initialState()
        initial.document = .validation
        // Pre-seed plausible decay curves so the chart is populated.
        // Behavior correctness is covered by the unit tests above.
        initial.results = (0..<201).map { step -> [Double] in
            let t = Double(step)
            return [exp(-0.05 * t), max(0.0, exp(-0.08 * t) - 0.1), max(0.0, exp(-0.11 * t) - 0.2)]
        }
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snap(feature, named: "chart-results")
    }

    @Test func snapshotReportTab() async {
        var initial = CalculatorFeature.initialState()
        initial.document = .validation
        initial.activeView = .report
        // Pre-seed results so the report table is populated
        initial.results = Array(repeating: [1.0, 0.5, 0.0], count: 5)
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snap(feature, named: "report-results")
    }

    @Test func snapshotParamPanelHidden() async {
        var initial = CalculatorFeature.initialState()
        initial.isParamPanelVisible = false
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snap(feature, named: "param-panel-hidden")
    }
}
#endif
