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
    let name: String
    let value: Int
    let rank: Int
}

class APIService: ObservableObject {
    static let shared = APIService()

    private let baseURL = "https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api"

    private init() {}

    // MARK: - Authentication Helper

    private func addAuthHeaders(to request: inout URLRequest) async {
        do {
            let token = try await Auth0Manager.shared.getAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            print("Failed to get access token: \(error)")
        }
    }

    // MARK: - User Management

    func createUser(_ user: User) async throws -> User {
        let url = URL(string: "\(baseURL)/CreateUser")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

        let userData = ["name": user.name, "email": user.email]
        let jsonData = try JSONSerialization.data(withJSONObject: userData)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
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
        let url = URL(string: "\(baseURL)/LogSessionStart")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await addAuthHeaders(to: &request)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
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
            let name: String
            let score: Int
            let rank: Int
        }

        let totalResponse = try JSONDecoder().decode(LeaderboardAPIResponse.self, from: totalData)
        let streakResponse = try JSONDecoder().decode(LeaderboardAPIResponse.self, from: streakData)

        // Convert to app format
        let totalEntries = totalResponse.leaderboard.map { entry in
            LeaderboardEntry(
                userId: "", // API doesn't return userId for privacy
                name: entry.name,
                value: entry.score,
                rank: entry.rank
            )
        }

        let streakEntries = streakResponse.leaderboard.map { entry in
            LeaderboardEntry(
                userId: "", // API doesn't return userId for privacy
                name: entry.name,
                value: entry.score,
                rank: entry.rank
            )
        }

        return LeaderboardResponse(totalTaps: totalEntries, streaks: streakEntries)
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