import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var nickname: String = ""
    @State private var selectedRank: KendoRank = .unranked
    @State private var experienceYears: Int = 0
    @State private var experienceMonths: Int = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            Button(action: { dismiss() }) {
                                Text("← BACK")
                                    .font(.pixelifyButton)
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            Text("PROFILE")
                                .font(.pixelifyHeadline)
                                .foregroundColor(.white)

                            Spacer()
                                .frame(width: 80)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))

                        if let user = authViewModel.currentUser {
                            // User Stats Card
                            VStack(spacing: 16) {
                                // Display Name
                                Text(user.displayName)
                                    .font(.pixelifyTitle)
                                    .foregroundColor(.white)

                                // User Number
                                if let userNumber = user.userNumber {
                                    Text("Player #\(userNumber)")
                                        .font(.pixelifySmall)
                                        .foregroundColor(.gray)
                                }

                                Divider()
                                    .background(Color.white.opacity(0.2))

                                // Stats Grid
                                HStack(spacing: 20) {
                                    StatBox(title: "STREAK", value: "\(user.streak)", color: .orange)
                                    StatBox(title: "TOTAL TAPS", value: "\(user.totalCount)", color: .green)
                                }
                            }
                            .padding(20)
                            .background(Color.gray.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)

                            // Nickname Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("NICKNAME")
                                        .font(.pixelifyBodyBold)
                                        .foregroundColor(.white)

                                    if !user.canChangeNickname, let lastChanged = user.nicknameLastChanged {
                                        let daysRemaining = 30 - Calendar.current.dateComponents([.day], from: lastChanged, to: Date()).day!
                                        Text("(\(daysRemaining) days until change)")
                                            .font(.pixelify(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                }

                                TextField("", text: $nickname)
                                    .placeholder(when: nickname.isEmpty) {
                                        Text("Enter nickname")
                                            .font(.pixelifyBody)
                                            .foregroundColor(.gray)
                                    }
                                    .font(.pixelifyBody)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.gray.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .disabled(!user.canChangeNickname)
                                    .opacity(user.canChangeNickname ? 1.0 : 0.5)

                                Text("3-50 characters • Changes limited to once per 30 days")
                                    .font(.pixelify(size: 9))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 20)

                            // Kendo Rank Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("KENDO RANK")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)

                                Menu {
                                    ForEach(KendoRank.allCases, id: \.self) { rank in
                                        Button(action: {
                                            selectedRank = rank
                                        }) {
                                            Text(rank.displayName)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedRank.displayName)
                                            .font(.pixelifyBody)
                                            .foregroundColor(.white)

                                        Spacer()

                                        Text("▼")
                                            .font(.pixelify(size: 12))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.gray.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)

                            // Kendo Experience Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("KENDO EXPERIENCE")
                                    .font(.pixelifyBodyBold)
                                    .foregroundColor(.white)

                                HStack(spacing: 12) {
                                    // Years input
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Years")
                                            .font(.pixelify(size: 10))
                                            .foregroundColor(.gray)

                                        Picker("Years", selection: $experienceYears) {
                                            ForEach(0...50, id: \.self) { year in
                                                Text("\(year)").tag(year)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    }

                                    // Months input
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Months")
                                            .font(.pixelify(size: 10))
                                            .foregroundColor(.gray)

                                        Picker("Months", selection: $experienceMonths) {
                                            ForEach(0...11, id: \.self) { month in
                                                Text("\(month)").tag(month)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.gray.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)

                            // Messages
                            if let error = errorMessage {
                                Text(error)
                                    .font(.pixelifySmall)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                            }

                            if let success = successMessage {
                                Text(success)
                                    .font(.pixelifySmall)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 20)
                            }

                            // Save Button
                            Button(action: {
                                saveProfile()
                            }) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.yellow)
                                } else {
                                    Text("SAVE CHANGES")
                                        .font(.pixelifyButton)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color.yellow)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                }
                            }
                            .disabled(isLoading)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            Spacer()
                        }
                    }
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                }
            }
        }
        .onAppear {
            // Load from cached user data first
            loadUserData()
        }
    }

    private func refreshUserData() {
        guard let userId = authViewModel.currentUser?.id else {
            print("ProfileView: No current user found")
            return
        }

        Task {
            do {
                let freshUser = try await APIService.shared.getUser(id: userId)
                await MainActor.run {
                    authViewModel.currentUser = freshUser
                    loadUserData()
                }
            } catch {
                print("ProfileView: Failed to refresh user data: \(error)")
                // Fallback to cached data
                loadUserData()
            }
        }
    }

    private func loadUserData() {
        guard let user = authViewModel.currentUser else {
            print("ProfileView: No current user found")
            return
        }
        print("ProfileView: Loading user data - nickname: \(user.nickname ?? "nil"), rank: \(user.kendoRank?.rawValue ?? "nil"), years: \(user.kendoExperienceYears), months: \(user.kendoExperienceMonths)")
        nickname = user.nickname ?? ""
        selectedRank = user.kendoRank ?? .unranked
        experienceYears = user.kendoExperienceYears
        experienceMonths = user.kendoExperienceMonths
    }

    private func saveProfile() {
        guard let user = authViewModel.currentUser else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                // Determine what changed
                let nicknameChanged = !nickname.isEmpty && nickname != user.nickname
                let rankChanged = selectedRank != user.kendoRank
                let experienceYearsChanged = experienceYears != user.kendoExperienceYears
                let experienceMonthsChanged = experienceMonths != user.kendoExperienceMonths

                if !nicknameChanged && !rankChanged && !experienceYearsChanged && !experienceMonthsChanged {
                    await MainActor.run {
                        errorMessage = "No changes to save"
                        isLoading = false
                    }
                    return
                }

                // Update profile
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: nicknameChanged ? nickname : nil,
                    kendoRank: rankChanged ? selectedRank : nil,
                    experienceYears: experienceYearsChanged ? experienceYears : nil,
                    experienceMonths: experienceMonthsChanged ? experienceMonths : nil
                )

                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    successMessage = "Profile updated successfully!"
                    isLoading = false
                    // Reload the UI with updated data
                    loadUserData()
                }
            } catch {
                print("ProfileView: Save failed with error: \(error)")
                print("ProfileView: Error type: \(type(of: error))")
                print("ProfileView: Error description: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    if error.localizedDescription.contains("already taken") {
                        errorMessage = "This nickname is already taken"
                    } else if error.localizedDescription.contains("days") {
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

// Stat Box Component
struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.pixelifyTitle)
                .foregroundColor(color)

            Text(title)
                .font(.pixelify(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
    }
}
