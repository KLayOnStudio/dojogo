// SessionStatsCalculator.swift
// DojoGo - Post-session stats computation
//
// Computes 5 core stats from IMU data + detected swings:
//   Swings, Session Time, Tempo, Avg Speed, Max Power

import Foundation

// MARK: - Session Stats Result

struct SessionStats {
    let swingCount: Int
    let durationSec: Double
    let tempo: Double?             // swings/min; nil if duration < 10s or 0 swings
    let avgSpeed: Double?          // mean peak gyro magnitude across swings (rad/s)
    let maxSpeed: Double?          // max peak gyro magnitude across swings (rad/s)
    let maxPower: Double?          // max peak accel magnitude across swings (m/s²)

    // Guided-only reaction data (nil in free practice)
    let reactionResult: ReactionTimeResult?

    // Guided-only: avg time from cue to peak deceleration (strike impact), ms
    let avgStrikeTimeMs: Double?
}

// MARK: - Calculator

struct SessionStatsCalculator {

    // MARK: - Tuning Constants

    /// Minimum session duration (seconds) to show tempo
    static let minDurationForTempo: Double = 10.0

    /// Window around detected peak to search for per-swing maxima.
    /// [peak - preSec ... peak + postSec]
    static let swingWindowPreSec: Double = 0.25
    static let swingWindowPostSec: Double = 0.45

    // MARK: - Compute

    /// Compute session stats from raw IMU samples and previously detected swings.
    /// `goCueTimestamps` should be non-nil only for guided practice sessions.
    static func compute(
        samples: [IMUSample],
        swings: [SwingSegment],
        goCueTimestamps: [Double]? = nil
    ) -> SessionStats {

        // --- Duration ---
        let durationSec: Double
        if let first = samples.first, let last = samples.last {
            durationSec = Double(last.ts_ns - first.ts_ns) / 1_000_000_000.0
        } else {
            durationSec = 0
        }

        // --- Swing count ---
        let swingCount = swings.count

        // --- Tempo ---
        let tempo: Double?
        if swingCount > 0, durationSec >= minDurationForTempo {
            tempo = Double(swingCount) / (durationSec / 60.0)
        } else {
            tempo = nil
        }

        // --- Per-swing peak gyro (speed) and peak accel (power) ---
        var peakGyros: [Double] = []
        var peakAccels: [Double] = []

        for swing in swings {
            // Use the swing segment boundaries directly
            let startIdx = swing.startIndex
            let endIdx = min(swing.endIndex, samples.count - 1)
            guard startIdx <= endIdx else { continue }

            var maxGyro: Double = 0
            var maxAccel: Double = 0

            for i in startIdx...endIdx {
                let s = samples[i]
                let gyroMag = sqrt(
                    Double(s.gx) * Double(s.gx) +
                    Double(s.gy) * Double(s.gy) +
                    Double(s.gz) * Double(s.gz)
                )
                let accelMag = sqrt(
                    Double(s.ax) * Double(s.ax) +
                    Double(s.ay) * Double(s.ay) +
                    Double(s.az) * Double(s.az)
                )
                maxGyro = max(maxGyro, gyroMag)
                maxAccel = max(maxAccel, accelMag)
            }

            peakGyros.append(maxGyro)
            peakAccels.append(maxAccel)
        }

        let avgSpeed: Double? = peakGyros.isEmpty ? nil : peakGyros.reduce(0, +) / Double(peakGyros.count)
        let maxSpeed: Double? = peakGyros.isEmpty ? nil : peakGyros.max()
        let maxPower: Double? = peakAccels.isEmpty ? nil : peakAccels.max()

        // --- Reaction time (guided only) ---
        let reactionResult: ReactionTimeResult?
        if let cues = goCueTimestamps, !cues.isEmpty {
            reactionResult = ReactionTimeCalculator.compute(
                samples: samples,
                goCueTimestamps: cues
            )
        } else {
            reactionResult = nil
        }

        // --- Strike time: cue → peak deceleration (guided only) ---
        let avgStrikeTimeMs: Double?
        if let cues = goCueTimestamps, !cues.isEmpty, !samples.isEmpty {
            avgStrikeTimeMs = computeAvgStrikeTime(samples: samples, goCueTimestamps: cues)
        } else {
            avgStrikeTimeMs = nil
        }

        return SessionStats(
            swingCount: swingCount,
            durationSec: durationSec,
            tempo: tempo,
            avgSpeed: avgSpeed,
            maxSpeed: maxSpeed,
            maxPower: maxPower,
            reactionResult: reactionResult,
            avgStrikeTimeMs: avgStrikeTimeMs
        )
    }

    // MARK: - Strike Time (cue → peak deceleration)

    /// For each GO cue, find the time to the peak accel magnitude
    /// (deceleration at impact) within a search window after the cue.
    /// Returns the average across all cues, in ms.
    private static func computeAvgStrikeTime(
        samples: [IMUSample],
        goCueTimestamps: [Double]
    ) -> Double? {
        let timestamps = samples.map { Double($0.ts_ns) / 1_000_000_000.0 }
        let maxSearchSec = 2.0  // look up to 2s after cue

        var strikeTimes: [Double] = []

        for cueTime in goCueTimestamps {
            // Find start index at or after cue
            guard let startIdx = timestamps.firstIndex(where: { $0 >= cueTime }) else { continue }
            let endTime = cueTime + maxSearchSec
            let endIdx = timestamps.lastIndex(where: { $0 <= endTime }) ?? (samples.count - 1)
            guard startIdx < endIdx else { continue }

            // Find peak accel magnitude in window
            var peakAccel: Double = 0
            var peakIdx = startIdx
            for i in startIdx...endIdx {
                let s = samples[i]
                let mag = sqrt(
                    Double(s.ax) * Double(s.ax) +
                    Double(s.ay) * Double(s.ay) +
                    Double(s.az) * Double(s.az)
                )
                if mag > peakAccel {
                    peakAccel = mag
                    peakIdx = i
                }
            }

            // Only count if there was meaningful acceleration (above gravity + threshold)
            if peakAccel > 12.0 {  // ~2 m/s² above gravity
                let strikeMs = (timestamps[peakIdx] - cueTime) * 1000.0
                if strikeMs > 50 {  // filter out noise < 50ms
                    strikeTimes.append(strikeMs)
                }
            }
        }

        guard !strikeTimes.isEmpty else { return nil }
        return strikeTimes.reduce(0, +) / Double(strikeTimes.count)
    }
}
