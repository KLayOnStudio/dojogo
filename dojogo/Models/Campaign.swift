import Foundation

struct Campaign: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let rules: String?
    let prize: String?
    let prizeUrl: String?
    let startDate: Date
    let endDate: Date
    let isActive: Bool
}

struct CampaignLeaderboardEntry: Codable, Identifiable {
    let rank: Int?          // nil before campaign starts
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let kendoRank: String?
    let totalSwings: Int
    let maxStreak: Int
    let score: Int
    let isMe: Bool
    let isFriend: Bool
    let isPending: Bool

    var id: String { userId }

    var displayName: String {
        if let n = nickname, !n.isEmpty { return n }
        if let num = userNumber { return "#\(num)" }
        return "???"
    }
}

struct CampaignLeaderboardResponse: Codable {
    let campaign: Campaign
    let isParticipant: Bool
    let participantCount: Int
    let entries: [CampaignLeaderboardEntry]
}
