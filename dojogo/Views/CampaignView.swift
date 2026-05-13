import SwiftUI

struct CampaignView: View {
    @Environment(\.dismiss) var dismiss

    @State private var leaderboardData: CampaignLeaderboardResponse? = nil
    @State private var isLoading = true
    @State private var isJoining = false
    @State private var showRules = false
    @State private var pendingRequestIds: Set<String> = []   // optimistic UI

    // Sprite animation
    @State private var frameIndex = 0
    private let frames = (1...5).map { "SkuraCampaign400_\($0)" }
    private let animTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    private var campaign: Campaign? { leaderboardData?.campaign }
    private var isParticipant: Bool { leaderboardData?.isParticipant ?? false }
    private var entries: [CampaignLeaderboardEntry] { leaderboardData?.entries ?? [] }
    private var participantCount: Int { leaderboardData?.participantCount ?? 0 }

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }

    private var campaignStarted: Bool {
        guard let c = campaign else { return false }
        return today >= cal.startOfDay(for: c.startDate)
    }

    private var status: CampaignStatus {
        guard let c = campaign else { return .upcoming }
        let startDay = cal.startOfDay(for: c.startDate)
        let endDay = cal.startOfDay(for: c.endDate)
        if today < startDay { return .upcoming }
        if today > endDay { return .ended }
        return .active
    }

    private var daysUntilStart: Int {
        guard let c = campaign else { return 0 }
        let startDay = cal.startOfDay(for: c.startDate)
        return max(cal.dateComponents([.day], from: today, to: startDay).day ?? 0, 0)
    }

    private var daysRemaining: Int {
        guard let c = campaign else { return 0 }
        let endDay = cal.startOfDay(for: c.endDate)
        return max(cal.dateComponents([.day], from: today, to: endDay).day ?? 0, 0)
    }

    private var campaignDateRangeLabel: String {
        guard let c = campaign else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let start = fmt.string(from: c.startDate).uppercased()
        fmt.dateFormat = "MMM d, yyyy"
        let end = fmt.string(from: c.endDate).uppercased()
        return "\(start) – \(end)"
    }

    private var campaignStartLabel: String {
        guard let c = campaign else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: c.startDate)
    }

    enum CampaignStatus {
        case upcoming, active, ended
        var label: String {
            switch self {
            case .upcoming: return "UPCOMING"
            case .active: return "ACTIVE"
            case .ended: return "ENDED"
            }
        }
        var color: Color {
            switch self {
            case .upcoming: return .cyan
            case .active: return .green
            case .ended: return .gray
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("← BACK")
                            .font(.pixelifyButton)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("CAMPAIGN")
                        .font(.pixelifyHeadline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { showRules = true }) {
                        Text("RULES")
                            .font(.pixelify(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            heroSection

                            if status != .ended {
                                joinSection
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                            }

                            Divider()
                                .background(Color.white.opacity(0.15))
                                .padding(.horizontal, 20)

                            leaderboardSection
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .task {
            await loadLeaderboard()
        }
        .sheet(isPresented: $showRules) {
            CampaignRulesSheet(campaign: campaign)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image(frames[frameIndex])
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .onReceive(animTimer) { _ in
                    frameIndex = (frameIndex + 1) % frames.count
                }

            Text(status.label)
                .font(.pixelify(size: 10, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(status.color)

            Text(campaign?.name ?? "Campaign")
                .font(.pixelifyTitle)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(campaignDateRangeLabel)
                .font(.pixelifySmall)
                .foregroundColor(.gray)

            switch status {
            case .upcoming:
                Text("D-\(daysUntilStart) — Starts in \(daysUntilStart) day\(daysUntilStart == 1 ? "" : "s")")
                    .font(.pixelifyBody)
                    .foregroundColor(.cyan)
            case .active:
                Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining")
                    .font(.pixelifyBody)
                    .foregroundColor(.green)
            case .ended:
                Text("Challenge complete")
                    .font(.pixelifyBody)
                    .foregroundColor(.gray)
            }

            if participantCount > 0 {
                Text("\(participantCount) kenshi\(participantCount == 1 ? "" : "s") enrolled")
                    .font(.pixelify(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Join Section

    private var joinSection: some View {
        Group {
            if isParticipant {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("YOU'RE IN!")
                        .font(.pixelifyBodyBold)
                }
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green, lineWidth: 2)
                )
            } else {
                Button(action: { Task { await joinCampaign() } }) {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(status == .active ? Color.green : Color.cyan)
                    } else {
                        Text("SIGN UP")
                            .font(.pixelifyBodyBold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(status == .active ? Color.green : Color.cyan)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .disabled(isJoining)
            }
        }
    }

    // MARK: - Leaderboard Section

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text(campaignStarted ? "LEADERBOARD" : "PARTICIPANTS")
                    .font(.pixelify(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                if !campaignStarted {
                    Text("Rankings open on \(campaignStartLabel)")
                        .font(.pixelify(size: 9))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            if campaignStarted {
                // Column headers
                HStack(spacing: 0) {
                    Text("#")
                        .frame(width: 32, alignment: .center)
                    Text("NAME")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("SWINGS")
                        .frame(width: 58, alignment: .trailing)
                    Text("STREAK")
                        .frame(width: 52, alignment: .trailing)
                    Text("SCORE")
                        .frame(width: 58, alignment: .trailing)
                }
                .font(.pixelify(size: 9, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
            }

            if entries.isEmpty {
                Text(campaignStarted ? "No participants yet." : "No one has signed up yet. Be the first!")
                    .font(.pixelify(size: 10))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if campaignStarted {
                ForEach(entries) { entry in
                    activeLeaderboardRow(entry: entry)
                }
            } else {
                ForEach(entries) { entry in
                    participantRow(entry: entry)
                }
            }
        }
    }

    // MARK: - Active leaderboard row (with scores)

    private func activeLeaderboardRow(entry: CampaignLeaderboardEntry) -> some View {
        HStack(spacing: 0) {
            Text("#\(entry.rank ?? 0)")
                .font(.pixelifyBodyBold)
                .foregroundColor(rankColor(entry.rank ?? 0))
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.pixelifyBody)
                    .foregroundColor(entry.isMe ? .yellow : .white)
                    .lineLimit(1)
                if entry.isMe {
                    Text("YOU")
                        .font(.pixelify(size: 7, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(entry.totalSwings)")
                .font(.pixelifySmall)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 58, alignment: .trailing)

            Text("\(entry.maxStreak)d")
                .font(.pixelifySmall)
                .foregroundColor(.orange.opacity(0.9))
                .frame(width: 52, alignment: .trailing)

            Text("\(entry.score)")
                .font(.pixelify(size: 11, weight: .bold))
                .foregroundColor(entry.isMe ? .yellow : .green)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(entry.isMe ? Color.yellow.opacity(0.06) : Color.white.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Pre-start participant row (no scores, nakama button)

    private func participantRow(entry: CampaignLeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.pixelifyBody)
                    .foregroundColor(entry.isMe ? .yellow : .white)
                    .lineLimit(1)
                if entry.isMe {
                    Text("YOU")
                        .font(.pixelify(size: 7, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.isMe {
                nakamaButton(entry: entry)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(entry.isMe ? Color.yellow.opacity(0.06) : Color.white.opacity(0.02))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func nakamaButton(entry: CampaignLeaderboardEntry) -> some View {
        let alreadySent = pendingRequestIds.contains(entry.userId)
        if entry.isFriend {
            Text("NAKAMA")
                .font(.pixelify(size: 9, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
        } else if entry.isPending || alreadySent {
            Text("PENDING")
                .font(.pixelify(size: 9, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
        } else {
            Button(action: { Task { await sendNakamaRequest(to: entry.userId) } }) {
                Text("+ NAKAMA")
                    .font(.pixelify(size: 9, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                    )
            }
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .white.opacity(0.5)
        }
    }

    // MARK: - Actions

    private func loadLeaderboard() async {
        do {
            let data = try await APIService.shared.getCampaignLeaderboard()
            await MainActor.run { leaderboardData = data }
        } catch {
            print("Failed to load campaign leaderboard: \(error)")
        }
        await MainActor.run { isLoading = false }
    }

    private func joinCampaign() async {
        guard let campaignId = campaign?.id else { return }
        await MainActor.run { isJoining = true }
        do {
            try await APIService.shared.joinCampaign(campaignId: campaignId)
            await loadLeaderboard()
        } catch {
            print("Failed to join campaign: \(error)")
        }
        await MainActor.run { isJoining = false }
    }

    private func sendNakamaRequest(to userId: String) async {
        await MainActor.run { pendingRequestIds.insert(userId) }
        do {
            _ = try await APIService.shared.createFriendRequest(toUserId: userId)
        } catch {
            await MainActor.run { pendingRequestIds.remove(userId) }
            print("Failed to send nakama request: \(error)")
        }
    }
}

// MARK: - Rules Sheet

private struct CampaignRulesSheet: View {
    let campaign: Campaign?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("CLOSE")
                            .font(.pixelifyButton)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Description
                        VStack(alignment: .leading, spacing: 10) {
                            Text("FROM THE CREATOR")
                                .font(.pixelify(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                            Text(campaign?.description ?? "")
                                .font(.pixelifyBody)
                                .foregroundColor(.white)
                                .lineSpacing(4)
                        }

                        Divider().background(Color.white.opacity(0.15))

                        // Rules
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RULES & SCORING")
                                .font(.pixelify(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                            Text(campaign?.rules ?? "")
                                .font(.pixelifyBody)
                                .foregroundColor(.white)
                                .lineSpacing(4)

                            HStack(spacing: 8) {
                                FormulaBox(label: "SWINGS", color: .green)
                                Text("+")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)
                                FormulaBox(label: "MAX STREAK × 50", color: .orange)
                                Text("= SCORE")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)

                            Text("e.g. 768 swings + (7-day streak × 50) = 1,118 pts")
                                .font(.pixelify(size: 10))
                                .foregroundColor(.gray)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }

                        Divider().background(Color.white.opacity(0.15))

                        // Prize
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PRIZE")
                                .font(.pixelify(size: 10, weight: .bold))
                                .foregroundColor(.gray)

                            if let imageUrlString = campaign?.prizeImageUrl,
                               let imageUrl = URL(string: imageUrlString) {
                                AsyncImage(url: imageUrl) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color.white.opacity(0.05))
                                            .frame(maxWidth: .infinity, minHeight: 100)
                                            .overlay(
                                                Text("Prize image unavailable")
                                                    .font(.pixelifySmall)
                                                    .foregroundColor(.gray)
                                            )
                                    default:
                                        Rectangle()
                                            .fill(Color.white.opacity(0.05))
                                            .frame(maxWidth: .infinity, minHeight: 100)
                                            .overlay(ProgressView().tint(.gray))
                                    }
                                }
                            }

                            Text(campaign?.prize ?? "")
                                .font(.pixelifyBody)
                                .foregroundColor(.yellow)
                                .lineSpacing(4)

                            if let urlString = campaign?.prizeUrl, let url = URL(string: urlString) {
                                Link(destination: url) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 12))
                                        Text("Check out Kikentai")
                                            .font(.pixelifySmall)
                                    }
                                    .foregroundColor(.cyan)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

private struct FormulaBox: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.pixelify(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(color.opacity(0.5), lineWidth: 1))
    }
}

typealias CampaignPlaceholderView = CampaignView
