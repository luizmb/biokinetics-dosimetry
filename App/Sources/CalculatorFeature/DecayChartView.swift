import AppDomain
import Charts
import SwiftUI

// MARK: - DecayChartView

struct DecayChartView: View {
    let viewModel: CalculatorFeature.ViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if viewModel.isCalculating {
                ProgressView("Calculating…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = viewModel.error {
                errorView(err)
            } else if viewModel.series.isEmpty {
                emptyView
            } else {
                chartView
            }
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        let visible = viewModel.series.filter(\.isVisible)

        Chart {
            ForEach(visible) { series in
                let chartPoints = transformedPoints(series.points)
                ForEach(chartPoints.indices, id: \.self) { idx in
                    LineMark(
                        x: .value("Day",      chartPoints[idx].x),
                        y: .value("Activity", chartPoints[idx].y)
                    )
                    .foregroundStyle(by: .value("Compartment", series.name))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: visible.map(\.name),
            range: visible.map { series in
                Color(hue: series.tint.hue / 360, saturation: 0.65, brightness: 0.62)
            }
        )
        .chartXAxis { xAxisContent }
        .chartYAxis { yAxisContent }
        .chartLegend(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformSecondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 4)
    }

    // MARK: - Axis marks

    @AxisContentBuilder
    private var xAxisContent: some AxisContent {
        if viewModel.logX {
            AxisMarks(values: logTicks(min: 0.1, max: Double(viewModel.finalDay))) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(pow(10, v))) d")
                            .font(.caption2)
                    }
                }
            }
        } else {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v)) d").font(.caption2)
                    }
                }
            }
        }
    }

    @AxisContentBuilder
    private var yAxisContent: some AxisContent {
        if viewModel.logY {
            AxisMarks(values: logTicks(min: 1e-6, max: 1.0)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("10^\(Int(v))")
                            .font(.caption2)
                    }
                }
            }
        } else {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(2))))
                            .font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let x, y: Double
    }

    private func transformedPoints(
        _ raw: [CalculatorFeature.ViewModel.SeriesPoint]
    ) -> [ChartPoint] {
        raw.compactMap { pt in
            let x: Double = viewModel.logX
                ? (pt.day > 0 ? log10(pt.day) : nil) ?? log10(0.1)
                : pt.day
            let y: Double = viewModel.logY
                ? (pt.value > 0 ? log10(pt.value) : nil) ?? -8
                : pt.value
            guard x.isFinite && y.isFinite else { return nil }
            return ChartPoint(x: x, y: y)
        }
    }

    private func logTicks(min: Double, max: Double) -> [Double] {
        let lo = Int(floor(log10(min)))
        let hi = Int(ceil(log10(max)))
        return (lo...hi).map { Double($0) }
    }

    // MARK: - Empty / error views

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Tap Calculate to run the solver")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
