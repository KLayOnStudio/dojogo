import Foundation

class LocalStorageService: ObservableObject {
    static let shared = LocalStorageService()

    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "saved_sessions"
    private let userKey = "current_user"

    private init() {}

    // MARK: - Session Management

    func saveSession(_ session: Session) {
        var savedSessions = getSavedSessions()
        savedSessions.append(session)

        do {
            let encoded = try JSONEncoder().encode(savedSessions)
            userDefaults.set(encoded, forKey: sessionsKey)
        } catch {
            print("Failed to save session: \(error)")
        }
    }

    func getSavedSessions() -> [Session] {
        guard let data = userDefaults.data(forKey: sessionsKey) else {
            return []
        }

        do {
            let sessions = try JSONDecoder().decode([Session].self, from: data)
            return sessions
        } catch {
            print("Failed to decode sessions: \(error)")
            return []
        }
    }

    func getSessionsForUser(_ userId: String) -> [Session] {
        return getSavedSessions().filter { $0.userId == userId }
    }

    func getSessionsForDate(_ date: Date, userId: String) -> [Session] {
        let calendar = Calendar.current
        return getSessionsForUser(userId).filter { session in
            calendar.isDate(session.date, inSameDayAs: date)
        }
    }

    func getTotalTapsForUser(_ userId: String) -> Int {
        return getSessionsForUser(userId).reduce(0) { $0 + $1.tapCount }
    }

    func getStreakForUser(_ userId: String) -> Int {
        let sessions = getSessionsForUser(userId)
        guard !sessions.isEmpty else { return 0 }

        // Sort sessions by date (most recent first)
        let sortedSessions = sessions.sorted { $0.date > $1.date }
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()

        // Start from today and count backwards
        for i in 0..<365 { // Max 365 days
            let checkDate = calendar.date(byAdding: .day, value: -i, to: currentDate)!
            let hasSessionOnDate = sortedSessions.contains { session in
                calendar.isDate(session.date, inSameDayAs: checkDate)
            }

            if hasSessionOnDate {
                streak += 1
            } else if i > 0 { // If no session and it's not today, break the streak
                break
            }
        }

        return streak
    }

    // MARK: - User Management

    func saveUser(_ user: User) {
        do {
            let encoded = try JSONEncoder().encode(user)
            userDefaults.set(encoded, forKey: userKey)
        } catch {
            print("Failed to save user: \(error)")
        }
    }

    func getCurrentUser() -> User? {
        guard let data = userDefaults.data(forKey: userKey) else {
            return nil
        }

        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            return user
        } catch {
            print("Failed to decode user: \(error)")
            return nil
        }
    }

    func clearUserData() {
        userDefaults.removeObject(forKey: userKey)
        userDefaults.removeObject(forKey: sessionsKey)
    }

    func clearStoredUser() {
        userDefaults.removeObject(forKey: userKey)
    }

    // MARK: - Statistics

    func getSessionReport(for session: Session) -> SessionReport {
        let totalSessions = getSessionsForUser(session.userId).count
        let totalTaps = getTotalTapsForUser(session.userId)
        let currentStreak = getStreakForUser(session.userId)

        return SessionReport(
            session: session,
            totalSessions: totalSessions,
            totalTaps: totalTaps,
            currentStreak: currentStreak
        )
    }
}

struct SessionReport {
    let session: Session
    let totalSessions: Int
    let totalTaps: Int
    let currentStreak: Int
}