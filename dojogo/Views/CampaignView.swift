import SwiftUI

struct CampaignView: View {
    @Environment(\.dismiss) var dismiss

    // Debug flags — set both to false before shipping
    private let debugForceActive = false
    private let campaignEnabled = false  // flip to true when API is ready
    @State private var hasJoined = false

    private let campaignName = "Sugiyama Suburi Challenge"
    private let description = "Hey Miyoga kenshis! You know I've been building this app for a year now — it's finally time to put it out there. I'd love for you to be part of this from the beginning. Every suburi you log helps me move forward, and I genuinely believe we can build something that changes how our whole community practices kendo. Let's do this together."
    private let rules = "Score = Total Swings + (Max Streak × 50). Swings and streak are counted only within the campaign window."
    private let prize = "Kikentai Merch — design in progress, stay tuned!"
    private let prizeURL = URL(string: "https://klayonstudio.com/kikentailookbook.html")!
    private let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 4))!
    private let endDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 17))!

    private var status: CampaignStatus {
        if debugForceActive { return .active }
        let now = Date()
        if now < startDate { return .upcoming }
        if now > endDate { return .ended }
        return .active
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

    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }

    private var daysUntilStart: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
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
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Icon + Status
                    VStack(spacing: 12) {
                        Image("toriiGate")
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)

                        // Status badge
                        Text(status.label)
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(status.color)

                        Text(campaignName)
                            .font(.pixelifyTitle)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        // Date range
                        Text("MAY 4 – MAY 17, 2026")
                            .font(.pixelifySmall)
                            .foregroundColor(.gray)

                        // Countdown
                        switch status {
                        case .upcoming:
                            Text("Starts in \(daysUntilStart) days")
                                .font(.pixelifyBody)
                                .foregroundColor(.cyan)
                        case .active:
                            Text("\(daysRemaining) days remaining")
                                .font(.pixelifyBody)
                                .foregroundColor(.green)
                        case .ended:
                            Text("Challenge complete")
                                .font(.pixelifyBody)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 28)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FROM THE CREATOR")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.gray)

                        Text(description)
                            .font(.pixelifyBody)
                            .foregroundColor(.white)
                            .lineSpacing(4)
                    }
                    .padding(20)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Rules
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RULES")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.gray)

                        Text(rules)
                            .font(.pixelifyBody)
                            .foregroundColor(.white)
                            .lineSpacing(4)

                        // Score formula breakdown
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

                        // Example
                        Text("e.g. 768 swings + (7 day streak × 50) = 1,118 pts")
                            .font(.pixelify(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(20)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Prize
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PRIZE")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.gray)

                        Text(prize)
                            .font(.pixelifyBody)
                            .foregroundColor(.yellow)

                        // Kikentai brand link
                        Link(destination: prizeURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 12))
                                Text("Check out Kikentai")
                                    .font(.pixelifySmall)
                            }
                            .foregroundColor(.cyan)
                        }

                        // Prize image placeholder
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.gray.opacity(0.15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Text("PRIZE IMAGE\nCOMING SOON")
                                    .font(.pixelify(size: 10))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            )
                    }
                    .padding(20)

                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 20)

                    // Enter / Leaderboard section
                    VStack(spacing: 16) {
                        if campaignEnabled && (status == .active || status == .upcoming) {
                            if hasJoined {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("YOU'RE IN!")
                                        .font(.pixelifyBodyBold)
                                }
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.green, lineWidth: 2)
                                )
                            } else {
                                Button(action: { hasJoined = true }) {
                                    Text(status == .active ? "JOIN THE CHALLENGE" : "SIGN UP EARLY")
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
                        }

                        if campaignEnabled && status == .active {
                            // Leaderboard placeholder
                            VStack(alignment: .leading, spacing: 12) {
                                Text("LEADERBOARD")
                                    .font(.pixelify(size: 10, weight: .bold))
                                    .foregroundColor(.gray)

                                if hasJoined {
                                    // Sample leaderboard entries when joined
                                    ForEach(Array([
                                        ("Klayon01", 1240),
                                        ("reion", 980),
                                        ("kenshi01", 720)
                                    ].enumerated()), id: \.offset) { index, entry in
                                        HStack(spacing: 12) {
                                            Text("#\(index + 1)")
                                                .font(.pixelifyBodyBold)
                                                .foregroundColor(index == 0 ? .yellow : index == 1 ? Color.gray.opacity(0.8) : .orange)
                                                .frame(width: 32)
                                            Text(entry.0)
                                                .font(.pixelifyBody)
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text("\(entry.1) pts")
                                                .font(.pixelifyButton)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                } else {
                                    ForEach(1...3, id: \.self) { rank in
                                        HStack(spacing: 12) {
                                            Text("#\(rank)")
                                                .font(.pixelifyBodyBold)
                                                .foregroundColor(rank == 1 ? .yellow : rank == 2 ? Color.gray.opacity(0.8) : .orange)
                                                .frame(width: 32)
                                            RoundedRectangle(cornerRadius: 0)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(height: 16)
                                            Text("—")
                                                .font(.pixelifyBody)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    Text("Join to see the full leaderboard")
                                        .font(.pixelifySmall)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
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
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

// Keep old name working
typealias CampaignPlaceholderView = CampaignView
