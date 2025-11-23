import SwiftUI

struct ActionView: View {
    @ObservedObject var gameViewModel: GameViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showReport = false

    private var backgroundGradient: LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())

        let colors: [Color]
        switch hour {
        case 5..<8:  // Dawn
            colors = [Color.orange.opacity(0.3), Color.purple.opacity(0.4)]
        case 8..<17: // Day
            colors = [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)]
        case 17..<20: // Sunset
            colors = [Color.orange.opacity(0.5), Color.pink.opacity(0.3)]
        default:     // Night
            colors = [Color.black, Color.blue.opacity(0.2)]
        }

        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Time-based background
                Rectangle()
                    .fill(backgroundGradient)
                    .ignoresSafeArea()

                // Random button
                if gameViewModel.isSessionActive {
                    Button(action: {
                        if let userId = authViewModel.currentUser?.id {
                            gameViewModel.handleTap(userId: userId)
                        }
                    }) {
                        Image("shinaiPixel")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(geometry.size.width * 0.3, 120), height: min(geometry.size.width * 0.3, 120))
                            .overlay(
                                Text("TAP")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 2)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .position(gameViewModel.buttonPosition)
                    .animation(.easeInOut(duration: 0.3), value: gameViewModel.buttonPosition)
                }

                // UI Overlay
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        // Tap Counter
                        Text("TAPS: \(gameViewModel.tapCount)")
                            .font(.pixelifyButton)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )

                        Spacer()

                        // Mute Button
                        Button(action: {
                            gameViewModel.toggleSound()
                        }) {
                            Text(gameViewModel.isSoundEnabled ? "Sound On" : "Sound Off")
                                .font(.pixelifySmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }

                        // Stop Button
                        Button(action: {
                            if let userId = authViewModel.currentUser?.id {
                                gameViewModel.endSession(userId: userId)
                            }
                        }) {
                            Text("YAME!")
                                .font(.pixelifyButton)
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .frame(minWidth: 80)
                                .background(Color.yellow)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 12)

                    Spacer()

                    if !gameViewModel.isSessionActive {
                        Text("SESSION ENDED")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .onChange(of: gameViewModel.isSessionActive) { isActive in
            if !isActive && gameViewModel.currentSession != nil {
                showReport = true
            }
        }
        .fullScreenCover(isPresented: $showReport) {
            ReportView(session: gameViewModel.currentSession!)
                .environmentObject(authViewModel)
                .environmentObject(gameViewModel)
                .onDisappear {
                    dismiss()
                }
        }
    }
}
