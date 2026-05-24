import AppDomain
import Domain
import SwiftRexArchitecture
import SwiftUI

// MARK: - CalculatorView

@BoundTo(CalculatorFeature.self)
public struct CalculatorView: View {
    @Environment(\.horizontalSizeClass) private var hSize

    public var body: some View {
        HStack(spacing: 0) {
            // Left panel — parameters
            if viewModel.isParamPanelVisible {
                ParameterPanel(viewModel: viewModel)
                    .frame(width: 240)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                reopenStrip { viewModel.dispatch(.toggleParamPanel) }
            }

            Divider()

            // Main area
            VStack(spacing: 0) {
                // Chart / Report toggle tab
                Picker("View", selection: Binding(
                    get: { viewModel.activeView },
                    set: { viewModel.dispatch(.setActiveView($0)) }
                )) {
                    Label("Chart", systemImage: "chart.xyaxis.line").tag(CalculatorFeature.CalcView.chart)
                    Label("Report", systemImage: "tablecells").tag(CalculatorFeature.CalcView.report)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                switch viewModel.activeView {
                case .chart:
                    chartArea
                case .report:
                    ReportView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .navigationTitle(viewModel.documentName)
        .inlineNavigationTitle()
        .toolbar { toolbarContent }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .platformNavigationLeading) {
            if viewModel.halfLife > 0 {
                Text("T½ \(viewModel.halfLife.formatted(.number.precision(.fractionLength(1)))) d")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
        }
        ToolbarItemGroup(placement: .platformNavigationTrailing) {
            Button {
                viewModel.dispatch(.toggleParamPanel)
            } label: {
                Image(systemName: "sidebar.left")
                    .symbolVariant(viewModel.isParamPanelVisible ? .fill : .none)
            }
            .tint(viewModel.isParamPanelVisible ? Color.accentColor : Color.secondary)
        }
    }

    // MARK: - Chart area

    @ViewBuilder
    private var chartArea: some View {
        VStack(spacing: 0) {
            // Axis controls
            HStack(spacing: 12) {
                Spacer()
                axisToggle(label: "Lin X", logLabel: "Log X",
                           isLog: viewModel.logX) { viewModel.dispatch(.setLogX(!viewModel.logX)) }
                axisToggle(label: "Lin Y", logLabel: "Log Y",
                           isLog: viewModel.logY) { viewModel.dispatch(.setLogY(!viewModel.logY)) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Chart
            DecayChartView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Series legend
            SeriesLegend(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Axis toggle helper

    private func axisToggle(
        label: String,
        logLabel: String,
        isLog: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        Button(action: toggle) {
            Text(isLog ? logLabel : label)
                .font(.system(size: 11.5, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isLog ? Color.accentColor : Color.secondary)
    }

    // MARK: - Reopen strip

    private func reopenStrip(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 18)
        .frame(maxHeight: .infinity)
        .background(.quaternary)
    }
}

// MARK: - SeriesLegend

struct SeriesLegend: View {
    let viewModel: CalculatorFeature.ViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.series) { s in
                    Button {
                        viewModel.dispatch(.toggleSeries(s.id))
                    } label: {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(s.tint.fillColor(dark: colorScheme == .dark))
                                .frame(width: 12, height: 4)
                            Text(s.name)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(s.isVisible ? .primary : .tertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            s.isVisible ? s.tint.fillColor(dark: colorScheme == .dark).opacity(0.12) : Color.clear,
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(
                            s.isVisible ? s.tint.strokeColor(dark: colorScheme == .dark).opacity(0.4) : .secondary.opacity(0.2),
                            lineWidth: 0.5
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
