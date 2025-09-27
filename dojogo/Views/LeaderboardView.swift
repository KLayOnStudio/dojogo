import SwiftUI

struct LeaderboardUser: Identifiable {
    let id = UUID()
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
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("← BACK")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("LEADERBOARD")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding()

                // Toggle Buttons
                HStack(spacing: 0) {
                    ForEach(LeaderboardType.allCases, id: \.self) { type in
                        Button(action: {
                            leaderboardType = type
                        }) {
                            Text(type.title)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(leaderboardType == type ? .black : .white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(leaderboardType == type ? Color.yellow : Color.gray.opacity(0.3))
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white, lineWidth: 2)
                )
                .padding(.horizontal)

                // Leaderboard List
                if isLoading {
                    Spacer()
                    Text("LOADING...")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(currentLeaderboard) { user in
                                LeaderboardRow(user: user, type: leaderboardType)
                            }
                        }
                        .padding()
                    }
                }

                Spacer()
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
        Task {
            do {
                let leaderboardData = try await APIService.shared.getLeaderboard()

                await MainActor.run {
                    self.totalTapsLeaderboard = leaderboardData.totalTaps.map { entry in
                        LeaderboardUser(name: entry.name, value: entry.value, rank: entry.rank)
                    }
                    self.streakLeaderboard = leaderboardData.streaks.map { entry in
                        LeaderboardUser(name: entry.name, value: entry.value, rank: entry.rank)
                    }
                    self.isLoading = false
                }
            } catch {
                print("Failed to fetch leaderboard: \(error)")

                // Fallback to mock data
                await MainActor.run {
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
            return LeaderboardUser(name: name, value: value, rank: index + 1)
        }
    }
}

struct LeaderboardRow: View {
    let user: LeaderboardUser
    let type: LeaderboardView.LeaderboardType

    var body: some View {
        HStack {
            // Rank
            Text("#\(user.rank)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .frame(width: 40, alignment: .leading)

            // Name
            Text(user.name)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            // Value
            Text("\(user.value)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.green)

            // Unit
            Text(type == .totalTaps ? "TAPS" : "DAYS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}