import AppDomain
import Charts
import Domain
import SwiftUI
import Localization
import Vitral

// MARK: - DecayChartContent (pure)

struct DecayChartContent: View {
    let series: [CalculatorFeature.Series]
    let isCalculating: Bool
    let error: LocalizedStringResource?
    let logX: Bool
    let logY: Bool
    let duration: Int
    let units: WorkingUnits
    let validationIssues: [CompartmentalModel.ValidationIssue]
    var remedies: [CalculatorFeature.Remedy] = []
    /// Set when `series` is a stopped run's: the chart greys out what comes after.
    var stoppedAt: Double? = nil
    var stoppedLabel: LocalizedStringResource? = nil
    var onToggleSeries: (String) -> Void
    var onRemedy: (CalculatorFeature.Remedy) -> Void = { _ in }

    /// The screen's appearance, from its parent's view state.
    let colorScheme: ColorScheme
    /// Each issue's text, in step with `validationIssues`, and the axes' marks: written where the
    /// view state is made.
    let validationIssueTexts: [LocalizedStringResource]
    let xTicks: [CalculatorFeature.AxisTick]
    let yTicks: [CalculatorFeature.AxisTick]

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
                    Text(L.Common.calculating).font(.callout).foregroundStyle(.inkMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = error, series.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title).foregroundStyle(.warning)
                    Text(err).font(.callout).foregroundStyle(.inkMuted)
                        .multilineTextAlignment(.center)
                    remedyButtons.padding(.top, 6)
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
                            .font(.system(size: 48)).foregroundStyle(.inkFaint)
                        Text(L.Calc.tapCalculate)
                            .font(.callout).foregroundStyle(.inkMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    if !nonErrorIssues.isEmpty {
                        validationWarningList(nonErrorIssues)
                            .padding(.horizontal, 8).padding(.top, 6)
                    }
                    // A stopped run: its valid part below, the reason and the fixes above it.
                    if let err = error {
                        VStack(alignment: .leading, spacing: 8) {
                            Banner(Text(err), style: .warning)
                            remedyButtons
                        }
                        .padding(.horizontal, 10).padding(.top, 8)
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
                    .foregroundStyle(.warning)
                Text(L.Calc.cannotCalculate)
                    .font(.headline)
            }
            Hairline()
            ForEach(errorIssues.indices, id: \.self) { i in
                issueRow(errorIssues[i])
            }
            if !nonErrorIssues.isEmpty {
                Hairline()
                Text(L.Calc.also)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.inkMuted)
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
                .font(TypeToken.detail)
                .foregroundStyle(tintFor(issue.severity))
                .frame(width: 18)
            Text(validationIssues.firstIndex(of: issue).map { validationIssueTexts[$0] } ?? "")
                .font(TypeToken.detail)
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

    @ViewBuilder
    private var remedyButtons: some View {
        if !remedies.isEmpty {
            // Side by side where they fit, stacked where they don't, never wrapping a title.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { remedyButtonList }
                VStack(alignment: .leading, spacing: 8) { remedyButtonList }
            }
        }
    }

    private var remedyButtonList: some View {
        ForEach(remedies, id: \.self) { remedy in
            Group {
                if remedy == remedies.first {
                    ButtonPrimary(remedy.title, size: .small) { onRemedy(remedy) }
                } else {
                    ButtonSecondary(remedy.title, size: .small) { onRemedy(remedy) }
                }
            }
            .fixedSize()
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartView: some View {
        let visible = series.filter(\.isVisible)
        Chart {
            // Past the stop nothing was computed: grey it out to the end of the horizon, so the
            // axis still spans the run that was asked for.
            if let stop = stoppedAt {
                RectangleMark(
                    xStart: .value(L.domain(units.time.displayName), xPosition(stop)),
                    xEnd: .value(L.domain(units.time.displayName), xPosition(Double(duration)))
                )
                .foregroundStyle(Color(ColorToken.ink.opacity(0.07), scheme: colorScheme))
                RuleMark(x: .value(L.domain(units.time.displayName), xPosition(stop)))
                    .foregroundStyle(Color(.warning, scheme: colorScheme))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .top, spacing: 4) {
                        if let stoppedLabel {
                            Text(stoppedLabel).font(.caption2).foregroundStyle(.warning).fixedSize()
                        }
                    }
            }
            ForEach(visible) { s in
                let pts = transformedPoints(s.points)
                ForEach(pts.indices, id: \.self) { idx in
                    LineMark(
                        x: .value(L.domain(units.time.displayName), pts[idx].x),
                        y: .value(L.Calc.activity, pts[idx].y)
                    )
                    .foregroundStyle(by: .value(L.Common.compartment, s.name))
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
        AxisMarks(values: xTicks.map(\.value)) { value in
            AxisGridLine(); AxisTick()
            AxisValueLabel {
                if let v = value.as(Double.self), let tick = xTicks.first(where: { $0.value == v }) {
                    (Text(verbatim: tick.label + " ") + Text(L.domain(units.time.symbol))).font(.caption2)
                }
            }
        }
    }

    @AxisContentBuilder
    private var yAxisContent: some AxisContent {
        AxisMarks(values: yTicks.map(\.value)) { value in
            AxisGridLine(); AxisTick()
            AxisValueLabel {
                if let v = value.as(Double.self), let tick = yTicks.first(where: { $0.value == v }) {
                    Text(verbatim: tick.label).font(.caption2)
                }
            }
        }
    }

    private var seriesLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(series) { s in
                    SeriesChip(
                        colour: Color(hue: s.tint.hue / 360, saturation: 0.65, brightness: 0.62),
                        name: s.name,
                        isShown: s.isVisible
                    ) { onToggleSeries(s.id) }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private struct ChartPoint { let x, y: Double }

    private func xPosition(_ day: Double) -> Double {
        logX ? (day > 0 ? log10(day) : log10(0.1)) : day
    }

    /// Below this a value is within the solvers' own error (Birchall ~1e-11 per entry).
    private static let logFloor = 1e-10

    /// On a log axis anything below the floor is zero, drawn as a flat line on the floor, before
    /// and after: a curve rises from it and settles back onto it. The old 1e-8 floor sat above the
    /// rounding noise around zero, so a long run's tail flickered across it.
    private func transformedPoints(_ raw: [CalculatorFeature.SeriesPoint]) -> [ChartPoint] {
        raw.compactMap { pt in
            let x: Double = logX ? (pt.time > 0 ? log10(pt.time) : log10(0.1)) : pt.time
            let y: Double = logY ? log10(max(pt.value, Self.logFloor)) : pt.value
            guard x.isFinite && y.isFinite else { return nil }
            return ChartPoint(x: x, y: y)
        }
    }

}

/// A series in the chart's legend: its line's colour, its name, faded while hidden. Tap to show or
/// hide it.
private struct SeriesChip: View {
    let colour: Color
    let name: String
    let isShown: Bool
    let onToggle: () -> Void

    var body: some View {
        Pill(isActive: false, action: onToggle) {
            HStack(spacing: Space.small) {
                Capsule().fill(colour).frame(width: 18, height: 4)
                Text(name)
                    .font(.controlSmall)
                    .foregroundStyle(isShown ? .ink : .inkFaint)
            }
            .padding(.leading, Space.small)
            .padding(.trailing, Space.medium)
            .frame(height: Size.controlSmall)
        }
        .opacity(isShown ? 1 : 0.5)
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }
}
