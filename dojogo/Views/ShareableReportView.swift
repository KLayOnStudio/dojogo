import SwiftUI
import Charts

struct ShareableReportView: View {
    let swingCount: Int
    let duration: TimeInterval
    let streak: Int?
    let stats: StoredSessionStats?
    let segments: [ChartSegment]
    let samples: [IMUSample]
    let backgroundColor: Color

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("SESSION REPORT")
                .font(.pixelify(size: 28, weight: .bold))
                .foregroundColor(textColor)

            // Main stats
            VStack(spacing: 12) {
                HStack {
                    Text("SWINGS:")
                        .font(.pixelify(size: 16, weight: .bold))
                        .foregroundColor(textColor)
                    Spacer()
                    Text("\(swingCount)")
                        .font(.pixelify(size: 22, weight: .bold))
                        .foregroundColor(.green)
                }

                Rectangle()
                    .fill(textColor.opacity(0.2))
                    .frame(height: 1)

                HStack {
                    Text("DURATION:")
                        .font(.pixelify(size: 16, weight: .bold))
                        .foregroundColor(textColor)
                    Spacer()
                    Text(formatDuration(duration))
                        .font(.pixelify(size: 18, weight: .semiBold))
                        .foregroundColor(.cyan)
                }

                if let streak = streak {
                    Rectangle()
                        .fill(textColor.opacity(0.2))
                        .frame(height: 1)

                    HStack {
                        Text("STREAK:")
                            .font(.pixelify(size: 16, weight: .bold))
                            .foregroundColor(textColor)
                        Spacer()
                        Text("\(streak) DAYS")
                            .font(.pixelify(size: 18, weight: .semiBold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(20)
            .background(textColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(textColor.opacity(0.3), lineWidth: 2)
            )

            // Stats tiles
            if let stats = stats {
                shareableStatsGrid(stats: stats)
            }

            // Swing Overlay Charts
            if !segments.isEmpty {
                SwingOverlayChart(
                    segments: segments,
                    samples: samples,
                    title: "SWING SPEED (gx)",
                    unit: "rad/s",
                    color: .cyan,
                    valueExtractor: { $0.gx },
                    synchronous: true
                )

                SwingOverlayChart(
                    segments: segments,
                    samples: samples,
                    title: "SWING FORCE (ay)",
                    unit: "m/s²",
                    color: .yellow,
                    valueExtractor: { $0.ay },
                    synchronous: true
                )
            }

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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private func shareableStatsGrid(stats: StoredSessionStats) -> some View {
        let reactionStr = stats.avgReactionMs.map { "\(Int($0))" } ?? "—"
        let strikeStr = stats.avgStrikeTimeMs.map { "\(Int($0))" } ?? "—"
        let powerStr = stats.maxPower.map { String(format: "%.1f", $0) } ?? "—"
        let speedStr = stats.maxSpeed.map { String(format: "%.1f", $0) } ?? "—"
        let timeStr = formatDuration(duration)

        let tiles: [(String, String, String?, Color)] = [
            ("SWINGS", "\(swingCount)", nil, .yellow),
            ("REACTION", reactionStr, "ms", .green),
            ("STRIKE", strikeStr, "ms", .cyan),
            ("MAX POWER", powerStr, "m/s²", .red),
            ("MAX SPEED", speedStr, "rad/s", .orange),
            ("TIME", timeStr, nil, .purple)
        ]

        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(tiles.indices, id: \.self) { i in
                VStack(spacing: 4) {
                    Text(tiles[i].0)
                        .font(.pixelify(size: 9, weight: .bold))
                        .foregroundColor(textColor.opacity(0.6))
                    Text(tiles[i].1)
                        .font(.pixelify(size: 16, weight: .bold))
                        .foregroundColor(tiles[i].3)
                    Text(tiles[i].2 ?? " ")
                        .font(.pixelify(size: 8, weight: .regular))
                        .foregroundColor(tiles[i].2 != nil ? textColor.opacity(0.4) : .clear)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(textColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(textColor.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }
}
