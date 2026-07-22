import Foundation
import CoreGraphics

/// One of the top swingers on a given stage's torii gate.
struct StageChampion: Codable {
    let rank: Int
    let userId: String
    let nickname: String?
    let userNumber: Int?
    let totalSwings: Int

    var displayName: String {
        nickname ?? "Player #\(userNumber ?? 0)"
    }
}

/// The komainu (guardian) standings for a single stage: top swingers, and how
/// long the current #1 has held the lead.
struct StageChampionsEntry: Codable {
    let topSwingers: [StageChampion]
    let leaderSince: Int?

    var komainu: StageChampion? {
        topSwingers.first { $0.rank == 1 }
    }

    var komainuSinceDate: Date? {
        guard let ts = leaderSince else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }
}

struct Stage: Identifiable, Hashable {
    let id: Int
    let name: String
    let subtitle: String
    let description: String
    let swingsRequired: Int
    let cueConfig: CueConfigValues
    /// Normalized position on the map (0-1 range, multiplied by geometry size)
    let mapPosition: CGPoint

    struct CueConfigValues: Hashable {
        let interSwingSec: Double
        let useRandomInterval: Bool
        let randomRangeMin: Double
        let randomRangeMax: Double
    }

    /// Progress clamped to 20% increments (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)
    func progress(swings: Int) -> Double {
        let raw = Double(swings) / Double(swingsRequired)
        let clamped = min(raw, 1.0)
        return (clamped * 5.0).rounded(.down) / 5.0
    }

    func isCompleted(swings: Int) -> Bool {
        swings >= swingsRequired
    }

    func isUnlocked(stageSwings: [Int: Int]) -> Bool {
        if id == 1 { return true }
        let prevStage = Stage.allStages.first { $0.id == id - 1 }
        guard let prev = prevStage else { return false }
        let prevSwings = stageSwings[prev.id] ?? 0
        return prev.isCompleted(swings: prevSwings)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Stage, rhs: Stage) -> Bool {
        lhs.id == rhs.id
    }

    func toCueManagerConfig() -> CueManager.Config {
        var config = CueManager.Config()
        config.interSwingSec = cueConfig.interSwingSec
        config.useRandomInterval = cueConfig.useRandomInterval
        config.randomRangeSec = (min: cueConfig.randomRangeMin, max: cueConfig.randomRangeMax)
        return config
    }

    // MARK: - Stage Definitions

    static let allStages: [Stage] = [
        Stage(
            id: 1,
            name: "WARM UP",
            subtitle: "Find your rhythm",
            description: "A gentle pace to settle into your stance and build consistency. Focus on clean form.",
            swingsRequired: 100,
            cueConfig: CueConfigValues(interSwingSec: 2.5, useRandomInterval: false, randomRangeMin: 2.0, randomRangeMax: 5.0),
            mapPosition: CGPoint(x: 0.50, y: 0.72)
        ),
        Stage(
            id: 2,
            name: "STEADY",
            subtitle: "Sharpen your timing",
            description: "Random intervals keep you alert. Stay relaxed and respond to each cue with precision.",
            swingsRequired: 200,
            cueConfig: CueConfigValues(interSwingSec: 1.75, useRandomInterval: true, randomRangeMin: 1.5, randomRangeMax: 2.0),
            mapPosition: CGPoint(x: 0.35, y: 0.60)
        ),
        Stage(
            id: 3,
            name: "PRESS",
            subtitle: "Increase pressure",
            description: "Faster cues demand quicker recovery. Push through fatigue and maintain your kiai.",
            swingsRequired: 300,
            cueConfig: CueConfigValues(interSwingSec: 1.0, useRandomInterval: false, randomRangeMin: 2.0, randomRangeMax: 5.0),
            mapPosition: CGPoint(x: 0.55, y: 0.48)
        ),
        Stage(
            id: 4,
            name: "ENDURE",
            subtitle: "Test your spirit",
            description: "High volume at high speed. This is where discipline meets endurance.",
            swingsRequired: 400,
            cueConfig: CueConfigValues(interSwingSec: 1.0, useRandomInterval: false, randomRangeMin: 2.0, randomRangeMax: 5.0),
            mapPosition: CGPoint(x: 0.40, y: 0.40)
        ),
        Stage(
            id: 5,
            name: "SUMMIT",
            subtitle: "Master the mountain",
            description: "Unpredictable timing at full intensity. Only the sharpest spirit reaches the summit.",
            swingsRequired: 500,
            cueConfig: CueConfigValues(interSwingSec: 1.0, useRandomInterval: true, randomRangeMin: 0.5, randomRangeMax: 1.5),
            mapPosition: CGPoint(x: 0.50, y: 0.20)
        ),
    ]

    static let freePracticePosition = CGPoint(x: 0.80, y: 0.83)
}
