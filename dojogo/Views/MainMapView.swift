import SwiftUI

struct MainMapView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var gameViewModel = GameViewModel()
    @State private var showActionView = false
    @State private var showLeaderboard = false

    var body: some View {
        ZStack {
            // Pixelated map background (placeholder)
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .brown]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()

            // Map texture overlay (simulating pixels)
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .ignoresSafeArea()

            VStack {
                // User Info & Sign Out
                HStack {
                    VStack(alignment: .leading) {
                        if let user = authViewModel.currentUser {
                            Text("Welcome, \(user.name)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("ID: \(user.id)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Button("SIGN OUT") {
                        Task {
                            await authViewModel.signOut()
                        }
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow)
                }
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()

                // Start Button
                Button(action: {
                    print("START button tapped")
                    print("Current user: \(String(describing: authViewModel.currentUser))")
                    if let userId = authViewModel.currentUser?.id {
                        print("Starting session for user: \(userId)")
                        gameViewModel.startSession(userId: userId)
                        showActionView = true
                    } else {
                        print("No user ID found - user might not be authenticated")
                    }
                }) {
                    Text("START")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(width: 150, height: 60)
                        .background(Color.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 3)
                        )
                }

                Spacer()

                // Navigation Bar
                HStack {
                    Spacer()

                    // Home Button (current page)
                    Button(action: {}) {
                        VStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text("🏠")
                                        .font(.system(size: 16))
                                )
                            Text("HOME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    // Leaderboard Button
                    Button(action: {
                        showLeaderboard = true
                    }) {
                        VStack {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text("🏆")
                                        .font(.system(size: 16))
                                )
                            Text("RANKS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                .background(Color.black.opacity(0.8))
            }
        }
        .onAppear {
            // Log session start when entering main page
            if let userId = authViewModel.currentUser?.id {
                logSessionStart(userId: userId)
            }
        }
        .fullScreenCover(isPresented: $showActionView) {
            ActionView(gameViewModel: gameViewModel)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView()
                .environmentObject(authViewModel)
        }
    }

    private func logSessionStart(userId: String) {
        Task {
            do {
                try await APIService.shared.logSessionStart(userId: userId)
                print("Session start logged successfully for user: \(userId)")
            } catch {
                print("Failed to log session start: \(error.localizedDescription)")
            }
        }
    }
}