// MockIMUManager.swift
// DojoGo - Mock IMU Data Generator for Simulator Testing
//
// Simulates realistic kendo swing motion with proper biomechanics:
// - Kamae (ready position) → Strike → Zashin (stillness) → Return → Kamae
// - Realistic acceleration/gyroscope patterns based on actual kendo movement

import Foundation
import Combine
import simd

#if targetEnvironment(simulator)

// MARK: - Mock IMU Manager
// Note: IMUSample is now defined in Models/IMUSample.swift (shared with RealIMUManager)

class MockIMUManager: ObservableObject {

    // MARK: - Properties

    @Published var isRecording = false
    private(set) var samples: [IMUSample] = []

    private var timer: Timer?
    private var sessionStartTime: Date?
    private let sampleRate: Double = 100.0  // 100 Hz
    private var sampleIndex: Int = 0

    // Swing simulation parameters
    private var currentPhase: SwingPhase = .idle
    private var phaseStartTime: TimeInterval = 0
    private var swingCount: Int = 0

    // MARK: - Swing Phases

    enum SwingPhase {
        case idle           // Not swinging (kamae)
        case preparation    // Drawing back (0.2s)
        case strike         // Forward strike (0.3s)
        case zashin         // Stillness after strike (0.4s)
        case recovery       // Return to kamae (0.3s)
    }

    // MARK: - Public Methods

    func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        samples.removeAll()
        sessionStartTime = Date()
        sampleIndex = 0
        currentPhase = .idle
        swingCount = 0

