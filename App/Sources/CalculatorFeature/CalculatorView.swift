import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI
import UIComponents

private extension Array where Element == CompartmentalModel.ValidationIssue {
    var hasErrors: Bool { contains { $0.severity == .error } }
}

// MARK: - CalculatorView (container)

@BoundTo(CalculatorFeature.self)
public struct CalculatorView: View {
    public var body: some View {
        let activeViewBinding = Binding(
            get: { viewModel.activeView },
            set: { viewModel.dispatch(.setActiveView($0)) }
        )
        let logXBinding = Binding(
            get: { viewModel.logX },
            set: { viewModel.dispatch(.setLogX($0)) }
        )
        let logYBinding = Binding(
            get: { viewModel.logY },
            set: { viewModel.dispatch(.setLogY($0)) }
        )
        // Birchall composition binding — only created when Birchall is the active solver.
        let birchallBinding: Binding<BirchallComposition>? = {
            guard case .birchall = viewModel.solver else { return nil }
            return Binding(
                get: {
                    if case .birchall(let c) = viewModel.solver { return c }
                    return .perTime
                },
                set: { viewModel.dispatch(.setSolver(.birchall(composition: $0))) }
            )
        }()

        let paramBindings = ParameterBindings(
            finalDay: Binding(
                get: { viewModel.finalDay },
                set: { viewModel.dispatch(.setFinalDay($0)) }
            ),
            stepSize: Binding(
                get: { viewModel.stepSize },
                set: { viewModel.dispatch(.setStepSize($0)) }
            ),
            tolerance: Binding(
                get: { viewModel.tolerance },
                set: { viewModel.dispatch(.setTolerance($0)) }
            ),
            selectedVariant: Binding(
                get: { viewModel.selectedVariant },
                set: { viewModel.dispatch(.selectVariant($0)) }
            ),
            birchallComposition: birchallBinding
        )

        return CalculatorContent(
            documentName:         viewModel.documentName,
            lingo:                viewModel.lingo,
            halfLife:             viewModel.halfLife,
            variants:             viewModel.variants,
            solver:               viewModel.solver,
            series:               viewModel.series,
            reportRows:           viewModel.reportRows,
            compartmentNames:     viewModel.compartmentNames,
            isCalculating:        viewModel.isCalculating,
            error:                viewModel.error,
            isParamPanelVisible:  viewModel.isParamPanelVisible,
            durationWarning:      viewModel.durationWarning,
            estimatedDurationLabel: viewModel.estimatedDurationLabel,
            solverShortName:      viewModel.solverShortName,
            calculateButtonTitle: viewModel.calculateButtonTitle,
            logXLabel:            viewModel.logXLabel,
            logYLabel:            viewModel.logYLabel,
            durationWarningMessage: viewModel.durationWarningMessage,
            isParamSheetOpen:     viewModel.isParamSheetOpen,
            validationIssues:     viewModel.validationIssues,
            activeView:           activeViewBinding,
            logX:                 logXBinding,
            logY:                 logYBinding,
            paramBindings:        paramBindings,
            onCalculate:          { viewModel.dispatch(.calculate) },
            onSetSolver:          { viewModel.dispatch(.setSolver($0)) },
            onToggleSeries:       { viewModel.dispatch(.toggleSeries($0)) },
            onToggleParamPanel:   { viewModel.dispatch(.toggleParamPanel) },
            onSetParamSheet:      { viewModel.dispatch(.setParamSheet($0)) }
        )
        .inlineNavigationTitle()
    }
}

// MARK: - CalculatorContent (pure view)

struct CalculatorContent: View {
    // MARK: Read-only view state
    let documentName: String
    let lingo: FieldLingo
    let halfLife: Double
    let variants: [String]
    let solver: SolverMethod
    let series: [CalculatorFeature.ViewModel.Series]
    let reportRows: [CalculatorFeature.ViewModel.ReportRow]
    let compartmentNames: [String]
    let isCalculating: Bool
    let error: String?
    let isParamPanelVisible: Bool
    let durationWarning: BiokineticsSimulationPlan.DurationWarning
    let estimatedDurationLabel: String
    let solverShortName: String
    let calculateButtonTitle: String
    let logXLabel: String
    let logYLabel: String
    let durationWarningMessage: String?
    let isParamSheetOpen: Bool
    let validationIssues: [CompartmentalModel.ValidationIssue]

    // MARK: Bidirectional bindings
    var activeView: Binding<CalculatorFeature.CalcView>
    var logX: Binding<Bool>
    var logY: Binding<Bool>
    var paramBindings: ParameterBindings

    // MARK: One-way action callbacks
    var onCalculate: () -> Void
    var onSetSolver: (SolverMethod) -> Void
    var onToggleSeries: (String) -> Void
    var onToggleParamPanel: () -> Void
    var onSetParamSheet: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize
    private var isCompact: Bool { hSize == .compact }

    var body: some View {
        ZStack {
            GlassAppBackground()
            if isCompact { compactLayout } else { regularLayout }
        }
        .navigationTitle(documentName)
        .toolbar { toolbarItems }
    }

