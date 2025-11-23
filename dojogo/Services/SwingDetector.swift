// SwingDetector.swift
// DojoGo - Swing Detection Engine
//
// Detects swing boundaries and ZUPT (Zero-Velocity Update) periods
// using motion energy and state machine with hysteresis

import Foundation

// MARK: - Swing Segment

struct SwingSegment {
    let startIndex: Int
    let endIndex: Int
    let peakMotionEnergy: Double
    let duration: Double
    let hasZanshin: Bool  // Whether swing ended with clear zashin period

    var sampleCount: Int {
        return endIndex - startIndex + 1
    }
}

// MARK: - ZUPT Period

struct ZUPTPeriod {
    let startIndex: Int
    let endIndex: Int
    let avgMotionEnergy: Double
    let duration: Double

    var sampleCount: Int {
        return endIndex - startIndex + 1
    }
}

// MARK: - Swing Detector

class SwingDetector {

    // MARK: - Configuration

    struct Config {
        // Motion energy thresholds
        var swingStartThreshold: Double = 8.0      // Start swing when energy exceeds this
        var swingEndThreshold: Double = 3.0        // End swing when energy drops below this
        var zuptThreshold: Double = 1.5            // ZUPT when energy consistently below this

        // Temporal constraints
        var minSwingDuration: Double = 0.15        // Min 150ms for valid swing
        var minZUPTDuration: Double = 0.10         // Min 100ms for valid ZUPT
        var minSwingSeparation: Double = 0.05      // Min 50ms between swings

        // Motion energy weights
        var accelWeight: Double = 1.0              // Weight for linear acceleration
        var gyroWeight: Double = 0.8               // Weight for angular velocity

        // Variance-based ZUPT detection
        var enableVarianceCheck: Bool = true       // Use variance for ZUPT confirmation
        var varianceWindow: Int = 10               // Samples to calculate variance over
        var varianceThreshold: Double = 0.5        // Max variance for ZUPT
    }

    private let config: Config

    // MARK: - Initialization

    init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Motion Energy Calculation

    /// Calculate motion energy for a single IMU sample
    /// Combines linear acceleration and angular velocity
    func motionEnergy(for sample: IMUSample) -> Double {
        // Linear acceleration magnitude (m/s²)
        let accelMag = sqrt(
            Double(sample.ax * sample.ax) +
            Double(sample.ay * sample.ay) +
            Double(sample.az * sample.az)
        )

        // Angular velocity magnitude (rad/s)
        let gyroMag = sqrt(
            Double(sample.gx * sample.gx) +
            Double(sample.gy * sample.gy) +
            Double(sample.gz * sample.gz)
        )

        // Combined motion energy (weighted sum)
        return config.accelWeight * accelMag + config.gyroWeight * gyroMag
    }

    /// Calculate motion energy for all samples
    func motionEnergies(for samples: [IMUSample]) -> [Double] {
        return samples.map { motionEnergy(for: $0) }
    }

    // MARK: - Swing Detection

    enum DetectionState {
        case idle           // Waiting for swing to start
        case swinging       // Active swing detected
    }

    /// Detect swing segments in IMU data
    func detectSwings(in samples: [IMUSample]) -> [SwingSegment] {
        guard samples.count > 10 else { return [] }

        let energies = motionEnergies(for: samples)
        var swings: [SwingSegment] = []
        var state: DetectionState = .idle
        var swingStartIndex: Int = 0
        var peakEnergy: Double = 0.0

        for i in 0..<samples.count {
            let energy = energies[i]
            let timestamp = Double(samples[i].ts_ns) / 1_000_000_000.0

            switch state {
            case .idle:
                // Look for swing start
                if energy > config.swingStartThreshold {
                    swingStartIndex = i
                    peakEnergy = energy
                    state = .swinging
                }

            case .swinging:
                // Track peak energy
                if energy > peakEnergy {
                    peakEnergy = energy
                }

                // Look for swing end
                if energy < config.swingEndThreshold {
                    let swingEndIndex = i
                    let duration = Double(samples[swingEndIndex].ts_ns - samples[swingStartIndex].ts_ns) / 1_000_000_000.0

                    // Validate swing duration
                    if duration >= config.minSwingDuration {
                        // Check if swing ended with zashin (ZUPT period)
                        let hasZanshin = checkForZanshin(
                            energies: energies,
                            startIndex: swingEndIndex,
                            samples: samples
                        )

                        let swing = SwingSegment(
                            startIndex: swingStartIndex,
                            endIndex: swingEndIndex,
                            peakMotionEnergy: peakEnergy,
                            duration: duration,
                            hasZanshin: hasZanshin
                        )
                        swings.append(swing)
                    }

                    state = .idle
                    peakEnergy = 0.0
                }
            }
        }

        return swings
    }

