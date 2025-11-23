// IntegrationEngine.swift
// DojoGo - IMU Integration Engine
//
// Integrates acceleration to velocity and position using trapezoidal method
// Applies ZUPT (Zero-Velocity Update) to prevent drift accumulation

import Foundation
import simd

// MARK: - Kinematics Point

struct KinematicsPoint {
    let timestamp: Double          // Seconds since start
    let position: SIMD3<Double>    // Position (m)
    let velocity: SIMD3<Double>    // Velocity (m/s)
    let acceleration: SIMD3<Double> // Acceleration (m/s²)
}

// MARK: - Integration Result

struct IntegrationResult {
    let points: [KinematicsPoint]
    let zuptResets: [Int]          // Indices where ZUPT was applied
    let totalDrift: SIMD3<Double>  // Estimated drift at end (before final ZUPT)

    var duration: Double {
        guard let first = points.first, let last = points.last else { return 0.0 }
        return last.timestamp - first.timestamp
    }

    var maxSpeed: Double {
        return points.map { simd_length($0.velocity) }.max() ?? 0.0
    }

    var totalDistance: Double {
        return simd_length(points.last?.position ?? SIMD3<Double>(0, 0, 0))
    }
}

// MARK: - Integration Engine

class IntegrationEngine {

    // MARK: - Configuration

    struct Config {
        // Integration method
        var useTrapezoidal: Bool = true         // Use trapezoidal (vs simple Euler)

        // ZUPT settings
        var applyZUPT: Bool = true              // Enable ZUPT corrections
        var zuptResetVelocity: Bool = true      // Reset velocity to zero at ZUPT
        var zuptResetPosition: Bool = false     // Reset position to zero at ZUPT (usually false)

        // Drift correction
        var applyLinearDriftCorrection: Bool = true  // Apply linear drift correction between ZUPTs
    }

    private let config: Config
    private let swingDetector: SwingDetector

    // MARK: - Initialization

    init(config: Config = Config(), swingDetector: SwingDetector = SwingDetector()) {
        self.config = config
        self.swingDetector = swingDetector
    }

    // MARK: - Integration

    /// Integrate IMU samples to get velocity and position trajectories
    func integrate(samples: [IMUSample]) -> IntegrationResult {
        guard samples.count > 1 else {
            return IntegrationResult(points: [], zuptResets: [], totalDrift: SIMD3<Double>(0, 0, 0))
        }

        // Detect ZUPT periods
        let zuptPeriods = config.applyZUPT ? swingDetector.detectZUPT(in: samples) : []

        // Initialize state
        var points: [KinematicsPoint] = []
        var velocity = SIMD3<Double>(0, 0, 0)
        var position = SIMD3<Double>(0, 0, 0)
        var zuptResets: [Int] = []
        var lastZUPTIndex: Int? = nil
        var driftAtLastZUPT = SIMD3<Double>(0, 0, 0)

        // Get first timestamp as reference
        let t0 = Double(samples[0].ts_ns) / 1_000_000_000.0

        // Create ZUPT lookup for efficient checking
        var zuptIndexSet = Set<Int>()
        for zupt in zuptPeriods {
            for i in zupt.startIndex...zupt.endIndex {
                zuptIndexSet.insert(i)
            }
        }

        // Integrate through all samples
        for i in 0..<samples.count {
            let sample = samples[i]
            let t = Double(sample.ts_ns) / 1_000_000_000.0 - t0

            // Extract acceleration
            let accel = SIMD3<Double>(
                Double(sample.ax),
                Double(sample.ay),
                Double(sample.az)
            )

            // Integrate to velocity
            if i > 0 {
                let dt = Double(sample.ts_ns - samples[i-1].ts_ns) / 1_000_000_000.0

                if config.useTrapezoidal {
                    // Trapezoidal integration (second-order accurate)
                    let accel_prev = SIMD3<Double>(
                        Double(samples[i-1].ax),
                        Double(samples[i-1].ay),
                        Double(samples[i-1].az)
                    )
                    velocity += 0.5 * (accel + accel_prev) * dt
                } else {
                    // Simple Euler integration (first-order accurate)
                    velocity += accel * dt
                }

                // Integrate velocity to position
                if config.useTrapezoidal {
                    let velocity_prev = points[i-1].velocity
                    position += 0.5 * (velocity + velocity_prev) * dt
                } else {
                    position += velocity * dt
                }
            }

            // Apply ZUPT if we're in a ZUPT period
            if zuptIndexSet.contains(i) {
                // Check if this is the start of a new ZUPT period
                let isZUPTStart = !zuptIndexSet.contains(i - 1) || i == 0

                if isZUPTStart {
                    // Store drift before resetting
                    driftAtLastZUPT = velocity

                    // Reset velocity to zero
                    if config.zuptResetVelocity {
                        velocity = SIMD3<Double>(0, 0, 0)
                        zuptResets.append(i)
                    }

                    // Optionally reset position (usually not done)
                    if config.zuptResetPosition {
                        position = SIMD3<Double>(0, 0, 0)
                    }

                    lastZUPTIndex = i
                }
            }

            // Store point
            let point = KinematicsPoint(
                timestamp: t,
                position: position,
                velocity: velocity,
                acceleration: accel
            )
            points.append(point)
        }

        return IntegrationResult(
            points: points,
            zuptResets: zuptResets,
            totalDrift: driftAtLastZUPT
        )
    }

