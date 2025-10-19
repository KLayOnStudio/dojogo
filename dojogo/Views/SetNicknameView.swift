import SwiftUI

struct SetNicknameView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var nickname: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let isOptional: Bool // Can user skip this step?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    // Title
                    VStack(spacing: 12) {
                        Text("CHOOSE YOUR")
                            .font(.pixelifyBody)
                            .foregroundColor(.gray)

                        Text("NICKNAME")
                            .font(.pixelifyTitle)
                            .foregroundColor(.white)
                    }

                    // Subtitle
                    Text("This is how other players will see you")
                        .font(.pixelifySmall)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Nickname input
                    VStack(alignment: .leading, spacing: 8) {
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

                        Text("3-50 characters")
                            .font(.pixelify(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 40)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.pixelifySmall)
                            .foregroundColor(.red)
                            .padding(.horizontal, 40)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        // Set Nickname Button
                        Button(action: {
                            setNickname()
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.yellow)
                            } else {
                                Text("SET NICKNAME")
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
                        .disabled(isLoading || nickname.count < 3)
                        .opacity((isLoading || nickname.count < 3) ? 0.5 : 1.0)

                        // Skip button (if optional)
                        if isOptional {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("SKIP FOR NOW")
                                    .font(.pixelifySmall)
                                    .foregroundColor(.gray)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
            }
        }
    }

    private func setNickname() {
        guard nickname.count >= 3 && nickname.count <= 50 else {
            errorMessage = "Nickname must be 3-50 characters"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Update user with nickname
                let updatedUser = try await APIService.shared.updateNickname(nickname: nickname)

                await MainActor.run {
                    authViewModel.currentUser = updatedUser
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if error.localizedDescription.contains("already taken") {
                        errorMessage = "This nickname is already taken"
                    } else {
                        errorMessage = "Failed to set nickname. Please try again."
                    }
                }
            }
        }
    }
}

// Helper extension for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
