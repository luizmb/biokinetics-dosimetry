import AppDomain
import CalculatorFeature
import Domain
import SnapshotTesting
import Solver
import SwiftRex
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
    private var rk45State: CalculatorFeature.State {
        var state = CalculatorFeature.initialState(with: ())
        state.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        return state
    }
    private func store(
        initial: CalculatorFeature.State = CalculatorFeature.initialState(with: ())
    ) -> TestStore<CalculatorFeature.Action, CalculatorFeature.State, CalculatorFeature.Environment> {
        TestStore(initial: initial, behavior: CalculatorFeature.behavior(), environment: env)
    }

    // MARK: - Initial state

    @Test func initialState() {
        let s = CalculatorFeature.initialState(with: ())
        #expect(s.results == nil)
        #expect(!s.isCalculating)
        #expect(s.error == nil)
        #expect(s.logX == true)
        #expect(s.logY == true)
        // Parameters is pre-selected on open (13dcbd7) so the calculator opens showing
        // configuration, not an empty chart — .chart here predates that decision.
        #expect(s.activeView == .parameters)
        #expect(s.isParamPanelVisible == true)
        #expect(s.visibleSeriesIds.isEmpty)
    }

    // MARK: - .load

    @Test func loadSetsDocumentAndClearsResultsAndError() {
        var initial = CalculatorFeature.initialState(with: ())
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
        var initial = CalculatorFeature.initialState(with: ())
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
        var initial = CalculatorFeature.initialState(with: ())
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
        var initial = CalculatorFeature.initialState(with: ())
        initial.isCalculating = true
        store(initial: initial).dispatch(.resultsReady(mockResults)) { state in
            state.results = mockResults
            state.isCalculating = false
        }
    }

    @Test func resultsFailedStoresErrorAndClearsIsCalculating() {
        var initial = CalculatorFeature.initialState(with: ())
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

    @Test func setSolverToRungeKutta4() async {
        let s = store()
        s.dispatch(.setSolver(.rungeKutta4(stepSize: 0.5))) { $0.solver = .rungeKutta4(stepSize: 0.5) }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.integrationStepResolved) { pair, state in
            state.integrationStepText = pair.1
        }
        #expect(s.state.integrationStepText == env.formatDouble(0.5, 4))
    }

    @Test func setSolverToRungeKutta45() {
        store().dispatch(.setSolver(.rungeKutta45(tolerance: 1e-8, budget: .automatic))) {
            $0.solver = .rungeKutta45(tolerance: 1e-8, budget: .automatic)
            $0.toleranceText = "1e-8"
        }
    }

    // The reporting interval and the solver's own step are separate settings.

    @Test func integrationStepTextSetsRK4StepNotTheReportingInterval() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.solver = .rungeKutta4(stepSize: 0.01)
        let s = store(initial: initial)
        s.dispatch(.setIntegrationStepText("0.005")) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.integrationStepResolved) { _, state in
            state.integrationStepText = "0.005"
            state.solver = .rungeKutta4(stepSize: 0.005)
        }
        #expect(s.state.stepSize == 1.0)
    }

    @Test func setStepBudgetChangesOnlyRK45() {
        var initial = CalculatorFeature.initialState(with: ())
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        store(initial: initial).dispatch(.setStepBudget(.manual(stepsPerDay: 54))) {
            $0.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 54))
            $0.manualStepsText = "54"
        }
    }

    @Test func manualStepsTextSetsTheCap() {
        var initial = CalculatorFeature.initialState(with: ())
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 54))
        store(initial: initial).dispatch(.setManualStepsText("5")) {
            $0.manualStepsText = "5"
            $0.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 5))
        }
    }

    @Test func aFailedRunOffersItsFixes() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = doc
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 5))
        let s = store(initial: initial)
        s.dispatch(.solveFailed(.stepBudgetExhausted(reachedDay: 40, finalDay: 200, steps: 3_000, partial: []))) {
            $0.solveFailure = .stepBudgetExhausted(reachedDay: 40, finalDay: 200, steps: 3_000, partial: [])
        }
        let vs = CalculatorFeature.mapState(env)(s.state)
        #expect(vs.remedies == [.useAutomaticBudget, .useBirchall])
        #expect(vs.error.map { String(localized: $0) }?.hasPrefix("RK45 stopped at day") == true)
    }

    /// What ran before the stop becomes the results, marked as partial: the chart, the report
    /// and both exports stop at the day it reached.
    @Test func aStoppedRunKeepsWhatItComputed() {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = doc
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 5))
        let partial = Array(mockResults.prefix(2))
        let failure = SolveError.stepBudgetExhausted(reachedDay: 1.5, finalDay: 200, steps: 3_000, partial: partial)
        let s = store(initial: initial)
        s.dispatch(.solveFailed(failure)) {
            $0.solveFailure = failure
            $0.results = partial
        }
        let vs = CalculatorFeature.mapState(env)(s.state)
        #expect(vs.stoppedAtDay == 1.5)
        #expect(vs.stoppedLabel != nil)
        #expect(vs.reportRows.count == 2)
        #expect(vs.csvExportInput?.note?.hasPrefix("Partial run: stopped at") == true)
        #expect(vs.pdfExportInput?.note == vs.csvExportInput?.note)
        #expect(vs.error.map { String(localized: $0) }?.contains("the results cover the days it reached") == true)
    }

    @Test func aStopWithNothingComputedHasNoResults() {
        let failure = SolveError.stepUnderflow(day: 0, partial: [])
        store().dispatch(.solveFailed(failure)) { $0.solveFailure = failure }
    }

    @Test func aRemedyChangesTheSettingsAndRunsAgain() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 5))
        initial.solveFailure = .stepBudgetExhausted(reachedDay: 40, finalDay: 200, steps: 3_000, partial: [])
        let s = store(initial: initial)
        s.dispatch(.applyRemedy(.useAutomaticBudget)) { $0.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic) }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.calculate) { _, state in
            state.isCalculating = true
            state.solveFailure = nil
        }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.resultsReady) { data, state in
            state.results = data
            state.isCalculating = false
        }
        #expect(s.state.solveFailure == nil)
        #expect(s.state.results == mockResults)
    }

    /// The model's limits reach the fields before anything runs.
    @Test func anUnstableStepIsCaughtAtTheField() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = doc
        state.solver = .rungeKutta4(stepSize: 50)
        let vs = CalculatorFeature.mapState(env)(state)
        #expect(vs.integrationStepIsUnstable)
        #expect(vs.integrationStepHint.map { String(localized: $0) }?.hasPrefix("Stable below") == true)
        state.solver = .rungeKutta4(stepSize: 0.01)
        #expect(!CalculatorFeature.mapState(env)(state).integrationStepIsUnstable)
    }

    @Test func aLowManualCapSaysWhereItWillStop() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = doc
        state.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        let automatic = CalculatorFeature.mapState(env)(state)
        #expect(automatic.stepBudgetWarning == nil)
        #expect(automatic.stepBudgetHint.map { String(localized: $0) }?.hasPrefix("This model needs about") == true)
        state.finalDay = 1_000_000
        state.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 0))
        #expect(CalculatorFeature.mapState(env)(state).stepBudgetWarning != nil)
    }

    @Test func toleranceTextReadsExponentNotation() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        let s = store(initial: initial)
        s.dispatch(.setToleranceText("1e-11")) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.toleranceResolved) { _, state in
            state.toleranceText = "1e-11"
            state.solver = .rungeKutta45(tolerance: 1e-11, budget: .automatic)
        }
    }

    // Typed text is never rewritten; leaving the field formats it.

    @Test func typingIsNeverRewrittenEvenOnTheWayThroughAnInvalidValue() async {
        let s = store()
        for typed in ["0,", "0", ""] {
            s.dispatch(.setStepSizeText(typed)) { _ in }
            await s.runEffects()
            s.receive(CalculatorFeature.Action.prism.stepSizeResolved) { _, state in state.stepSizeText = typed }
        }
        #expect(s.state.stepSize == 1.0)
    }

    @Test func leavingTheFieldFormatsTheLastGoodValue() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.stepSize = 0.5
        initial.stepSizeText = "0,"
        let s = store(initial: initial)
        s.dispatch(.commitField(.reportEvery)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.fieldFormatted) { pair, state in state.stepSizeText = pair.1 }
        #expect(s.state.stepSizeText == CalculatorFeature.trimmed(env.formatDouble(0.5, 6)))
    }

    @Test func toleranceOutOfRangeWhileTypingKeepsTheTextAndTheLastValue() async {
        let s = store(initial: rk45State)
        s.dispatch(.setToleranceText("1e-1")) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.toleranceResolved) { _, state in state.toleranceText = "1e-1" }
        #expect(s.state.solver == .rungeKutta45(tolerance: 1e-13, budget: .automatic))
        s.dispatch(.commitField(.tolerance)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.fieldFormatted) { _, state in state.toleranceText = "1e-13" }
    }

    @Test func trimmedDropsTrailingZerosInAnyLocale() {
        #expect(CalculatorFeature.trimmed("0,500000") == "0,5")
        #expect(CalculatorFeature.trimmed("2.000000") == "2")
        #expect(CalculatorFeature.trimmed("1500") == "1500")
    }

    @Test func solverFailuresReadAsAdvice() {
        let format: (Double, Int) -> String = { value, digits in String(format: "%.\(digits)f", value) }
        #expect(String(localized: CalculatorFeature.message(for: .unstableStep(step: 1, stableLimit: 0.0627), format: format))
            == "An RK4 step of 1.0000 d is unstable for this model. Use a step below 0.063 d, or Birchall.")
        #expect(String(localized: CalculatorFeature.message(for: .stepBudgetExhausted(reachedDay: 835.9, finalDay: 1001, steps: 900, partial: []), format: format))
            == "RK45 stopped at day 835.9 of 1001 after 900 steps. Raise the step budget, or use Birchall.")
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

    // .setStepSize/.setTolerance only produce an effect (clamping + formatting happen via
    // the environment) — the actual mutation lands via the .stepSizeResolved/
    // .toleranceResolved they emit, so these need runEffects()/receive(), not a bare
    // dispatch(_:source:) read immediately after (which never runs pending effects).

    @Test func setStepSizeWithValidValueUpdatesDirectly() async {
        let s = store()
        s.dispatch(.setStepSize(0.5)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.stepSizeResolved) { pair, state in
            state.stepSize = pair.0
            state.stepSizeText = pair.1
        }
        #expect(s.state.stepSize == 0.5)
    }

    @Test func setStepSizeBelowMinimumClampsTo0_001() async {
        let s = store()
        s.dispatch(.setStepSize(0.0)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.stepSizeResolved) { pair, state in
            state.stepSize = pair.0
            state.stepSizeText = pair.1
        }
        #expect(s.state.stepSize == 0.001)
    }

    @Test func setToleranceWithValidValue() async {
        let s = store(initial: rk45State)
        s.dispatch(.setTolerance(1e-8)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.toleranceResolved) { pair, state in
            state.solver = .rungeKutta45(tolerance: pair.0, budget: .automatic)
            state.toleranceText = pair.1
        }
        #expect(s.state.solver == .rungeKutta45(tolerance: 1e-8, budget: .automatic))
        #expect(s.state.toleranceText == "1e-8")
    }

    @Test func setToleranceBelowMinimumClampsTo1e_14() async {
        let s = store(initial: rk45State)
        s.dispatch(.setTolerance(1e-20)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.toleranceResolved) { pair, state in
            state.solver = .rungeKutta45(tolerance: pair.0, budget: .automatic)
            state.toleranceText = pair.1
        }
        #expect(s.state.solver == .rungeKutta45(tolerance: 1e-14, budget: .automatic))
    }

    @Test func setToleranceAboveMaximumClampsTo1e_2() async {
        let s = store(initial: rk45State)
        s.dispatch(.setTolerance(1.0)) { _ in }
        await s.runEffects()
        s.receive(CalculatorFeature.Action.prism.toleranceResolved) { pair, state in
            state.solver = .rungeKutta45(tolerance: pair.0, budget: .automatic)
            state.toleranceText = pair.1
        }
        #expect(s.state.solver == .rungeKutta45(tolerance: 1e-2, budget: .automatic))
        #expect(s.state.toleranceText == "1e-2")
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
        var initial = CalculatorFeature.initialState(with: ())
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
        var initial = CalculatorFeature.initialState(with: ())
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
        let state = CalculatorFeature.initialState(with: ())
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.series.isEmpty)
        #expect(vs.reportRows.isEmpty)
    }

    @Test func documentNameAndHalfLifeForwardedCorrectly() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = .validation
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.documentName == ModelDocument.validation.name)
        #expect(vs.halfLife == ModelDocument.validation.halfLife)
    }

    @Test func seriesCountMatchesFollowedCompartments() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = .validation
        // validation has A(follow), B(follow), C(follow) → 3 followed compartments
        state.results = Array(
            repeating: [1.0, 0.5, 0.0],
            count: 10
        )
        state.visibleSeriesIds = ["A", "B", "C"]
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.series.count == 3)
    }

    @Test func reportRowCountMatchesStepCount() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = .validation
        state.results = [[1.0, 0.5, 0.0], [0.9, 0.45, 0.05], [0.8, 0.4, 0.1]]
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.reportRows.count == 3)
        #expect(vs.reportRows[0].id == 0)
        #expect(vs.reportRows[2].id == 2)
    }

    @Test func seriesVisibilityRespectsVisibleIds() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = .validation
        state.results = [[1.0, 0.5, 0.0]]
        state.visibleSeriesIds = ["A"]  // Only A visible
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.series.first { $0.id == "A" }?.isVisible == true)
        #expect(vs.series.first { $0.id == "B" }?.isVisible == false)
    }

    @Test func emptyVisibleIdsShowsAllSeries() {
        var state = CalculatorFeature.initialState(with: ())
        state.document = .validation
        state.results = [[1.0, 0.5, 0.0]]
        state.visibleSeriesIds = []  // Empty → show all
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.series.allSatisfy { $0.isVisible })
    }

    @Test func parametersForwardedToViewState() {
        var state = CalculatorFeature.initialState(with: ())
        state.solver = .rungeKutta45(tolerance: 1e-8, budget: .automatic)
        state.finalDay = 365
        state.stepSize = 0.5;  state.stepSizeText  = "0.5"
        state.toleranceText = "1e-8"
        state.logX = false
        state.logY = false
        state.activeView = .report
        state.isParamPanelVisible = false
        let vs = CalculatorFeature.mapState(.alwaysFails)(state)
        #expect(vs.solver == .rungeKutta45(tolerance: 1e-8, budget: .automatic))
        #expect(vs.finalDay == 365)
        #expect(vs.stepSizeText  == "0.5")
        #expect(vs.toleranceText == "1e-8")
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
        let viewActions: [CalculatorFeature.ViewAction] = [
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
            _ = CalculatorFeature.mapAction(.alwaysFails)(va)
        }
    }
}

