import SwiftUI

struct ReportView: View {
    let session: Session
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var gameViewModel: GameViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentStreak = 0
    @State private var isLoading = true
    @State private var showVisualization = false
    @State private var showTrajectory = false

    // Data quality tracking
    @State private var actualSwings: String = ""
    @State private var sessionQuality: SessionQuality = .good
    @State private var issueReason: IssueReason = .phoneSlipped
    @State private var otherReasonText: String = ""
    @State private var isEditingSwings = false

    enum SessionQuality: String, CaseIterable {
        case good = "Good session"
        case practice = "Practice/testing"
        case issues = "Had issues"
    }

    enum IssueReason: String, CaseIterable {
        case phoneSlipped = "Phone slipped/fell"
        case interrupted = "Session interrupted"
        case testing = "Just testing features"
        case notSwings = "Other movement (not swings)"
        case other = "Other"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.1)

                        // Title
                        Text("SESSION REPORT")
                            .font(.pixelifyTitle)
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 4, x: 0, y: 2)
                            .padding(.bottom, 24)

                    // Results Box
                    VStack(spacing: 24) {
                        // Tap Count
                        HStack {
                            Text("TOTAL TAPS:")
                                .font(.pixelifyBodyBold)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(session.tapCount)")
                                .font(.pixelify(size: 24, weight: .bold))
                                .foregroundColor(.green)
                        }

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Duration
                        HStack {
                            Text("DURATION:")
                                .font(.pixelifyBodyBold)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatDuration(session.duration))
                                .font(.pixelify(size: 20, weight: .semiBold))
                                .foregroundColor(.cyan)
                        }

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Current Streak
                        HStack {
                            Text("CURRENT STREAK:")
                                .font(.pixelifyBodyBold)
                                .foregroundColor(.white)
                            Spacer()
                            if isLoading {
                                Text("...")
                                    .font(.pixelify(size: 20, weight: .semiBold))
                                    .foregroundColor(.yellow)
                            } else {
                                Text("\(currentStreak) DAYS")
                                    .font(.pixelify(size: 20, weight: .semiBold))
                                    .foregroundColor(.yellow)
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.3))

                        // Actual Swings (Editable)
                        swingCountEditor
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                        Spacer()
                            .frame(height: 20)

                        // Session Quality Section
                        qualitySection

                        Spacer()
                            .frame(height: 20)

                        // Visualization Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showVisualization.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(showVisualization ? "HIDE DATA" : "SHOW DATA")
                                    .font(.pixelifyButton)
                                Image(systemName: showVisualization ? "chevron.up" : "chart.xyaxis.line")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                            .frame(height: 48)
                            .background(Color.cyan)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .padding(.horizontal, 20)

                        // IMU Visualization (collapsible)
                        if showVisualization {
                            IMUPlotView(samples: gameViewModel.imuSamples)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        Spacer()
                            .frame(height: 20)

                        // Trajectory Visualization Button
                        if let integrationResult = gameViewModel.integrationResult {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showTrajectory.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(showTrajectory ? "HIDE TRAJECTORY" : "SHOW TRAJECTORY")
                                        .font(.pixelifyButton)
                                    Image(systemName: showTrajectory ? "chevron.up" : "move.3d")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                .frame(height: 48)
                                .background(Color.purple)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .padding(.horizontal, 20)

                            // Position Trajectory Visualization (collapsible)
                            if showTrajectory {
                                PositionTrajectoryView(
                                    integrationResult: integrationResult,
                                    swings: gameViewModel.detectedSwings
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            Spacer()
                                .frame(height: 20)
                        }

                        // Continue Button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("CONTINUE")
                                .font(.pixelifyButtonLarge)
                                .foregroundColor(.black)
                                .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                .frame(height: 56)
                                .background(Color.green)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))

                        // Extra bottom padding to ensure content is fully visible
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            // Initialize actual swings with tap count
            actualSwings = "\(session.tapCount)"
            submitSessionData()
        }
    }

    // MARK: - Subviews

    private var swingCountEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTUAL SWINGS:")
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)

            HStack {
                TextField("", text: $actualSwings)
                    .font(.pixelify(size: 24, weight: .bold))
                    .foregroundColor(.green)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )

                Image(systemName: "pencil.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)

                Spacer()

                Text("(Tap to edit)")
                    .font(.pixelify(size: 10, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
                Text("Session Quality")
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.white)
            }

            Text("(helps us improve the app)")
                .font(.pixelify(size: 10, weight: .regular))
                .foregroundColor(.gray)

            qualityRadioButtons

            if sessionQuality == .issues {
                issueReasonSection
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal, 20)
    }

    private var qualityRadioButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SessionQuality.allCases, id: \.self) { quality in
                Button(action: {
                    sessionQuality = quality
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: sessionQuality == quality ? "circle.inset.filled" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(sessionQuality == quality ? .green : .white.opacity(0.6))

                        Text(quality.rawValue)
                            .font(.pixelify(size: 14, weight: .regular))
                            .foregroundColor(.white)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var issueReasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What happened?")
                .font(.pixelify(size: 12, weight: .semiBold))
                .foregroundColor(.white.opacity(0.8))

            Picker("Reason", selection: $issueReason) {
                ForEach(IssueReason.allCases, id: \.self) { reason in
                    Text(reason.rawValue).tag(reason)
                }
            }
            .pickerStyle(.menu)
            .tint(.cyan)
            .font(.pixelify(size: 14, weight: .regular))
            .padding(8)
            .background(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )

            if issueReason == .other {
                otherReasonTextField
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var otherReasonTextField: some View {
        TextField("Please describe...", text: $otherReasonText)
            .font(.pixelify(size: 12, weight: .regular))
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
            )
    }

    // MARK: - Helper Functions

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func submitSessionData() {
        guard let userId = authViewModel.currentUser?.id else { return }

        Task {
            do {
                // Submit to Azure database
                let result = try await APIService.shared.submitSession(session)

                await MainActor.run {
                    self.currentStreak = result.streak
                    self.isLoading = false
                    self.authViewModel.currentUser = result.updatedUser
                }
            } catch {
                print("Failed to submit session: \(error)")

                // Fallback to local calculation
                await MainActor.run {
                    self.currentStreak = LocalStorageService.shared.getStreakForUser(userId)
                    self.isLoading = false

                    if var user = authViewModel.currentUser {
                        user.totalCount += session.tapCount
                        user.streak = self.currentStreak
                        user.lastSessionDate = session.date
                        authViewModel.currentUser = user
                        LocalStorageService.shared.saveUser(user)
                    }
                }
            }

            // Log quality data (will be sent to backend in future implementation)
            logQualityData()
        }

        print("Submitting session data: \(session)")
    }

    private func logQualityData() {
        let swingCount = Int(actualSwings) ?? session.tapCount
        let issueReasonString: String? = {
            if sessionQuality == .issues {
                if issueReason == .other {
                    return "other: \(otherReasonText)"
                } else {
                    return issueReason.rawValue
                }
            }
            return nil
        }()

        print("""
        📊 Session Quality Data:
           - Tap Count: \(session.tapCount)
           - User Reported Swings: \(swingCount)
           - Quality: \(sessionQuality.rawValue)
           - Issue Reason: \(issueReasonString ?? "N/A")
           - IMU Samples: \(gameViewModel.imuSamples.count)
        """)

        // TODO: Send to backend when API endpoint is ready
        // let qualityData = SessionQualityData(
        //     sessionId: session.id,
        //     tapCount: session.tapCount,
        //     userReportedSwings: swingCount,
        //     quality: sessionQuality.rawValue,
        //     issueReason: issueReasonString,
        //     imuSampleCount: gameViewModel.imuSamples.count
        // )
        // try await APIService.shared.submitQualityData(qualityData)
    }
}