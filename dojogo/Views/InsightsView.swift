// InsightsView.swift
// DojoGo - Personal stats log with trends over time

import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = InsightsViewModel()
    @State private var showCustomRangePicker = false
    @State private var selectedDataPoint: DailyDataPoint?
    @State private var showShareOptions = false
    @State private var shareBackgroundColor: Color = .black

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("← BACK")
                                .font(.pixelifyButton)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PixelButtonStyle())

                        Spacer()

                        Text("INSIGHTS")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 2)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showShareOptions.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("SHARE")
                                    .font(.pixelify(size: 12, weight: .bold))
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.yellow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    // Share options panel
                    if showShareOptions {
                        shareOptionsPanel
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Range Selector
                            rangeSelector

                            // Session count
                            HStack {
                                Text("\(viewModel.sessionCount) SESSION\(viewModel.sessionCount == 1 ? "" : "S")")
                                    .font(.pixelify(size: 10, weight: .regular))
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding(.horizontal, 20)

                            // Chart
                            chartSection
                                .padding(.horizontal, 20)

                            // Metric Cards (2x3 grid)
                            metricGrid
                                .padding(.horizontal, 20)

                            Spacer()
                                .frame(height: max(geometry.safeAreaInsets.bottom, 20))
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSessions()
        }
        .sheet(isPresented: $showCustomRangePicker) {
            customRangeSheet
        }
    }

    // MARK: - Range Selector

    private var rangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(DateRangeType.allCases) { range in
                Button(action: {
                    if range == .custom {
                        showCustomRangePicker = true
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.rangeType = range
                    }
                }) {
                    Text(range.label)
                        .font(.pixelify(size: 12, weight: .bold))
                        .foregroundColor(viewModel.rangeType == range ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(viewModel.rangeType == range ? Color.yellow : Color.gray.opacity(0.3))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active metric header
            HStack(alignment: .bottom, spacing: 8) {
                Text(viewModel.selectedMetric.displayName)
                    .font(.pixelifyBodyBold)
                    .foregroundColor(metricColor(viewModel.selectedMetric))

                Text(viewModel.summaryValue)
                    .font(.pixelify(size: 28, weight: .bold))
                    .foregroundColor(.white)

                if !viewModel.selectedMetric.unit.isEmpty {
                    Text(viewModel.selectedMetric.unit)
                        .font(.pixelify(size: 10, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }

                Text(viewModel.summaryLabel)
                    .font(.pixelify(size: 10, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)

                Spacer()
            }

            // Chart
            if viewModel.chartData.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    // Cumulative overlay (behind daily, only for swings)
                    ForEach(viewModel.cumulativeChartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Cumulative", point.value),
                            series: .value("Series", "cumulative")
                        )
                        .foregroundStyle(Color.yellow.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .interpolationMethod(.linear)
                    }

                    // Daily data
                    ForEach(viewModel.chartData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(metricColor(viewModel.selectedMetric))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [metricColor(viewModel.selectedMetric).opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(metricColor(viewModel.selectedMetric))
                        .symbolSize(viewModel.chartData.count == 1 ? 60 : 20)
                    }
                }
                .chartXScale(domain: xAxisDomain)
                .chartXAxis {
                    AxisMarks(values: xAxisValues) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel(format: xAxisFormat)
                            .font(.pixelify(size: 9, weight: .regular))
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel()
                            .font(.pixelify(size: 9, weight: .regular))
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geo[plotFrame].origin
                                let x = location.x - origin.x
                                guard let date: Date = proxy.value(atX: x) else { return }
                                // Find nearest data point
                                let nearest = viewModel.chartData.min(by: {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                })
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedDataPoint?.id == nearest?.id {
                                        selectedDataPoint = nil
                                    } else {
                                        selectedDataPoint = nearest
                                    }
                                }
                            }
                    }
                }
                .frame(height: 200)
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedMetric)
                .onChange(of: viewModel.selectedMetric) { _ in selectedDataPoint = nil }
                .onChange(of: viewModel.rangeType) { _ in selectedDataPoint = nil }

                // Selected point detail
                if let point = selectedDataPoint {
                    HStack(spacing: 6) {
                        let formatter: DateFormatter = {
                            let f = DateFormatter()
                            f.dateFormat = "EEE, MMM d"
                            return f
                        }()
                        Text(formatter.string(from: point.date))
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.white)
                        Text("•")
                            .foregroundColor(.gray)
                        Text(formatPointValue(point.value))
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(metricColor(viewModel.selectedMetric))
                        if !viewModel.selectedMetric.unit.isEmpty {
                            Text(viewModel.selectedMetric.unit)
                                .font(.pixelify(size: 9, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            Text("NO DATA YET")
                .font(.pixelifySmall)
                .foregroundColor(.gray)
            Text("Complete sessions to see trends")
                .font(.pixelify(size: 10, weight: .regular))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }

    private var xAxisDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let range = viewModel.chartDateRange
        // Extend end by half a day so the last axis label isn't clipped
        let paddedEnd = calendar.date(byAdding: .hour, value: 12, to: range.end)!
        return range.start...paddedEnd
    }

    private var xAxisValues: [Date] {
        let calendar = Calendar.current
        let range = viewModel.chartDateRange
        let start = calendar.startOfDay(for: range.start)
        var dates: [Date] = []

        // Generate marks forward from the domain start
        switch viewModel.rangeType {
        case .sevenDays:
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: start) {
                    dates.append(date)
                }
            }
        case .twentyEightDays:
            for i in 0..<4 {
                if let date = calendar.date(byAdding: .day, value: i * 7, to: start) {
                    dates.append(date)
                }
            }
        case .year:
            for i in 0..<12 {
                if let date = calendar.date(byAdding: .month, value: i, to: start) {
                    dates.append(date)
                }
            }
        case .custom:
            let end = calendar.startOfDay(for: range.end)
            let daysBetween = calendar.dateComponents([.day], from: start, to: end).day ?? 0

            let markCount: Int
            let interval: Int
            if daysBetween <= 7 {
                markCount = min(daysBetween + 1, 7)
                interval = 1
            } else if daysBetween <= 28 {
                markCount = 4
                interval = 7
            } else if daysBetween <= 90 {
                markCount = 6
                interval = 14
            } else {
                markCount = 12
                interval = 30
            }

            for i in 0..<markCount {
                if let date = calendar.date(byAdding: .day, value: i * interval, to: start) {
                    dates.append(date)
                }
            }
        }

        return dates
    }

    private var xAxisFormat: Date.FormatStyle {
        switch viewModel.rangeType {
        case .sevenDays:
            // Compact: just day number (e.g., "27")
            return .dateTime.day()
        case .twentyEightDays:
            // Show month and day (e.g., "Jan 27")
            return .dateTime.month(.abbreviated).day()
        case .year:
            // Just month (e.g., "Jan")
            return .dateTime.month(.abbreviated)
        case .custom:
            // Use month and day for custom
            return .dateTime.month(.abbreviated).day()
        }
    }

    private func formatPointValue(_ value: Double) -> String {
        switch viewModel.selectedMetric {
        case .swingCount, .reactionTime, .strikeTime, .sessionTime:
            return "\(Int(value))"
        default:
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Metric Grid (2x3)

    private var metricGrid: some View {
        let metrics = MetricType.allCases
        let rows = [
            Array(metrics.prefix(3)),
            Array(metrics.suffix(3))
        ]

        return VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rowIndex]) { metric in
                        metricCard(metric)
                    }
                }
            }
        }
    }

    private func metricCard(_ metric: MetricType) -> some View {
        let isSelected = viewModel.selectedMetric == metric
        let value = viewModel.metricSummaries[metric] ?? "—"
        let color = metricColor(metric)

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedMetric = metric
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    Text(metric.displayName)
                        .font(.pixelify(size: 9, weight: .regular))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }

                HStack {
                    Text(value)
                        .font(.pixelify(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? color : .white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                }

                if !metric.unit.isEmpty {
                    HStack {
                        Text(metric.unit)
                            .font(.pixelify(size: 8, weight: .regular))
                            .foregroundColor(.gray.opacity(0.6))
                        Spacer()
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(Color.gray.opacity(isSelected ? 0.3 : 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Range Sheet

    private var customRangeSheet: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("CUSTOM RANGE")
                        .font(.pixelifyHeadline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { showCustomRangePicker = false }) {
                        Text("DONE")
                            .font(.pixelifyButton)
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.yellow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("FROM")
                        .font(.pixelify(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    DatePicker("", selection: $viewModel.customStart, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("TO")
                        .font(.pixelify(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    DatePicker("", selection: $viewModel.customEnd, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Share

    private var shareOptionsPanel: some View {
        VStack(spacing: 12) {
            Text("BACKGROUND")
                .font(.pixelify(size: 10, weight: .bold))
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                shareColorButton(.black, label: "Dark")
                shareColorButton(.white, label: "Light")
                shareColorButton(.clear, label: "Clear")
            }

            Button(action: {
                shareInsights()
            }) {
                Text("EXPORT")
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.black)
                    .frame(width: 120, height: 40)
                    .background(Color.green)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func shareColorButton(_ color: Color, label: String) -> some View {
        Button(action: {
            shareBackgroundColor = color
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if color == .clear {
                        Canvas { context, size in
                            let tileSize: CGFloat = 6
                            for row in 0..<Int(size.height / tileSize) + 1 {
                                for col in 0..<Int(size.width / tileSize) + 1 {
                                    let isLight = (row + col) % 2 == 0
                                    context.fill(
                                        Path(CGRect(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize, width: tileSize, height: tileSize)),
                                        with: .color(isLight ? .gray.opacity(0.3) : .gray.opacity(0.15))
                                    )
                                }
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(color)
                            .frame(width: 36, height: 36)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(shareBackgroundColor == color ? Color.cyan : Color.white.opacity(0.3), lineWidth: shareBackgroundColor == color ? 3 : 1)
                )
                Text(label)
                    .font(.pixelify(size: 9, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }

    private func shareInsights() {
        let view = ShareableInsightsView(
            chartData: viewModel.chartData,
            cumulativeChartData: viewModel.cumulativeChartData,
            selectedMetric: viewModel.selectedMetric,
            metricSummaries: viewModel.metricSummaries,
            summaryValue: viewModel.summaryValue,
            summaryLabel: viewModel.summaryLabel,
            sessionCount: viewModel.sessionCount,
            rangeLabel: viewModel.rangeLabel,
            backgroundColor: shareBackgroundColor
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderer.isOpaque = shareBackgroundColor != .clear

        guard let image = renderer.uiImage else { return }
        guard let pngData = image.pngData() else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("DojoGo_Insights.png")
        try? pngData.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Helpers

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
