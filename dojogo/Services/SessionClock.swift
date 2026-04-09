// SessionClock.swift
// DojoGo - Monotonic session clock for cue/IMU time alignment
//
// Produces ms-since-session-start timestamps using the same monotonic
// timebase as CoreMotion, ensuring cue events align with IMU samples.

import Foundation

final class SessionClock {
    /// ProcessInfo.systemUptime at session t=0
    let startUptime: TimeInterval
    /// Corresponding absolute ts_ns at t=0 (for IMU alignment)
    let startTsNs: Int64

    init() {
        self.startUptime = ProcessInfo.processInfo.systemUptime
        self.startTsNs = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
    }

    /// Current time in ms since session start (monotonic, no clock drift)
    var nowMs: Int {
        let elapsed = ProcessInfo.processInfo.systemUptime - startUptime
        return Int(elapsed * 1000)
    }

    /// Convert an IMU sample's ts_ns to ms-since-session-start
    func msFromTsNs(_ tsNs: Int64) -> Int {
        return Int((tsNs - startTsNs) / 1_000_000)
    }
}
