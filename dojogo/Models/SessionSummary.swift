// SessionSummary.swift
// DojoGo - Per-session summary stats for Insights/Log

import Foundation

struct SessionSummary: Identifiable {
    let id: UUID
    let date: Date
    let swingCount: Int
    let reactionTimeMs: Double?   // guided only: avg reaction time
    let strikeTimeMs: Double?     // guided only: avg cue → impact time
    let maxMotionEnergy: Double?
    let maxRotVel: Double?
    let sessionDuration: Double?  // seconds
    let mode: SessionMode

    /// Build from a Session + optional SessionStats (computed at session end)
    static func from(session: Session, stats: SessionStats?) -> SessionSummary {
        SessionSummary(
            id: session.id,
            date: session.date,
            swingCount: session.swingCount,
            reactionTimeMs: stats?.reactionResult?.avgReactionMs,
            strikeTimeMs: stats?.avgStrikeTimeMs,
            maxMotionEnergy: stats?.maxPower,
            maxRotVel: stats?.maxSpeed,
            sessionDuration: stats?.durationSec,
            mode: session.mode
        )
    }

    /// Build from a Session + locally persisted stats
    static func from(session: Session, storedStats: StoredSessionStats?) -> SessionSummary {
        SessionSummary(
            id: session.id,
            date: session.date,
            swingCount: session.swingCount,
            reactionTimeMs: storedStats?.avgReactionMs,
            strikeTimeMs: storedStats?.avgStrikeTimeMs,
            maxMotionEnergy: storedStats?.maxPower,
            maxRotVel: storedStats?.maxSpeed,
            sessionDuration: session.duration,
            mode: session.mode
        )
    }
}

/// A single data point for the Insights chart (aggregated per day)
struct DailyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
