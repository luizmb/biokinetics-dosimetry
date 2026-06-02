import AppDomain
import Charts
import Domain
import SwiftUI
import UIComponents

// MARK: - DecayChartContent (pure)

struct DecayChartContent: View {
    let series: [CalculatorFeature.ViewModel.Series]
    let isCalculating: Bool
    let error: String?
    let logX: Bool
    let logY: Bool
    let finalDay: Int
    let lingo: FieldLingo
    let validationIssues: [CompartmentalModel.ValidationIssue]
    var onToggleSeries: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var errorIssues: [CompartmentalModel.ValidationIssue] {
        validationIssues.filter { $0.severity == .error }
    }
    private var nonErrorIssues: [CompartmentalModel.ValidationIssue] {
        validationIssues.filter { $0.severity != .error }
    }

    var body: some View {
        Group {
            if !errorIssues.isEmpty {
                validationErrorState
            } else if isCalculating {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Calculating…").font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title).foregroundStyle(.orange)
                    Text(err).font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else if series.isEmpty {
                VStack(spacing: 8) {
                    if !nonErrorIssues.isEmpty {
                        validationWarningList(nonErrorIssues)
                            .padding(.horizontal).padding(.bottom, 8)
                    }
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 48)).foregroundStyle(.quaternary)
                        Text("Tap Calculate to run the solver")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    if !nonErrorIssues.isEmpty {
                        validationWarningList(nonErrorIssues)
                            .padding(.horizontal, 8).padding(.top, 6)
                    }
                    chartView
                    seriesLegend
                        .padding(.horizontal, 14).padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Blocking error state

    private var validationErrorState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Model cannot be calculated")
                    .font(.headline)
            }
            Divider()
            ForEach(errorIssues.indices, id: \.self) { i in
                issueRow(errorIssues[i])
            }
            if !nonErrorIssues.isEmpty {
                Divider()
                Text("Also:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(nonErrorIssues.indices, id: \.self) { i in
                    issueRow(nonErrorIssues[i])
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Non-blocking warning strip

    private func validationWarningList(_ issues: [CompartmentalModel.ValidationIssue]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(issues.indices, id: \.self) { i in
                issueRow(issues[i])
            }
        }
    }

    private func issueRow(_ issue: CompartmentalModel.ValidationIssue) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: issue.systemImageName)
                .font(.system(size: 13))
                .foregroundStyle(tintFor(issue.severity))
                .frame(width: 18)
            Text(issue.issueDescription)
                .font(.system(size: 12.5))
                .foregroundStyle(tintFor(issue.severity))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tintFor(_ severity: CompartmentalModel.ValidationIssue.Severity) -> Color {
        switch severity {
        case .error:   .orange
        case .warning: colorScheme == .dark ? .yellow : Color(hue: 0.12, saturation: 0.8, brightness: 0.6)
        case .info:    .secondary
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        let visible = series.filter(\.isVisible)
        Chart {
            ForEach(visible) { s in
                let pts = transformedPoints(s.points)
                ForEach(pts.indices, id: \.self) { idx in
                    LineMark(
                        x: .value(lingo.timeUnit.displayName, pts[idx].x),
                        y: .value("Activity", pts[idx].y)
                    )
                    .foregroundStyle(by: .value("Compartment", s.name))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartForegroundStyleScale(
            domain: visible.map(\.name),
            range: visible.map { s in
                Color(hue: s.tint.hue / 360, saturation: 0.65, brightness: 0.62)
            }
        )
        .chartXAxis { xAxisContent }
        .chartYAxis { yAxisContent }
        .chartLegend(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
    }

    @AxisContentBuilder
    private var xAxisContent: some AxisContent {
        if logX {
            AxisMarks(values: logTicks(min: 0.1, max: Double(finalDay))) { value in
                AxisGridLine(); AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(pow(10, v))) \(lingo.timeUnit.label)").font(.caption2)
                    }
                }
            }
        } else {
            AxisMarks { value in
                AxisGridLine(); AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v)) \(lingo.timeUnit.label)").font(.caption2)
                    }
                }
            }
        }
    }

    @AxisContentBuilder
    private var yAxisContent: some AxisContent {
        if logY {
            AxisMarks(values: logTicks(min: 1e-6, max: 1.0)) { value in
                AxisGridLine(); AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("10^\(Int(v))").font(.caption2)
                    }
                }
            }
        } else {
            AxisMarks { value in
                AxisGridLine(); AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(2)))).font(.caption2)
                    }
                }
            }
        }
    }

    private var seriesLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(series) { s in
                    GChip(
                        color: Color(hue: s.tint.hue / 360, saturation: 0.65, brightness: 0.62),
                        label: s.name,
                        isActive: s.isVisible
                    ) { onToggleSeries(s.id) }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private struct ChartPoint { let x, y: Double }

    private func transformedPoints(_ raw: [CalculatorFeature.ViewModel.SeriesPoint]) -> [ChartPoint] {
        raw.compactMap { pt in
            let x: Double = logX ? (pt.day > 0 ? log10(pt.day) : log10(0.1)) : pt.day
            let y: Double = logY ? (pt.value > 0 ? log10(pt.value) : -8) : pt.value
            guard x.isFinite && y.isFinite else { return nil }
            return ChartPoint(x: x, y: y)
        }
    }

    private func logTicks(min: Double, max: Double) -> [Double] {
        let lo = Int(floor(log10(min)))
        let hi = Int(ceil(log10(max)))
        return (lo...hi).map { Double($0) }
    }
}
