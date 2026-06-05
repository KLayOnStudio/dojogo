import SwiftUI
import Charts

struct SavedReportView: View {
    let report: StoredSessionReport
    @Environment(\.dismiss) var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.08)

                        // Title
                        Text("SESSION REPORT")
                            .font(.pixelifyTitle)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 2)
                            .padding(.bottom, 24)

                        // Results Box
                        VStack(spacing: 24) {
                            // Swing Count
                            HStack {
                                Text("SWINGS:")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(report.session.swingCount)")
                                    .font(.pixelify(size: 24, weight: .bold))
                                    .foregroundColor(.green)
                            }

                            Divider()
                                .background(Color.white.opacity(0.3))

                            // Duration
                            HStack {
                                Text("DURATION:")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(formatDuration(report.session.duration))
                                    .font(.pixelify(size: 20, weight: .semiBold))
                                    .foregroundColor(.cyan)
                            }

                            Divider()
                                .background(Color.white.opacity(0.3))

                            // Date
                            HStack {
                                Text("DATE:")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(formattedDate)
                                    .font(.pixelify(size: 20, weight: .semiBold))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(24)
                        .background(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .padding(.horizontal, 20)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                        Spacer()
                            .frame(height: 20)

                        // Session Summary Card (stats tiles)
                        if let stats = report.stats {
                            StoredStatsSummaryCard(stats: stats)
                                .padding(.horizontal, 20)

                            Spacer()
                                .frame(height: 20)
                        }

                        // Swing Overlay Charts
                        if !chartSegments.isEmpty {
                            SwingOverlayChart(
                                segments: chartSegments,
                                samples: report.imuSamples,
                                title: "SWING SPEED (gx)",
                                unit: "rad/s",
                                color: .cyan,
                                valueExtractor: { $0.gx }
                            )
                            .padding(.horizontal, 20)

                            Spacer()
                                .frame(height: 16)

                            SwingOverlayChart(
                                segments: chartSegments,
                                samples: report.imuSamples,
                                title: "SWING FORCE (ay)",
                                unit: "m/s²",
                                color: .yellow,
                                valueExtractor: { $0.ay }
                            )
                            .padding(.horizontal, 20)

                            Spacer()
                                .frame(height: 20)
                        }

                        // IMU Data Toggle
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showVisualization.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(showVisualization ? "HIDE DATA" : "SHOW DATA")
                                    .font(.pixelifyButton)
                                Image(systemName: showVisualization ? "chevron.up" : "chart.xyaxis.line")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                            .frame(height: 48)
                            .background(Color.cyan)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 20)

                        if showVisualization {
                            IMUPlotView(samples: report.imuSamples)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        Spacer()
                            .frame(height: 20)

                        // Share Button
                        Button(action: { showShareOptions.toggle() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                Text("SHARE")
                                    .font(.pixelifyButton)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                            .frame(height: 48)
                            .background(Color.yellow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 20)

                        if showShareOptions {
                            VStack(spacing: 8) {
                                Text("BACKGROUND")
                                    .font(.pixelify(size: 10))
                                    .foregroundColor(.gray)

                                HStack(spacing: 12) {
                                    shareColorButton(.black, label: "Dark")
                                    shareColorButton(.white, label: "Light")
                                    shareColorButton(.clear, label: "Clear")
                                }

                                Button(action: { shareReport() }) {
                                    Text("EXPORT IMAGE")
                                        .font(.pixelifyBodyBold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                        .frame(height: 44)
                                        .background(Color.blue.opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Close Button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("CLOSE")
                                .font(.pixelifyButtonLarge)
                                .foregroundColor(.black)
                                .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                .frame(height: 56)
                                .background(Color.green)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
    }

    // MARK: - State

    @State private var showVisualization = false
    @State private var showShareOptions = false
    @State private var shareBackgroundColor: Color = .black

    // MARK: - Chart Segments

    private var chartSegments: [ChartSegment] {
        let cues = report.cueEvents
        let samples = report.imuSamples

        let actionCues = cues.filter { $0.cueType == .countdownGo || $0.cueType == .postZanshinCue }

        guard actionCues.count >= 2, let firstSampleTs = samples.first?.ts_ns else {
            return report.swingSegments.map {
                ChartSegment(startIndex: $0.startIndex, endIndex: $0.endIndex)
            }
        }

        var segments: [ChartSegment] = []
        for i in 0..<(actionCues.count - 1) {
            let cueMs = actionCues[i].visualAtMs ?? actionCues[i].scheduledAtMs
            let nextCueMs = actionCues[i + 1].visualAtMs ?? actionCues[i + 1].scheduledAtMs

            let cueNs = firstSampleTs + Int64(cueMs) * 1_000_000
            let nextCueNs = firstSampleTs + Int64(nextCueMs) * 1_000_000

            let startIdx = samples.firstIndex(where: { $0.ts_ns >= cueNs }) ?? 0
            let endIdx = (samples.lastIndex(where: { $0.ts_ns <= nextCueNs }) ?? (samples.count - 1))

            if startIdx < endIdx {
                segments.append(ChartSegment(startIndex: startIdx, endIndex: endIdx))
            }
        }

        return segments.isEmpty
            ? report.swingSegments.map { ChartSegment(startIndex: $0.startIndex, endIndex: $0.endIndex) }
            : segments
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: report.session.date)
    }

    // MARK: - Share

    private func shareColorButton(_ color: Color, label: String) -> some View {
        Button(action: { shareBackgroundColor = color }) {
            Text(label)
                .font(.pixelify(size: 10, weight: .bold))
                .foregroundColor(color == .white ? .black : .white)
                .frame(width: 64, height: 32)
                .background(color == .clear ? Color.gray.opacity(0.3) : color)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(shareBackgroundColor == color ? Color.cyan : Color.white.opacity(0.3),
                                lineWidth: shareBackgroundColor == color ? 3 : 1)
                )
        }
        .buttonStyle(PixelButtonStyle())
    }

    private func shareReport() {
        let view = ShareableReportView(
            swingCount: report.session.swingCount,
            duration: report.session.duration,
            streak: nil,
            stats: report.stats,
            segments: chartSegments,
            samples: report.imuSamples,
            backgroundColor: shareBackgroundColor
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderer.isOpaque = shareBackgroundColor != .clear

        guard let image = renderer.uiImage else { return }
        guard let pngData = image.pngData() else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("DojoGo_Report.png")
        try? pngData.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Stored Stats Summary Card

private struct StoredStatsSummaryCard: View {
    let stats: StoredSessionStats

    var body: some View {
        VStack(spacing: 0) {
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

            // Row 1: Reaction | Strike | Max Speed
            HStack(spacing: 0) {
                statTile(
                    label: "REACTION",
                    value: stats.avgReactionMs.map { "\(Int($0))" } ?? "—",
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
                tileDivider
                statTile(
                    label: "MAX SPEED",
                    value: stats.maxSpeed.map { String(format: "%.1f", $0) } ?? "—",
                    color: .orange,
                    unit: "rad/s"
                )
            }
            .frame(height: 60)

            Divider()
                .background(Color.white.opacity(0.15))
                .padding(.vertical, 4)

            // Row 2: Max Power | Avg Speed | Tempo
            HStack(spacing: 0) {
                statTile(
                    label: "MAX POWER",
                    value: stats.maxPower.map { String(format: "%.1f", $0) } ?? "—",
                    color: .red,
                    unit: "m/s²"
                )
                tileDivider
                statTile(
                    label: "AVG SPEED",
                    value: stats.avgSpeed.map { String(format: "%.1f", $0) } ?? "—",
                    color: .purple,
                    unit: "rad/s"
                )
                tileDivider
                statTile(
                    label: "TEMPO",
                    value: stats.tempo.map { String(format: "%.1f", $0) } ?? "—",
                    color: .yellow,
                    unit: "sw/min"
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
}
