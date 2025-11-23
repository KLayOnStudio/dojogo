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

    // Edit mode states for each field
    @State private var isEditingNickname = false
    @State private var isEditingRank = false
    @State private var isEditingExperience = false

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

                                    Spacer()

                                    if isEditingNickname {
                                        Button(action: { saveNickname() }) {
                                            Text("CONFIRM")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.green)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                        .disabled(isLoading)

                                        Button(action: {
                                            isEditingNickname = false
                                            loadUserData()  // Reset to original value
                                        }) {
                                            Text("CANCEL")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                    } else if user.canChangeNickname {
                                        Button(action: { isEditingNickname = true }) {
                                            Text("EDIT")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                    }
                                }

                                HStack {
                                    if isEditingNickname {
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
                                            .background(Color.gray.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(Color.yellow, lineWidth: 2)
                                            )
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    } else {
                                        Text(user.nickname ?? "Not set")
                                            .font(.pixelifyBody)
                                            .foregroundColor(user.nickname != nil ? .white : .gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 14)
                                            .background(Color.gray.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }

                                if !user.canChangeNickname, let lastChanged = user.nicknameLastChanged {
                                    let daysSinceChange = Calendar.current.dateComponents([.day], from: lastChanged, to: Date()).day ?? 0
                                    let daysRemaining = 14 - daysSinceChange
                                    Text("Can change in \(daysRemaining) days")
                                        .font(.pixelify(size: 9))
                                        .foregroundColor(.orange)
                                } else {
                                    Text("3-50 characters • Changes limited to once per 14 days")
                                        .font(.pixelify(size: 9))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 20)

                            // Kendo Rank Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("KENDO RANK")
                                        .font(.pixelifyBodyBold)
                                        .foregroundColor(.white)

                                    Spacer()

                                    if isEditingRank {
                                        Button(action: { saveRank() }) {
                                            Text("CONFIRM")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.green)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                        .disabled(isLoading)

                                        Button(action: {
                                            isEditingRank = false
                                            loadUserData()  // Reset to original value
                                        }) {
                                            Text("CANCEL")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                    } else {
                                        Button(action: { isEditingRank = true }) {
                                            Text("EDIT")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                    }
                                }

                                if isEditingRank {
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
                                        .background(Color.gray.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.yellow, lineWidth: 2)
                                        )
                                    }
                                } else {
                                    Text((user.kendoRank ?? .unranked).displayName)
                                        .font(.pixelifyBody)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 20)

                            // Kendo Experience Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("KENDO EXPERIENCE")
                                        .font(.pixelifyBodyBold)
                                        .foregroundColor(.white)

                                    Spacer()

                                    if isEditingExperience {
                                        Button(action: { saveExperience() }) {
                                            Text("CONFIRM")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.green)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                        .disabled(isLoading)

                                        Button(action: {
                                            isEditingExperience = false
                                            loadUserData()  // Reset to original value
                                        }) {
                                            Text("CANCEL")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                    } else {
                                        Button(action: { isEditingExperience = true }) {
                                            Text("EDIT")
                                                .font(.pixelify(size: 10))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 0)
                                                        .stroke(Color.white, lineWidth: 1)
                                                )
                                        }
                                    }
                                }

                                if isEditingExperience {
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
                                            .background(Color.gray.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(Color.yellow, lineWidth: 2)
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
                                            .background(Color.gray.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(Color.yellow, lineWidth: 2)
                                            )
                                        }
                                    }
                                } else {
                                    Text("\(user.kendoExperienceYears) years, \(user.kendoExperienceMonths) months")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 0)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal, 20)

                            // Messages
                            if let error = errorMessage {
                                Text(error)
                                    .font(.pixelifySmall)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }

                            if let success = successMessage {
                                Text(success)
                                    .font(.pixelifySmall)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }

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

        // Debug nickname change date
        if let lastChanged = user.nicknameLastChanged {
            let daysSinceChange = Calendar.current.dateComponents([.day], from: lastChanged, to: Date()).day ?? 0
            let daysRemaining = 14 - daysSinceChange
            print("DEBUG ProfileView: lastChanged=\(lastChanged), daysSinceChange=\(daysSinceChange), daysRemaining=\(daysRemaining), canChange=\(user.canChangeNickname)")
        } else {
            print("DEBUG ProfileView: nicknameLastChanged is nil")
        }

        nickname = user.nickname ?? ""
        selectedRank = user.kendoRank ?? .unranked
        experienceYears = user.kendoExperienceYears
        experienceMonths = user.kendoExperienceMonths
    }

    // MARK: - Individual Save Functions

    private func saveNickname() {
        guard let user = authViewModel.currentUser else { return }
        guard !nickname.isEmpty && nickname != user.nickname else {
            errorMessage = "No changes to save"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: nickname,
                    kendoRank: nil,
                    experienceYears: nil,
                    experienceMonths: nil
                )

                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    LocalStorageService.shared.saveUser(updatedUser)
                    successMessage = "Nickname updated successfully!"
                    isLoading = false
                    isEditingNickname = false
                    loadUserData()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if error.localizedDescription.contains("already taken") {
                        errorMessage = "This nickname is already taken"
                    } else if error.localizedDescription.contains("days") {
                        errorMessage = error.localizedDescription
                    } else {
                        errorMessage = "Failed to update nickname: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func saveRank() {
        guard let user = authViewModel.currentUser else { return }
        guard selectedRank != user.kendoRank else {
            errorMessage = "No changes to save"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: nil,
                    kendoRank: selectedRank,
                    experienceYears: nil,
                    experienceMonths: nil
                )

                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    LocalStorageService.shared.saveUser(updatedUser)
                    successMessage = "Kendo rank updated successfully!"
                    isLoading = false
                    isEditingRank = false
                    loadUserData()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update rank: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveExperience() {
        guard let user = authViewModel.currentUser else { return }
        guard experienceYears != user.kendoExperienceYears || experienceMonths != user.kendoExperienceMonths else {
            errorMessage = "No changes to save"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: nil,
                    kendoRank: nil,
                    experienceYears: experienceYears,
                    experienceMonths: experienceMonths
                )

                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    LocalStorageService.shared.saveUser(updatedUser)
                    successMessage = "Experience updated successfully!"
                    isLoading = false
                    isEditingExperience = false
                    loadUserData()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update experience: \(error.localizedDescription)"
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
