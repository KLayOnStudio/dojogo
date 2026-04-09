// InsightsViewModel.swift
// DojoGo - ViewModel for the Insights/Log page

import Foundation
import Combine

enum DateRangeType: CaseIterable, Identifiable {
    case sevenDays, twentyEightDays, year, custom

    var id: Self { self }

    var label: String {
        switch self {
        case .sevenDays: return "7D"
        case .twentyEightDays: return "28D"
        case .year: return "365D"
        case .custom: return "CUSTOM"
        }
    }

    /// Number of days back from today (nil for custom)
    var days: Int? {
        switch self {
        case .sevenDays: return 7
        case .twentyEightDays: return 28
        case .year: return 365
        case .custom: return nil
        }
    }
}

enum MetricType: String, CaseIterable, Identifiable {
    case swingCount
    case reactionTime
    case strikeTime
    case maxMotionEnergy
    case maxRotVel
    case sessionTime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .swingCount: return "SWINGS"
        case .reactionTime: return "REACTION"
        case .strikeTime: return "STRIKE"
        case .maxMotionEnergy: return "MAX POWER"
        case .maxRotVel: return "MAX SPEED"
        case .sessionTime: return "TIME"
        }
    }

    var unit: String {
        switch self {
        case .swingCount: return ""
        case .reactionTime: return "ms"
        case .strikeTime: return "ms"
        case .maxMotionEnergy: return "m/s²"
        case .maxRotVel: return "rad/s"
        case .sessionTime: return "sec"
        }
    }

    /// How to aggregate multiple sessions in a single day
    var aggregation: Aggregation {
        switch self {
        case .swingCount: return .sum
        default: return .average
        }
    }

    enum Aggregation {
        case sum, average
    }

    /// Color for this metric
    var color: String {
        switch self {
        case .swingCount: return "yellow"
        case .reactionTime: return "green"
        case .strikeTime: return "cyan"
        case .maxMotionEnergy: return "red"
        case .maxRotVel: return "orange"
        case .sessionTime: return "purple"
        }
    }

    /// Whether this metric is only meaningful for guided sessions
    var isGuidedOnly: Bool { self == .reactionTime || self == .strikeTime }
}

@MainActor
class InsightsViewModel: ObservableObject {
    @Published var rangeType: DateRangeType = .sevenDays
    @Published var selectedMetric: MetricType = .swingCount
    @Published var customStart: Date = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
    @Published var customEnd: Date = Date()

    @Published private(set) var summaries: [SessionSummary] = []
    @Published private(set) var chartData: [DailyDataPoint] = []
    @Published private(set) var cumulativeChartData: [DailyDataPoint] = []
    @Published private(set) var summaryValue: String = "—"
    @Published private(set) var summaryLabel: String = ""
    @Published private(set) var sessionCount: Int = 0

