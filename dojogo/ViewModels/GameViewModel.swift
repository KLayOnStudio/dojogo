import Foundation
import SwiftUI
import AVFoundation

@MainActor
class GameViewModel: ObservableObject {
    @Published var currentSession: Session?
    @Published var tapCount = 0
    @Published var isSessionActive = false
    @Published var buttonPosition = CGPoint(x: 100, y: 100)
    @Published var sessionStartTime: Date?
    @Published var lastTapTime: Date?
    @Published var sessions: [Session] = []
    @Published var isSoundEnabled = true

    private var inactivityTimer: Timer?
    private let inactivityTimeout: TimeInterval = 20.0
    private var audioPlayer: AVAudioPlayer?

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

    init() {
        setupAudioPlayer()
    }

    private func setupAudioPlayer() {
        guard let soundURL = Bundle.main.url(forResource: "SFXswoosh", withExtension: "mp3") else {
            print("Sound file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }

    func startSession(userId: String) {
        tapCount = 0
        isSessionActive = true
        sessionStartTime = Date()
        lastTapTime = Date()
        randomizeButtonPosition()
        startInactivityTimer()

        // Start IMU recording (mock on simulator, real on device)
        imuManager.startRecording()

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

    // Public getter for IMU samples
    var imuSamples: [IMUSample] {
        return imuManager.samples
    }

    func endSession(userId: String) {
        guard let startTime = sessionStartTime else { return }

        let endTime = Date()
        let session = Session(
            userId: userId,
            tapCount: tapCount,
            startTime: startTime,
            endTime: endTime
        )

        currentSession = session
        sessions.append(session)
        isSessionActive = false
        inactivityTimer?.invalidate()

        // Stop IMU recording (mock on simulator, real on device)
        imuManager.stopRecording()
        let sampleCount = imuManager.samples.count
        print("🎯 IMU recording stopped. Total samples: \(sampleCount)")

        // Analyze IMU data
        if sampleCount > 0 {
            // Detect swings
            detectedSwings = swingDetector.detectSwings(in: imuManager.samples)
            print("\n" + swingDetector.diagnostics(for: imuManager.samples))

            // Integrate to get velocity and position
            integrationResult = integrationEngine.integrate(samples: imuManager.samples)
            if let result = integrationResult {
                print("\n" + integrationEngine.diagnostics(for: result))
            }

            // Log first few samples for debugging
            print("\n📊 Sample data preview (full sensor suite):")
            for i in 0..<min(3, sampleCount) {
                let s = imuManager.samples[i]
                print("  [\(i)] User accel: (\(s.ax), \(s.ay), \(s.az)) m/s²")
                print("       Raw accel:  (\(s.raw_ax), \(s.raw_ay), \(s.raw_az)) m/s²")
                print("       Gyro:       (\(s.gx), \(s.gy), \(s.gz)) rad/s")
                print("       Quat:       (\(s.qw), \(s.qx), \(s.qy), \(s.qz))")
                if let mx = s.mx, let my = s.my, let mz = s.mz {
                    print("       Mag:        (\(mx), \(my), \(mz)) µT")
                }
            }
        }

        // Save locally
        saveSessionLocally(session)
    }

    func handleTap(userId: String) {
        guard isSessionActive else { return }

        tapCount += 1
        lastTapTime = Date()
        randomizeButtonPosition()
        playTapSound()

        // Trigger swing (only affects mock on simulator)
        imuManager.triggerSwing()

        // Reset inactivity timer
        startInactivityTimer()
    }

    private func playTapSound() {
        guard isSoundEnabled else { return }
        audioPlayer?.currentTime = 0 // Reset to start for rapid taps
        audioPlayer?.play()
    }

    func toggleSound() {
        isSoundEnabled.toggle()
    }

    private func randomizeButtonPosition() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let buttonSize: CGFloat = 60

        let x = CGFloat.random(in: buttonSize...(screenWidth - buttonSize))
        let y = CGFloat.random(in: buttonSize...(screenHeight - buttonSize))

        buttonPosition = CGPoint(x: x, y: y)
    }

    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { _ in
            Task { @MainActor in
                if let userId = self.currentUserId {
                    self.endSession(userId: userId)
                }
            }
        }
    }

    private var currentUserId: String? {
        // TODO: Get from AuthViewModel
        return "temp_user_id"
    }

    private func saveSessionLocally(_ session: Session) {
        LocalStorageService.shared.saveSession(session)
        print("Session saved locally: \(session)")
    }
}