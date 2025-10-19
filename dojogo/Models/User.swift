import Foundation

enum KendoRank: String, Codable, CaseIterable {
    case unranked = "unranked"
    case kyu9 = "9kyu"
    case kyu8 = "8kyu"
    case kyu7 = "7kyu"
    case kyu6 = "6kyu"
    case kyu5 = "5kyu"
    case kyu4 = "4kyu"
    case kyu3 = "3kyu"
    case kyu2 = "2kyu"
    case kyu1 = "1kyu"
    case dan1 = "1dan"
    case dan2 = "2dan"
    case dan3 = "3dan"
    case dan4 = "4dan"
    case dan5 = "5dan"
    case dan6 = "6dan"
    case dan7 = "7dan"
    case dan8 = "8dan"

    var displayName: String {
        switch self {
        case .unranked: return "Unranked"
        case .kyu9: return "9 Kyu"
        case .kyu8: return "8 Kyu"
        case .kyu7: return "7 Kyu"
        case .kyu6: return "6 Kyu"
        case .kyu5: return "5 Kyu"
        case .kyu4: return "4 Kyu"
        case .kyu3: return "3 Kyu"
        case .kyu2: return "2 Kyu"
        case .kyu1: return "1 Kyu"
        case .dan1: return "1 Dan"
        case .dan2: return "2 Dan"
        case .dan3: return "3 Dan"
        case .dan4: return "4 Dan"
        case .dan5: return "5 Dan"
        case .dan6: return "6 Dan"
        case .dan7: return "7 Dan"
        case .dan8: return "8 Dan"
        }
    }
}

struct User: Codable, Identifiable {
    let id: String // Auth0 ID
    var userNumber: Int? // Sequential user number
    let name: String // Auth0 name
    var nickname: String? // User-chosen display name
    var nicknameLastChanged: Date? // Last nickname change
    var kendoRank: KendoRank? // Kendo rank
    var kendoExperienceYears: Int = 0 // Years of practice
    var kendoExperienceMonths: Int = 0 // Additional months (0-11)
    let email: String
    var streak: Int
    var totalCount: Int
    var createdAt: Date
    var lastSessionDate: Date?

    // Custom decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userNumber = try container.decodeIfPresent(Int.self, forKey: .userNumber)
        name = try container.decode(String.self, forKey: .name)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        nicknameLastChanged = try container.decodeIfPresent(Date.self, forKey: .nicknameLastChanged)
        kendoRank = try container.decodeIfPresent(KendoRank.self, forKey: .kendoRank)
        kendoExperienceYears = try container.decodeIfPresent(Int.self, forKey: .kendoExperienceYears) ?? 0
        kendoExperienceMonths = try container.decodeIfPresent(Int.self, forKey: .kendoExperienceMonths) ?? 0
        email = try container.decode(String.self, forKey: .email)
        streak = try container.decode(Int.self, forKey: .streak)
        totalCount = try container.decode(Int.self, forKey: .totalCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastSessionDate = try container.decodeIfPresent(Date.self, forKey: .lastSessionDate)
    }

    // Display name for UI (nickname if set, otherwise name)
    var displayName: String {
        return nickname ?? name
    }

    // Can user change nickname? (30 day cooldown)
    var canChangeNickname: Bool {
        guard let lastChanged = nicknameLastChanged else {
            return true // Never changed before
        }
        let daysSinceChange = Calendar.current.dateComponents([.day], from: lastChanged, to: Date()).day ?? 0
        return daysSinceChange >= 30
    }

    // Formatted experience string
    var experienceString: String {
        if kendoExperienceYears == 0 && kendoExperienceMonths == 0 {
            return "Not specified"
        }
        var parts: [String] = []
        if kendoExperienceYears > 0 {
            parts.append("\(kendoExperienceYears) year\(kendoExperienceYears == 1 ? "" : "s")")
        }
        if kendoExperienceMonths > 0 {
            parts.append("\(kendoExperienceMonths) month\(kendoExperienceMonths == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

    init(id: String, name: String, email: String) {
        self.id = id
        self.userNumber = nil
        self.name = name
        self.nickname = nil
        self.nicknameLastChanged = nil
        self.kendoRank = nil
        self.kendoExperienceYears = 0
        self.kendoExperienceMonths = 0
        self.email = email
        self.streak = 0
        self.totalCount = 0
        self.createdAt = Date()
        self.lastSessionDate = nil
    }
}