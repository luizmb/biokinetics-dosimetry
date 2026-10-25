import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI
import Localization
import Vitral

private extension Array where Element == CompartmentalModel.ValidationIssue {
    var hasErrors: Bool { contains { $0.severity == .error } }
}

// MARK: - CalculatorView (container)

@BoundTo(CalculatorFeature.self)
public struct CalculatorView: View {
    public var body: some View {
        let activeViewBinding = Binding(
            get: { viewStore.state.activeView.value },
            set: { viewStore.dispatch(.setActiveView($0)) }
        )
        let logXBinding = Binding(
            get: { viewStore.state.logX },
            set: { viewStore.dispatch(.setLogX($0)) }
        )
        let logYBinding = Binding(
            get: { viewStore.state.logY },
            set: { viewStore.dispatch(.setLogY($0)) }
        )
        // Birchall composition binding — only created when Birchall is the active solver.
        let birchallBinding: Binding<BirchallComposition>? = {
            guard case .birchall = viewStore.state.solver.value else { return nil }
            return Binding(
                get: {
                    if case .birchall(let c) = viewStore.state.solver.value { return c }
                    return .perTime
                },
                set: { viewStore.dispatch(.setSolver(.birchall(composition: $0))) }
            )
        }()

        // Step-budget binding — only created when RK45 is the active solver.
        let stepBudgetBinding: Binding<StepBudget>? = {
            guard case let .rungeKutta45(_, budget) = viewStore.state.solver.value else { return nil }
            return Binding(get: { budget }, set: { viewStore.dispatch(.setStepBudget($0)) })
        }()

        let paramBindings = ParameterBindings(
            duration: Binding(
                get: { viewStore.state.duration },
                set: { viewStore.dispatch(.setDuration($0)) }
            ),
            stepSizeText: Binding(
                get: { viewStore.state.stepSizeText },
                set: { viewStore.dispatch(.setStepSizeText($0)) }
            ),
            integrationStepText: Binding(
                get: { viewStore.state.integrationStepText },
                set: { viewStore.dispatch(.setIntegrationStepText($0)) }
            ),
            toleranceText: Binding(
                get: { viewStore.state.toleranceText },
                set: { viewStore.dispatch(.setToleranceText($0)) }
            ),
            stepBudget: stepBudgetBinding,
            selectedVariant: Binding(
                get: { viewStore.state.selectedVariant },
                set: { viewStore.dispatch(.selectVariant($0)) }
            ),
            birchallComposition: birchallBinding,
            manualStepsText: Binding(
                get: { viewStore.state.manualStepsText },
                set: { viewStore.dispatch(.setManualStepsText($0)) }
            ),
            onCommitField: { viewStore.dispatch(.commitField($0)) }
        )

        return CalculatorContent(
            documentName:         viewStore.state.documentName,
            units: viewStore.state.units.value,
            halfLife:             viewStore.state.halfLife,
            variants:             viewStore.state.variants.value,
            solver:               viewStore.state.solver.value,
            series:               viewStore.state.series.value,
            reportRows:           viewStore.state.reportRows.value,
            compartmentNames:     viewStore.state.compartmentNames.value,
            isCalculating:        viewStore.state.isCalculating,
            error:                viewStore.state.error,
            isParamPanelVisible:  viewStore.state.isParamPanelVisible,
            durationWarning:      viewStore.state.durationWarning.value,
            estimatedDurationLabel: viewStore.state.estimatedDurationLabel,
            solverShortName:      viewStore.state.solverShortName,
            calculateButtonTitle: viewStore.state.calculateButtonTitle,
            logXLabel:            viewStore.state.logXLabel,
            logYLabel:            viewStore.state.logYLabel,
            durationWarningMessage: viewStore.state.durationWarningMessage,
            fasterChoiceHint: viewStore.state.fasterChoiceHint,
            validationIssues:     viewStore.state.validationIssues.value,
            hints: SolverHints(
                integrationStepHint: viewStore.state.integrationStepHint,
                integrationStepIsUnstable: viewStore.state.integrationStepIsUnstable,
                stepBudgetHint: viewStore.state.stepBudgetHint,
                stepBudgetWarning: viewStore.state.stepBudgetWarning,
                automaticStepsPerDay: viewStore.state.automaticStepsPerDay
            ),
            remedies: viewStore.state.remedies.value,
            stoppedAt: viewStore.state.stoppedAt,
            stoppedLabel: viewStore.state.stoppedLabel,
            csvExportInput:       viewStore.state.csvExportInput.value,
            pdfExportInput:       viewStore.state.pdfExportInput.value,
            activeView:           activeViewBinding,
            logX:                 logXBinding,
            logY:                 logYBinding,
            paramBindings:        paramBindings,
            onCalculate:          { viewStore.dispatch(.calculate) },
            onSetSolver:          { viewStore.dispatch(.setSolver($0)) },
            onToggleSeries:       { viewStore.dispatch(.toggleSeries($0)) },
            onToggleParamPanel:   { viewStore.dispatch(.toggleParamPanel) },
            onRemedy:             { viewStore.dispatch(.applyRemedy($0)) },
            colorScheme: viewStore.state.colorScheme.value,
            isCompact: viewStore.state.isCompact,
            validationIssueTexts: viewStore.state.validationIssueTexts.value,
            xTicks: viewStore.state.xTicks.value,
            yTicks: viewStore.state.yTicks.value,
            durationText: viewStore.state.durationText,
            durationStepTexts: viewStore.state.durationStepTexts.value
        )
        .inlineNavigationTitle()
    }
}

