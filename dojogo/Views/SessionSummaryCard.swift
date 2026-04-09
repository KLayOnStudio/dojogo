// SessionSummaryCard.swift
// DojoGo - Compact stat tiles shown on the post-session report
// Matches the 6 Insights metrics: Swings, Reaction, Strike, Max Power, Max Speed, Time

import SwiftUI

struct SessionSummaryCard: View {
    let stats: SessionStats

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.cyan)
                Text("SESSION SUMMARY")
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 12)

            // Row 1: Swings | Reaction | Strike
            HStack(spacing: 0) {
                statTile(
                    label: "SWINGS",
                    value: "\(stats.swingCount)",
                    color: .yellow
                )
                tileDivider
                statTile(
                    label: "REACTION",
                    value: stats.reactionResult?.avgReactionMs.map { "\(Int($0))" } ?? "—",
                    color: .green,
                    unit: "ms"
                )
                tileDivider
                statTile(
                    label: "STRIKE",
                    value: stats.avgStrikeTimeMs.map { "\(Int($0))" } ?? "—",
                    color: .cyan,
                    unit: "ms"
                )
            }
            .frame(height: 60)

            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 4)

            // Row 2: Max Power | Max Speed | Time
            HStack(spacing: 0) {
                statTile(
                    label: "MAX POWER",
                    value: stats.maxPower.map { String(format: "%.1f", $0) } ?? "—",
                    color: .red,
                    unit: "m/s²"
                )
                tileDivider
                statTile(
                    label: "MAX SPEED",
                    value: stats.maxSpeed.map { String(format: "%.1f", $0) } ?? "—",
                    color: .orange,
                    unit: "rad/s"
                )
                tileDivider
                statTile(
                    label: "TIME",
                    value: formatDuration(stats.durationSec),
                    color: .purple
                )
            }
            .frame(height: 60)
        }
        .padding(16)
        .background(Color.gray.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: - Stat Tile

    private func statTile(
        label: String,
        value: String,
        color: Color,
        unit: String? = nil
    ) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.pixelify(size: 9, weight: .regular))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.pixelify(size: 20, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let unit {
                Text(unit)
                    .font(.pixelify(size: 8, weight: .regular))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tileDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1)
            .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
