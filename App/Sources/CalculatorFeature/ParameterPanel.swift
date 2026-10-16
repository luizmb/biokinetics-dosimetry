import AppDomain
import Domain
import SwiftUI
import UIComponents

// MARK: - Derived helpers used internally

private extension Array where Element == CompartmentalModel.ValidationIssue {
    var hasErrors: Bool { contains { $0.severity == .error } }
}

// MARK: - Parameter field bindings
// Created in the @BoundTo container; pure views consume them directly.

struct ParameterBindings {
    var finalDay:             Binding<Int>
    var stepSizeText:         Binding<String>             // days between reported rows
    var integrationStepText:  Binding<String>             // RK4's h
    var toleranceText:        Binding<String>
    var stepBudget:           Binding<StepBudget>?        // non-nil only when RK45 is selected
    var selectedVariant:      Binding<String?>           // nil = base model
    var birchallComposition:  Binding<BirchallComposition>?  // non-nil only when Birchall is selected
    var manualStepsText:      Binding<String>
}

/// What the model allows the explicit solvers, worded for the fields they sit under.
struct SolverHints: Equatable {
    var integrationStepHint: String?
    var integrationStepIsUnstable = false
    var stepBudgetHint: String?
    var stepBudgetWarning: String?
    var automaticStepsPerDay = 0
}

private enum BudgetMode: Hashable, Sendable { case automatic, manual }

// MARK: - ParameterContent (pure)

struct ParameterContent: View {
    // Bidirectional bindings for all editable parameter fields.
    var paramBindings: ParameterBindings

    // Read-only display state.
    let lingo:        FieldLingo
    let variants:     [String]
    let solver:       SolverMethod
    let isCalculating: Bool
    let validationIssues: [CompartmentalModel.ValidationIssue]
    let calculateButtonTitle: String
    let durationWarningMessage: String?
    let durationWarningTone: GBannerTone
    var hints = SolverHints()
    var showCalculateButton: Bool = true

    // One-way callbacks for actions that involve more than a simple value swap.
    var onSetSolver:  (SolverMethod) -> Void   // sets method + resets associated params
    var onCalculate:  () -> Void

    @Environment(\.glassTokens) private var g

    private let algorithms: [(name: String, method: SolverMethod)] = [
        ("Birchall",       .birchall(composition: .perTime)),
        ("Runge-Kutta 4",  .rungeKutta4(stepSize: 0.01)),
        ("Runge-Kutta 45", .rungeKutta45(tolerance: 1e-13, budget: .automatic)),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    GLabel("Parameters")
                        .padding(.top, 18)
                        .padding(.horizontal, 18)

                    if !variants.isEmpty {
                        GLabel("Variant").padding(.horizontal, 18)
                        GRadioList(
                            selection: paramBindings.selectedVariant,
                            options: ([nil as String?] + variants.map(Optional.some)).map { key in
                                GRadioOption(value: key, label: key ?? "Base model")
                            }
                        )
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }

                    GLabel("Method").padding(.horizontal, 18)
                    GRadioList(
                        selection: Binding(
                            get: { solverKey(for: solver) },
                            set: { key in
                                if let method = algorithms.first(where: { solverKey(for: $0.method) == key })?.method {
                                    onSetSolver(method)
                                }
                            }
                        ),
                        options: algorithms.map { GRadioOption(value: solverKey(for: $0.method), label: $0.name) }
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                    if let compBinding = paramBindings.birchallComposition {
                        GLabel("Composition").padding(.horizontal, 18)
                        GRadioList(
                            selection: compBinding,
                            options: [
                                GRadioOption(value: BirchallComposition.perTime,   label: "Per-time",  detail: "exact"),
                                GRadioOption(value: BirchallComposition.semigroup, label: "Semigroup", detail: "fast"),
                            ]
                        )
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }

                    GLabel("Duration (\(lingo.timeUnit.label))").padding(.horizontal, 18)
                    GJumpStepper(value: paramBindings.finalDay, unit: lingo.timeUnit.label)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                    GLabel("Report every (\(lingo.timeUnit.label))").padding(.horizontal, 18)
                    GField(paramBindings.stepSizeText)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)

                    if case .rungeKutta4 = solver {
                        GLabel("Integration step (\(lingo.timeUnit.label))").padding(.horizontal, 18)
                        GField(paramBindings.integrationStepText)
                            .padding(.horizontal, 18)
                        fieldNote(hints.integrationStepHint, tone: hints.integrationStepIsUnstable ? .red : nil)
                    }

                    if case .rungeKutta45 = solver {
                        GLabel("Tolerance").padding(.horizontal, 18)
                        GField(paramBindings.toleranceText)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)
                    }