// MARK: - CalculatorContent (pure view)

struct CalculatorContent: View {
    // MARK: Read-only view state
    let documentName: String
    let units: WorkingUnits
    let halfLife: Double
    let variants: [String]
    let solver: SolverMethod
    let series: [CalculatorFeature.Series]
    let reportRows: [CalculatorFeature.ReportRow]
    let compartmentNames: [String]
    let isCalculating: Bool
    let error: LocalizedStringResource?
    let isParamPanelVisible: Bool
    let durationWarning: BiokineticsSimulationPlan.DurationWarning
    let estimatedDurationLabel: String
    let solverShortName: String
    let calculateButtonTitle: LocalizedStringResource
    let logXLabel: LocalizedStringResource
    let logYLabel: LocalizedStringResource
    let durationWarningMessage: LocalizedStringResource?
    let fasterChoiceHint: LocalizedStringResource?
    let validationIssues: [CompartmentalModel.ValidationIssue]
    let hints: SolverHints
    let remedies: [CalculatorFeature.Remedy]
    let stoppedAt: Double?
    let stoppedLabel: LocalizedStringResource?
    let csvExportInput: CSVExportInput?
    let pdfExportInput: PDFExportInput?

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
    var onRemedy: (CalculatorFeature.Remedy) -> Void

    /// The screen's appearance and narrowness, from the view state.
    let colorScheme: ColorScheme
    let isCompact: Bool
    /// What the screen shows, written where the view state is made.
    let validationIssueTexts: [LocalizedStringResource]
    let xTicks: [CalculatorFeature.AxisTick]
    let yTicks: [CalculatorFeature.AxisTick]
    let durationText: String
    let durationStepTexts: [Int: String]

    var body: some View {
        ZStack {
            Backdrop()
            if isCompact { compactLayout } else { regularLayout }
        }
        .navigationTitle(documentName)
        .toolbar { toolbarItems }
    }

    // MARK: - Regular (iPad: left panel + TabView)

    private var regularLayout: some View {
        HStack(spacing: 0) {
            if isParamPanelVisible {
                ParameterContent(
                    paramBindings: paramBindings,
                    units: units,
                    variants: variants, solver: solver,
                    isCalculating: isCalculating,
                    validationIssues: validationIssues,
                    calculateButtonTitle: calculateButtonTitle,
                    durationWarningMessage: durationWarningMessage,
                    fasterChoiceHint: fasterChoiceHint,
                    durationWarningTone: bannerTone(durationWarning),
                    hints: hints,
                    onSetSolver: onSetSolver,
                    onCalculate: onCalculate,
                    colorScheme: colorScheme,
                    durationText: durationText, durationStepTexts: durationStepTexts
                )
                .frame(width: 300)
                .transition(.move(edge: .leading).combined(with: .opacity))
                Hairline(.vertical)
            }
            contentTabView.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isParamPanelVisible)
    }

    // MARK: - Compact (iPhone: three-tab TabView)

    private var compactLayout: some View {
        compactTabView
    }

    // MARK: - Compact three-tab TabView (iPhone)

    private var compactTabView: some View {
        TabView(selection: activeView) {
            // Chart tab
            Panel(cornerRadius: 20, padding: 0) {
                VStack(spacing: 0) {
                    if !series.isEmpty && !isCalculating {
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
                        duration: paramBindings.duration.wrappedValue,
                        units: units, validationIssues: validationIssues,
                        remedies: remedies,
                        stoppedAt: stoppedAt,
                        stoppedLabel: stoppedLabel,
                        onToggleSeries: onToggleSeries,
                        onRemedy: onRemedy, colorScheme: colorScheme, validationIssueTexts: validationIssueTexts, xTicks: xTicks, yTicks: yTicks
                    )
                }
            }
            .padding(.horizontal, 12)
            // Clear of the floating tab bar.
            .padding(.bottom, 16)
            .tabItem { Label(L.Calc.chart, systemImage: "waveform.path.ecg") }
            .tag(CalculatorFeature.CalcView.chart)

            // Report tab
            ReportContent(
                reportRows: reportRows, compartmentNames: compartmentNames,
                units: units, isCompact: true
            )
            .tabItem { Label(L.Calc.report, systemImage: "tablecells") }
            .tag(CalculatorFeature.CalcView.report)

            // Parameters tab: the list scrolls under the Calculate button, which floats on it as
            // a registered bar, so the scroll view gives it the system's edge effect.
            ParameterContent(
                    paramBindings: paramBindings,
                    units: units,
                    variants: variants, solver: solver,
                    isCalculating: isCalculating,
                    validationIssues: validationIssues,
                    calculateButtonTitle: calculateButtonTitle,
                    durationWarningMessage: durationWarningMessage,
                    fasterChoiceHint: fasterChoiceHint,
                    durationWarningTone: bannerTone(durationWarning),
                    hints: hints,
                    showCalculateButton: false,
                    onSetSolver: onSetSolver,
                    onCalculate: {},
                    colorScheme: colorScheme,
                    durationText: durationText, durationStepTexts: durationStepTexts
                )
            // The panel's own background sits between its scroll view and the bar, so the
            // system's edge effect doesn't reach; our fade, sized from the safe area (which now
            // holds the button), does the same job.
            .overlay { EdgeFade(.bottom) }
            .safeAreaBar(edge: .bottom) {
            VStack(spacing: 0) {
                if let msg = durationWarningMessage {
                    Banner(estimateText(msg, fasterChoiceHint), style: bannerTone(durationWarning))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                ButtonPrimary(
                    Text(calculateButtonTitle),
                    icon: Image(systemName: "play.fill"),
                    size: .large,
                    fillsWidth: true,
                    isBusy: isCalculating,
                    action: {
                        onCalculate()
                        activeView.wrappedValue = .chart
                    }
                )
                .disabled(validationIssues.hasErrors || hints.integrationStepIsUnstable)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 10)
            }
            }
            .tabItem { Label(L.Calc.parameters, systemImage: "slider.horizontal.3") }
            .tag(CalculatorFeature.CalcView.parameters)
        }
    }

