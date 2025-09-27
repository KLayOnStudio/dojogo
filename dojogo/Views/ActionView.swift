import SwiftUI

struct ActionView: View {
    @ObservedObject var gameViewModel: GameViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showReport = false

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            // Random button
            if gameViewModel.isSessionActive {
                Button(action: {
                    if let userId = authViewModel.currentUser?.id {
                        gameViewModel.handleTap(userId: userId)
                    }
                }) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text("TAP")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .position(gameViewModel.buttonPosition)
                .animation(.easeInOut(duration: 0.3), value: gameViewModel.buttonPosition)
            }

            // UI Overlay
            VStack {
                HStack {
                    // Tap Counter
                    Text("TAPS: \(gameViewModel.tapCount)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))

                    Spacer()

                    // Stop Button
                    Button(action: {
                        if let userId = authViewModel.currentUser?.id {
                            gameViewModel.endSession(userId: userId)
                        }
                    }) {
                        Text("STOP")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 80, height: 40)
                            .background(Color.yellow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .padding()
                }

                Spacer()

                if !gameViewModel.isSessionActive {
                    Text("SESSION ENDED")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
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
                .onDisappear {
                    dismiss()
                }
        }
    }
}