import Foundation

struct UserSummary: Codable, Identifiable {
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let kendoRank: String?

    var id: String { userId }

    var displayName: String {
        nickname ?? "Player #\(userNumber ?? 0)"
    }
}

struct FriendInfo: Codable, Identifiable {
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let kendoRank: String?
    let streak: Int
    let totalCount: Int
    let lastSessionDate: Int?

    var id: String { userId }

    var displayName: String {
        nickname ?? "Player #\(userNumber ?? 0)"
    }

    var lastActiveDate: Date? {
        guard let ts = lastSessionDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }
}

struct FriendRequest: Codable, Identifiable {
    let requestId: Int
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let kendoRank: String?
    let createdAt: Int?

    var id: Int { requestId }

    var displayName: String {
        nickname ?? "Player #\(userNumber ?? 0)"
    }
}

struct FriendInsights: Codable {
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let kendoRank: String?
    let kendoExperienceYears: Int?
    let kendoExperienceMonths: Int?
    let homeDojo: String?
    let streak: Int
    let totalCount: Int
    let lastSessionDate: Int?
    let swingRank: Int
    let streakRank: Int

    var displayName: String {
        nickname ?? "Player #\(userNumber ?? 0)"
    }

    var lastActiveDate: Date? {
        guard let ts = lastSessionDate else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }

    var experienceString: String {
        let years = kendoExperienceYears ?? 0
        let months = kendoExperienceMonths ?? 0
        if years == 0 && months == 0 { return "Not specified" }
        var parts: [String] = []
        if years > 0 { parts.append("\(years) year\(years == 1 ? "" : "s")") }
        if months > 0 { parts.append("\(months) month\(months == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }
}

struct LeaderboardV2Entry: Codable, Identifiable {
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let score: Int
    let rank: Int
    let isFriend: Bool
    let isPending: Bool

    var id: String { "\(userId)-\(rank)" }

    var displayName: String {
        nickname ?? "Player #\(userNumber ?? 0)"
    }
}

struct LeaderboardV2Response: Codable {
    let metric: String
    let scope: String
    let top: [LeaderboardV2Entry]
    let me: LeaderboardV2Entry?
    let aroundMe: [LeaderboardV2Entry]?

    var entries: [LeaderboardV2Entry] { top }
}
