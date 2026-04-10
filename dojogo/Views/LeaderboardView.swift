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
    @State private var leaderboardType: LeaderboardType = .totalSwings
    @State private var leaderboardScope: LeaderboardScope = .global
    @State private var entries: [LeaderboardV2Entry] = []
    @State private var myEntry: LeaderboardV2Entry?
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum LeaderboardType: CaseIterable {
        case totalSwings, streaks

        var title: String {
            switch self {
            case .totalSwings: return "TOTAL SWINGS"
            case .streaks: return "STREAKS"
            }
        }

        var metric: String {
            switch self {
            case .totalSwings: return "swings"
            case .streaks: return "streak"
            }
        }
    }

    enum LeaderboardScope: CaseIterable {
        case global, friends

        var title: String {
            switch self {
            case .global: return "ALL"
            case .friends: return "NAKAMA"
            }
        }

        var scope: String {
            switch self {
            case .global: return "global"
            case .friends: return "friends"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))
                    .padding(.bottom, 16)

                    // Scope Toggle (ALL / NAKAMA)
                    HStack(spacing: 0) {
                        ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    leaderboardScope = scope
                                }
                            }) {
                                Text(scope.title)
                                    .font(.pixelifyBody)
                                    .foregroundColor(leaderboardScope == scope ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(leaderboardScope == scope ? Color.cyan : Color.gray.opacity(0.3))
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // Type Toggle (TOTAL SWINGS / STREAKS)
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
                    } else if let error = errorMessage {
                        Spacer()
                        Text(error)
                            .font(.pixelifySmall)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    } else if entries.isEmpty {
                        Spacer()
                        Text("NO DATA")
                            .font(.pixelifyButton)
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    LeaderboardRow(
                                        user: LeaderboardUser(
                                            userId: entry.userId,
                                            name: entry.displayName,
                                            value: entry.score,
                                            rank: entry.rank
                                        ),
                                        type: leaderboardType,
                                        isCurrentUser: entry.userId == authViewModel.currentUser?.id
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        }

                        Spacer()

                        // Sticky MY RANK footer
                        if let me = myEntry {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)

                                HStack {
                                    Text("MY RANK")
                                        .font(.pixelify(size: 10, weight: .bold))
                                        .foregroundColor(.cyan)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                                LeaderboardRow(
                                    user: LeaderboardUser(
                                        userId: me.userId,
                                        name: me.displayName,
                                        value: me.score,
                                        rank: me.rank
                                    ),
                                    type: leaderboardType,
                                    isCurrentUser: true
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchLeaderboardData()
        }
        .onChange(of: leaderboardType) { _ in fetchLeaderboardData() }
        .onChange(of: leaderboardScope) { _ in fetchLeaderboardData() }
    }

    private func fetchLeaderboardData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response = try await APIService.shared.getLeaderboardV2(
                    metric: leaderboardType.metric,
                    scope: leaderboardScope.scope
                )

                await MainActor.run {
                    entries = response.entries
                    myEntry = response.me
                    isLoading = false
                }
            } catch {
                print("Failed to fetch leaderboard: \(error)")
                await MainActor.run {
                    entries = []
                    myEntry = nil
                    errorMessage = "Failed to load: \(error.localizedDescription)"
                    isLoading = false
                }
            }
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

                Text(type == .totalSwings ? "SWINGS" : "DAYS")
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