                    if let budget = paramBindings.stepBudget {
                        GLabel("Step budget").padding(.horizontal, 18)
                        GSegmented(
                            selection: Binding(
                                get: { if case .manual = budget.wrappedValue { BudgetMode.manual } else { .automatic } },
                                set: { mode in
                                    budget.wrappedValue = mode == .manual ? .manual(stepsPerDay: hints.automaticStepsPerDay) : .automatic
                                }
                            ),
                            options: [(label: "Automatic", value: BudgetMode.automatic), (label: "Manual", value: .manual)]
                        )
                        .padding(.horizontal, 18)
                        if case .manual = budget.wrappedValue {
                            GLabel("Max steps (per \(lingo.timeUnit.label))").padding(.horizontal, 18).padding(.top, 12)
                            GField(paramBindings.manualStepsText)
                                .padding(.horizontal, 18)
                        }
                        fieldNote(hints.stepBudgetWarning ?? hints.stepBudgetHint, tone: hints.stepBudgetWarning == nil ? nil : .orange)
                    }
                }
                .padding(.bottom, 8)
            }

            if showCalculateButton {
                VStack(spacing: 10) {
                    if let msg = durationWarningMessage {
                        GBanner(
                            tone: durationWarningTone,
                            systemImage: durationWarningTone == .neutral ? "clock" : "exclamationmark.triangle",
                            message: msg
                        )
                    }
                    GButton(
                        calculateButtonTitle,
                        icon: isCalculating ? nil : Image(systemName: "play.fill"),
                        size: .lg, fullWidth: true, disabled: isCalculating || validationIssues.hasErrors || hints.integrationStepIsUnstable,
                        action: onCalculate
                    )
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Helpers

    /// A line under a field: what the model allows, or a warning in `tone`.
    @ViewBuilder
    private func fieldNote(_ text: String?, tone: Color?) -> some View {
        if let text {
            Text(text)
                .font(.footnote)
                .foregroundStyle(tone ?? g.muted)
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 18)
        } else {
            Color.clear.frame(height: 18)
        }
    }

    private func solverKey(for method: SolverMethod) -> String {
        switch method {
        case .birchall:    "birchall"
        case .rungeKutta4: "rk4"
        case .rungeKutta45:"rk45"
        }
    }

}

// MARK: - ReportContent (pure — unchanged)

struct ReportContent: View {
    let reportRows: [CalculatorFeature.ReportRow]
    let compartmentNames: [String]
    let lingo: FieldLingo
    let isCompact: Bool

    @Environment(\.glassTokens) private var g

    var body: some View {
        if reportRows.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "tablecells")
                    .font(.system(size: 48)).foregroundStyle(.quaternary)
                Text("Run a calculation to see the tabular report")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // A table, not one block scrolled both ways: rows scroll vertically under a pinned
            // header and are built as they come into view; the columns that don't fit scroll
            // sideways, header and rows together.
            ScrollView(.horizontal) {
                // Nested rather than one two-way scroll view: each swipe moves one way. The inner
                // view's indicator would sit at the content's edge, not the screen's (it floated
                // mid-table once scrolled sideways), so it's hidden.
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(reportRows) { row in
                                HStack(spacing: 0) {
                                    timeCell(row.day.formatted(.number.precision(.fractionLength(0))))
                                    ForEach(Array(row.values.enumerated()), id: \.0) { _, val in
                                        dataCell(String(format: "%.9e", val))
                                    }
                                }
                                GlassDivider()
                            }
                        } header: {
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    timeHeaderCell("Time (\(lingo.timeUnit.label))")
                                    ForEach(Array(compartmentNames.enumerated()), id: \.0) { _, name in headerCell(name) }
                                }
                                GlassDivider()
                            }
                            .background(.bar)
                        }
                    }
                    .padding(.bottom, 90)
                }
                .scrollIndicators(.hidden)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .overlay { EdgeFade(.bottom) }
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private func timeHeaderCell(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            .frame(width: 64, alignment: .trailing)
            .padding(.horizontal, 8).padding(.vertical, 6)
    }
    private func timeCell(_ text: String) -> some View {
        Text(text)
            .frame(width: 64, alignment: .trailing)
            .padding(.horizontal, 8).padding(.vertical, 4)
    }
    private func headerCell(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            .frame(width: 120, alignment: .trailing)
            .padding(.horizontal, 8).padding(.vertical, 6)
    }
    private func dataCell(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary)
            .frame(width: 120, alignment: .trailing)
            .padding(.horizontal, 8).padding(.vertical, 4)
    }
}
