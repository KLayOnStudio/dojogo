// TrajectoryComingSoonView.swift
// DojoGo - Placeholder for upcoming trajectory visualization

import SwiftUI
import Charts

struct TrajectoryComingSoonView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("TRAJECTORY")
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.white)

                Text("Coming Soon")
                    .font(.pixelify(size: 12, weight: .regular))
                    .foregroundColor(.purple.opacity(0.8))
            }

            // Placeholder chart — static mock sine wave
            placeholderChart
                .frame(height: 160)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)

            // Description bullets
            VStack(alignment: .leading, spacing: 10) {
                bulletItem(
                    icon: "point.3.connected.trianglepath.dotted",
                    text: "Estimated shinai path in 3D space"
                )
                bulletItem(
                    icon: "ruler",
                    text: "Swing plane consistency analysis"
                )
            }
            .padding(.horizontal, 8)

            Text("We're working on accurate trajectory reconstruction.\nStay tuned!")
                .font(.pixelify(size: 10, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.gray.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.purple.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Placeholder Chart

    private var placeholderChart: some View {
        Chart {
            ForEach(mockPoints, id: \.x) { point in
                LineMark(
                    x: .value("X", point.x),
                    y: .value("Y", point.y)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.purple.opacity(0.6), .cyan.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(8)
    }

    private var mockPoints: [(x: Double, y: Double)] {
        (0..<60).map { i in
            let t = Double(i) / 60.0 * 4.0 * .pi
            return (x: Double(i), y: sin(t) * cos(t * 0.3) * 2.0)
        }
    }

    // MARK: - Bullet Item

    private func bulletItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.purple.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(.pixelify(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
