// CueManager.swift
// DojoGo - Guided session cue state machine
//
// Flow:
//   1. Countdown: "3 → 2 → 1 → Men!" with beep + green flash
//   2. User swings — swing detected by SwingDetector
//   3. Swing ends → display "ZANSHIN" (hold position)
//   4. After fixed pause → display "RESET" (return to kamae)
//   5. After fixed pause → "Men!" with beep + green flash → back to step 2
//
// Publishes state for SwiftUI overlays via @Published properties.

import Foundation
import Combine
import AudioToolbox
import CoreGraphics
import UIKit

@MainActor
final class CueManager: ObservableObject {

    // MARK: - Published State

    enum Phase: Equatable {
        case idle
        case countdown(remaining: Int)   // 3, 2, 1
        case countdownGo                 // "Men!" (initial)
        case active                      // waiting for swing
        case zanshin                     // hold after swing
        case reset                       // return to kamae
        case men                         // "Men!" cue (repeat)
        case ready                       // curtain done, waiting to fire Men! cue
        case earlySwing                  // "WAIT FOR CUE" warning
        case guidanceAbandoned           // user ignoring cues, suggest turning off guide
    }

    enum CurtainDirection {
        case bottomToTop, topToBottom
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var showGreenFlash: Bool = false
    @Published private(set) var curtainProgress: CGFloat = 0
    @Published private(set) var curtainDirection: CurtainDirection = .bottomToTop

    /// GO cue timestamps in IMU timebase (seconds since epoch, matching ts_ns / 1e9).
    /// Used by SessionStatsCalculator for reaction time and strike time.
    private(set) var goCueTimestampsNs: [Double] = []

    // MARK: - Configuration

    struct Config {
        var countdownTicks: Int = 3
        var countdownIntervalSec: Double = 1.0
        var postCountdownPauseSec: Double = 1.5   // pause after countdown before first Men!
        var interSwingSec: Double = 3.0        // total pause between swing end and next Men!
        var useRandomInterval: Bool = false    // randomize inter-swing timing
        var randomRangeSec: (min: Double, max: Double) = (2.0, 5.0)
        var curtainMinFillSec: Double = 1.0       // minimum curtain fill duration
        var curtainMaxFillSec: Double = 3.0       // max wait for user to settle
        var settledEnergyThreshold: Double = 2.0  // motion energy below this = settled
        var greenFlashDurationSec: Double = 0.3
        var menDisplaySec: Double = 0.8        // how long "Men!" stays on screen
        var earlySwingDisplaySec: Double = 1.0 // how long "WAIT FOR CUE" shows
        var maxConsecutiveFalseStarts: Int = 3  // abandon guidance after this many in a row
    }

    let config: Config
    let clock: SessionClock
    let logger: CueEventLogger

    /// Returns current motion energy from IMU. Set by GameViewModel.
    var motionEnergyProvider: (() -> Double)?

    /// Whether the session's cue timing data is reliable (no abandoned guidance).
    @Published private(set) var isCueDataReliable: Bool = true

    private var stopped = false
    private var consecutiveFalseStarts: Int = 0
    private var pendingCueTask: Task<Void, Never>?

    init(clock: SessionClock, logger: CueEventLogger, config: Config = Config()) {
        self.clock = clock
        self.logger = logger
        self.config = config
    }

    // MARK: - Countdown

    func startCountdown() async {
        stopped = false

        for i in stride(from: config.countdownTicks, through: 1, by: -1) {
            guard !stopped else { return }
            let scheduledMs = clock.nowMs
            phase = .countdown(remaining: i)

            let visualMs = clock.nowMs
            playBeep()
            let soundMs = clock.nowMs

            logger.log(
                type: .countdownTick,
                scheduledAtMs: scheduledMs,
                visualAtMs: visualMs,
                soundAtMs: soundMs,
                meta: ["label": "\(i)"]
            )
            flashGreen()

            try? await Task.sleep(nanoseconds: UInt64(config.countdownIntervalSec * 1_000_000_000))
        }

        guard !stopped else { return }

        // Brief pause after countdown so user can settle into ready stance
        phase = .active
        try? await Task.sleep(nanoseconds: UInt64(config.postCountdownPauseSec * 1_000_000_000))
        guard !stopped else { return }

        fireMenCue(isInitial: true)
        try? await Task.sleep(nanoseconds: UInt64(config.menDisplaySec * 1_000_000_000))
        guard !stopped else { return }
        phase = .active
    }

    // MARK: - Swing Lifecycle (called by GameViewModel)

    /// Call when SwingDetector reports a swing has ended.
    func onSwingEnded() {
        guard !stopped else { return }

        // Ignore during countdown, abandoned, or already handling an early swing
        switch phase {
        case .idle, .countdown, .countdownGo, .guidanceAbandoned, .earlySwing:
            return
        default:
            break
        }

        // Early swing: user swung during zanshin, reset, or waiting-for-Men!
        if phase != .active && phase != .men {
            handleEarlySwing()
            return
        }

        // Normal flow: proper swing after Men! cue (or during Men! display = fast reaction)
        consecutiveFalseStarts = 0
        startPostSwingSequence()
    }

