import SwiftUI

struct StageInfoSheet: View {
    let stage: Stage
    let swings: Int
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var progress: Double { stage.progress(swings: swings) }
    private var isCompleted: Bool { stage.isCompleted(swings: swings) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Stage header
                VStack(spacing: 6) {
                    Text("STAGE \(stage.id)")
                        .font(.pixelify(size: 12, weight: .bold))
                        .foregroundColor(.gray)

                    Text(stage.name)
                        .font(.pixelifyTitle)
                        .foregroundColor(.white)

                    Text(stage.subtitle)
                        .font(.pixelifyCaption)
                        .foregroundColor(.yellow)
                }
                .padding(.top, 32)

                if isCompleted {
                    Text("COMPLETED")
                        .font(.pixelify(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.yellow)
                }

                // Description
                Text(stage.description)
                    .font(.pixelifyBody)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Config details
                VStack(spacing: 8) {
                    configRow(label: "INTERVAL", value: intervalText)
                    configRow(label: "RANDOM", value: stage.cueConfig.useRandomInterval ? "ON" : "OFF")
                }
                .padding(.horizontal, 32)

                Spacer()

                // Progress bar
                VStack(spacing: 8) {
                    Text("\(swings) / \(stage.swingsRequired) swings")
                        .font(.pixelify(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 12)

                            Rectangle()
                                .fill(isCompleted ? Color.yellow : Color.red)
                                .frame(width: geo.size.width * progress, height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, 32)

                // HAJIME button
                Button(action: {
                    dismiss()
                    onStart()
                }) {
                    Text("HAJIME!")
                        .font(.pixelifyTitle)
                        .foregroundColor(.black)
                        .frame(maxWidth: 200)
                        .frame(height: 64)
                        .background(Color.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 4)
                        )
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var intervalText: String {
        if stage.cueConfig.useRandomInterval {
            return String(format: "%.1f-%.1fs", stage.cueConfig.randomRangeMin, stage.cueConfig.randomRangeMax)
        }
        return String(format: "%.1fs", stage.cueConfig.interSwingSec)
    }

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.pixelify(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.pixelify(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