// MARK: - Snapshot tests

// SwiftUI .image(layout:) strategy is only available on iOS/tvOS simulators.
// Run snapshot tests via `xcodebuild test -destination 'platform=iOS Simulator,...'`.
#if os(iOS) || os(tvOS)
import SwiftRexArchitecture
import SwiftUI

@Suite("CalculatorFeature Snapshots", .enabled(if: snapshotsAreComparable))
@MainActor
struct CalculatorFeatureSnapshotTests {

    /// `solve` is never actually called since all snapshot tests pre-seed `State.results` directly.
    private let env: CalculatorFeature.Environment = .alwaysFails

    private static let iPhoneLayout = SwiftUISnapshotLayout.fixed(width: 390,  height: 844)
    private static let iPadLayout   = SwiftUISnapshotLayout.fixed(width: 1194, height: 834)

    /// Captures one iPhone and one iPad snapshot inside a single `ignoringActions` block.
    private func snapBoth<F: Feature>(
        _ feature: TestFeature<F>,
        named baseName: String,
        testName: String = #function,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await feature.ignoringActions {
                assertSnapshot(of: feature.view, as: .image(layout: Self.iPhoneLayout),
                               named: "\(baseName)-iphone", file: file, testName: testName, line: line)
                assertSnapshot(of: feature.view, as: .image(layout: Self.iPadLayout),
                               named: "\(baseName)-ipad",   file: file, testName: testName, line: line)
        }
    }

    // MARK: - Baseline states

    @Test func snapshotIdleState() async {
        let feature = TestFeature<CalculatorFeature>(initial: CalculatorFeature.initialState(with: ()), environment: env)
        await snapBoth(feature, named: "idle")
    }

    @Test func snapshotWithDocument() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "loaded-validation")
    }

    @Test func snapshotAfterCalculate() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.results = (0..<201).map { step -> [Double] in
            let t = Double(step)
            return [exp(-0.05 * t), max(0.0, exp(-0.08 * t) - 0.1), max(0.0, exp(-0.11 * t) - 0.2)]
        }
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "chart-results")
    }

    @Test func snapshotReportTab() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.activeView = .report
        initial.results = Array(repeating: [1.0, 0.5, 0.0], count: 5)
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "report-results")
    }

    @Test func snapshotParamPanelHidden() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.isParamPanelVisible = false
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "param-panel-hidden")
    }

    // MARK: - Calculation states

    @Test func snapshotCalculating() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.isCalculating = true
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "calculating")
    }

    @Test func snapshotError() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.error = "Solver diverged: matrix is singular"
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "error-state")
    }

    /// A run that stopped at day 41 of 200: its valid part, a marker where it stopped, the rest
    /// greyed out, and the reason and fixes above the chart.
    @Test func snapshotPartialResults() async throws {
        let rows = try await Solver.solve(
            plan: BiokineticsSimulationPlan(step: 1, final: 200, solver: .birchall(composition: .perTime)),
            model: ModelDocument.validation.model
        ).run().get()
        let partial = Array(rows.prefix(42))
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 5))
        initial.manualStepsText = "5"
        initial.activeView = .chart
        initial.results = partial
        initial.solveFailure = .stepBudgetExhausted(reachedDay: 41.3, finalDay: 200, steps: 3_000, partial: partial)
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "partial-results")
    }

    /// A run that stopped: the reason, worded as advice, and the fixes as buttons.
    @Test func snapshotSolveFailure() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .manual(stepsPerDay: 5))
        initial.manualStepsText = "5"
        initial.activeView = .chart
        initial.solveFailure = .stepBudgetExhausted(reachedDay: 41.3, finalDay: 200, steps: 3_000, partial: [])
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "solve-failure")
    }

    // MARK: - Solver variants (ParameterPanel layout changes per solver)

    @Test func snapshotSolverRK4() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.solver = .rungeKutta4(stepSize: 0.5)
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "solver-rk4")
    }

    @Test func snapshotSolverRK45() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.solver = .rungeKutta45(tolerance: 1e-8, budget: .automatic)
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "solver-rk45")
    }

    @Test func snapshotSolverBirchallSemigroup() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.solver = .birchall(composition: .semigroup)
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "solver-birchall-semigroup")
    }

    // MARK: - Chart variants

    @Test func snapshotLogLinear() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.logX = false
        initial.logY = false
        initial.results = (0..<201).map { step -> [Double] in
            let t = Double(step)
            return [exp(-0.05 * t), max(0.0, exp(-0.08 * t) - 0.1), max(0.0, exp(-0.11 * t) - 0.2)]
        }
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "log-linear")
    }

    @Test func snapshotSeriesFiltered() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.results = (0..<201).map { step -> [Double] in
            let t = Double(step)
            return [exp(-0.05 * t), max(0.0, exp(-0.08 * t) - 0.1), max(0.0, exp(-0.11 * t) - 0.2)]
        }
        initial.visibleSeriesIds = ["A"]
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "series-filtered")
    }

    @Test func snapshotReportEmpty() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = .validation
        initial.activeView = .report
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "report-empty")
    }

    // MARK: - Duration warning banners
    // Calibrated to trigger each severity level via RK4 on iodo131 (n=9 compartments):
    //   brief    → h=0.1,  final=1000 → 4.64e-6 × 81 × 10_000  ≈  3.8 s
    //   slow     → h=0.01, final=1000 → 4.64e-6 × 81 × 100_000 ≈ 37.6 s
    //   veryLong → h=0.001,final=1000 → 4.64e-6 × 81 × 1_000_000 ≈ 376 s

    /// Validation with A → B at 10⁶/day: RK45 is held near h ≈ 3.3 / 10⁶ d, so its runs get long
    /// (estimates: 300 d ≈ 7 s, 1,000 d ≈ 23 s, 5,000 d ≈ 2 min).
    private var stiffValidation: ModelDocument {
        var doc = ModelDocument.validation
        doc.model = doc.model.with(connections: [
            CompartmentConnection(from: "A", to: "B", rate: 1e6),
            CompartmentConnection(from: "B", to: "C", rate: 0.2),
            CompartmentConnection(from: "C", to: "B", rate: 1.0)
        ])
        return doc
    }

    @Test func snapshotDurationBrief() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = stiffValidation
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        initial.finalDay = 300
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "duration-brief")
    }

    @Test func snapshotDurationSlow() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = stiffValidation
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        initial.finalDay = 1_000
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "duration-slow")
    }

    @Test func snapshotDurationVeryLong() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = stiffValidation
        initial.solver = .rungeKutta45(tolerance: 1e-13, budget: .automatic)
        initial.finalDay = 5_000
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "duration-very-long")
    }

    // MARK: - Variant picker

    @Test func snapshotWithVariants() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = Self.docWithVariants
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "with-variants")
    }

    @Test func snapshotWithVariantSelected() async {
        var initial = CalculatorFeature.initialState(with: ())
        initial.document = Self.docWithVariants
        initial.selectedVariant = "Type F"
        let feature = TestFeature<CalculatorFeature>(initial: initial, environment: env)
        await snapBoth(feature, named: "variant-selected")
    }

    // MARK: - Fixtures

    private static var docWithVariants: ModelDocument {
        let base = ModelDocument.validation
        let typeF = base.model
        let typeM = CompartmentalModel(
            nuclides: base.model.nuclides,
            compartments: base.model.compartments,
            connections: base.model.connections.map { c in
                CompartmentConnection(from: c.from, to: c.to, rate: c.rate * 0.5)
            }
        )
        return ModelDocument(
            id: base.id,
            name: "Uranium (Variants)",
            model: base.model,
            variants: ["Type F": typeF, "Type M": typeM],
            visuals: base.visuals
        )
    }
}
#endif