    private func handleEarlySwing() {
        // Cancel any pending cue sequence
        pendingCueTask?.cancel()
        pendingCueTask = nil

        consecutiveFalseStarts += 1

        // Log as false start with negative reaction time marker
        logger.log(
            type: .falseStart,
            scheduledAtMs: clock.nowMs,
            visualAtMs: clock.nowMs,
            meta: ["consecutive": "\(consecutiveFalseStarts)", "reactionMs": "-1"]
        )

        // After too many consecutive false starts, abandon guidance
        if consecutiveFalseStarts >= config.maxConsecutiveFalseStarts {
            isCueDataReliable = false
            phase = .guidanceAbandoned
            return
        }

        // Haptic error buzz for "wait for cue"
        playErrorHaptic()

        // Show warning, then restart the zanshin → reset → delay → Men! cycle
        pendingCueTask = Task {
            phase = .earlySwing
            try? await Task.sleep(nanoseconds: UInt64(config.earlySwingDisplaySec * 1_000_000_000))
            guard !stopped, !Task.isCancelled else { return }

            startPostSwingSequence()
        }
    }

    private func startPostSwingSequence() {
        pendingCueTask?.cancel()
        pendingCueTask = Task {
            // Zanshin: curtain fills bottom → top
            phase = .zanshin
            curtainDirection = .bottomToTop
            curtainProgress = 0

            await animateCurtain()
            guard !stopped, !Task.isCancelled else { return }

            // Reset: curtain fills top → bottom
            phase = .reset
            curtainDirection = .topToBottom
            curtainProgress = 0

            await animateCurtain()
            guard !stopped, !Task.isCancelled else { return }

            // Curtain complete — user is "ready". Now wait the configured delay.
            curtainProgress = 0
            phase = .ready    // distinct from .active — swing here = early

            let delaySec: Double
            if config.useRandomInterval {
                delaySec = Double.random(in: config.randomRangeSec.min...config.randomRangeSec.max)
            } else {
                delaySec = config.interSwingSec
            }

            try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
            guard !stopped, !Task.isCancelled else { return }

            fireMenCue(isInitial: false)

            try? await Task.sleep(nanoseconds: UInt64(config.menDisplaySec * 1_000_000_000))
            guard !stopped, !Task.isCancelled else { return }
            phase = .active
        }
    }

    /// Stop all cues (call on session end).
    func stop() {
        stopped = true
        pendingCueTask?.cancel()
        pendingCueTask = nil
        phase = .idle
    }

    // MARK: - Private

    private func fireMenCue(isInitial: Bool) {
        recordGoCue()

        let scheduledMs = clock.nowMs
        phase = isInitial ? .countdownGo : .men

        let visualMs = clock.nowMs
        playBeep()
        let soundMs = clock.nowMs

        logger.log(
            type: isInitial ? .countdownGo : .postZanshinCue,
            scheduledAtMs: scheduledMs,
            visualAtMs: visualMs,
            soundAtMs: soundMs,
            meta: ["label": "Men!"]
        )
        flashGreen()
    }

    private func recordGoCue() {
        let tsNsSec = Double(clock.startTsNs) / 1_000_000_000.0 +
            (ProcessInfo.processInfo.systemUptime - clock.startUptime)
        goCueTimestampsNs.append(tsNsSec)
    }

    private func flashGreen() {
        showGreenFlash = true
        Task {
            try? await Task.sleep(nanoseconds: UInt64(config.greenFlashDurationSec * 1_000_000_000))
            showGreenFlash = false
        }
    }

    /// Animate curtain fill, adapting to user's pace.
    /// Fills at minimum pace over `curtainMinFillSec`, but won't complete
    /// until motion energy drops below threshold (up to `curtainMaxFillSec`).
    private func animateCurtain() async {
        let steps = 30
        let minStepDuration = config.curtainMinFillSec / Double(steps)
        let startTime = ProcessInfo.processInfo.systemUptime

        for i in 1...steps {
            guard !stopped, !Task.isCancelled else { return }
            curtainProgress = CGFloat(i) / CGFloat(steps)
            try? await Task.sleep(nanoseconds: UInt64(minStepDuration * 1_000_000_000))
        }

        // Curtain visually full — now wait for user to actually settle
        let elapsed = ProcessInfo.processInfo.systemUptime - startTime
        let remainingWait = config.curtainMaxFillSec - elapsed
        if remainingWait > 0, let provider = motionEnergyProvider {
            let pollInterval: Double = 0.05  // 50ms
            var waited: Double = 0
            while waited < remainingWait, !stopped, !Task.isCancelled {
                let energy = provider()
                if energy < config.settledEnergyThreshold {
                    break
                }
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                waited += pollInterval
            }
        }
    }

    private func playBeep() {
        guard AudioService.shared.isSFXEnabled else { return }
        AudioServicesPlaySystemSound(1052)
    }

    private func playErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
