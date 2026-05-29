import AppDomain
import Domain
import SwiftUI

// MARK: - ParameterPanel

/// Left sidebar: algorithm picker, step/tolerance params, and Calculate button.
struct ParameterPanel: View {
    let viewModel: CalculatorFeature.ViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let algorithms: [(String, String, SolverMethod)] = [
        ("Birchall",  "birchall",  .birchall(composition: .perTime)),
        ("RK4",       "rk4",       .rungeKutta4(stepSize: 1.0)),
        ("RK45",      "rk45",      .rungeKutta45(tolerance: 1e-6)),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Parameters")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Variant picker (only visible when the document has named variants)
                    if !viewModel.variants.isEmpty {
                        paramSection("Variant") {
                            VStack(spacing: 0) {
                                let allKeys = [nil as String?] + viewModel.variants.map(Optional.some)
                                ForEach(Array(allKeys.enumerated()), id: \.0) { idx, key in
                                    let label = key ?? "Base model"
                                    let isSelected = viewModel.selectedVariant == key
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                        Text(label)
                                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                    .onTapGesture { viewModel.dispatch(.selectVariant(key)) }
                                    if idx < allKeys.count - 1 { Divider() }
                                }
                            }
                            .background(Color.platformSecondaryGroupedBackground,
                                         in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.separator, lineWidth: 0.5))
                        }
                    }

                    // Algorithm picker
                    paramSection("Method") {
                        VStack(spacing: 0) {
                            ForEach(Array(algorithms.enumerated()), id: \.0) { idx, algo in
                                let (label, _, method) = algo
                                let isSelected = solverMatches(method)
                                HStack {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                    Text(label)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.dispatch(.setSolver(method)) }
                                if idx < algorithms.count - 1 { Divider() }
                            }
                        }
                        .background(Color.platformSecondaryGroupedBackground,
                                     in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.separator, lineWidth: 0.5))
                    }

                    // Duration
                    paramSection("Duration (days)") {
                        Stepper(
                            value: Binding(
                                get: { viewModel.finalDay },
                                set: { viewModel.dispatch(.setFinalDay($0)) }
                            ),
                            in: 1...10000, step: 10
                        ) {
                            Text("\(viewModel.finalDay)")
                                .font(.system(size: 13, design: .monospaced))
                        }
                    }

                    // Step size (RK only)
                    switch viewModel.solver {
                    case .rungeKutta4, .rungeKutta45:
                        paramSection("Step size (days)") {
                            TextField("Step", value: Binding(
                                get: { viewModel.stepSize },
                                set: { viewModel.dispatch(.setStepSize($0)) }
                            ), format: .number.precision(.fractionLength(4)))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .decimalKeyboard()
                        }
                    default:
                        EmptyView()
                    }

                    // Tolerance (RK45 only)
                    if case .rungeKutta45 = viewModel.solver {
                        paramSection("Tolerance") {
                            TextField("Tolerance", value: Binding(
                                get: { viewModel.tolerance },
                                set: { viewModel.dispatch(.setTolerance($0)) }
                            ), format: .number.precision(.fractionLength(10)))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .decimalKeyboard()
                        }
                    }
                }
                .padding(.bottom, 16)
            }

            Divider()

            // Duration warning
            if viewModel.durationWarning != .none {
                durationWarningBanner
            }

            // Calculate button
            Button {
                viewModel.dispatch(.calculate)
            } label: {
                Group {
                    if viewModel.isCalculating {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Calculating…")
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Calculate")
                            if viewModel.durationWarning == .none {
                                Text("· \(viewModel.estimatedDurationLabel)")
                                    .foregroundStyle(.secondary.opacity(0.8))
                            }
                        }
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(14)
            .disabled(viewModel.isCalculating)
        }
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Duration warning banner

    @ViewBuilder
    private var durationWarningBanner: some View {
        let (icon, tint, message): (String, Color, String) = {
            switch viewModel.durationWarning {
            case .brief:
                return ("clock", .secondary, "Est. \(viewModel.estimatedDurationLabel)")
            case .slow:
                return ("exclamationmark.triangle", .orange, "Est. \(viewModel.estimatedDurationLabel) — may be slow")
            case .veryLong:
                return ("exclamationmark.triangle.fill", .red, "Est. \(viewModel.estimatedDurationLabel) — this will take a long time")
            case .none:
                return ("", .clear, "")
            }
        }()

        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 11.5))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
    }

    // MARK: - Helpers

    private func solverMatches(_ method: SolverMethod) -> Bool {
        switch (method, viewModel.solver) {
        case (.birchall, .birchall):   true
        case (.rungeKutta4, .rungeKutta4): true
        case (.rungeKutta45, .rungeKutta45): true
        default: false
        }
    }

    @ViewBuilder
    private func paramSection(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - ReportView

struct ReportView: View {
    let viewModel: CalculatorFeature.ViewModel

    var body: some View {
        if viewModel.reportRows.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tablecells")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                Text("Run a calculation to see the tabular report")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        headerCell("Day (d)")
                        ForEach(Array(viewModel.compartmentNames.enumerated()), id: \.0) { _, name in
                            headerCell(name)
                        }
                    }
                    .background(Color.platformTertiaryGroupedBackground)

                    Divider()

                    // Data rows
                    ForEach(viewModel.reportRows) { row in
                        HStack(spacing: 0) {
                            dataCell(row.day.formatted(.number.precision(.fractionLength(0))))
                            ForEach(Array(row.values.enumerated()), id: \.0) { _, val in
                                dataCell(String(format: "%.9e", val))
                            }
                        }
                        Divider().opacity(0.4)
                    }
                }
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .frame(width: 120, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private func dataCell(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(width: 120, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}
