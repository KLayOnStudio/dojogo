import Foundation

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
}

struct LeaderboardResponse: Codable {
    let totalSwings: [LeaderboardEntry]
    let streaks: [LeaderboardEntry]
}

struct LeaderboardEntry: Codable {
    let userId: String
    let userNumber: Int?
    let name: String
    let nickname: String?
    let value: Int
    let rank: Int

    // Display name (nickname if set, otherwise masked name)
    var displayName: String {
        if let nickname = nickname {
            return nickname
        }
        // Mask email addresses for privacy
        return maskEmail(name)
    }

    private func maskEmail(_ email: String) -> String {
        // Check if it's an email
        guard email.contains("@") else {
            return email // Not an email, return as-is
        }

        let components = email.components(separatedBy: "@")
        guard components.count == 2 else {
            return email
        }

        let username = components[0]
        let domain = components[1]

        // Mask username: show first 3 chars, then ***
        let visibleChars = min(3, username.count)
        let maskedUsername = username.prefix(visibleChars) + "***"

        return "\(maskedUsername)@\(domain)"
    }
}

class APIService: ObservableObject {
    static let shared = APIService()

    private let baseURL = "https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api"

    private init() {}

    // MARK: - JSON Decoder Configuration

    /// Returns a properly configured JSONDecoder for API responses
    /// Always use this instead of creating JSONDecoder() directly to ensure consistent date handling
    private func configuredDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970  // API sends Unix timestamps (seconds since 1970)
        return decoder
    }

    // MARK: - Authentication Helper

    private func addAuthHeaders(to request: inout URLRequest) async throws {
        let token = try await Auth0Manager.shared.getIdToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - User Management

    func createUser(_ user: User) async throws -> User {
        print("Creating user: \(user.name) (\(user.email))")
        let url = URL(string: "\(baseURL)/CreateUser")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await addAuthHeaders(to: &request)

        let userData = ["name": user.name, "email": user.email]
        let jsonData = try JSONSerialization.data(withJSONObject: userData)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("CreateUser: Invalid response type")
            throw APIError.serverError
        }

        print("CreateUser response - Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("CreateUser response body: \(responseString)")
        }

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct CreateUserResponse: Codable {
            let message: String
            let user: User
        }

        let apiResponse = try configuredDecoder().decode(CreateUserResponse.self, from: data)
        return apiResponse.user
    }

    func getUser(id: String) async throws -> User {
        let url = URL(string: "\(baseURL)/GetUser")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.userNotFound
        }

        if let responseString = String(data: data, encoding: .utf8) {
            print("GetUser response body: \(responseString)")
        }

        struct GetUserResponse: Codable {
            let user: UserResponse
        }

        struct UserResponse: Codable {
            let id: String
            let userNumber: Int?
            let name: String
            let nickname: String?
            let nicknameLastChanged: Int?
            let kendoRank: String?
            let kendoExperienceYears: Int?
            let kendoExperienceMonths: Int?
            let homeDojo: String?
            let avatar: String?
            let email: String
            let streak: Int
            let totalCount: Int
            let createdAt: Int?
            let lastSessionDate: Int?
            let isPublic: Bool?
        }

        let apiResponse = try configuredDecoder().decode(GetUserResponse.self, from: data)
        let userResponse = apiResponse.user

        // Convert to User model
        var user = User(id: userResponse.id, name: userResponse.name, email: userResponse.email)
        user.userNumber = userResponse.userNumber
        user.nickname = userResponse.nickname
        if let timestamp = userResponse.nicknameLastChanged {
            user.nicknameLastChanged = Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        user.kendoRank = userResponse.kendoRank != nil ? KendoRank(rawValue: userResponse.kendoRank!) : nil
        user.kendoExperienceYears = userResponse.kendoExperienceYears ?? 0
        user.kendoExperienceMonths = userResponse.kendoExperienceMonths ?? 0
        user.homeDojo = userResponse.homeDojo
        user.avatar = userResponse.avatar ?? "kendoka"
        user.streak = userResponse.streak
        user.totalCount = userResponse.totalCount
        user.createdAt = userResponse.createdAt != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.createdAt!)) : Date()
        if let lastSessionTimestamp = userResponse.lastSessionDate {
            user.lastSessionDate = Date(timeIntervalSince1970: TimeInterval(lastSessionTimestamp))
        }
        user.isPublic = userResponse.isPublic ?? true

        return user
    }

    // MARK: - Session Management

    func logSessionStart(userId: String) async throws {
        print("Logging session start for user: \(userId)")
        let url = URL(string: "\(baseURL)/LogSessionStart")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("LogSessionStart: Invalid response type")
            throw APIError.serverError
        }

        print("LogSessionStart response - Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("LogSessionStart response body: \(responseString)")
        }

        guard httpResponse.statusCode == 201 else {
            throw APIError.serverError
        }
    }

    func submitSession(_ session: Session, stats: StoredSessionStats? = nil) async throws -> (updatedUser: User, streak: Int) {
        let url = URL(string: "\(baseURL)/CreateSession")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await addAuthHeaders(to: &request)

        // Build body manually to include optional stats fields
        let localDateFormatter = DateFormatter()
        localDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDateFormatter.dateFormat = "yyyy-MM-dd"
        let localDate = localDateFormatter.string(from: session.startTime)

        let localDatetimeFormatter = DateFormatter()
        localDatetimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        localDatetimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let localDatetime = localDatetimeFormatter.string(from: session.startTime)

        var body: [String: Any] = [
            "id": session.id.uuidString,
            "swingCount": session.swingCount,
            "duration": session.duration,
            "mode": session.mode.rawValue,
            "sensorMode": session.sensorMode.rawValue,
            "localDate": localDate,
            "localDatetime": localDatetime
        ]
        if let stageId = session.stageId {
            body["stageId"] = stageId
        }
        if let deviceModel = session.deviceModel {
            body["deviceModel"] = deviceModel
        }
        if let stats = stats {
            if let v = stats.tempo { body["tempo"] = v }
            if let v = stats.avgSpeed { body["avgSpeed"] = v }
            if let v = stats.maxSpeed { body["maxSpeed"] = v }
            if let v = stats.maxPower { body["maxPower"] = v }
            if let v = stats.avgReactionMs { body["avgReactionMs"] = v }
            if let v = stats.avgStrikeTimeMs { body["avgStrikeTimeMs"] = v }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.serverError
        }

        struct SessionSubmissionResponse: Codable {
            let message: String
            let session_id: String
            let user: User
        }

        let apiResponse = try configuredDecoder().decode(SessionSubmissionResponse.self, from: data)
        return (updatedUser: apiResponse.user, streak: apiResponse.user.streak)
    }

    // MARK: - Fetch Sessions (with stats)

    func fetchSessions(userId: String) async throws -> ([Session], [UUID: StoredSessionStats]) {
        let url = URL(string: "\(baseURL)/GetSessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct ServerSession: Codable {
            let id: String
            let swingCount: Int
            let duration: Double
            let mode: String
            let createdAt: Double?
            let tempo: Double?
            let avgSpeed: Double?
            let maxSpeed: Double?
            let maxPower: Double?
            let avgReactionMs: Double?
            let avgStrikeTimeMs: Double?
            let stageId: Int?
        }

        struct SessionsResponse: Codable {
            let sessions: [ServerSession]
        }

        let apiResponse = try configuredDecoder().decode(SessionsResponse.self, from: data)
        var sessions: [Session] = []
        var statsMap: [UUID: StoredSessionStats] = [:]

        for s in apiResponse.sessions {
            guard let uuid = UUID(uuidString: s.id) else { continue }
            let sessionDate = s.createdAt.map { Date(timeIntervalSince1970: $0) } ?? Date()
            let sessionMode = SessionMode(rawValue: s.mode) ?? .guided

            let session = Session(
                id: uuid,
                userId: userId,
                date: sessionDate,
                swingCount: s.swingCount,
                duration: s.duration,
                mode: sessionMode,
                stageId: s.stageId
            )
            sessions.append(session)

            let hasStats = s.tempo != nil || s.avgSpeed != nil || s.maxSpeed != nil ||
                           s.maxPower != nil || s.avgReactionMs != nil || s.avgStrikeTimeMs != nil
            if hasStats {
                statsMap[uuid] = StoredSessionStats(
                    tempo: s.tempo,
                    avgSpeed: s.avgSpeed,
                    maxSpeed: s.maxSpeed,
                    maxPower: s.maxPower,
                    avgReactionMs: s.avgReactionMs,
                    avgStrikeTimeMs: s.avgStrikeTimeMs
                )
            }
        }

        return (sessions, statsMap)
    }

    // MARK: - Session Data Upload

    func uploadSessionData(sessionId: UUID, imuSamples: [IMUSample], cueEvents: [CueEvent], deviceModel: String?, sensorMode: SensorMode) async throws {
        let url = URL(string: "\(baseURL)/uploadsessiondata")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // No auth — works for both authenticated and guest sessions

        // Encode IMU samples to compact dictionaries (all 20 fields)
        let encoder = JSONEncoder()
        let imuData = try encoder.encode(imuSamples)
        let cueData = try encoder.encode(cueEvents)

        // Build the body with pre-encoded JSON arrays
        let imuArray = try JSONSerialization.jsonObject(with: imuData)
        let cueArray = try JSONSerialization.jsonObject(with: cueData)

        var body: [String: Any] = [
            "sessionId": sessionId.uuidString,
            "sensorMode": sensorMode.rawValue,
            "imuSamples": imuArray,
            "cueEvents": cueArray
        ]
        if let deviceModel = deviceModel {
            body["deviceModel"] = deviceModel
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Session data upload failed: \(responseString)")
            }
            throw APIError.serverError
        }

        print("Session data uploaded: \(imuSamples.count) IMU samples, \(cueEvents.count) cue events")
    }

    // MARK: - Guest Sessions

    func submitGuestSession(session: Session, kendoRank: KendoRank, experienceYears: Int, experienceMonths: Int, guestName: String?, deviceId: String?) async throws {
        let url = URL(string: "\(baseURL)/createguestsession")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // No auth headers — guest endpoint

        var body: [String: Any] = [
            "id": session.id.uuidString,
            "swingCount": session.swingCount,
            "duration": session.duration,
            "mode": session.mode.rawValue,
            "kendoRank": kendoRank.rawValue,
            "experienceYears": experienceYears,
            "experienceMonths": experienceMonths
        ]
        if let name = guestName {
            body["guestName"] = name
        }
        if let deviceId = deviceId {
            body["deviceId"] = deviceId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Guest session submission failed: \(responseString)")
            }
            throw APIError.serverError
        }
    }

    // MARK: - Leaderboard

    func getLeaderboard() async throws -> LeaderboardResponse {
        // Get both total taps and streak leaderboards
        let totalUrl = URL(string: "\(baseURL)/GetLeaderboard?type=total&limit=50")!
        let streakUrl = URL(string: "\(baseURL)/GetLeaderboard?type=streak&limit=50")!

        let (totalData, _) = try await URLSession.shared.data(from: totalUrl)
        let (streakData, _) = try await URLSession.shared.data(from: streakUrl)

        struct LeaderboardAPIResponse: Codable {
            let type: String
            let leaderboard: [LeaderboardEntryAPI]
        }

        struct LeaderboardEntryAPI: Codable {
            let user_id: String
            let user_number: Int?
            let name: String
            let nickname: String?
            let score: Int
            let rank: Int
        }

        let totalResponse = try configuredDecoder().decode(LeaderboardAPIResponse.self, from: totalData)
        let streakResponse = try configuredDecoder().decode(LeaderboardAPIResponse.self, from: streakData)

        // Convert to app format
        let totalEntries = totalResponse.leaderboard.map { entry in
            LeaderboardEntry(
                userId: entry.user_id,
                userNumber: entry.user_number,
                name: entry.name,
                nickname: entry.nickname,
                value: entry.score,
                rank: entry.rank
            )
        }

        let streakEntries = streakResponse.leaderboard.map { entry in
            LeaderboardEntry(
                userId: entry.user_id,
                userNumber: entry.user_number,
                name: entry.name,
                nickname: entry.nickname,
                value: entry.score,
                rank: entry.rank
            )
        }

        return LeaderboardResponse(totalSwings: totalEntries, streaks: streakEntries)
    }

    // MARK: - User Profile

    func updateNickname(nickname: String) async throws -> User {
        let url = URL(string: "\(baseURL)/UpdateNickname")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await addAuthHeaders(to: &request)

        let body = ["nickname": nickname]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? configuredDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw APIError.serverError
        }

        struct UpdateNicknameResponse: Codable {
            let message: String
            let user: UserResponse
        }

        struct UserResponse: Codable {
            let id: String
            let userNumber: Int?
            let name: String
            let nickname: String?
            let nicknameLastChanged: Int?
            let email: String
            let streak: Int
            let totalCount: Int
            let createdAt: Int?
        }

        let apiResponse = try configuredDecoder().decode(UpdateNicknameResponse.self, from: data)
        let userResponse = apiResponse.user

        // Convert to User model
        var user = User(id: userResponse.id, name: userResponse.name, email: userResponse.email)
        user.userNumber = userResponse.userNumber
        user.nickname = userResponse.nickname
        if let timestamp = userResponse.nicknameLastChanged {
            print("DEBUG getUser: Raw timestamp from API: \(timestamp)")
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            print("DEBUG getUser: Converted to date: \(date)")
            user.nicknameLastChanged = date
        } else {
            user.nicknameLastChanged = nil
        }
        user.streak = userResponse.streak
        user.totalCount = userResponse.totalCount
        user.createdAt = userResponse.createdAt != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.createdAt!)) : Date()

        return user
    }

    func updateProfile(nickname: String?, kendoRank: KendoRank?, experienceYears: Int?, experienceMonths: Int?, homeDojo: String? = nil, isPublic: Bool? = nil, avatar: String? = nil) async throws -> User {
        let url = URL(string: "\(baseURL)/UpdateProfile")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        try await addAuthHeaders(to: &request)

        var body: [String: Any] = [:]
        if let nickname = nickname {
            body["nickname"] = nickname
        }
        if let kendoRank = kendoRank {
            body["kendoRank"] = kendoRank.rawValue
        }
        if let experienceYears = experienceYears {
            body["kendoExperienceYears"] = experienceYears
        }
        if let experienceMonths = experienceMonths {
            body["kendoExperienceMonths"] = experienceMonths
        }
        if let homeDojo = homeDojo {
            body["homeDojo"] = homeDojo
        }
        if let isPublic = isPublic {
            body["isPublic"] = isPublic
        }
        if let avatar = avatar {
            body["avatar"] = avatar
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("UpdateProfile: Invalid response type")
            throw APIError.invalidResponse
        }

        print("UpdateProfile response - Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("UpdateProfile response body: \(responseString)")
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? configuredDecoder().decode([String: String].self, from: data),
               let errorMessage = errorResponse["error"] {
                print("UpdateProfile error message: \(errorMessage)")
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            print("UpdateProfile: Unknown server error")
            throw APIError.serverError
        }

        struct UpdateProfileResponse: Codable {
            let message: String
            let user: UserResponse
        }

        struct UserResponse: Codable {
            let id: String
            let userNumber: Int?
            let name: String
            let nickname: String?
            let nicknameLastChanged: Int?
            let kendoRank: String?
            let kendoExperienceYears: Int?
            let kendoExperienceMonths: Int?
            let homeDojo: String?
            let avatar: String?
            let email: String
            let streak: Int
            let totalCount: Int
            let createdAt: Int?
            let isPublic: Bool?
        }

        let apiResponse = try configuredDecoder().decode(UpdateProfileResponse.self, from: data)
        let userResponse = apiResponse.user

        // Convert to User model
        var user = User(id: userResponse.id, name: userResponse.name, email: userResponse.email)
        user.userNumber = userResponse.userNumber
        user.nickname = userResponse.nickname
        if let timestamp = userResponse.nicknameLastChanged {
            print("DEBUG updateProfile: Raw timestamp from API: \(timestamp)")
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            print("DEBUG updateProfile: Converted to date: \(date)")
            user.nicknameLastChanged = date
        } else {
            user.nicknameLastChanged = nil
        }
        user.kendoRank = userResponse.kendoRank != nil ? KendoRank(rawValue: userResponse.kendoRank!) : nil
        user.kendoExperienceYears = userResponse.kendoExperienceYears ?? 0
        user.kendoExperienceMonths = userResponse.kendoExperienceMonths ?? 0
        user.homeDojo = userResponse.homeDojo
        user.avatar = userResponse.avatar ?? "kendoka"
        user.streak = userResponse.streak
        user.totalCount = userResponse.totalCount
        user.createdAt = userResponse.createdAt != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.createdAt!)) : Date()
        user.isPublic = userResponse.isPublic ?? true

        return user
    }

    // MARK: - Announcements

    func getStageProgress() async throws -> [Int: Int] {
        let url = URL(string: "\(baseURL)/GetStageProgress")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct ProgressResponse: Codable {
            let stageProgress: [String: Int]
        }
        let parsed = try configuredDecoder().decode(ProgressResponse.self, from: data)
        return Dictionary(uniqueKeysWithValues: parsed.stageProgress.compactMap { k, v in
            guard let id = Int(k) else { return nil }
            return (id, v)
        })
    }

    func getAudioManifest() async throws -> [AudioAsset] {
        let url = URL(string: "\(baseURL)/GetAudioManifest")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        struct ManifestResponse: Codable { let assets: [AudioAsset] }
        return try configuredDecoder().decode(ManifestResponse.self, from: data).assets
    }

    func logAnnouncementViews(ids: [Int]) async throws {
        guard !ids.isEmpty else { return }
        let url = URL(string: "\(baseURL)/LogAnnouncementViews")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["announcementIds": ids])
        _ = try? await URLSession.shared.data(for: request)
    }

    func getAnnouncements() async throws -> [Announcement] {
        let url = URL(string: "\(baseURL)/GetAnnouncements")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct AnnouncementsResponse: Codable { let announcements: [Announcement] }
        let decoder = configuredDecoder()
        return try decoder.decode(AnnouncementsResponse.self, from: data).announcements
    }

    func getNotifications() async throws -> NotificationsResponse {
        let url = URL(string: "\(baseURL)/GetNotifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try configuredDecoder().decode(NotificationsResponse.self, from: data)
    }

    func markNotificationsRead(ids: [Int]? = nil) async throws {
        let url = URL(string: "\(baseURL)/MarkNotificationsRead")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)
        if let ids = ids {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["notificationIds": ids])
        }
        _ = try await URLSession.shared.data(for: request)
    }

    func sendCampaignInvite(campaignId: Int, userIds: [String]) async throws -> Int {
        let url = URL(string: "\(baseURL)/SendCampaignInvite")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "campaignId": campaignId,
            "userIds": userIds
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        struct InviteResponse: Codable { let sent: Int }
        return (try? configuredDecoder().decode(InviteResponse.self, from: data).sent) ?? 0
    }

    // MARK: - Friends / Nakama

    func searchUsers(query: String, limit: Int = 10) async throws -> [UserSummary] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/SearchUsers?query=\(encoded)&limit=\(limit)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct SearchResponse: Codable { let results: [UserSummary] }
        return try configuredDecoder().decode(SearchResponse.self, from: data).results
    }

    func searchByDojo(dojo: String) async throws -> [UserSummary] {
        let encoded = dojo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dojo
        let url = URL(string: "\(baseURL)/SearchByDojo?dojo=\(encoded)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct DojoSearchResponse: Codable { let results: [UserSummary] }
        return try configuredDecoder().decode(DojoSearchResponse.self, from: data).results
    }

    func createFriendRequest(toUserId: String) async throws -> Int {
        let url = URL(string: "\(baseURL)/CreateFriendRequest")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(["toUserId": toUserId])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if httpResponse.statusCode == 201 {
            struct CreateResponse: Codable { let requestId: Int }
            return try configuredDecoder().decode(CreateResponse.self, from: data).requestId
        }

        // Parse error message
        if let errorResponse = try? configuredDecoder().decode([String: String].self, from: data),
           let errorMessage = errorResponse["error"] {
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        throw APIError.serverError
    }

    func createNudge(toUserId: String, message: String) async throws {
        let url = URL(string: "\(baseURL)/CreateNudge")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(["toUserId": toUserId, "message": message])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if httpResponse.statusCode == 201 { return }

        if let errorResponse = try? configuredDecoder().decode([String: String].self, from: data),
           let errorMessage = errorResponse["error"] {
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        throw APIError.serverError
    }

    func getFriendRequests(type: String) async throws -> [FriendRequest] {
        let url = URL(string: "\(baseURL)/GetFriendRequests?type=\(type)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct RequestsResponse: Codable { let requests: [FriendRequest] }
        return try configuredDecoder().decode(RequestsResponse.self, from: data).requests
    }

    func respondFriendRequest(requestId: Int, action: String) async throws {
        let url = URL(string: "\(baseURL)/RespondFriendRequest")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)

        let body: [String: Any] = ["requestId": requestId, "action": action]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }

    func getFriends() async throws -> [FriendInfo] {
        let url = URL(string: "\(baseURL)/GetFriends")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct FriendsResponse: Codable { let friends: [FriendInfo] }
        return try configuredDecoder().decode(FriendsResponse.self, from: data).friends
    }

    func getUserInsights(userId: String) async throws -> FriendInsights {
        let encoded = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userId
        let url = URL(string: "\(baseURL)/GetUserInsights?userId=\(encoded)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct InsightsResponse: Codable { let user: FriendInsights }
        return try configuredDecoder().decode(InsightsResponse.self, from: data).user
    }

    func getLeaderboardV2(metric: String, scope: String, page: Int = 1, pageSize: Int = 10) async throws -> LeaderboardV2Response {
        let url = URL(string: "\(baseURL)/GetLeaderboardV2?metric=\(metric)&scope=\(scope)&page=\(page)&pageSize=\(pageSize)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        return try configuredDecoder().decode(LeaderboardV2Response.self, from: data)
    }

    // MARK: - Campaign

    func getCampaignLeaderboard(campaignId: Int? = nil) async throws -> CampaignLeaderboardResponse {
        var urlString = "\(baseURL)/GetCampaignLeaderboard"
        if let id = campaignId {
            urlString += "?campaignId=\(id)"
        }
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        try await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        let decoder = configuredDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Parse ISO date strings like "2026-05-04"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = Calendar.current.timeZone
            if let date = formatter.date(from: string) { return date }
            // Fallback to full ISO8601
            let iso = ISO8601DateFormatter()
            if let date = iso.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot parse date: \(string)")
        }
        return try decoder.decode(CampaignLeaderboardResponse.self, from: data)
    }

    func joinCampaign(campaignId: Int) async throws {
        let url = URL(string: "\(baseURL)/JoinCampaign")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await addAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["campaignId": campaignId])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }

    // MARK: - Dojo Names (for autocomplete)

    func getDojoNames() async throws -> [String] {
        let url = URL(string: "\(baseURL)/GetDojoNames")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }

        struct DojoNamesResponse: Codable {
            let dojos: [String]
        }

        let apiResponse = try configuredDecoder().decode(DojoNamesResponse.self, from: data)
        return apiResponse.dojos
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case serverError
    case invalidResponse
    case userNotFound
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .serverError:
            return "Server error"
        case .invalidResponse:
            return "Invalid response"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error"
        }
    }
}