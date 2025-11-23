import SwiftUI

struct MainMapView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var gameViewModel = GameViewModel()
    @State private var showCountdownSplash = false
    @State private var showActionView = false
    @State private var showLeaderboard = false
    @State private var showProfile = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map background image
                Image("MapVer0")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // User Info & Sign Out
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let user = authViewModel.currentUser {
                                Text("Welcome, \(user.displayName)")
                                    .font(.pixelifySmall)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)

                                Button(action: {
                                    showProfile = true
                                }) {
                                    Text(user.nickname == nil ? "Set Nickname" : "View Profile")
                                        .font(.pixelify(size: 9))
                                        .foregroundColor(.yellow)
                                        .underline()
                                }
                            }
                        }

                        Spacer()

                        // TEMPORARY: Token test button
                        Button("🔑") {
                            authViewModel.printTokenForTesting()
                        }
                        .font(.pixelify(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)

                        Button("SIGN OUT") {
                            Task {
                                await authViewModel.signOut()
                            }
                        }
                        .font(.pixelify(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.yellow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 8)
                    .background(Color.black.opacity(0.3))

                    Spacer()

                    // Start Button
                    Button(action: {
                        print("START button tapped")
                        print("Current user: \(String(describing: authViewModel.currentUser))")
                        if let userId = authViewModel.currentUser?.id {
                            print("Starting session for user: \(userId)")
                            gameViewModel.startSession(userId: userId)
                            showCountdownSplash = true
                        } else {
                            print("No user ID found - user might not be authenticated")
                        }
                    }) {
                        Text("HAJIME!")
                            .font(.pixelifyTitle)
                            .foregroundColor(.black)
                            .frame(maxWidth: min(geometry.size.width * 0.5, 200))
                            .frame(height: 64)
                            .background(Color.red)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 4)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }

                    Spacer()

                    // Navigation Bar
                    HStack(spacing: 0) {
                        Spacer()

                        // Home Button (current page)
                        Button(action: {}) {
                            VStack(spacing: 6) {
                                Image("dojoIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                Text("HOME")
                                    .font(.pixelify(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: geometry.size.width * 0.25)
                            .padding(.vertical, 16)
                        }

                        Spacer()

                        // Leaderboard Button
                        Button(action: {
                            showLeaderboard = true
                        }) {
                            VStack(spacing: 6) {
                                Image("badgeLeague")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                Text("RANKS")
                                    .font(.pixelify(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: geometry.size.width * 0.25)
                            .padding(.vertical, 16)
                        }

                        Spacer()

                        // Profile Button
                        Button(action: {
                            showProfile = true
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(.white)
                                Text("PROFILE")
                                    .font(.pixelify(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: geometry.size.width * 0.25)
                            .padding(.vertical, 16)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.85))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1),
                        alignment: .top
                    )
                }
            }
        }
        .onAppear {
            // Log session start when entering main page
            if let userId = authViewModel.currentUser?.id {
                logSessionStart(userId: userId)
            }
        }
        .fullScreenCover(isPresented: $showCountdownSplash) {
            CountdownSplashView(isPresented: $showCountdownSplash) {
                showActionView = true
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
        .sheet(isPresented: $showProfile) {
            ProfileView()
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
