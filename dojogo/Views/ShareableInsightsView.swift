import SwiftUI
import Charts

struct ShareableInsightsView: View {
    let chartData: [DailyDataPoint]
    let cumulativeChartData: [DailyDataPoint]
    let selectedMetric: MetricType
    let metricSummaries: [MetricType: String]
    let summaryValue: String
    let summaryLabel: String
    let sessionCount: Int
    let rangeLabel: String
    let backgroundColor: Color

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("INSIGHTS")
                .font(.pixelify(size: 28, weight: .bold))
                .foregroundColor(textColor)

            // Date range + session count
            HStack {
                Text(rangeLabel)
                    .font(.pixelify(size: 12, weight: .regular))
                    .foregroundColor(textColor.opacity(0.6))
                Spacer()
                Text("\(sessionCount) SESSION\(sessionCount == 1 ? "" : "S")")
                    .font(.pixelify(size: 10, weight: .regular))
                    .foregroundColor(textColor.opacity(0.5))
            }

            // Active metric header
            HStack(alignment: .bottom, spacing: 8) {
                Text(selectedMetric.displayName)
                    .font(.pixelifyBodyBold)
                    .foregroundColor(metricColor(selectedMetric))

                Text(summaryValue)
                    .font(.pixelify(size: 28, weight: .bold))
                    .foregroundColor(textColor)

                if !selectedMetric.unit.isEmpty {
                    Text(selectedMetric.unit)
                        .font(.pixelify(size: 10, weight: .regular))
                        .foregroundColor(textColor.opacity(0.5))
                        .padding(.bottom, 4)
                }

                Text(summaryLabel)
                    .font(.pixelify(size: 10, weight: .regular))
                    .foregroundColor(textColor.opacity(0.5))
                    .padding(.bottom, 4)

                Spacer()
            }

            // Chart
            if !chartData.isEmpty {
                Chart {
                    ForEach(cumulativeChartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Cumulative", point.value),
                            series: .value("Series", "cumulative")
                        )
                        .foregroundStyle(Color.yellow.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.linear)
                    }

                    ForEach(chartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(metricColor(selectedMetric))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [metricColor(selectedMetric).opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(metricColor(selectedMetric))
                        .symbolSize(chartData.count == 1 ? 60 : 20)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(textColor.opacity(0.1))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.pixelify(size: 9, weight: .regular))
                            .foregroundStyle(textColor.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(textColor.opacity(0.1))
                        AxisValueLabel()
                            .font(.pixelify(size: 9, weight: .regular))
                            .foregroundStyle(textColor.opacity(0.5))
                    }
                }
                .frame(height: 180)
            }

            // 6 metric tiles (2x3 grid)
            metricTiles

            Spacer()
                .frame(height: 8)

            // Branding
            Text("DojoGo")
                .font(.pixelify(size: 14, weight: .bold))
                .foregroundColor(textColor.opacity(0.4))
        }
        .padding(24)
        .background(backgroundColor)
        .frame(width: 390)
    }

    private var textColor: Color {
        backgroundColor == .white ? .black : .white
    }

    private var metricTiles: some View {
        let metrics = MetricType.allCases
        let rows = [
            Array(metrics.prefix(3)),
            Array(metrics.suffix(3))
        ]

        return VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex]) { metric in
                        let isSelected = selectedMetric == metric
                        let value = metricSummaries[metric] ?? "—"
                        let color = metricColor(metric)

                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)
                                Text(metric.displayName)
                                    .font(.pixelify(size: 9, weight: .regular))
                                    .foregroundColor(textColor.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                            }

                            HStack {
                                Text(value)
                                    .font(.pixelify(size: 16, weight: .bold))
                                    .foregroundColor(isSelected ? color : textColor.opacity(0.7))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Spacer()
                            }

                            if !metric.unit.isEmpty {
                                HStack {
                                    Text(metric.unit)
                                        .font(.pixelify(size: 8, weight: .regular))
                                        .foregroundColor(textColor.opacity(0.4))
                                    Spacer()
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(textColor.opacity(isSelected ? 0.12 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(isSelected ? color : textColor.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                        )
                    }
                }
            }
        }
    }

    private func metricColor(_ metric: MetricType) -> Color {
        switch metric.color {
        case "yellow": return .yellow
        case "green": return .green
        case "cyan": return .cyan
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .white
        }
    }
}
