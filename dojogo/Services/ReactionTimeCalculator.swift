// ReactionTimeCalculator.swift
// DojoGo - Guided Practice reaction time computation
//
// Measures the delay between a GO cue and the onset of motion,
// using smoothed gyro magnitude as the motion energy signal.

import Foundation
import Accelerate

// MARK: - Result Types

struct ReactionTimeResult {
    let perCue: [CueReactionResult]

    /// Valid (non-early, non-timeout) reaction times in ms
    var validReactionTimesMs: [Double] {
        perCue.compactMap { $0.reactionMs }
    }

    var avgReactionMs: Double? {
        let v = validReactionTimesMs
        guard v.count >= 1 else { return nil }
        return v.reduce(0, +) / Double(v.count)
    }

    var bestReactionMs: Double? {
        validReactionTimesMs.min()
    }

    var earlyCount: Int {
        perCue.filter { $0.isEarly }.count
    }

    /// True if there are enough valid samples to show meaningful stats
    var isSufficient: Bool {
        validReactionTimesMs.count >= 3
    }
}

struct CueReactionResult {
    let cueTimestamp: Double      // seconds (same timebase as IMU)
    let reactionMs: Double?      // nil if early or no-response
    let isEarly: Bool
    let isNoResponse: Bool
}

// MARK: - Calculator

struct ReactionTimeCalculator {

    // MARK: - Tuning Constants (all in one place for easy adjustment)

    struct Defaults {
        /// Smoothing window for motion energy (samples). At 100 Hz, 5 = 50 ms.
        static let smoothWindowSamples: Int = 5

        /// Multiplier on MAD above baseline to declare motion onset
        static let kStart: Double = 2.5
        /// Minimum consecutive ms the signal must stay above threshold
        static let startHoldMs: Double = 100.0

        /// Pre-cue window to check for early starts (ms before cue)
        static let earlyWindowMs: Double = 200.0
        /// Multiplier on MAD for early-start detection
        static let kEarly: Double = 2.0
        /// Minimum consecutive ms above threshold to count as early
        static let earlyHoldMs: Double = 80.0

        /// Maximum time after cue to look for a response (ms)
        static let maxReactionMs: Double = 1500.0

        /// Rolling baseline window size (samples). ~2 s at 100 Hz.
        static let baselineWindowSamples: Int = 200
    }

    // MARK: - Compute

    static func compute(
        samples: [IMUSample],
        goCueTimestamps: [Double]
    ) -> ReactionTimeResult {
        guard samples.count > Defaults.smoothWindowSamples else {
            return ReactionTimeResult(perCue: [])
        }

        // Build timestamps array (seconds)
        let timestamps = samples.map { Double($0.ts_ns) / 1_000_000_000.0 }

        // Build smoothed gyro magnitude signal
        let energy = smoothedGyroMagnitude(samples: samples, windowSize: Defaults.smoothWindowSamples)

        // Rolling baseline and MAD
        let (baseline, mad) = rollingBaselineAndMAD(
            signal: energy,
            windowSize: Defaults.baselineWindowSamples
        )

        var results: [CueReactionResult] = []

        for cueTime in goCueTimestamps {
            let result = processCue(
                cueTime: cueTime,
                timestamps: timestamps,
                energy: energy,
                baseline: baseline,
                mad: mad
            )
            results.append(result)
        }

        return ReactionTimeResult(perCue: results)
    }

    // MARK: - Per-cue Processing