    // Metric card summaries
    @Published private(set) var metricSummaries: [MetricType: String] = [:]

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Recompute when range or metric changes
        Publishers.CombineLatest4($rangeType, $selectedMetric, $customStart, $customEnd)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.recompute()
            }
            .store(in: &cancellables)
    }

    func loadSessions() {
        let stored = LocalStorageService.shared.getSavedSessions()
        summaries = stored.map { session in
            let storedStats = LocalStorageService.shared.getSessionStats(for: session.id)
            return SessionSummary.from(session: session, storedStats: storedStats)
        }
        recompute()
    }

    /// Add a just-finished session with its computed stats
    func addSession(_ session: Session, stats: SessionStats?) {
        let summary = SessionSummary.from(session: session, stats: stats)
        if !summaries.contains(where: { $0.id == summary.id }) {
            summaries.append(summary)
        }
        recompute()
    }

    /// Human-readable label for the current date range
    var rangeLabel: String {
        switch rangeType {
        case .sevenDays: return "Last 7 Days"
        case .twentyEightDays: return "Last 28 Days"
        case .year: return "Last 365 Days"
        case .custom:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: customStart)) – \(formatter.string(from: customEnd))"
        }
    }

    // MARK: - Private

    /// Full display range for the chart x-axis (may extend past today)
    var chartDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let range = dateRange
        let start = calendar.startOfDay(for: range.start)

        switch rangeType {
        case .sevenDays, .twentyEightDays, .year:
            let N = rangeType.days!
            let displayEnd = calendar.date(byAdding: .day, value: N - 1, to: start)!
            return (start, displayEnd)
        case .custom:
            let customStartDay = calendar.startOfDay(for: customStart)
            let customEndDay = calendar.startOfDay(for: customEnd)
            let span = calendar.dateComponents([.day], from: customStartDay, to: customEndDay).day ?? 0
            let displayEnd = calendar.date(byAdding: .day, value: span, to: start)!
            return (start, displayEnd)
        }
    }

    /// Data range for filtering sessions and zero-filling (capped at today)
    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)!

        switch rangeType {
        case .sevenDays, .twentyEightDays, .year:
            let N = rangeType.days!
            let defaultStart = calendar.date(byAdding: .day, value: -(N - 1), to: today)!

            // If oldest data is more recent than the default start, anchor to it
            if let oldest = summaries.map(\.date).min() {
                let oldestDay = calendar.startOfDay(for: oldest)
                if oldestDay > defaultStart {
                    return (oldestDay, endOfToday)
                }
            }
            return (defaultStart, endOfToday)
        case .custom:
            let customStartDay = calendar.startOfDay(for: customStart)
            let customEndDay = calendar.startOfDay(for: customEnd)
            let span = calendar.dateComponents([.day], from: customStartDay, to: customEndDay).day ?? 0

            // If oldest data is more recent than custom start, anchor to it
            if let oldest = summaries.map(\.date).min() {
                let oldestDay = calendar.startOfDay(for: oldest)
                if oldestDay > customStartDay {
                    let cappedEnd = min(endOfToday, calendar.date(byAdding: .day, value: span + 1, to: oldestDay)!)
                    return (oldestDay, cappedEnd)
                }
            }
            return (customStartDay,
                    calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: customEnd) ?? customEnd))
        }
    }

    private func recompute() {
        let range = dateRange
        let filtered = summaries.filter { $0.date >= range.start && $0.date < range.end }
        sessionCount = filtered.count

        // Compute chart data for selected metric
        chartData = aggregateByDay(filtered, metric: selectedMetric)

        // Compute cumulative data for swings, normalized to fit daily Y range
        if selectedMetric == .swingCount, !chartData.isEmpty {
            var running: Double = 0
            var raw: [(date: Date, value: Double)] = []
            for point in chartData {
                running += point.value
                raw.append((point.date, running))
            }
            let dailyMax = chartData.map(\.value).max() ?? 1
            let cumulativeMax = raw.last?.value ?? 1
            let scale = cumulativeMax > 0 ? dailyMax / cumulativeMax : 1
            cumulativeChartData = raw.map {
                DailyDataPoint(date: $0.date, value: $0.value * scale)
            }
        } else {
            cumulativeChartData = []
        }

        // Compute summary for selected metric
        let values = extractValues(from: filtered, metric: selectedMetric)
        summaryValue = computeSummaryValue(values: values, metric: selectedMetric)
        summaryLabel = selectedMetric.aggregation == .sum ? "total" : "avg"

        // Compute card summaries for all metrics
        var cards: [MetricType: String] = [:]
        for metric in MetricType.allCases {
            let vals = extractValues(from: filtered, metric: metric)
            cards[metric] = computeSummaryValue(values: vals, metric: metric)
        }
        metricSummaries = cards
    }

    private func extractValues(from summaries: [SessionSummary], metric: MetricType) -> [Double] {
        summaries.compactMap { s in
            switch metric {
            case .swingCount: return Double(s.swingCount)
            case .reactionTime: return s.reactionTimeMs
            case .strikeTime: return s.strikeTimeMs
            case .maxMotionEnergy: return s.maxMotionEnergy
            case .maxRotVel: return s.maxRotVel
            case .sessionTime: return s.sessionDuration
            }
        }
    }

    private func computeSummaryValue(values: [Double], metric: MetricType) -> String {
        guard !values.isEmpty else { return "—" }

        let result: Double
        switch metric.aggregation {
        case .sum:
            result = values.reduce(0, +)
        case .average:
            result = values.reduce(0, +) / Double(values.count)
        }

        switch metric {
        case .swingCount, .reactionTime, .strikeTime, .sessionTime:
            return "\(Int(result))"
        default:
            return String(format: "%.1f", result)
        }
    }

    private func aggregateByDay(_ sessions: [SessionSummary], metric: MetricType) -> [DailyDataPoint] {
        let calendar = Calendar.current

        // Group by day
        var dayBuckets: [Date: [Double]] = [:]
        for s in sessions {
            let day = calendar.startOfDay(for: s.date)
            let value: Double?
            switch metric {
            case .swingCount: value = Double(s.swingCount)
            case .reactionTime: value = s.reactionTimeMs
            case .strikeTime: value = s.strikeTimeMs
            case .maxMotionEnergy: value = s.maxMotionEnergy
            case .maxRotVel: value = s.maxRotVel
            case .sessionTime: value = s.sessionDuration
            }
            if let v = value {
                dayBuckets[day, default: []].append(v)
            }
        }

        // Aggregate existing days
        var result = dayBuckets.map { (day, values) in
            let aggregated: Double
            switch metric.aggregation {
            case .sum: aggregated = values.reduce(0, +)
            case .average: aggregated = values.reduce(0, +) / Double(values.count)
            }
            return DailyDataPoint(date: day, value: aggregated)
        }

        // For sum metrics, fill in 0 for every day in the range that has no data
        if metric.aggregation == .sum {
            let range = dateRange
            let start = calendar.startOfDay(for: range.start)
            let end = calendar.startOfDay(for: range.end)
            var current = start
            while current < end {
                if dayBuckets[current] == nil {
                    result.append(DailyDataPoint(date: current, value: 0))
                }
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? end
            }
        }

        return result.sorted { $0.date < $1.date }
    }
}
