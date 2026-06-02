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
    var stepSize:             Binding<Double>
    var tolerance:            Binding<Double>
    var selectedVariant:      Binding<String?>           // nil = base model
    var birchallComposition:  Binding<BirchallComposition>?  // non-nil only when Birchall is selected
}

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

    // One-way callbacks for actions that involve more than a simple value swap.
    var onSetSolver:  (SolverMethod) -> Void   // sets method + resets associated params
    var onCalculate:  () -> Void

    @Environment(\.glassTokens) private var g

    private let algorithms: [(name: String, method: SolverMethod)] = [
        ("Birchall",       .birchall(composition: .perTime)),
        ("Runge-Kutta 4",  .rungeKutta4(stepSize: 1.0)),
        ("Runge-Kutta 45", .rungeKutta45(tolerance: 1e-6)),
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
                    HStack {
                        Text(paramBindings.finalDay.wrappedValue.formatted())
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(g.ink)
                        Spacer()
                        HStack(spacing: 6) {
                            GStepper(
                                onDecrement: { paramBindings.finalDay.wrappedValue = max(1, paramBindings.finalDay.wrappedValue - 20) },
                                onIncrement: { paramBindings.finalDay.wrappedValue = paramBindings.finalDay.wrappedValue + 20 },
                                label: "20"
                            )
                            GStepper(
                                onDecrement: { paramBindings.finalDay.wrappedValue = max(1, paramBindings.finalDay.wrappedValue - 1) },
                                onIncrement: { paramBindings.finalDay.wrappedValue = paramBindings.finalDay.wrappedValue + 1 },
                                label: "1"
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                    switch solver {
                    case .rungeKutta4, .rungeKutta45:
                        GLabel("Step size (\(lingo.timeUnit.label))").padding(.horizontal, 18)
                        doubleField(binding: paramBindings.stepSize, dp: 4)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)
                    default:
                        EmptyView()
                    }

                    if case .rungeKutta45 = solver {
                        GLabel("Tolerance").padding(.horizontal, 18)
                        doubleField(binding: paramBindings.tolerance, dp: 10)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)
                    }
                }
                .padding(.bottom, 8)
            }

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
                    size: .lg, fullWidth: true, disabled: isCalculating || validationIssues.hasErrors,
                    action: onCalculate
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Helpers

    private func solverKey(for method: SolverMethod) -> String {
        switch method {
        case .birchall:    "birchall"
        case .rungeKutta4: "rk4"
        case .rungeKutta45:"rk45"
        }
    }

    private func doubleField(binding: Binding<Double>, dp: Int) -> some View {
        GField(
            Binding(
                get: { String(format: "%.\(dp)f", binding.wrappedValue) },
                set: { if let v = Double($0.replacingOccurrences(of: ",", with: ".")) { binding.wrappedValue = v } }
            )
        )
    }
}

// MARK: - ReportContent (pure — unchanged)

struct ReportContent: View {
    let reportRows: [CalculatorFeature.ViewModel.ReportRow]
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
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        headerCell("Time (\(lingo.timeUnit.label))")
                        ForEach(Array(compartmentNames.enumerated()), id: \.0) { _, name in headerCell(name) }
                    }
                    .background(Color.platformTertiaryGroupedBackground)
                    GlassDivider()
                    ForEach(reportRows) { row in
                        HStack(spacing: 0) {
                            dataCell(row.day.formatted(.number.precision(.fractionLength(0))))
                            ForEach(Array(row.values.enumerated()), id: \.0) { _, val in
                                dataCell(String(format: "%.9e", val))
                            }
                        }
                        GlassDivider()
                    }
                }
            }
            .font(.system(size: 11, design: .monospaced))
        }
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