    /// Integrate a single swing segment independently
    /// This provides better accuracy by treating each swing in isolation
    func integrateSwing(samples: [IMUSample], swing: SwingSegment) -> IntegrationResult {
        // Extract samples for this swing
        let swingSamples = Array(samples[swing.startIndex...swing.endIndex])

        // Integrate just this segment
        return integrate(samples: swingSamples)
    }

    /// Integrate all swings independently and return results
    func integrateSwings(samples: [IMUSample]) -> [(swing: SwingSegment, kinematics: IntegrationResult)] {
        let swings = swingDetector.detectSwings(in: samples)

        return swings.map { swing in
            let result = integrateSwing(samples: samples, swing: swing)
            return (swing: swing, kinematics: result)
        }
    }

    // MARK: - Utilities

    /// Get velocity magnitude time series (scalar speed)
    func velocityMagnitudes(from result: IntegrationResult) -> [Double] {
        return result.points.map { simd_length($0.velocity) }
    }

    /// Get position magnitude time series (distance from origin)
    func positionMagnitudes(from result: IntegrationResult) -> [Double] {
        return result.points.map { simd_length($0.position) }
    }

    /// Get 2D projection of position for visualization
    enum Plane {
        case xy  // Top-down view
        case xz  // Side view (horizontal-vertical)
        case yz  // Side view (lateral-vertical)
    }

    func project2D(_ position: SIMD3<Double>, onto plane: Plane) -> SIMD2<Double> {
        switch plane {
        case .xy: return SIMD2<Double>(position.x, position.y)
        case .xz: return SIMD2<Double>(position.x, position.z)
        case .yz: return SIMD2<Double>(position.y, position.z)
        }
    }

    /// Get 2D position trajectory for a specific plane
    func trajectory2D(from result: IntegrationResult, plane: Plane) -> [(x: Double, y: Double)] {
        return result.points.map { point in
            let proj = project2D(point.position, onto: plane)
            return (x: proj.x, y: proj.y)
        }
    }

    /// Get diagnostics for debugging
    func diagnostics(for result: IntegrationResult) -> String {
        let maxSpeed = result.maxSpeed
        let totalDistance = result.totalDistance
        let driftMag = simd_length(result.totalDrift)

        let avgVelocity = result.points.map { simd_length($0.velocity) }.reduce(0.0, +) / Double(result.points.count)

        return """
        📊 Integration Diagnostics:
           Duration: \(String(format: "%.2f", result.duration))s
           Points: \(result.points.count)
           ZUPT Resets: \(result.zuptResets.count)

           Velocity:
           - Max Speed: \(String(format: "%.2f", maxSpeed)) m/s
           - Avg Speed: \(String(format: "%.2f", avgVelocity)) m/s
           - Final Drift: \(String(format: "%.3f", driftMag)) m/s

           Position:
           - Total Distance: \(String(format: "%.2f", totalDistance)) m
           - Final: (\(String(format: "%.2f", result.points.last?.position.x ?? 0)), \(String(format: "%.2f", result.points.last?.position.y ?? 0)), \(String(format: "%.2f", result.points.last?.position.z ?? 0)))
        """
    }
}
