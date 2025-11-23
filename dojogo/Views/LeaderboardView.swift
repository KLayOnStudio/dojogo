import SwiftUI

struct LeaderboardUser: Identifiable {
    let id = UUID()
    let userId: String
    let name: String
    let value: Int
    let rank: Int
}

struct LeaderboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var leaderboardType: LeaderboardType = .totalTaps
    @State private var totalTapsLeaderboard: [LeaderboardUser] = []
    @State private var streakLeaderboard: [LeaderboardUser] = []
    @State private var isLoading = true

    enum LeaderboardType: CaseIterable {
        case totalTaps, streaks

        var title: String {
            switch self {
            case .totalTaps: return "TOTAL TAPS"
            case .streaks: return "STREAKS"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("← BACK")
                                .font(.pixelifyButton)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text("LEADERBOARD")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 2)

                        Spacer()
                            .frame(width: 80) // Balance the back button width
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    // Toggle Buttons
                    HStack(spacing: 0) {
                        ForEach(LeaderboardType.allCases, id: \.self) { type in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    leaderboardType = type
                                }
                            }) {
                                Text(type.title)
                                    .font(.pixelifyBody)
                                    .foregroundColor(leaderboardType == type ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(leaderboardType == type ? Color.yellow : Color.gray.opacity(0.3))
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Leaderboard List
                    if isLoading {
                        Spacer()
                        Text("LOADING...")
                            .font(.pixelifyButton)
                            .foregroundColor(.white)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(currentLeaderboard) { user in
                                    LeaderboardRow(
                                        user: user,
                                        type: leaderboardType,
                                        isCurrentUser: user.userId == authViewModel.currentUser?.id
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchLeaderboardData()
        }
    }

    private var currentLeaderboard: [LeaderboardUser] {
        switch leaderboardType {
        case .totalTaps: return totalTapsLeaderboard
        case .streaks: return streakLeaderboard
        }
    }

    private func fetchLeaderboardData() {
        print("Fetching leaderboard data...")
        Task {
            do {
                print("Calling APIService.getLeaderboard()...")
                let leaderboardData = try await APIService.shared.getLeaderboard()
                print("Successfully fetched leaderboard data")

                await MainActor.run {
                    self.totalTapsLeaderboard = leaderboardData.totalTaps.map { entry in
                        LeaderboardUser(userId: entry.userId, name: entry.displayName, value: entry.value, rank: entry.rank)
                    }
                    self.streakLeaderboard = leaderboardData.streaks.map { entry in
                        LeaderboardUser(userId: entry.userId, name: entry.displayName, value: entry.value, rank: entry.rank)
                    }
                    self.isLoading = false
                    print("Updated leaderboard UI - Total: \(self.totalTapsLeaderboard.count), Streaks: \(self.streakLeaderboard.count)")
                }
            } catch {
                print("Failed to fetch leaderboard: \(error)")

                // Fallback to mock data
                await MainActor.run {
                    print("Using mock leaderboard data")
                    self.totalTapsLeaderboard = generateMockLeaderboard(type: .totalTaps)
                    self.streakLeaderboard = generateMockLeaderboard(type: .streaks)
                    self.isLoading = false
                }
            }
        }
    }

    private func generateMockLeaderboard(type: LeaderboardType) -> [LeaderboardUser] {
        let names = ["Player1", "Player2", "Player3", "Player4", "Player5"]
        return names.enumerated().map { index, name in
            let value = type == .totalTaps
                ? Int.random(in: 100...1000)
                : Int.random(in: 1...30)
            return LeaderboardUser(userId: "mock_\(index)", name: name, value: value, rank: index + 1)
        }
    }
}

struct LeaderboardRow: View {
    let user: LeaderboardUser
    let type: LeaderboardView.LeaderboardType
    let isCurrentUser: Bool

    private var rankColor: Color {
        switch user.rank {
        case 1: return Color.yellow
        case 2: return Color.gray.opacity(0.8)
        case 3: return Color.orange.opacity(0.7)
        default: return Color.white
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(rankColor, lineWidth: 2)
                    )

                Text("\(user.rank)")
                    .font(.pixelifyBodyBold)
                    .foregroundColor(rankColor)
            }

            // Name
            HStack(spacing: 6) {
                Text(user.name)
                    .font(.pixelifyBody)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if isCurrentUser {
                    Text("(YOU)")
                        .font(.pixelify(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }

            Spacer()

            // Value
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.value)")
                    .font(.pixelifyButton)
                    .foregroundColor(.green)

                Text(type == .totalTaps ? "TAPS" : "DAYS")
                    .font(.pixelify(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrentUser ? Color.cyan.opacity(0.2) : Color.gray.opacity(user.rank <= 3 ? 0.25 : 0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isCurrentUser ? Color.cyan : (user.rank <= 3 ? rankColor.opacity(0.5) : Color.white.opacity(0.2)), lineWidth: isCurrentUser ? 3 : (user.rank <= 3 ? 2 : 1))
        )
        .shadow(color: isCurrentUser ? Color.cyan.opacity(0.5) : .black.opacity(0.3), radius: isCurrentUser ? 6 : (user.rank <= 3 ? 4 : 2), x: 0, y: 2)
    }
}