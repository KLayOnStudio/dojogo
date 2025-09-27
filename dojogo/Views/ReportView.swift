import SwiftUI

struct ReportView: View {
    let session: Session
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentStreak = 0
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                Text("SESSION REPORT")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // Results Box
                VStack(spacing: 20) {
                    // Tap Count
                    HStack {
                        Text("TOTAL TAPS:")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(session.tapCount)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }

                    // Duration
                    HStack {
                        Text("DURATION:")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatDuration(session.duration))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }

                    // Current Streak
                    HStack {
                        Text("CURRENT STREAK:")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        if isLoading {
                            Text("...")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        } else {
                            Text("\(currentStreak) DAYS")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white, lineWidth: 2)
                )

                // Continue Button
                Button(action: {
                    dismiss()
                }) {
                    Text("CONTINUE")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.green)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            .padding()
        }
        .onAppear {
            submitSessionData()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func submitSessionData() {
        guard let userId = authViewModel.currentUser?.id else { return }

        Task {
            do {
                // Submit to Azure database
                let result = try await APIService.shared.submitSession(session)

                await MainActor.run {
                    self.currentStreak = result.streak
                    self.isLoading = false
                    self.authViewModel.currentUser = result.updatedUser
                }
            } catch {
                print("Failed to submit session: \(error)")

                // Fallback to local calculation
                await MainActor.run {
                    self.currentStreak = LocalStorageService.shared.getStreakForUser(userId)
                    self.isLoading = false

                    if var user = authViewModel.currentUser {
                        user.totalCount += session.tapCount
                        user.streak = self.currentStreak
                        user.lastSessionDate = session.date
                        authViewModel.currentUser = user
                        LocalStorageService.shared.saveUser(user)
                    }
                }
            }
        }

        print("Submitting session data: \(session)")
    }
}