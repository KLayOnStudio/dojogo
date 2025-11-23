// PositionTrajectoryView.swift
// DojoGo - 2D Position Trajectory Visualization
//
// Displays sword tip trajectory across 3 planes (X-Y, X-Z, Y-Z)
// Color-coded by velocity magnitude

import SwiftUI
import Charts
import simd

struct PositionTrajectoryView: View {
    let integrationResult: IntegrationResult
    let swings: [SwingSegment]

    @State private var selectedPlane: Plane = .xy
    @State private var showSwingBoundaries: Bool = true
    @State private var showZUPT: Bool = true

    enum Plane: String, CaseIterable {
        case xy = "X-Y (Top)"
        case xz = "X-Z (Side)"
        case yz = "Y-Z (Front)"
    }

    var body: some View {
        VStack(spacing: 12) {
            if integrationResult.points.isEmpty {
                emptyState
            } else {
                headerSection
                planeSelector
                trajectoryChart
                legendSection
                statsSection
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("POSITION TRAJECTORY")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            Text("No trajectory data")
                .font(.pixelifyBody)
                .foregroundColor(.gray)
                .padding()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("POSITION TRAJECTORY")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            Text("Sword tip path • Color = speed")
                .font(.pixelify(size: 10, weight: .regular))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Plane Selector

    private var planeSelector: some View {
        HStack(spacing: 8) {
            ForEach(Plane.allCases, id: \.self) { plane in
                Button {
                    selectedPlane = plane
                } label: {
                    Text(plane.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(selectedPlane == plane ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedPlane == plane ? Color.cyan : Color.gray.opacity(0.3))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan, lineWidth: selectedPlane == plane ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Trajectory Chart

    private var trajectoryChart: some View {
        Chart {
            // Main trajectory with velocity color-coding
            ForEach(trajectoryData.indices, id: \.self) { i in
                let point = trajectoryData[i]

                PointMark(
                    x: .value("X", point.x),
                    y: .value("Y", point.y)
                )
                .foregroundStyle(velocityColor(point.velocity))
                .symbolSize(30)
            }

            // Swing boundaries
            if showSwingBoundaries {
                ForEach(swingBoundaryPoints, id: \.index) { boundary in
                    PointMark(
                        x: .value("X", boundary.x),
                        y: .value("Y", boundary.y)
                    )
                    .foregroundStyle(.yellow)
                    .symbol(.diamond)
                    .symbolSize(60)
                }
            }

            // ZUPT periods
            if showZUPT {
                ForEach(zuptPoints, id: \.index) { zupt in
                    PointMark(
                        x: .value("X", zupt.x),
                        y: .value("Y", zupt.y)
                    )
                    .foregroundStyle(.white.opacity(0.3))
                    .symbolSize(20)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.2))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.2))
                AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.white.opacity(0.4))
                AxisValueLabel()
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(height: 280)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .padding(.horizontal, 8)
    }

    // MARK: - Legend

    private var legendSection: some View {
        VStack(spacing: 8) {
            // Velocity gradient legend
            HStack(spacing: 4) {
                Text("Slow")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)

                HStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { i in
                        Rectangle()
                            .fill(velocityColor(Double(i) / 19.0 * maxVelocity))
                            .frame(width: 8, height: 12)
                    }
                }
                .cornerRadius(2)

                Text("Fast")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()

                Text("Max: \(String(format: "%.1f", maxVelocity)) m/s")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Toggle controls
            HStack(spacing: 12) {
                Toggle(isOn: $showSwingBoundaries) {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Text("Swings")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .toggleStyle(.button)
                .tint(.gray.opacity(0.3))

                Toggle(isOn: $showZUPT) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.white.opacity(0.3))
                        Text("ZUPT")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .toggleStyle(.button)
                .tint(.gray.opacity(0.3))

                Spacer()
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DISTANCE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text("\(String(format: "%.2f", integrationResult.totalDistance)) m")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("SWINGS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text("\(swings.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ZUPT RESETS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Text("\(integrationResult.zuptResets.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }

    // MARK: - Data Processing

    private struct TrajectoryPoint {
        let x: Double
        let y: Double
        let velocity: Double
        let index: Int
    }

    private var trajectoryData: [TrajectoryPoint] {
        let points = integrationResult.points
        guard !points.isEmpty else { return [] }

        return points.enumerated().map { (index, point) in
            let (x, y) = project2D(point.position)
            let velocity = simd_length(point.velocity)
            return TrajectoryPoint(x: x, y: y, velocity: velocity, index: index)
        }
    }

    private func project2D(_ position: SIMD3<Double>) -> (x: Double, y: Double) {
        switch selectedPlane {
        case .xy: return (position.x, position.y)
        case .xz: return (position.x, position.z)
        case .yz: return (position.y, position.z)
        }
    }

    private var maxVelocity: Double {
        return integrationResult.points.map { simd_length($0.velocity) }.max() ?? 1.0
    }

    private func velocityColor(_ velocity: Double) -> Color {
        let normalized = min(velocity / maxVelocity, 1.0)

        if normalized < 0.33 {
            // Blue to cyan (slow)
            let t = normalized / 0.33
            return Color(
                red: 0.0,
                green: t * 0.5,
                blue: 1.0
            )
        } else if normalized < 0.67 {
            // Cyan to yellow (medium)
            let t = (normalized - 0.33) / 0.34
            return Color(
                red: t,
                green: 0.5 + t * 0.5,
                blue: 1.0 - t
            )
        } else {
            // Yellow to red (fast)
            let t = (normalized - 0.67) / 0.33
            return Color(
                red: 1.0,
                green: 1.0 - t * 0.5,
                blue: 0.0
            )
        }
    }

    private var swingBoundaryPoints: [TrajectoryPoint] {
        var boundaries: [TrajectoryPoint] = []

        for swing in swings {
            // Add start point
            if swing.startIndex < integrationResult.points.count {
                let point = integrationResult.points[swing.startIndex]
                let (x, y) = project2D(point.position)
                boundaries.append(TrajectoryPoint(
                    x: x,
                    y: y,
                    velocity: simd_length(point.velocity),
                    index: swing.startIndex
                ))
            }

            // Add end point
            if swing.endIndex < integrationResult.points.count {
                let point = integrationResult.points[swing.endIndex]
                let (x, y) = project2D(point.position)
                boundaries.append(TrajectoryPoint(
                    x: x,
                    y: y,
                    velocity: simd_length(point.velocity),
                    index: swing.endIndex
                ))
            }
        }

        return boundaries
    }

    private var zuptPoints: [TrajectoryPoint] {
        return integrationResult.zuptResets.compactMap { index -> TrajectoryPoint? in
            guard index < integrationResult.points.count else { return nil }
            let point = integrationResult.points[index]
            let (x, y) = project2D(point.position)
            return TrajectoryPoint(
                x: x,
                y: y,
                velocity: simd_length(point.velocity),
                index: index
            )
        }
    }
}
