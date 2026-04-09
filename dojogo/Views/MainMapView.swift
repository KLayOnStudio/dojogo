import SwiftUI

struct MainMapView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var gameViewModel = GameViewModel()
    @State private var showActionView = false
    @State private var showLeaderboard = false
    @State private var showInsights = false
    @State private var showNakama = false
    @State private var showProfile = false
    @State private var showLastSessionReport = false
    @State private var lastSessionReport: StoredSessionReport? = nil

    // Stage map state
    @State private var selectedStage: Stage? = nil
    @State private var showFreePracticeSheet = false
    @State private var showFreePracticeBubble = false
    @State private var stageSwings: [Int: Int] = [:]
    @State private var avatarPosition: CGPoint = Stage.allStages[0].mapPosition
    @State private var avatarFacingRight = true
    @State private var boatBob: CGFloat = 0
    @State private var boatSway: CGFloat = 0

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
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedStage = nil
                            showFreePracticeBubble = false
                            avatarFacingRight.toggle()
                        }
                    }

                // Stage nodes overlaid on map
                ForEach(Stage.allStages) { stage in
                    let swings = stageSwings[stage.id] ?? 0
                    let unlocked = authViewModel.isGuest || stage.isUnlocked(stageSwings: stageSwings)
                    StageNodeView(
                        stage: stage,
                        swings: swings,
                        isUnlocked: unlocked,
                        onTap: {
                            showFreePracticeBubble = false
                            avatarFacingRight.toggle()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedStage = selectedStage == stage ? nil : stage
                            }
                            withAnimation(.easeInOut(duration: 0.4)) {
                                avatarPosition = stage.mapPosition
                            }
                        }
                    )
                    .position(
                        x: stage.mapPosition.x * geometry.size.width,
                        y: stage.mapPosition.y * geometry.size.height
                    )
                }

                // Free practice ship
                FreePracticeShipView(
                    onTap: {
                        selectedStage = nil
                        avatarFacingRight.toggle()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showFreePracticeBubble.toggle()
                        }
                        withAnimation(.easeInOut(duration: 0.4)) {
                            avatarPosition = Stage.freePracticePosition
                        }
                    },
                    bobOffset: boatBob,
                    swayOffset: boatSway
                )
                .position(
                    x: Stage.freePracticePosition.x * geometry.size.width,
                    y: Stage.freePracticePosition.y * geometry.size.height
                )

                // Player avatar
                let isAtBoat = avatarPosition == Stage.freePracticePosition
                let avatarX = avatarPosition.x * geometry.size.width + (isAtBoat ? -20 : 30)
                let avatarY = avatarPosition.y * geometry.size.height + (isAtBoat ? -30 : 0)
                let bubbleX = min(max(avatarX, 100), geometry.size.width - 100)

                AvatarView()
                    .scaleEffect(x: avatarFacingRight ? 1 : -1, y: 1)
                    .animation(.easeInOut(duration: 0.15), value: avatarFacingRight)
                    .offset(x: isAtBoat ? boatSway : 0, y: isAtBoat ? boatBob : 0)
                    .position(x: avatarX, y: avatarY)
                    .zIndex(5)

                // Speech bubble for selected stage (bottom-aligned above avatar)
                if let stage = selectedStage {
                    let swings = stageSwings[stage.id] ?? 0
                    let unlocked = authViewModel.isGuest || stage.isUnlocked(stageSwings: stageSwings)
                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(alignment: .bottom) {
                            StageBubbleView(
                                stage: stage,
                                swings: swings,
                                isUnlocked: unlocked,
                                onHajime: {
                                    selectedStage = nil
                                    startStageSession(stage)
                                }
                            )
                            .fixedSize()
                        }
                        .position(x: bubbleX, y: avatarY - 36)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .zIndex(10)
                }

                // Free practice speech bubble (bottom-aligned above avatar)
                if showFreePracticeBubble {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(alignment: .bottom) {
                            FreePracticeBubbleView(onHajime: {
                                showFreePracticeBubble = false
                                showFreePracticeSheet = true
                            })
                            .fixedSize()
                        }
                        .position(x: bubbleX, y: avatarY - 36)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .zIndex(10)
                }


                VStack(spacing: 0) {
                    // Top bar: user info + sign out
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let user = authViewModel.currentUser {
                                Text("Welcome, \(user.displayName)")
                                    .font(.pixelifySmall)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)

                                if !authViewModel.isGuest {
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
                        }

                        Spacer()

                        if authViewModel.isGuest {
                            Button("EXIT") {
                                authViewModel.exitGuestMode()
                            }
                            .font(.pixelify(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                        } else {
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 8)
                    .background(Color.black.opacity(0.3))

                    Spacer()

                    // Last session report button (lower-left)
                    if !authViewModel.isGuest, lastSessionReport != nil {
                        HStack {
                            Button(action: {
                                showLastSessionReport = true
                            }) {
                                Image(systemName: "scroll.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.yellow)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    // Navigation Bar
                    HStack(spacing: 0) {
                        // Home Button (current page)
                        Button(action: {}) {
                            VStack(spacing: 6) {
                                Image("dojoIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                Text("HOME")
                                    .font(.pixelify(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }

                        if !authViewModel.isGuest {
                            // Insights Button
                            Button(action: {
                                showInsights = true
                            }) {
                                VStack(spacing: 6) {
                                    Image("insights")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                    Text("INSIGHTS")
                                        .font(.pixelify(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }

                            // Leaderboard Button
                            Button(action: {
                                showLeaderboard = true
                            }) {
                                VStack(spacing: 6) {
                                    Image("badgeLeague")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                    Text("RANKS")
                                        .font(.pixelify(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }

                            // Nakama Button
                            Button(action: {
                                showNakama = true
                            }) {
                                VStack(spacing: 6) {
                                    Image("nakamaIcon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                    Text("NAKAMA")
                                        .font(.pixelify(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }

                            // Profile Button
                            Button(action: {
                                showProfile = true
                            }) {
                                VStack(spacing: 6) {
                                    Image("Profile_men")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                    Text("PROFILE")
                                        .font(.pixelify(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
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
            loadData()
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                boatBob = -3
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                boatSway = 4
            }
        }
        .fullScreenCover(isPresented: $showActionView, onDismiss: {
            if let userId = authViewModel.currentUser?.id {
                // Track stage progress
                if let stageId = gameViewModel.currentStageId,
                   let session = gameViewModel.currentSession,
                   session.swingCount > 0 {
                    LocalStorageService.shared.addSwingsToStage(stageId, swings: session.swingCount, for: userId)
                }
                // Reload data
                stageSwings = LocalStorageService.shared.getStageSwings(for: userId)
                lastSessionReport = LocalStorageService.shared.getLastSessionReport(for: userId)
                // Move avatar to current stage after progress update
                if let current = self.currentStage {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        avatarPosition = current.mapPosition
                    }
                }
            }
        }) {
            ActionView(gameViewModel: gameViewModel)
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showFreePracticeSheet) {
            FreePracticeSheet(
                gameViewModel: gameViewModel,
                onStart: {
                    startFreePracticeSession()
                }
            )
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $showInsights) {
            InsightsView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showNakama) {
            NakamaView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showLastSessionReport) {
            if let report = lastSessionReport {
                SavedReportView(report: report)
            }
        }
    }

    /// The first incomplete unlocked stage (or last stage if all completed)
    private var currentStage: Stage? {
        Stage.allStages.first { stage in
            let unlocked = authViewModel.isGuest || stage.isUnlocked(stageSwings: stageSwings)
            let swings = stageSwings[stage.id] ?? 0
            return unlocked && !stage.isCompleted(swings: swings)
        } ?? Stage.allStages.last
    }

    // MARK: - Actions

    private func loadData() {
        if let userId = authViewModel.currentUser?.id {
            if !authViewModel.isGuest {
                logSessionStart(userId: userId)
                lastSessionReport = LocalStorageService.shared.getLastSessionReport(for: userId)
            }
            stageSwings = LocalStorageService.shared.getStageSwings(for: userId)
        }
        if let current = currentStage {
            avatarPosition = current.mapPosition
        }
    }

    private func startStageSession(_ stage: Stage) {
        guard let userId = authViewModel.currentUser?.id else { return }
        gameViewModel.configureForStage(stage)
        gameViewModel.startSession(userId: userId)
        showActionView = true
    }

    private func startFreePracticeSession() {
        guard let userId = authViewModel.currentUser?.id else { return }
        gameViewModel.startSession(userId: userId)
        showActionView = true
    }

    private func logSessionStart(userId: String) {
        Task {
            do {
                try await APIService.shared.logSessionStart(userId: userId)
            } catch {
                print("Failed to log session start: \(error.localizedDescription)")
            }
        }
    }
}

struct FreePracticeBubbleView: View {
    let onHajime: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("FREE PRACTICE")
                    .font(.pixelify(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Set your own pace.\nSwings don't count toward stages.")
                    .font(.pixelify(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onHajime) {
                    Text("HAJIME!")
                        .font(.pixelify(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 160)
            .background(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white, lineWidth: 2)
            )

            // Speech bubble tail
            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 8)
        }
        .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