    private static func processCue(
        cueTime: Double,
        timestamps: [Double],
        energy: [Double],
        baseline: [Double],
        mad: [Double]
    ) -> CueReactionResult {
        // Find index closest to cue time
        guard let cueIdx = closestIndex(in: timestamps, to: cueTime) else {
            return CueReactionResult(cueTimestamp: cueTime, reactionMs: nil, isEarly: false, isNoResponse: true)
        }

        let sampleRate = estimateSampleRate(timestamps: timestamps)

        // --- Early start check ---
        let earlyWindowSamples = Int((Defaults.earlyWindowMs / 1000.0) * sampleRate)
        let earlyHoldSamples = Int((Defaults.earlyHoldMs / 1000.0) * sampleRate)
        let earlyStartIdx = max(0, cueIdx - earlyWindowSamples)

        if earlyStartIdx < cueIdx {
            let earlyThr = baseline[cueIdx] + Defaults.kEarly * max(mad[cueIdx], 0.1)
            var consecutive = 0
            for i in earlyStartIdx..<cueIdx {
                if energy[i] > earlyThr {
                    consecutive += 1
                    if consecutive >= earlyHoldSamples {
                        return CueReactionResult(cueTimestamp: cueTime, reactionMs: nil, isEarly: true, isNoResponse: false)
                    }
                } else {
                    consecutive = 0
                }
            }
        }

        // --- Detect motion onset after cue ---
        let maxReactionSamples = Int((Defaults.maxReactionMs / 1000.0) * sampleRate)
        let startHoldSamples = Int((Defaults.startHoldMs / 1000.0) * sampleRate)
        let searchEnd = min(energy.count, cueIdx + maxReactionSamples)

        let startThr = baseline[cueIdx] + Defaults.kStart * max(mad[cueIdx], 0.1)
        var consecutive = 0
        var onsetIdx: Int?

        for i in cueIdx..<searchEnd {
            if energy[i] > startThr {
                if consecutive == 0 { onsetIdx = i }
                consecutive += 1
                if consecutive >= startHoldSamples {
                    // onset confirmed at the start of the run
                    let reactionSec = timestamps[onsetIdx!] - cueTime
                    let reactionMs = reactionSec * 1000.0
                    return CueReactionResult(cueTimestamp: cueTime, reactionMs: reactionMs, isEarly: false, isNoResponse: false)
                }
            } else {
                consecutive = 0
                onsetIdx = nil
            }
        }

        // No response within window
        return CueReactionResult(cueTimestamp: cueTime, reactionMs: nil, isEarly: false, isNoResponse: true)
    }

    // MARK: - Signal Processing Helpers

    /// Smoothed gyro magnitude using a simple moving average
    private static func smoothedGyroMagnitude(samples: [IMUSample], windowSize: Int) -> [Double] {
        let raw = samples.map { s in
            sqrt(Double(s.gx) * Double(s.gx) +
                 Double(s.gy) * Double(s.gy) +
                 Double(s.gz) * Double(s.gz))
        }

        guard raw.count >= windowSize else { return raw }

        // Simple moving average
        var smoothed = [Double](repeating: 0, count: raw.count)
        var runningSum = raw[0..<windowSize].reduce(0, +)
        let half = windowSize / 2

        for i in 0..<raw.count {
            let windowStart = max(0, i - half)
            let windowEnd = min(raw.count - 1, i + half)
            let wSize = windowEnd - windowStart + 1
            // Recompute for edges; use running sum in the middle
            if i < half || i >= raw.count - half {
                smoothed[i] = raw[windowStart...windowEnd].reduce(0, +) / Double(wSize)
            } else {
                smoothed[i] = runningSum / Double(windowSize)
                // Slide window
                if i + half + 1 < raw.count {
                    runningSum += raw[i + half + 1] - raw[i - half]
                }
            }
        }

        return smoothed
    }

    /// Rolling median and MAD over a trailing window
    private static func rollingBaselineAndMAD(
        signal: [Double],
        windowSize: Int
    ) -> (baseline: [Double], mad: [Double]) {
        var baselines = [Double](repeating: 0, count: signal.count)
        var mads = [Double](repeating: 0, count: signal.count)

        for i in 0..<signal.count {
            let windowStart = max(0, i - windowSize + 1)
            let window = Array(signal[windowStart...i])
            let sorted = window.sorted()
            let median = sorted[sorted.count / 2]
            baselines[i] = median

            let deviations = window.map { abs($0 - median) }.sorted()
            mads[i] = deviations[deviations.count / 2]
        }

        return (baselines, mads)
    }

    private static func closestIndex(in timestamps: [Double], to target: Double) -> Int? {
        guard !timestamps.isEmpty else { return nil }
        // Binary search for closest
        var lo = 0, hi = timestamps.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if timestamps[mid] < target { lo = mid + 1 } else { hi = mid }
        }
        // Check lo and lo-1
        if lo > 0 && abs(timestamps[lo - 1] - target) < abs(timestamps[lo] - target) {
            return lo - 1
        }
        return lo
    }

    private static func estimateSampleRate(timestamps: [Double]) -> Double {
        guard timestamps.count >= 2 else { return 100.0 }
        let totalDuration = timestamps.last! - timestamps.first!
        guard totalDuration > 0 else { return 100.0 }
        return Double(timestamps.count - 1) / totalDuration
    }
}
