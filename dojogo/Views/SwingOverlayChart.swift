import SwiftUI
import Charts

struct ChartSegment {
    let startIndex: Int
    let endIndex: Int
}

struct SwingOverlayChart: View {
    let segments: [ChartSegment]
    let samples: [IMUSample]
    let title: String
    let unit: String
    let color: Color
    let valueExtractor: (IMUSample) -> Float
    var synchronous: Bool = false

    @State private var cachedSwingData: [[DataPoint]] = []
    @State private var cachedAverage: [DataPoint] = []

    private var activeSwingData: [[DataPoint]] {
        synchronous ? computeSwingData() : cachedSwingData
    }
    private var activeAverage: [DataPoint] {
        synchronous ? computeAverage(from: activeSwingData) : cachedAverage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            if activeSwingData.isEmpty {
                Text("No swing data")
                    .font(.pixelifySmall)
                    .foregroundColor(.gray)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Individual swings at low opacity — evenly sampled, max 10
                    ForEach(sampledIndices.indices, id: \.self) { i in
                        let swingIndex = sampledIndices[i]
                        let swing = activeSwingData[swingIndex]
                        ForEach(swing.indices, id: \.self) { pointIndex in
                            let point = swing[pointIndex]
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value(unit, point.value),
                                series: .value("Swing", "s\(swingIndex)")
                            )
                            .foregroundStyle(color.opacity(0.15))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                        }
                    }

                    // Average swing at full opacity
                    ForEach(activeAverage.indices, id: \.self) { i in
                        let point = activeAverage[i]
                        LineMark(
                            x: .value("Time", point.time),
                            y: .value(unit, point.value),
                            series: .value("Swing", "avg")
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel()
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartLegend(.hidden)
                .drawingGroup()
                .frame(height: 160)
                .padding(12)
                .background(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .task {
            guard !synchronous else { return }
            let data = computeSwingData()
            cachedSwingData = data
            cachedAverage = computeAverage(from: data)
        }
    }

    private var sampledIndices: [Int] {
        let count = activeSwingData.count
        guard count > 10 else { return Array(0..<count) }
        return (0..<10).map { i in Int(Double(i) / 9.0 * Double(count - 1)) }
    }

    // MARK: - Data Processing

    private struct DataPoint {
        let time: Double
        let value: Double
    }

    private func computeSwingData() -> [[DataPoint]] {
        segments.compactMap { segment -> [DataPoint]? in
            guard segment.startIndex >= 0, segment.endIndex < samples.count else { return nil }
            let swingSamples = Array(samples[segment.startIndex...segment.endIndex])
            guard let firstTs = swingSamples.first?.ts_ns else { return nil }

            return swingSamples.map { sample in
                DataPoint(
                    time: Double(sample.ts_ns - firstTs) / 1_000_000_000.0,
                    value: Double(valueExtractor(sample))
                )
            }
        }
    }

    private func computeAverage(from allSwings: [[DataPoint]]) -> [DataPoint] {
        guard !allSwings.isEmpty else { return [] }

        // Resample all swings to a fixed number of points
        let resampleCount = 50
        let resampled: [[Double]] = allSwings.map { swing in
            resample(swing.map { $0.value }, to: resampleCount)
        }

        let avgDuration = allSwings.map { $0.last?.time ?? 0 }.reduce(0, +) / Double(allSwings.count)

        // Average each point
        var avgValues: [Double] = Array(repeating: 0, count: resampleCount)
        for swing in resampled {
            for i in 0..<resampleCount {
                avgValues[i] += swing[i]
            }
        }
        avgValues = avgValues.map { $0 / Double(resampled.count) }

        // Create data points with time scaled to average duration
        return avgValues.enumerated().map { i, value in
            DataPoint(
                time: avgDuration * Double(i) / Double(resampleCount - 1),
                value: value
            )
        }
    }

    private func resample(_ values: [Double], to count: Int) -> [Double] {
        guard values.count >= 2, count >= 2 else {
            return Array(repeating: values.first ?? 0, count: count)
        }

        var result: [Double] = []
        for i in 0..<count {
            let position = Double(i) / Double(count - 1) * Double(values.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, values.count - 1)
            let fraction = position - Double(lower)
            result.append(values[lower] * (1 - fraction) + values[upper] * fraction)
        }
        return result
    }
}
