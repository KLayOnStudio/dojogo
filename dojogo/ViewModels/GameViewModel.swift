import Foundation
import SwiftUI

@MainActor
class GameViewModel: ObservableObject {
    @Published var currentSession: Session?
    @Published var tapCount = 0
    @Published var isSessionActive = false
    @Published var buttonPosition = CGPoint(x: 100, y: 100)
    @Published var sessionStartTime: Date?
    @Published var lastTapTime: Date?
    @Published var sessions: [Session] = []

    private var inactivityTimer: Timer?
    private let inactivityTimeout: TimeInterval = 20.0

    func startSession(userId: String) {
        tapCount = 0
        isSessionActive = true
        sessionStartTime = Date()
        lastTapTime = Date()
        randomizeButtonPosition()
        startInactivityTimer()

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

        // Save locally
        saveSessionLocally(session)
    }

    func handleTap(userId: String) {
        guard isSessionActive else { return }

        tapCount += 1
        lastTapTime = Date()
        randomizeButtonPosition()

        // Reset inactivity timer
        startInactivityTimer()
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