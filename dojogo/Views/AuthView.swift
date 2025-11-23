import SwiftUI

struct AuthView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.3), .white]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()

                // Background image
                Image("MainLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 16) {
                        // Sign Up Button
                        Button(action: {
                            authViewModel.signUp()
                        }) {
                            Text("SIGN UP")
                                .font(.pixelifyButtonLarge)
                                .foregroundColor(.black)
                                .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                .frame(height: 56)
                                .background(Color.green)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 3)
                                )
                        }
                        .disabled(authViewModel.isLoading)

                        // Sign In Button
                        Button(action: {
                            authViewModel.signIn()
                        }) {
                            Text("SIGN IN")
                                .font(.pixelifyButtonLarge)
                                .foregroundColor(.black)
                                .frame(maxWidth: min(geometry.size.width * 0.7, 280))
                                .frame(height: 56)
                                .background(Color.yellow)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.white, lineWidth: 3)
                                )
                        }
                        .disabled(authViewModel.isLoading)
                    }
                    .padding(.horizontal, 20)

                    if authViewModel.isLoading {
                        Text("LOADING...")
                            .font(.pixelifyCaption)
                            .foregroundColor(.white)
                            .padding(.top, 24)
                    }

                    if let errorMessage = authViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.pixelifySmall)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 24)
                    }

                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .fullScreenCover(isPresented: $authViewModel.isAuthenticated) {
            MainMapView()
                .environmentObject(authViewModel)
        }
    }
}