    // MARK: - Regular (iPad: left panel + chart/report)

    private var regularLayout: some View {
        HStack(spacing: 0) {
            if isParamPanelVisible {
                ParameterContent(
                    paramBindings: paramBindings,
                    variants: variants, solver: solver,
                    isCalculating: isCalculating,
                    validationIssues: validationIssues,
                    calculateButtonTitle: calculateButtonTitle,
                    durationWarningMessage: durationWarningMessage,
                    durationWarningTone: bannerTone(durationWarning),
                    onSetSolver: onSetSolver,
                    onCalculate: onCalculate
                )
                .frame(width: 300)
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                GlassPanelRevealStrip(edge: .leading, action: onToggleParamPanel)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            GlassVDivider()

            VStack(spacing: 0) {
                tabBar.padding(.horizontal, 16).padding(.vertical, 10)
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isParamPanelVisible)
    }

    // MARK: - Compact (iPhone: chart/report + bottom-sheet params)

    private var compactLayout: some View {
        VStack(spacing: 0) {
            tabBar.padding(.horizontal, 14).padding(.top, 4)
            contentArea
            bottomBar
        }
        .sheet(isPresented: Binding(
            get: { isParamSheetOpen },
            set: { onSetParamSheet($0) }
        )) { paramsSheet }
    }

    // MARK: - Tab bar (Chart / Report)

    private var tabBar: some View {
        GSegmented(
            selection: activeView,
            options: [
                ("Chart",  CalculatorFeature.CalcView.chart),
                ("Report", CalculatorFeature.CalcView.report),
            ]
        )
    }

    // MARK: - Main content area

    @ViewBuilder
    private var contentArea: some View {
        switch activeView.wrappedValue {
        case .chart:
            GCard(cornerRadius: 20, intensity: 0.55,
                  tint: colorScheme == .dark
                        ? Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.35)
                        : Color.white.opacity(0.40)) {
                VStack(spacing: 0) {
                    if !series.isEmpty && !isCalculating && error == nil {
                        HStack(spacing: 7) {
                            Spacer()
                            logPill(logXLabel, binding: logX)
                            logPill(logYLabel, binding: logY)
                        }
                        .padding(.horizontal, 12).padding(.top, 10)
                    }
                    DecayChartContent(
                        series: series, isCalculating: isCalculating,
                        error: error, logX: logX.wrappedValue, logY: logY.wrappedValue,
                        finalDay: paramBindings.finalDay.wrappedValue,
                        validationIssues: validationIssues,
                        onToggleSeries: onToggleSeries
                    )
                }
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.bottom, isCompact ? 0 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .report:
            ReportContent(
                reportRows: reportRows, compartmentNames: compartmentNames,
                isCompact: isCompact
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - iPhone bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            GPill(intensity: 0.85, action: { onSetParamSheet(true) }) {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .medium))
                    Text(solverShortName)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 18).frame(height: 52)
            }
            GButton(
                calculateButtonTitle,
                icon: isCalculating ? nil : Image(systemName: "play.fill"),
                size: .lg, fullWidth: true, disabled: isCalculating || validationIssues.hasErrors,
                action: onCalculate
            )
        }
        .padding(.horizontal, 14).padding(.bottom, 30).padding(.top, 12)
    }

    // MARK: - iPhone params sheet

    private var paramsSheet: some View {
        NavigationStack {
            ScrollView {
                ParameterContent(
                    paramBindings: paramBindings,
                    variants: variants, solver: solver,
                    isCalculating: isCalculating,
                    validationIssues: validationIssues,
                    calculateButtonTitle: calculateButtonTitle,
                    durationWarningMessage: durationWarningMessage,
                    durationWarningTone: bannerTone(durationWarning),
                    onSetSolver: onSetSolver,
                    onCalculate: { onSetParamSheet(false); onCalculate() }
                )
            }
            .navigationTitle("Parameters")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSetParamSheet(false) }
                }
            }
        }
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .platformNavigationLeading) {
            if halfLife > 0 {
                Text("\(lingo.halfLifeLabel) \(halfLife.formatted(.number.precision(.fractionLength(1)))) d")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
        ToolbarItemGroup(placement: .platformNavigationTrailing) {
            if !isCompact {
                Button(action: onToggleParamPanel) {
                    Image(systemName: "sidebar.left")
                        .symbolVariant(isParamPanelVisible ? .fill : .none)
                }
                .tint(isParamPanelVisible ? .accentColor : .secondary)
            }
        }
    }

    // MARK: - Helpers

    private func logPill(_ label: String, binding: Binding<Bool>) -> some View {
        GPill(intensity: binding.wrappedValue ? 1.0 : 0.5, action: { binding.wrappedValue.toggle() }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(binding.wrappedValue ? Color.accentColor : .secondary)
                .padding(.horizontal, 13).frame(height: 34)
        }
    }

    private func bannerTone(_ w: BiokineticsSimulationPlan.DurationWarning) -> GBannerTone {
        switch w {
        case .none, .brief: .neutral
        case .slow:         .warn
        case .veryLong:     .danger
        }
    }
}