    // MARK: - Two-tab TabView (iPad — no parameters tab, sidebar handles params)

    private var contentTabView: some View {
        // On iPad, .parameters is not a valid tab — fall back to .chart
        let ipadBinding = Binding(
            get: { activeView.wrappedValue == .parameters ? CalculatorFeature.CalcView.chart : activeView.wrappedValue },
            set: { activeView.wrappedValue = $0 }
        )
        return TabView(selection: ipadBinding) {
            // Chart tab
            Panel(cornerRadius: 20, padding: 0) {
                VStack(spacing: 0) {
                    if !series.isEmpty && !isCalculating {
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
                        duration: paramBindings.duration.wrappedValue,
                        units: units,
                        validationIssues: validationIssues,
                        remedies: remedies,
                        stoppedAt: stoppedAt,
                        stoppedLabel: stoppedLabel,
                        onToggleSeries: onToggleSeries,
                        onRemedy: onRemedy, colorScheme: colorScheme, validationIssueTexts: validationIssueTexts, xTicks: xTicks, yTicks: yTicks
                    )
                }
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.bottom, isCompact ? 0 : 4)
            .tabItem { Label(L.Calc.chart, systemImage: "waveform.path.ecg") }
            .tag(CalculatorFeature.CalcView.chart)

            // Report tab
            ReportContent(
                reportRows: reportRows, compartmentNames: compartmentNames,
                units: units, isCompact: isCompact
            )
            .tabItem { Label(L.Calc.report, systemImage: "tablecells") }
            .tag(CalculatorFeature.CalcView.report)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // iPad: sidebar toggle
        if !isCompact {
            ToolbarItem(placement: .platformNavigationTrailing) {
                Button(action: onToggleParamPanel) {
                    Image(systemName: "sidebar.left")
                        .symbolVariant(isParamPanelVisible ? .fill : .none)
                }
                .tint(isParamPanelVisible ? .accentColor : .secondary)
            }
        }
        // Export menu — right side, both layouts, only when results are ready
        ToolbarItem(placement: .platformNavigationTrailing) {
            if csvExportInput != nil || pdfExportInput != nil {
                Menu {
                    if let csv = csvExportInput {
                        ShareLink(
                            item: csv,
                            preview: SharePreview(csv.documentName + ".csv",
                                                  image: Image(systemName: "tablecells"))
                        ) {
                            Label(L.Calc.exportCSV, systemImage: "tablecells")
                        }
                    }
                    if let pdf = pdfExportInput {
                        ShareLink(
                            item: pdf,
                            preview: SharePreview(pdf.documentName + ".pdf",
                                                  image: Image(systemName: "doc.richtext"))
                        ) {
                            Label(L.Calc.exportPDF, systemImage: "doc.richtext")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Helpers

    private func logPill(_ label: LocalizedStringResource, binding: Binding<Bool>) -> some View {
        Pill(isActive: binding.wrappedValue, action: { binding.wrappedValue.toggle() }) {
            Text(label)
                .font(TypeToken.detail.weight(.semibold))
                .foregroundStyle(binding.wrappedValue ? Color.accentColor : .secondary)
                .padding(.horizontal, 13).frame(height: 34)
        }
    }

    private func bannerTone(_ w: BiokineticsSimulationPlan.DurationWarning) -> BannerStyle {
        switch w {
        case .none, .brief: .neutral
        case .slow:         .warning
        case .veryLong:     .error
        }
    }

}

/// A slow estimate, and after it what would be quicker when something would.
func estimateText(_ estimate: LocalizedStringResource, _ hint: LocalizedStringResource?) -> Text {
    hint.map { Text(estimate) + Text(verbatim: ". ") + Text($0) } ?? Text(estimate)
}
