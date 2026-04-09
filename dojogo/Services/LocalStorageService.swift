import Foundation

class LocalStorageService: ObservableObject {
    static let shared = LocalStorageService()

    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "saved_sessions"
    private let sessionStatsKey = "saved_session_stats"
    private let userKey = "current_user"
    private let dojoNamesKey = "cached_dojo_names"
    private let dojoNamesCacheTimeKey = "dojo_names_cache_time"
    private let stageSwingsKeyPrefix = "stage_swings_"

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

    func getTotalSwingsForUser(_ userId: String) -> Int {
        return getSessionsForUser(userId).reduce(0) { $0 + $1.swingCount }
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

    // MARK: - Session Stats (for Insights)

    func saveSessionStats(_ stats: SessionStats, for sessionId: UUID) {
        var allStats = getAllSessionStats()
        allStats[sessionId.uuidString] = StoredSessionStats.from(stats)
        do {
            let encoded = try JSONEncoder().encode(allStats)
            userDefaults.set(encoded, forKey: sessionStatsKey)
        } catch {
            print("Failed to save session stats: \(error)")
        }
    }

    func getSessionStats(for sessionId: UUID) -> StoredSessionStats? {
        return getAllSessionStats()[sessionId.uuidString]
    }

    private func getAllSessionStats() -> [String: StoredSessionStats] {
        guard let data = userDefaults.data(forKey: sessionStatsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: StoredSessionStats].self, from: data)) ?? [:]
    }

    /// Merge server sessions into local storage (inserts only new ones)
    func mergeSessionsFromServer(_ sessions: [Session], stats: [UUID: StoredSessionStats]) {
        var existing = getSavedSessions()
        let existingIds = Set(existing.map { $0.id })

        var newCount = 0
        for session in sessions {
            guard !existingIds.contains(session.id) else { continue }
            existing.append(session)
            newCount += 1
        }

        if newCount > 0 {
            do {
                let encoded = try JSONEncoder().encode(existing)
                userDefaults.set(encoded, forKey: sessionsKey)
            } catch {
                print("Failed to save merged sessions: \(error)")
            }
        }

        // Merge stats
        if !stats.isEmpty {
            var allStats = getAllSessionStats()
            for (sessionId, stat) in stats {
                if allStats[sessionId.uuidString] == nil {
                    allStats[sessionId.uuidString] = stat
                }
            }
            if let encoded = try? JSONEncoder().encode(allStats) {
                userDefaults.set(encoded, forKey: sessionStatsKey)
            }
        }

        print("Merged \(newCount) new sessions from server (total local: \(existing.count))")
    }

    // MARK: - User Management

    func saveUser(_ user: User) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970  // Fix: Use Unix epoch, not Apple reference date
            let encoded = try encoder.encode(user)
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970  // Fix: Use Unix epoch, not Apple reference date
            let user = try decoder.decode(User.self, from: data)
            return user
        } catch {
            print("Failed to decode user: \(error)")
            return nil
        }
    }

    func clearUserData() {
        userDefaults.removeObject(forKey: userKey)
        userDefaults.removeObject(forKey: sessionsKey)
        userDefaults.removeObject(forKey: sessionStatsKey)
        // Clear stage swings for all users (iterate known keys)
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix(stageSwingsKeyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Stage Swings (cumulative progress)

    func getStageSwings(for userId: String) -> [Int: Int] {
        let key = stageSwingsKeyPrefix + userId
        guard let data = userDefaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([Int: Int].self, from: data)) ?? [:]
    }

    func addSwingsToStage(_ stageId: Int, swings: Int, for userId: String) {
        var current = getStageSwings(for: userId)
        current[stageId] = (current[stageId] ?? 0) + swings
        let key = stageSwingsKeyPrefix + userId
        if let data = try? JSONEncoder().encode(current) {
            userDefaults.set(data, forKey: key)
        }
    }

    func clearStoredUser() {
        userDefaults.removeObject(forKey: userKey)
    }

    // MARK: - Dojo Names Cache

    func saveDojoNames(_ names: [String]) {
        userDefaults.set(names, forKey: dojoNamesKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: dojoNamesCacheTimeKey)
    }

    func getCachedDojoNames() -> [String] {
        return userDefaults.stringArray(forKey: dojoNamesKey) ?? []
    }

    /// Returns true if cache is older than 24 hours or doesn't exist
    func shouldRefreshDojoNames() -> Bool {
        guard let cacheTime = userDefaults.object(forKey: dojoNamesCacheTimeKey) as? Double else {
            return true
        }
        let cacheDate = Date(timeIntervalSince1970: cacheTime)
        let hoursSinceCache = Date().timeIntervalSince(cacheDate) / 3600
        return hoursSinceCache > 24
    }

    /// Add a new dojo name to local cache (for immediate UI feedback)
    func addDojoNameToCache(_ name: String) {
        var names = getCachedDojoNames()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !names.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            names.append(trimmed)
            names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            userDefaults.set(names, forKey: dojoNamesKey)
        }
    }

    // MARK: - Last Session

    func getLastSession(for userId: String) -> (session: Session, stats: StoredSessionStats?)? {
        let sessions = getSessionsForUser(userId)
        guard let latest = sessions.sorted(by: { $0.date > $1.date }).first else { return nil }
        let stats = getSessionStats(for: latest.id)
        return (latest, stats)
    }

    // MARK: - Session Reports (file-based)

    private func sessionReportsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("session_reports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveSessionReport(_ report: StoredSessionReport) {
        let dir = sessionReportsDirectory()
        let fileURL = dir.appendingPathComponent("\(report.sessionId.uuidString).json")
        do {
            let data = try JSONEncoder().encode(report)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save session report: \(error)")
        }
        pruneOldReports(keep: 5)
    }

    func getSessionReport(for sessionId: UUID) -> StoredSessionReport? {
        let dir = sessionReportsDirectory()
        let fileURL = dir.appendingPathComponent("\(sessionId.uuidString).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(StoredSessionReport.self, from: data)
    }

    func getLastSessionReport(for userId: String) -> StoredSessionReport? {
        let sessions = getSessionsForUser(userId)
        let sorted = sessions.sorted { $0.date > $1.date }
        for session in sorted {
            if let report = getSessionReport(for: session.id) {
                return report
            }
        }
        return nil
    }

    private func pruneOldReports(keep: Int) {
        let dir = sessionReportsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return }

        guard files.count > keep else { return }

        let sorted = files.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return dateA < dateB
        }

        for file in sorted.prefix(sorted.count - keep) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Statistics

    func getSessionReport(for session: Session) -> SessionReport {
        let totalSessions = getSessionsForUser(session.userId).count
        let totalSwings = getTotalSwingsForUser(session.userId)
        let currentStreak = getStreakForUser(session.userId)

        return SessionReport(
            session: session,
            totalSessions: totalSessions,
            totalSwings: totalSwings,
            currentStreak: currentStreak
        )
    }
}

struct SessionReport {
    let session: Session
    let totalSessions: Int
    let totalSwings: Int
    let currentStreak: Int
}

struct StoredSessionStats: Codable {
    let tempo: Double?
    let avgSpeed: Double?
    let maxSpeed: Double?
    let maxPower: Double?
    let avgReactionMs: Double?
    let avgStrikeTimeMs: Double?

    static func from(_ stats: SessionStats) -> StoredSessionStats {
        StoredSessionStats(
            tempo: stats.tempo,
            avgSpeed: stats.avgSpeed,
            maxSpeed: stats.maxSpeed,
            maxPower: stats.maxPower,
            avgReactionMs: stats.reactionResult?.avgReactionMs,
            avgStrikeTimeMs: stats.avgStrikeTimeMs
        )
    }
}