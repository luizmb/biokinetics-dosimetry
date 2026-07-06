import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI
import UIComponents

private extension Array where Element == CompartmentalModel.ValidationIssue {
    var hasErrors: Bool { contains { $0.severity == .error } }
}

// MARK: - CalculatorView (container)

@BoundTo(CalculatorFeature.self, strategy: .observationSimple)
public struct CalculatorView: View {
    public var body: some View {
        let activeViewBinding = Binding(
            get: { viewStore.state.activeView },
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
            guard case .birchall = viewStore.state.solver else { return nil }
            return Binding(
                get: {
                    if case .birchall(let c) = viewStore.state.solver { return c }
                    return .perTime
                },
                set: { viewStore.dispatch(.setSolver(.birchall(composition: $0))) }
            )
        }()

        let paramBindings = ParameterBindings(
            finalDay: Binding(
                get: { viewStore.state.finalDay },
                set: { viewStore.dispatch(.setFinalDay($0)) }
            ),
            stepSizeText: Binding(
                get: { viewStore.state.stepSizeText },
                set: { viewStore.dispatch(.setStepSizeText($0)) }
            ),
            toleranceText: Binding(
                get: { viewStore.state.toleranceText },
                set: { viewStore.dispatch(.setToleranceText($0)) }
            ),
            selectedVariant: Binding(
                get: { viewStore.state.selectedVariant },
                set: { viewStore.dispatch(.selectVariant($0)) }
            ),
            birchallComposition: birchallBinding
        )

        return CalculatorContent(
            documentName:         viewStore.state.documentName,
            lingo:                viewStore.state.lingo,
            halfLife:             viewStore.state.halfLife,
            variants:             viewStore.state.variants,
            solver:               viewStore.state.solver,
            series:               viewStore.state.series,
            reportRows:           viewStore.state.reportRows,
            compartmentNames:     viewStore.state.compartmentNames,
            isCalculating:        viewStore.state.isCalculating,
            error:                viewStore.state.error,
            isParamPanelVisible:  viewStore.state.isParamPanelVisible,
            durationWarning:      viewStore.state.durationWarning,
            estimatedDurationLabel: viewStore.state.estimatedDurationLabel,
            solverShortName:      viewStore.state.solverShortName,
            calculateButtonTitle: viewStore.state.calculateButtonTitle,
            logXLabel:            viewStore.state.logXLabel,
            logYLabel:            viewStore.state.logYLabel,
            durationWarningMessage: viewStore.state.durationWarningMessage,
            isParamSheetOpen:     viewStore.state.isParamSheetOpen,
            validationIssues:     viewStore.state.validationIssues,
            csvExportInput:       viewStore.state.csvExportInput,
            pdfExportInput:       viewStore.state.pdfExportInput,
            activeView:           activeViewBinding,
            logX:                 logXBinding,
            logY:                 logYBinding,
            paramBindings:        paramBindings,
            onCalculate:          { viewStore.dispatch(.calculate) },
            onSetSolver:          { viewStore.dispatch(.setSolver($0)) },
            onToggleSeries:       { viewStore.dispatch(.toggleSeries($0)) },
            onToggleParamPanel:   { viewStore.dispatch(.toggleParamPanel) },
            onSetParamSheet:      { viewStore.dispatch(.setParamSheet($0)) },
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
    let series: [CalculatorFeature.Series]
    let reportRows: [CalculatorFeature.ReportRow]
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

    // MARK: - Regular (iPad: left panel + TabView)

    private var regularLayout: some View {
        HStack(spacing: 0) {
            if isParamPanelVisible {
                ParameterContent(
                    paramBindings: paramBindings,
                    lingo: lingo,
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
                        lingo: lingo, validationIssues: validationIssues,
                        onToggleSeries: onToggleSeries
                    )
                }
            }
            .padding(.horizontal, 12)
            .tabItem { Label("Chart", systemImage: "waveform.path.ecg") }
            .tag(CalculatorFeature.CalcView.chart)

            // Report tab
            ReportContent(
                reportRows: reportRows, compartmentNames: compartmentNames,
                lingo: lingo, isCompact: true
            )
            .tabItem { Label("Report", systemImage: "tablecells") }
            .tag(CalculatorFeature.CalcView.report)

            // Parameters tab
            VStack(spacing: 0) {
                ParameterContent(
                    paramBindings: paramBindings,
                    lingo: lingo,
                    variants: variants, solver: solver,
                    isCalculating: isCalculating,
                    validationIssues: validationIssues,
                    calculateButtonTitle: calculateButtonTitle,
                    durationWarningMessage: durationWarningMessage,
                    durationWarningTone: bannerTone(durationWarning),
                    showCalculateButton: false,
                    onSetSolver: onSetSolver,
                    onCalculate: {}
                )
                GButton(
                    isCalculating ? "Calculating…" : "Calculate",
                    icon: isCalculating ? nil : Image(systemName: "play.fill"),
                    size: .lg, fullWidth: true,
                    disabled: isCalculating || validationIssues.hasErrors,
                    action: {
                        onCalculate()
                        activeView.wrappedValue = .chart
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
                .padding(.top, 10)
            }
            .tabItem { Label("Parameters", systemImage: "slider.horizontal.3") }
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
                        lingo: lingo,
                        validationIssues: validationIssues,
                        onToggleSeries: onToggleSeries
                    )
                }
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.bottom, isCompact ? 0 : 4)
            .tabItem { Label("Chart", systemImage: "waveform.path.ecg") }
            .tag(CalculatorFeature.CalcView.chart)

            // Report tab
            ReportContent(
                reportRows: reportRows, compartmentNames: compartmentNames,
                lingo: lingo, isCompact: isCompact
            )
            .tabItem { Label("Report", systemImage: "tablecells") }
            .tag(CalculatorFeature.CalcView.report)
        }
    }

    // MARK: - iPhone params sheet

    private var paramsSheet: some View {
        NavigationStack {
            ScrollView {
                ParameterContent(
                    paramBindings: paramBindings,
                    lingo: lingo,
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
                            Label("Export CSV", systemImage: "tablecells")
                        }
                    }
                    if let pdf = pdfExportInput {
                        ShareLink(
                            item: pdf,
                            preview: SharePreview(pdf.documentName + ".pdf",
                                                  image: Image(systemName: "doc.richtext"))
                        ) {
                            Label("Export PDF", systemImage: "doc.richtext")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
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
