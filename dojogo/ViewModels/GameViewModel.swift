import Foundation
import SwiftUI

@MainActor
class GameViewModel: ObservableObject {
    @Published var currentSession: Session?
    @Published var isSessionActive = false
    @Published var sessionStartTime: Date?
    @Published var sessions: [Session] = []

    // Live swing count (updated periodically during session)
    @Published var liveSwingCount: Int = 0

    // IMU Manager (simulator uses mock, device uses real CoreMotion)
    #if targetEnvironment(simulator)
    private var imuManager = MockIMUManager()
    #else
    private var imuManager = RealIMUManager()
    #endif

    // Swing detection and integration
    private let swingDetector = SwingDetector()
    private let integrationEngine = IntegrationEngine()
    @Published var detectedSwings: [SwingSegment] = []
    @Published var integrationResult: IntegrationResult?

    // Session stats (computed on session end)
    @Published var sessionStats: SessionStats?

    // Sensor mode (set before session start)
    @Published var sensorMode: SensorMode = .phone

    // Guided practice state (on by default, user can toggle off)
    @Published var isGuidedMode: Bool = true
    @Published var interSwingSec: Double = 3.0
    @Published var useRandomInterval: Bool = false

    // Stage mode
    @Published var currentStageId: Int?
    private var stageCueConfig: CueManager.Config?

    // Guided cue system
    private(set) var sessionClock: SessionClock?
    @Published var cueManager: CueManager?
    private var cueLogger: CueEventLogger?

    // Real-time swing detection timer
    private var swingDetectionTimer: Timer?

    // Public getter for IMU samples
    var imuSamples: [IMUSample] {
        return imuManager.samples
    }

    // Public getter for cue events (guided mode only)
    var cueEvents: [CueEvent] {
        return cueLogger?.events ?? []
    }

    func configureForStage(_ stage: Stage) {
        currentStageId = stage.id
        isGuidedMode = true
        interSwingSec = stage.cueConfig.interSwingSec
        useRandomInterval = stage.cueConfig.useRandomInterval
        stageCueConfig = stage.toCueManagerConfig()
    }

    func configureForFreePractice() {
        currentStageId = nil
        stageCueConfig = nil
    }

    func startSession(userId: String) {
        isSessionActive = true
        sessionStartTime = Date()
        sessionStats = nil
        liveSwingCount = 0
        detectedSwings = []

        // Initialize guided cue system only when guided mode is on
        if isGuidedMode {
            let clock = SessionClock()
            sessionClock = clock
            let logger = CueEventLogger(clock: clock)
            cueLogger = logger
            let cueConfig: CueManager.Config
            if let stageConfig = stageCueConfig {
                cueConfig = stageConfig
            } else {
                var cfg = CueManager.Config()
                cfg.interSwingSec = interSwingSec
                cfg.useRandomInterval = useRandomInterval
                cueConfig = cfg
            }
            let cm = CueManager(clock: clock, logger: logger, config: cueConfig)
            cm.motionEnergyProvider = { [weak self] in
                guard let self, let last = self.imuManager.samples.last else { return 0 }
                return self.swingDetector.motionEnergy(for: last)
            }
            cueManager = cm
        } else {
            sessionClock = nil
            cueLogger = nil
            cueManager = nil
        }

        // Start IMU recording (mock on simulator, real on device)
        imuManager.startRecording()

        // Start periodic swing detection (~1 Hz)
        swingDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveSwingCount()
            }
        }

        // Guided countdown is triggered from ActionView.onAppear
        // so overlays are visible when it fires

        // Log session start to database
        Task {
            do {
                try await APIService.shared.logSessionStart(userId: userId)
                print("Session start logged for user: \(userId)")
            } catch {
                print("Failed to log session start: \(error.localizedDescription)")
            }
        }
    }

    func endSession(userId: String) {
        guard let startTime = sessionStartTime else { return }

        // Stop periodic detection
        swingDetectionTimer?.invalidate()
        swingDetectionTimer = nil

        // Stop cue manager
        cueManager?.stop()

        let endTime = Date()

        isSessionActive = false

        // Stop IMU recording
        imuManager.stopRecording()
        let sampleCount = imuManager.samples.count
        print("IMU recording stopped. Total samples: \(sampleCount)")

        // Final swing detection (authoritative)
        if sampleCount > 0 {
            detectedSwings = swingDetector.detectSwings(in: imuManager.samples)
            print("\n" + swingDetector.diagnostics(for: imuManager.samples))

            // Integrate to get velocity and position
            integrationResult = integrationEngine.integrate(samples: imuManager.samples)
            if let result = integrationResult {
                print("\n" + integrationEngine.diagnostics(for: result))
            }

            // Compute session stats
            let cueTimestamps = isGuidedMode ? cueManager?.goCueTimestampsNs : nil
            sessionStats = SessionStatsCalculator.compute(
                samples: imuManager.samples,
                swings: detectedSwings,
                goCueTimestamps: cueTimestamps
            )
            if let stats = sessionStats {
                print("""
                Session Stats:
                   Swings: \(stats.swingCount)
                   Duration: \(String(format: "%.1f", stats.durationSec))s
                   Tempo: \(stats.tempo.map { String(format: "%.1f/min", $0) } ?? "—")
                   Avg Speed: \(stats.avgSpeed.map { String(format: "%.1f rad/s", $0) } ?? "—")
                   Max Power: \(stats.maxPower.map { String(format: "%.1f m/s²", $0) } ?? "—")
                """)
            }
        }

        let session = Session(
            userId: userId,
            swingCount: detectedSwings.count,
            startTime: startTime,
            endTime: endTime,
            mode: isGuidedMode ? .guided : .free,
            stageId: currentStageId,
            sensorMode: sensorMode
        )

        currentSession = session
        sessions.append(session)
        liveSwingCount = detectedSwings.count

        // Log cue events count
        if let logger = cueLogger, !logger.events.isEmpty {
            print("Cue events recorded: \(logger.events.count)")
        }

        // Save locally
        saveSessionLocally(session)

        // Save stats alongside session for Insights
        if let stats = sessionStats {
            LocalStorageService.shared.saveSessionStats(stats, for: session.id)
        }
    }

    // MARK: - Private

    private func updateLiveSwingCount() {
        guard isSessionActive, imuManager.samples.count > 10 else { return }
        let swings = swingDetector.detectSwings(in: imuManager.samples)
        let previousCount = liveSwingCount
        liveSwingCount = swings.count

        // Notify cue manager when a new swing is detected
        if swings.count > previousCount, isGuidedMode {
            cueManager?.onSwingEnded()
        }
    }

    private func saveSessionLocally(_ session: Session) {
        LocalStorageService.shared.saveSession(session)
        print("Session saved locally: \(session)")
    }
}
