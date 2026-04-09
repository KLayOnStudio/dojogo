import SwiftUI

struct FreePracticeSheet: View {
    @ObservedObject var gameViewModel: GameViewModel
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("FREE PRACTICE")
                    .font(.pixelifyTitle)
                    .foregroundColor(.white)
                    .padding(.top, 32)

                Text("Set your own pace. Swings here do not count toward stage progress.")
                    .font(.pixelifyCaption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Guide toggle
                HStack {
                    Text("GUIDE")
                        .font(.pixelify(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            gameViewModel.isGuidedMode.toggle()
                        }
                    }) {
                        Text(gameViewModel.isGuidedMode ? "ON" : "OFF")
                            .font(.pixelify(size: 14, weight: .bold))
                            .foregroundColor(gameViewModel.isGuidedMode ? .green : .red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)

                if gameViewModel.isGuidedMode {
                    // Interval control
                    HStack {
                        Text("INTERVAL")
                            .font(.pixelify(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                if gameViewModel.interSwingSec > 1.0 {
                                    gameViewModel.interSwingSec -= 0.5
                                }
                            }) {
                                Text("\u{2212}")
                                    .font(.pixelify(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.gray.opacity(0.5))
                            }

                            Text(gameViewModel.useRandomInterval ? "RND" : String(format: "%.1fs", gameViewModel.interSwingSec))
                                .font(.pixelify(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 50)

                            Button(action: {
                                if gameViewModel.interSwingSec < 8.0 {
                                    gameViewModel.interSwingSec += 0.5
                                }
                            }) {
                                Text("+")
                                    .font(.pixelify(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.gray.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    // Random toggle
                    HStack {
                        Text("RANDOM")
                            .font(.pixelify(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: {
                            gameViewModel.useRandomInterval.toggle()
                        }) {
                            Text(gameViewModel.useRandomInterval ? "ON" : "OFF")
                                .font(.pixelify(size: 12, weight: .bold))
                                .foregroundColor(gameViewModel.useRandomInterval ? .green : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // HAJIME button
                Button(action: {
                    gameViewModel.configureForFreePractice()
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
}
