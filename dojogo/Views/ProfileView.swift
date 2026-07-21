import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var nickname: String = ""
    @State private var selectedRank: KendoRank = .unranked
    @State private var experienceYears: Int = 0
    @State private var experienceMonths: Int = 0
    @State private var homeDojo: String = ""
    @State private var isPublic: Bool = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Edit mode
    @State private var isEditing = false

    // Avatar selection
    private let avatars = LocalStorageService.availableAvatars
    @State private var selectedAvatarIndex: Int = 0

    // Dojo autocomplete
    @State private var allDojoNames: [String] = []
    @State private var showDojoSuggestions = false

    // Clipboard feedback
    @State private var copiedToClipboard = false

    // Navigation
    @State private var showAbout = false
    @State private var showBetaInvite = false

    private let rankCases = KendoRank.allCases

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            Button(action: { dismiss() }) {
                                Text("← BACK")
                                    .font(.pixelifyButton)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(PixelButtonStyle())

                            Spacer()

                            Text("PROFILE")
                                .font(.pixelifyHeadline)
                                .foregroundColor(.white)

                            Spacer()
                                .frame(width: 80)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))

                        // Avatar Picker (always live — saves immediately)
                        VStack(spacing: 12) {
                            Text("AVATAR")
                                .font(.pixelifyBodyBold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)

                            HStack(spacing: 24) {
                                Button(action: {
                                    selectedAvatarIndex = (selectedAvatarIndex - 1 + avatars.count) % avatars.count
                                    syncAvatar(avatars[selectedAvatarIndex])
                                }) {
                                    Text("◀")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.gray.opacity(0.3))
                                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }

                                VStack(spacing: 8) {
                                    Image(avatars[selectedAvatarIndex])
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 96, height: 96)

                                    Text("\(selectedAvatarIndex + 1) / \(avatars.count)")
                                        .font(.pixelify(size: 10))
                                        .foregroundColor(.gray)
                                }

                                Button(action: {
                                    selectedAvatarIndex = (selectedAvatarIndex + 1) % avatars.count
                                    syncAvatar(avatars[selectedAvatarIndex])
                                }) {
                                    Text("▶")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.gray.opacity(0.3))
                                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gray.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .padding(.horizontal, 20)
                        }

                        if let user = authViewModel.currentUser {
                            // User Stats Card
                            VStack(spacing: 16) {
                                Text(user.displayName)
                                    .font(.pixelifyTitle)
                                    .foregroundColor(.white)

                                if let userNumber = user.userNumber {
                                    Button(action: {
                                        UIPasteboard.general.string = "#\(userNumber)"
                                        copiedToClipboard = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedToClipboard = false }
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("Player #\(userNumber)")
                                                .font(.pixelifySmall)
                                                .foregroundColor(.gray)
                                            Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 10))
                                                .foregroundColor(copiedToClipboard ? .green : .gray)
                                        }
                                    }
                                }

                                Divider().background(Color.white.opacity(0.2))

                                HStack(spacing: 20) {
                                    StatBox(title: "STREAK", value: "\(user.streak)", color: .orange)
                                    StatBox(title: "TOTAL SWINGS", value: "\(user.totalCount)", color: .green)
                                }
                            }
                            .padding(20)
                            .background(Color.gray.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .padding(.horizontal, 20)

                            // Edit Profile Button
                            if !isEditing {
                                Button(action: { isEditing = true }) {
                                    Text("EDIT PROFILE")
                                        .font(.pixelifyBodyBold)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.yellow)
                                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                                .buttonStyle(PixelButtonStyle())
                                .padding(.horizontal, 20)
                            }

                            // Profile Fields
                            VStack(spacing: 20) {
                                // Nickname
                                profileField(label: "NICKNAME") {
                                    if isEditing {
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
                                            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    } else {
                                        fieldDisplay(user.nickname ?? "Not set", muted: user.nickname == nil)
                                    }
                                }

                                // Kendo Rank
                                profileField(label: "KENDO RANK") {
                                    if isEditing {
                                        rankStepper
                                    } else {
                                        fieldDisplay((user.kendoRank ?? .unranked).displayName)
                                    }
                                }

                                // Kendo Experience
                                profileField(label: "KENDO EXPERIENCE") {
                                    if isEditing {
                                        experienceStepper
                                    } else {
                                        fieldDisplay("\(user.kendoExperienceYears) years, \(user.kendoExperienceMonths) months")
                                    }
                                }

                                // Home Dojo
                                profileField(label: "HOME DOJO") {
                                    if isEditing {
                                        VStack(alignment: .leading, spacing: 0) {
                                            TextField("", text: $homeDojo)
                                                .placeholder(when: homeDojo.isEmpty) {
                                                    Text("Enter your home dojo")
                                                        .font(.pixelifyBody)
                                                        .foregroundColor(.gray)
                                                }
                                                .font(.pixelifyBody)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 14)
                                                .background(Color.gray.opacity(0.3))
                                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
                                                .autocapitalization(.words)
                                                .disableAutocorrection(true)
                                                .onChange(of: homeDojo) { _, newValue in
                                                    showDojoSuggestions = !newValue.isEmpty && !filteredDojoSuggestions.isEmpty
                                                }

                                            if showDojoSuggestions && !filteredDojoSuggestions.isEmpty {
                                                ScrollView {
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        ForEach(filteredDojoSuggestions.prefix(5), id: \.self) { suggestion in
                                                            Button(action: {
                                                                homeDojo = suggestion
                                                                showDojoSuggestions = false
                                                            }) {
                                                                HStack {
                                                                    Text(suggestion)
                                                                        .font(.pixelifyBody)
                                                                        .foregroundColor(.white)
                                                                    Spacer()
                                                                }
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 12)
                                                                .background(Color.gray.opacity(0.2))
                                                            }
                                                            .buttonStyle(.plain)
                                                            Divider().background(Color.white.opacity(0.1))
                                                        }
                                                    }
                                                }
                                                .frame(maxHeight: 200)
                                                .background(Color.gray.opacity(0.3))
                                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                            }
                                        }
                                    } else {
                                        fieldDisplay(user.homeDojo ?? "Not set", muted: user.homeDojo == nil)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)

                            // Save / Cancel when editing
                            if isEditing {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        isEditing = false
                                        showDojoSuggestions = false
                                        loadUserData()
                                    }) {
                                        Text("CANCEL")
                                            .font(.pixelifyBodyBold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.red.opacity(0.7))
                                            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                    }
                                    .buttonStyle(PixelButtonStyle())

                                    Button(action: { saveAll() }) {
                                        HStack(spacing: 8) {
                                            if isLoading {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                                    .scaleEffect(0.8)
                                            }
                                            Text("SAVE")
                                                .font(.pixelifyBodyBold)
                                                .foregroundColor(.black)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.green)
                                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.4), lineWidth: 1))
                                    }
                                    .buttonStyle(PixelButtonStyle())
                                    .disabled(isLoading)
                                }
                                .padding(.horizontal, 20)
                            }

                            // Privacy toggle (always live)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PRIVACY")
                                    .font(.pixelify(size: 10, weight: .bold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Public Profile")
                                            .font(.pixelifyBody)
                                            .foregroundColor(.white)
                                        Text(isPublic ? "Visible in dojo & nickname search" : "Hidden from search (leaderboard shows ???)")
                                            .font(.pixelify(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { isPublic },
                                        set: { newValue in
                                            isPublic = newValue
                                            savePrivacy(newValue)
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(.yellow)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                .padding(.horizontal, 20)
                            }

                            // Messages
                            if let error = errorMessage {
                                Text(error)
                                    .font(.pixelifySmall)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 4)
                            }
                            if let success = successMessage {
                                Text(success)
                                    .font(.pixelifySmall)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 4)
                            }

                            // Invite Beta Testers Link
                            Button(action: { showBetaInvite = true }) {
                                HStack {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                    Text("Invite Beta Testers")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)

                            // About Link
                            Button(action: { showAbout = true }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                    Text("About DojoGo")
                                        .font(.pixelifyBody)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            Spacer()
                        }
                    }
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
                }
            }
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showBetaInvite) { BetaInviteView() }
        .onAppear {
            loadUserData()
            loadDojoNames()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func profileField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.pixelifyBodyBold)
                .foregroundColor(.white)
            content()
        }
    }

    private func fieldDisplay(_ text: String, muted: Bool = false) -> some View {
        Text(text)
            .font(.pixelifyBody)
            .foregroundColor(muted ? .gray : .white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.gray.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }

    private var rankStepper: some View {
        let currentIndex = rankCases.firstIndex(of: selectedRank) ?? 0
        return HStack(spacing: 0) {
            Button(action: {
                let prev = max(0, currentIndex - 1)
                selectedRank = rankCases[prev]
            }) {
                Text("−")
                    .font(.pixelifyBody)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 48)
                    .background(Color.gray.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(currentIndex == 0)

            Text(selectedRank.displayName)
                .font(.pixelifyBody)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.gray.opacity(0.3))
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))

            Button(action: {
                let next = min(rankCases.count - 1, currentIndex + 1)
                selectedRank = rankCases[next]
            }) {
                Text("+")
                    .font(.pixelifyBody)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 48)
                    .background(Color.gray.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(currentIndex == rankCases.count - 1)
        }
    }

    private var experienceStepper: some View {
        HStack(spacing: 12) {
            // Years
            VStack(alignment: .leading, spacing: 6) {
                Text("Years")
                    .font(.pixelify(size: 10))
                    .foregroundColor(.gray)
                HStack(spacing: 0) {
                    stepperButton("−") { if experienceYears > 0 { experienceYears -= 1 } }
                    Text("\(experienceYears)")
                        .font(.pixelifyBody)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.gray.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
                    stepperButton("+") { if experienceYears < 50 { experienceYears += 1 } }
                }
            }

            // Months
            VStack(alignment: .leading, spacing: 6) {
                Text("Months")
                    .font(.pixelify(size: 10))
                    .foregroundColor(.gray)
                HStack(spacing: 0) {
                    stepperButton("−") { if experienceMonths > 0 { experienceMonths -= 1 } }
                    Text("\(experienceMonths)")
                        .font(.pixelifyBody)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.gray.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
                    stepperButton("+") { if experienceMonths < 11 { experienceMonths += 1 } }
                }
            }
        }
    }

    private func stepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.pixelifyBody)
                .foregroundColor(.white)
                .frame(width: 36, height: 48)
                .background(Color.gray.opacity(0.3))
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
        }
        .buttonStyle(PixelButtonStyle())
    }

    // MARK: - Computed Properties

    private var filteredDojoSuggestions: [String] {
        guard !homeDojo.isEmpty else { return [] }
        let searchText = homeDojo.lowercased()
        return allDojoNames.filter { $0.lowercased().contains(searchText) }
    }

    // MARK: - Data Loading

    private func loadDojoNames() {
        allDojoNames = LocalStorageService.shared.getCachedDojoNames()
        if LocalStorageService.shared.shouldRefreshDojoNames() {
            Task {
                do {
                    let names = try await APIService.shared.getDojoNames()
                    await MainActor.run {
                        allDojoNames = names
                        LocalStorageService.shared.saveDojoNames(names)
                    }
                } catch {
                    print("Failed to fetch dojo names: \(error)")
                }
            }
        }
    }

    private func loadUserData() {
        guard let user = authViewModel.currentUser else { return }
        nickname = user.nickname ?? ""
        selectedRank = user.kendoRank ?? .unranked
        experienceYears = user.kendoExperienceYears
        experienceMonths = user.kendoExperienceMonths
        homeDojo = user.homeDojo ?? ""
        isPublic = user.isPublic
        let localAvatar = LocalStorageService.shared.getSelectedAvatar()
        let serverAvatar = user.avatar
        if serverAvatar == "kendoka" && localAvatar != "kendoka" && avatars.contains(localAvatar) {
            selectedAvatarIndex = avatars.firstIndex(of: localAvatar) ?? 0
            syncAvatar(localAvatar)
        } else {
            selectedAvatarIndex = avatars.firstIndex(of: serverAvatar) ?? 0
            LocalStorageService.shared.saveSelectedAvatar(serverAvatar)
        }
    }

    // MARK: - Avatar Sync

    private func syncAvatar(_ avatarName: String) {
        LocalStorageService.shared.saveSelectedAvatar(avatarName)
        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: nil, kendoRank: nil, experienceYears: nil,
                    experienceMonths: nil, avatar: avatarName
                )
                await MainActor.run {
                    LocalStorageService.shared.saveUser(updatedUser)
                    authViewModel.currentUser = updatedUser
                }
            } catch {
                print("Failed to sync avatar: \(error)")
            }
        }
    }

    // MARK: - Save

    private func saveAll() {
        guard let user = authViewModel.currentUser else { return }
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDojo = homeDojo.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: trimmedNickname.isEmpty ? nil : trimmedNickname,
                    kendoRank: selectedRank,
                    experienceYears: experienceYears,
                    experienceMonths: experienceMonths,
                    homeDojo: trimmedDojo.isEmpty ? nil : trimmedDojo
                )

                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    LocalStorageService.shared.saveUser(updatedUser)
                    if !trimmedDojo.isEmpty {
                        LocalStorageService.shared.addDojoNameToCache(trimmedDojo)
                        allDojoNames = LocalStorageService.shared.getCachedDojoNames()
                    }
                    successMessage = "Profile updated!"
                    isLoading = false
                    isEditing = false
                    showDojoSuggestions = false
                    loadUserData()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if error.localizedDescription.contains("already taken") {
                        errorMessage = "This nickname is already taken"
                    } else {
                        errorMessage = "Failed to save: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func savePrivacy(_ newValue: Bool) {
        Task {
            do {
                let updatedUser = try await APIService.shared.updateProfile(
                    nickname: nil, kendoRank: nil, experienceYears: nil,
                    experienceMonths: nil, isPublic: newValue
                )
                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    LocalStorageService.shared.saveUser(updatedUser)
                }
            } catch {
                await MainActor.run {
                    isPublic = !newValue
                    errorMessage = "Failed to update privacy setting"
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
