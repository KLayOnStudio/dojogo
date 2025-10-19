import Foundation

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let message: String?
}

struct LeaderboardResponse: Codable {
    let totalTaps: [LeaderboardEntry]
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

    // MARK: - Authentication Helper

    private func addAuthHeaders(to request: inout URLRequest) async {
        do {
            let token = try await Auth0Manager.shared.getIdToken()
            print("Successfully retrieved ID token: \(token.prefix(50))...")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            print("Failed to get ID token: \(error)")
        }
    }

    // MARK: - User Management

    func createUser(_ user: User) async throws -> User {
        print("Creating user: \(user.name) (\(user.email))")
        let url = URL(string: "\(baseURL)/CreateUser")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

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

        let apiResponse = try JSONDecoder().decode(CreateUserResponse.self, from: data)
        return apiResponse.user
    }

    func getUser(id: String) async throws -> User {
        let url = URL(string: "\(baseURL)/GetUser")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        await addAuthHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.userNotFound
        }

        struct GetUserResponse: Codable {
            let user: User
        }

        let apiResponse = try JSONDecoder().decode(GetUserResponse.self, from: data)
        return apiResponse.user
    }

    // MARK: - Session Management

    func logSessionStart(userId: String) async throws {
        print("Logging session start for user: \(userId)")
        let url = URL(string: "\(baseURL)/LogSessionStart")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

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

    func submitSession(_ session: Session) async throws -> (updatedUser: User, streak: Int) {
        let url = URL(string: "\(baseURL)/CreateSession")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

        let sessionData = try JSONEncoder().encode(session)
        request.httpBody = sessionData

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

        let apiResponse = try JSONDecoder().decode(SessionSubmissionResponse.self, from: data)
        return (updatedUser: apiResponse.user, streak: apiResponse.user.streak)
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

        let totalResponse = try JSONDecoder().decode(LeaderboardAPIResponse.self, from: totalData)
        let streakResponse = try JSONDecoder().decode(LeaderboardAPIResponse.self, from: streakData)

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

        return LeaderboardResponse(totalTaps: totalEntries, streaks: streakEntries)
    }

    // MARK: - User Profile

    func updateNickname(nickname: String) async throws -> User {
        let url = URL(string: "\(baseURL)/UpdateNickname")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

        let body = ["nickname": nickname]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
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

        let apiResponse = try JSONDecoder().decode(UpdateNicknameResponse.self, from: data)
        let userResponse = apiResponse.user

        // Convert to User model
        var user = User(id: userResponse.id, name: userResponse.name, email: userResponse.email)
        user.userNumber = userResponse.userNumber
        user.nickname = userResponse.nickname
        user.nicknameLastChanged = userResponse.nicknameLastChanged != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.nicknameLastChanged!)) : nil
        user.streak = userResponse.streak
        user.totalCount = userResponse.totalCount
        user.createdAt = userResponse.createdAt != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.createdAt!)) : Date()

        return user
    }

    func updateProfile(nickname: String?, kendoRank: KendoRank?, experienceYears: Int?, experienceMonths: Int?) async throws -> User {
        let url = URL(string: "\(baseURL)/UpdateProfile")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

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
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
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
            let email: String
            let streak: Int
            let totalCount: Int
            let createdAt: Int?
        }

        let apiResponse = try JSONDecoder().decode(UpdateProfileResponse.self, from: data)
        let userResponse = apiResponse.user

        // Convert to User model
        var user = User(id: userResponse.id, name: userResponse.name, email: userResponse.email)
        user.userNumber = userResponse.userNumber
        user.nickname = userResponse.nickname
        user.nicknameLastChanged = userResponse.nicknameLastChanged != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.nicknameLastChanged!)) : nil
        user.kendoRank = userResponse.kendoRank != nil ? KendoRank(rawValue: userResponse.kendoRank!) : nil
        user.kendoExperienceYears = userResponse.kendoExperienceYears ?? 0
        user.kendoExperienceMonths = userResponse.kendoExperienceMonths ?? 0
        user.streak = userResponse.streak
        user.totalCount = userResponse.totalCount
        user.createdAt = userResponse.createdAt != nil ? Date(timeIntervalSince1970: TimeInterval(userResponse.createdAt!)) : Date()

        return user
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