    /// Check if swing ended with clear zashin (ZUPT) period
    private func checkForZanshin(energies: [Double], startIndex: Int, samples: [IMUSample]) -> Bool {
        // Look ahead for sustained low energy
        let lookAheadSamples = min(20, energies.count - startIndex)  // Up to 20 samples (~0.2s at 100Hz)
        guard lookAheadSamples >= 5 else { return false }

        var lowEnergyCount = 0
        for i in 0..<lookAheadSamples {
            if energies[startIndex + i] < config.zuptThreshold {
                lowEnergyCount += 1
            }
        }

        // Consider it zashin if >70% of samples are below ZUPT threshold
        return Double(lowEnergyCount) / Double(lookAheadSamples) > 0.7
    }

    // MARK: - ZUPT Detection

    /// Detect ZUPT (Zero-Velocity Update) periods
    /// These are stationary periods where velocity can be reset to zero
    func detectZUPT(in samples: [IMUSample]) -> [ZUPTPeriod] {
        guard samples.count > config.varianceWindow else { return [] }

        let energies = motionEnergies(for: samples)
        var zuptPeriods: [ZUPTPeriod] = []
        var zuptStartIndex: Int? = nil
        var energySum: Double = 0.0
        var sampleCount: Int = 0

        for i in 0..<samples.count {
            let energy = energies[i]
            let isLowEnergy = energy < config.zuptThreshold

            // Additional variance check if enabled
            var passesVarianceCheck = true
            if config.enableVarianceCheck && i >= config.varianceWindow {
                let variance = calculateVariance(
                    energies: energies,
                    startIndex: i - config.varianceWindow,
                    endIndex: i
                )
                passesVarianceCheck = variance < config.varianceThreshold
            }

            if isLowEnergy && passesVarianceCheck {
                // Start or continue ZUPT period
                if zuptStartIndex == nil {
                    zuptStartIndex = i
                    energySum = 0.0
                    sampleCount = 0
                }
                energySum += energy
                sampleCount += 1
            } else {
                // End ZUPT period if we were in one
                if let startIdx = zuptStartIndex {
                    let duration = Double(samples[i - 1].ts_ns - samples[startIdx].ts_ns) / 1_000_000_000.0

                    if duration >= config.minZUPTDuration {
                        let zupt = ZUPTPeriod(
                            startIndex: startIdx,
                            endIndex: i - 1,
                            avgMotionEnergy: energySum / Double(sampleCount),
                            duration: duration
                        )
                        zuptPeriods.append(zupt)
                    }

                    zuptStartIndex = nil
                }
            }
        }

        // Handle case where ZUPT period extends to end of data
        if let startIdx = zuptStartIndex {
            let endIdx = samples.count - 1
            let duration = Double(samples[endIdx].ts_ns - samples[startIdx].ts_ns) / 1_000_000_000.0

            if duration >= config.minZUPTDuration {
                let zupt = ZUPTPeriod(
                    startIndex: startIdx,
                    endIndex: endIdx,
                    avgMotionEnergy: energySum / Double(sampleCount),
                    duration: duration
                )
                zuptPeriods.append(zupt)
            }
        }

        return zuptPeriods
    }

    /// Calculate variance of motion energy over a window
    private func calculateVariance(energies: [Double], startIndex: Int, endIndex: Int) -> Double {
        let window = energies[startIndex..<endIndex]
        guard window.count > 1 else { return 0.0 }

        let mean = window.reduce(0.0, +) / Double(window.count)
        let squaredDiffs = window.map { ($0 - mean) * ($0 - mean) }
        let variance = squaredDiffs.reduce(0.0, +) / Double(window.count)

        return variance
    }

    // MARK: - Utilities

    /// Get diagnostics for debugging
    func diagnostics(for samples: [IMUSample]) -> String {
        let energies = motionEnergies(for: samples)
        let swings = detectSwings(in: samples)
        let zupts = detectZUPT(in: samples)

        let avgEnergy = energies.reduce(0.0, +) / Double(energies.count)
        let maxEnergy = energies.max() ?? 0.0
        let minEnergy = energies.min() ?? 0.0

        let swingsWithZanshin = swings.filter { $0.hasZanshin }.count

        return """
        📊 Swing Detection Diagnostics:
           Samples: \(samples.count)
           Duration: \(String(format: "%.2f", Double(samples.last!.ts_ns - samples.first!.ts_ns) / 1_000_000_000.0))s

           Motion Energy:
           - Avg: \(String(format: "%.2f", avgEnergy))
           - Min: \(String(format: "%.2f", minEnergy))
           - Max: \(String(format: "%.2f", maxEnergy))

           Swings Detected: \(swings.count)
           - With Zanshin: \(swingsWithZanshin)
           - Without Zanshin: \(swings.count - swingsWithZanshin)

           ZUPT Periods: \(zupts.count)
           - Total duration: \(String(format: "%.2f", zupts.reduce(0.0) { $0 + $1.duration }))s
        """
    }
}