        // Start sampling timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / sampleRate, repeats: true) { [weak self] _ in
            self?.generateSample()
        }

        print("🎯 Mock IMU recording started at \(sampleRate) Hz")
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        timer?.invalidate()
        timer = nil

        print("🎯 Mock IMU recording stopped.")
        print("   Total samples: \(samples.count)")
        print("   Swings triggered: \(swingCount)")
        print("   Duration: \(String(format: "%.2fs", currentTime()))")
        print("   Final phase: \(currentPhase)")

        // Print acceleration statistics
        if !samples.isEmpty {
            let peakY = samples.map { abs($0.ay) }.max() ?? 0
            let peakZ = samples.map { abs($0.az) }.max() ?? 0
            print("   Peak Y-accel: \(String(format: "%.2f m/s²", peakY)) (vertical)")
            print("   Peak Z-accel: \(String(format: "%.2f m/s²", peakZ)) (forward)")
        }
    }

    func triggerSwing() {
        guard isRecording else { return }

        // Start a new swing cycle if idle
        if currentPhase == .idle {
            currentPhase = .preparation
            phaseStartTime = currentTime()
            swingCount += 1
            print("🥋 Swing #\(swingCount) started at t=\(String(format: "%.2fs", currentTime()))")
        } else {
            print("⚠️ Swing triggered while already in phase: \(currentPhase) (ignoring)")
        }
    }

    // MARK: - Sample Generation

    private func generateSample() {
        let now = currentTime()
        let phaseDuration = now - phaseStartTime

        // Update swing phase
        updateSwingPhase(currentTime: now, phaseDuration: phaseDuration)

        // Generate acceleration and gyroscope data based on phase
        let (rawAccel, gyro) = generateMotionData(phase: currentPhase, phaseDuration: phaseDuration)

        // Separate gravity from raw acceleration
        let gravity = SIMD3<Float>(0.0, 9.81, 0.0)
        let userAccel = rawAccel - gravity  // User acceleration (gravity removed)

        // Add small noise for realism
        let noisyUserAccel = addNoise(to: userAccel, magnitude: 0.05)
        let noisyRawAccel = addNoise(to: rawAccel, magnitude: 0.05)
        let noisyGyro = addNoise(to: gyro, magnitude: 0.01)

        // Generate quaternion from gyroscope integration (simplified)
        let quaternion = generateQuaternion(gyro: noisyGyro, dt: 1.0 / Float(sampleRate))

        // Generate magnetometer (simulated Earth's magnetic field)
        let magnetometer = generateMagnetometer()

        // Create sample with full sensor suite
        let timestamp = Date().timeIntervalSince1970 * 1_000_000_000  // Convert to nanoseconds
        let sample = IMUSample(
            ts_ns: Int64(timestamp),
            ax: noisyUserAccel.x,
            ay: noisyUserAccel.y,
            az: noisyUserAccel.z,
            gx: noisyGyro.x,
            gy: noisyGyro.y,
            gz: noisyGyro.z,
            mx: magnetometer.x,
            my: magnetometer.y,
            mz: magnetometer.z,
            qw: quaternion.real,
            qx: quaternion.imag.x,
            qy: quaternion.imag.y,
            qz: quaternion.imag.z,
            raw_ax: noisyRawAccel.x,
            raw_ay: noisyRawAccel.y,
            raw_az: noisyRawAccel.z,
            seq: Int64(sampleIndex)
        )

        samples.append(sample)
        sampleIndex += 1
    }

    private func updateSwingPhase(currentTime: TimeInterval, phaseDuration: TimeInterval) {
        let previousPhase = currentPhase

        switch currentPhase {
        case .idle:
            // Stay idle until triggerSwing() is called
            break

        case .preparation:
            if phaseDuration > 0.2 {
                currentPhase = .strike
                phaseStartTime = currentTime
            }

        case .strike:
            if phaseDuration > 0.3 {
                currentPhase = .zashin
                phaseStartTime = currentTime
            }

        case .zashin:
            if phaseDuration > 0.4 {
                currentPhase = .recovery
                phaseStartTime = currentTime
            }

        case .recovery:
            if phaseDuration > 0.3 {
                currentPhase = .idle
                phaseStartTime = currentTime
            }
        }

        // Log phase transitions for debugging
        if currentPhase != previousPhase && currentPhase != .idle {
            print("   Phase: \(previousPhase) → \(currentPhase)")
        }
    }

    private func generateMotionData(phase: SwingPhase, phaseDuration: TimeInterval) -> (accel: SIMD3<Float>, gyro: SIMD3<Float>) {

        // Device frame: X=right, Y=up, Z=out (toward user)
        // Kendo swing: mostly vertical motion with some forward/back

        let gravity: Float = 9.81

        switch phase {
        case .idle:
            // At rest - only gravity on Y axis
            return (
                accel: SIMD3<Float>(0.0, gravity, 0.0),
                gyro: SIMD3<Float>(0.0, 0.0, 0.0)
            )

        case .preparation:
            // Drawing back - slight upward and backward acceleration
            let t = Float(phaseDuration / 0.2)  // Normalized time (0-1)
            let backwardAccel = sin(t * .pi) * 3.0  // Peak ~3 m/s²

            return (
                accel: SIMD3<Float>(0.0, gravity + 1.0, -backwardAccel),
                gyro: SIMD3<Float>(-2.0 * sin(t * .pi), 0.0, 0.0)  // Tilt back
            )

        case .strike:
            // Fast downward strike - high acceleration
            let t = Float(phaseDuration / 0.3)  // Normalized time (0-1)

            // Peak acceleration at t=0.5, then deceleration
            let strikeAccel = sin(t * .pi) * 25.0  // Peak ~25 m/s² (strong strike)
            let forwardAccel = sin(t * .pi) * 8.0   // Forward motion

            return (
                accel: SIMD3<Float>(0.0, gravity - strikeAccel, forwardAccel),
                gyro: SIMD3<Float>(
                    15.0 * sin(t * .pi),      // Fast forward rotation (~860°/s peak)
                    0.0,
                    -2.0 * sin(t * .pi * 2.0) // Slight twist
                )
            )

        case .zashin:
            // Stillness - minimal motion, slight oscillation from stopping
            let t = Float(phaseDuration / 0.4)
            let damping = exp(-t * 5.0)  // Exponential decay
            let oscillation = sin(t * .pi * 8.0) * damping * 0.3

            return (
                accel: SIMD3<Float>(0.0, gravity + oscillation, 0.2 * damping),
                gyro: SIMD3<Float>(0.1 * damping, 0.0, 0.0)
            )

        case .recovery:
            // Return to kamae - smooth deceleration
            let t = Float(phaseDuration / 0.3)
            let returnAccel = sin(t * .pi) * 5.0  // Moderate acceleration

            return (
                accel: SIMD3<Float>(0.0, gravity + 2.0, -returnAccel),
                gyro: SIMD3<Float>(-3.0 * sin(t * .pi), 0.0, 0.0)  // Return rotation
            )
        }
    }

    private func addNoise(to vector: SIMD3<Float>, magnitude: Float) -> SIMD3<Float> {
        return SIMD3<Float>(
            vector.x + Float.random(in: -magnitude...magnitude),
            vector.y + Float.random(in: -magnitude...magnitude),
            vector.z + Float.random(in: -magnitude...magnitude)
        )
    }

    // MARK: - Quaternion Generation

    private var currentQuaternion = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)  // Identity quaternion

    private func generateQuaternion(gyro: SIMD3<Float>, dt: Float) -> simd_quatf {
        // Simple quaternion integration from angular velocity
        // dq/dt = 0.5 * q * omega (where omega is angular velocity as pure quaternion)

        let halfGyro = gyro * 0.5 * dt
        let magnitude = length(halfGyro)

        if magnitude > 0.0001 {
            // Create rotation quaternion from axis-angle
            let axis = normalize(halfGyro)
            let angle = magnitude
            let s = sin(angle / 2.0)
            let c = cos(angle / 2.0)

            let deltaQ = simd_quatf(ix: axis.x * s, iy: axis.y * s, iz: axis.z * s, r: c)

            // Integrate: q_new = q_old * delta_q
            currentQuaternion = simd_mul(currentQuaternion, deltaQ)
            currentQuaternion = simd_normalize(currentQuaternion)
        }

        return currentQuaternion
    }

    // MARK: - Magnetometer Generation

    private func generateMagnetometer() -> SIMD3<Float> {
        // Simulate Earth's magnetic field (typical values in µT)
        // Earth's field: ~25-65 µT depending on location
        // Assume device is mostly upright, so field is mostly in X-Z plane

        // Magnetic north in device frame (assuming device Y-up)
        // X component (horizontal north): ~40 µT
        // Y component (vertical): ~20 µT
        // Z component (horizontal east): ~30 µT

        let baseMag = SIMD3<Float>(40.0, 20.0, 30.0)

        // Add small noise
        return addNoise(to: baseMag, magnitude: 2.0)
    }

    private func currentTime() -> TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
}

#endif
