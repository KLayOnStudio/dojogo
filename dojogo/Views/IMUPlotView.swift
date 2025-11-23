import SwiftUI
import Charts

// MARK: - IMU Plot View (Acceleration + Gyroscope)
// Displays both acceleration and gyroscope data in separate charts

struct IMUPlotView: View {
    let samples: [IMUSample]

    // Axis selection for each sensor type
    @State private var selectedAccelAxis: Axis = .z
    @State private var selectedGyroAxis: Axis = .z

    enum Axis: String, CaseIterable {
        case z = "Z"
        case y = "Y"
        case x = "X"
    }

    var body: some View {
        VStack(spacing: 12) {
            if samples.isEmpty {
                emptyState
            } else {
                accelerationSection
                gyroscopeSection
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("ACCELERATION DATA")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            Text("No IMU data recorded")
                .font(.pixelifyBody)
                .foregroundColor(.gray)
                .padding()
        }
    }

    // MARK: - Acceleration Section

    private var accelerationSection: some View {
        VStack(spacing: 8) {
            Text("ACCELERATION DATA")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            accelerationChartContainer
        }
    }

    // MARK: - Gyroscope Section

    private var gyroscopeSection: some View {
        VStack(spacing: 8) {
            Text("GYROSCOPE DATA")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            gyroscopeChartContainer
        }
    }

    private var accelerationChartContainer: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Sample info
            HStack {
                Text("Samples: \(samples.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
                Spacer()
                Text("~\(sampleRate)Hz")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 8)

            // Chart
            accelerationChartView

            // Legend
            accelerationLegendView
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.5), lineWidth: 2))
    }

    private var gyroscopeChartContainer: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Sample info
            HStack {
                Text("Samples: \(samples.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.pink)
                Spacer()
                Text("~\(sampleRate)Hz")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.pink)
            }
            .padding(.horizontal, 8)

            // Chart
            gyroscopeChartView

            // Legend
            gyroscopeLegendView
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.5), lineWidth: 2))
    }

    private var accelerationChartView: some View {
        Chart {
            // Z-axis (cyan) - Primary sword arc motion
            ForEach(accelChartData.indices, id: \.self) { i in
                LineMark(
                    x: .value("Time", accelChartData[i].time),
                    y: .value("Acceleration", accelChartData[i].z),
                    series: .value("Axis", "Z")
                )
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: selectedAccelAxis == .z ? 2 : 1))
                .opacity(selectedAccelAxis == .z ? 1.0 : 0.3)
            }

            // Y-axis (yellow) - Vertical motion
            ForEach(accelChartData.indices, id: \.self) { i in
                LineMark(
                    x: .value("Time", accelChartData[i].time),
                    y: .value("Acceleration", accelChartData[i].y),
                    series: .value("Axis", "Y")
                )
                .foregroundStyle(.yellow)
                .lineStyle(StrokeStyle(lineWidth: selectedAccelAxis == .y ? 2 : 1))
                .opacity(selectedAccelAxis == .y ? 1.0 : 0.3)
            }

            // X-axis (green) - Lateral motion
            ForEach(accelChartData.indices, id: \.self) { i in
                LineMark(
                    x: .value("Time", accelChartData[i].time),
                    y: .value("Acceleration", accelChartData[i].x),
                    series: .value("Axis", "X")
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: selectedAccelAxis == .x ? 2 : 1))
                .opacity(selectedAccelAxis == .x ? 1.0 : 0.3)
            }
        }
        .frame(height: 200)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }

    private var gyroscopeChartView: some View {
        Chart {
            // Z-axis (pink/magenta) - Rotation around Z
            ForEach(gyroChartData.indices, id: \.self) { i in
                LineMark(
                    x: .value("Time", gyroChartData[i].time),
                    y: .value("Angular Velocity", gyroChartData[i].z),
                    series: .value("Axis", "Z")
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: selectedGyroAxis == .z ? 2 : 1))
                .opacity(selectedGyroAxis == .z ? 1.0 : 0.3)
            }

            // Y-axis (orange) - Rotation around Y
            ForEach(gyroChartData.indices, id: \.self) { i in
                LineMark(
                    x: .value("Time", gyroChartData[i].time),
                    y: .value("Angular Velocity", gyroChartData[i].y),
                    series: .value("Axis", "Y")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: selectedGyroAxis == .y ? 2 : 1))
                .opacity(selectedGyroAxis == .y ? 1.0 : 0.3)
            }

            // X-axis (blue) - Rotation around X
            ForEach(gyroChartData.indices, id: \.self) { i in
                LineMark(
                    x: .value("Time", gyroChartData[i].time),
                    y: .value("Angular Velocity", gyroChartData[i].x),
                    series: .value("Axis", "X")
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: selectedGyroAxis == .x ? 2 : 1))
                .opacity(selectedGyroAxis == .x ? 1.0 : 0.3)
            }
        }
        .frame(height: 200)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }

    private var accelerationLegendView: some View {
        HStack(spacing: 10) {
            // Z button
            Button { selectedAccelAxis = .z } label: {
                HStack(spacing: 4) {
                    Rectangle().fill(selectedAccelAxis == .z ? .white : .cyan).frame(width: 20, height: 3)
                    Text("Z")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedAccelAxis == .z ? Color.cyan : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.cyan, lineWidth: selectedAccelAxis == .z ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            // Y button
            Button { selectedAccelAxis = .y } label: {
                HStack(spacing: 4) {
                    Rectangle().fill(selectedAccelAxis == .y ? .white : .yellow).frame(width: 20, height: 3)
                    Text("Y")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedAccelAxis == .y ? Color.yellow : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.yellow, lineWidth: selectedAccelAxis == .y ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            // X button
            Button { selectedAccelAxis = .x } label: {
                HStack(spacing: 4) {
                    Rectangle().fill(selectedAccelAxis == .x ? .white : .green).frame(width: 20, height: 3)
                    Text("X")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedAccelAxis == .x ? Color.green : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green, lineWidth: selectedAccelAxis == .x ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Peak: \(String(format: "%.1f", accelPeakValue))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accelAxisColor.opacity(0.9))
        }
        .padding(.horizontal, 8)
    }

    private var gyroscopeLegendView: some View {
        HStack(spacing: 10) {
            // Z button
            Button { selectedGyroAxis = .z } label: {
                HStack(spacing: 4) {
                    Rectangle().fill(selectedGyroAxis == .z ? .white : .pink).frame(width: 20, height: 3)
                    Text("Z")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedGyroAxis == .z ? Color.pink : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.pink, lineWidth: selectedGyroAxis == .z ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            // Y button
            Button { selectedGyroAxis = .y } label: {
                HStack(spacing: 4) {
                    Rectangle().fill(selectedGyroAxis == .y ? .white : .orange).frame(width: 20, height: 3)
                    Text("Y")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedGyroAxis == .y ? Color.orange : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange, lineWidth: selectedGyroAxis == .y ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            // X button
            Button { selectedGyroAxis = .x } label: {
                HStack(spacing: 4) {
                    Rectangle().fill(selectedGyroAxis == .x ? .white : .blue).frame(width: 20, height: 3)
                    Text("X")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedGyroAxis == .x ? Color.blue : Color.gray.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: selectedGyroAxis == .x ? 2 : 0)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Peak: \(String(format: "%.2f", gyroPeakValue))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(gyroAxisColor.opacity(0.9))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Data Processing

    private struct ChartPoint {
        let time: Double
        let x, y, z: Double
    }

    private var accelChartData: [ChartPoint] {
        guard !samples.isEmpty else { return [] }

        let first = samples[0].ts_ns
        let data = samples.map { sample in
            ChartPoint(
                time: Double(sample.ts_ns - first) / 1_000_000_000.0,
                x: Double(sample.ax),
                y: Double(sample.ay),
                z: Double(sample.az)
            )
        }

        // Downsample for long sessions
        let maxPoints = 300
        if data.count <= maxPoints {
            return data
        } else {
            let step = data.count / maxPoints
            return stride(from: 0, to: data.count, by: step).map { data[$0] }
        }
    }

    private var gyroChartData: [ChartPoint] {
        guard !samples.isEmpty else { return [] }

        let first = samples[0].ts_ns
        let data = samples.map { sample in
            ChartPoint(
                time: Double(sample.ts_ns - first) / 1_000_000_000.0,
                x: Double(sample.gx),
                y: Double(sample.gy),
                z: Double(sample.gz)
            )
        }

        // Downsample for long sessions
        let maxPoints = 300
        if data.count <= maxPoints {
            return data
        } else {
            let step = data.count / maxPoints
            return stride(from: 0, to: data.count, by: step).map { data[$0] }
        }
    }

    private var sampleRate: Int {
        guard samples.count > 1 else { return 0 }
        let duration = Double(samples.last!.ts_ns - samples.first!.ts_ns) / 1_000_000_000.0
        return Int(Double(samples.count) / max(duration, 0.1))
    }

    private var accelPeakValue: Double {
        guard !samples.isEmpty else { return 0 }
        switch selectedAccelAxis {
        case .x: return samples.map { abs(Double($0.ax)) }.max() ?? 0
        case .y: return samples.map { abs(Double($0.ay)) }.max() ?? 0
        case .z: return samples.map { abs(Double($0.az)) }.max() ?? 0
        }
    }

    private var gyroPeakValue: Double {
        guard !samples.isEmpty else { return 0 }
        switch selectedGyroAxis {
        case .x: return samples.map { abs(Double($0.gx)) }.max() ?? 0
        case .y: return samples.map { abs(Double($0.gy)) }.max() ?? 0
        case .z: return samples.map { abs(Double($0.gz)) }.max() ?? 0
        }
    }

    private var accelAxisColor: Color {
        switch selectedAccelAxis {
        case .x: return .green
        case .y: return .yellow
        case .z: return .cyan
        }
    }

    private var gyroAxisColor: Color {
        switch selectedGyroAxis {
        case .x: return .blue
        case .y: return .orange
        case .z: return .pink
        }
    }
}

// MARK: - Preview
// (Disabled to avoid compiler timeouts - test with real data)
