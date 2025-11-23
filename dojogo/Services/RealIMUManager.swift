// RealIMUManager.swift
// DojoGo - Real IMU Data Capture from CoreMotion (Physical Device Only)
//
// Captures full sensor suite from CMDeviceMotion:
// - User acceleration (gravity-removed)
// - Raw acceleration (gravity-included)
// - Gyroscope (angular velocity)
// - Magnetometer (if available)
// - Quaternion (device orientation)

import Foundation
import CoreMotion
import Combine

#if !targetEnvironment(simulator)

class RealIMUManager: ObservableObject {

    // MARK: - Properties

    @Published var isRecording = false
    private(set) var samples: [IMUSample] = []

    private let motionManager = CMMotionManager()
    private var sessionStartTime: Date?
    private var sampleIndex: Int64 = 0

    // Configuration
    private let sampleRate: Double = 100.0  // 100 Hz
    private let updateInterval: TimeInterval

    init() {
        self.updateInterval = 1.0 / sampleRate
    }

    // MARK: - Public Methods

    func startRecording() {
        guard !isRecording else { return }
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Device motion not available on this device")
            return
        }

        isRecording = true
        samples.removeAll()
        sessionStartTime = Date()
        sampleIndex = 0

        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.showsDeviceMovementDisplay = true

        // Start device motion updates (includes all sensors fused)
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical,
                                               to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("❌ Device motion error: \(error.localizedDescription)")
                }
                return
            }

            self.captureSample(from: motion)
        }

        print("🎯 Real IMU recording started at \(sampleRate) Hz")
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        motionManager.stopDeviceMotionUpdates()

        print("🎯 Real IMU recording stopped. Total samples: \(samples.count)")
    }

    func triggerSwing() {
        // No-op for real device (doesn't need manual swing triggers)
        // Real device captures actual motion continuously
    }

    // MARK: - Sample Capture

    private func captureSample(from motion: CMDeviceMotion) {
        guard isRecording else { return }

        let timestamp = Date().timeIntervalSince1970 * 1_000_000_000  // Nanoseconds

        // User acceleration (gravity already removed by CoreMotion)
        let userAccel = motion.userAcceleration

        // Gravity vector
        let gravity = motion.gravity

        // Calculate raw acceleration (user + gravity)
        let rawAccel = (
            x: userAccel.x + gravity.x,
            y: userAccel.y + gravity.y,
            z: userAccel.z + gravity.z
        )

        // Rotation rate (gyroscope)
        let gyro = motion.rotationRate

        // Attitude quaternion
        let quaternion = motion.attitude.quaternion

        // Magnetic field (optional - may be nil if not available)
        let magneticField = motion.magneticField
        let hasMagnetometer = magneticField.accuracy != .uncalibrated

        // Create sample with full sensor suite
        let sample = IMUSample(
            ts_ns: Int64(timestamp),
            // User acceleration (gravity removed) - convert g to m/s²
            ax: Float(userAccel.x * 9.81),
            ay: Float(userAccel.y * 9.81),
            az: Float(userAccel.z * 9.81),
            // Gyroscope (angular velocity in rad/s)
            gx: Float(gyro.x),
            gy: Float(gyro.y),
            gz: Float(gyro.z),
            // Magnetometer (microtesla) - optional
            mx: hasMagnetometer ? Float(magneticField.field.x) : nil,
            my: hasMagnetometer ? Float(magneticField.field.y) : nil,
            mz: hasMagnetometer ? Float(magneticField.field.z) : nil,
            // Quaternion (device orientation)
            qw: Float(quaternion.w),
            qx: Float(quaternion.x),
            qy: Float(quaternion.y),
            qz: Float(quaternion.z),
            // Raw acceleration (includes gravity) - convert g to m/s²
            raw_ax: Float(rawAccel.x * 9.81),
            raw_ay: Float(rawAccel.y * 9.81),
            raw_az: Float(rawAccel.z * 9.81),
            // Sequence number
            seq: sampleIndex
        )

        samples.append(sample)
        sampleIndex += 1
    }
}

#endif
