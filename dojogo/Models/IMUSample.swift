// IMUSample.swift
// DojoGo - IMU Data Sample Model
//
// Shared data structure for both MockIMUManager and RealIMUManager
// Compatible with Azure IMU upload format

import Foundation

struct IMUSample: Codable {
    // Timestamp
    let ts_ns: Int64        // Nanoseconds since Unix epoch

    // Accelerometer (gravity-removed, user acceleration only)
    let ax: Float           // User acceleration X (m/s²)
    let ay: Float           // User acceleration Y (m/s²)
    let az: Float           // User acceleration Z (m/s²)

    // Gyroscope (angular velocity)
    let gx: Float           // Gyroscope X (rad/s)
    let gy: Float           // Gyroscope Y (rad/s)
    let gz: Float           // Gyroscope Z (rad/s)

    // Magnetometer (optional, for heading)
    let mx: Float?          // Magnetometer X (µT)
    let my: Float?          // Magnetometer Y (µT)
    let mz: Float?          // Magnetometer Z (µT)

    // Quaternion (device orientation, from CMAttitude)
    let qw: Float           // Quaternion W (scalar part)
    let qx: Float           // Quaternion X
    let qy: Float           // Quaternion Y
    let qz: Float           // Quaternion Z

    // Raw acceleration (includes gravity, for reference)
    let raw_ax: Float       // Raw acceleration X (m/s²)
    let raw_ay: Float       // Raw acceleration Y (m/s²)
    let raw_az: Float       // Raw acceleration Z (m/s²)

    // Sequence number (for debugging dropped samples)
    let seq: Int64          // Monotonic sequence number
}
