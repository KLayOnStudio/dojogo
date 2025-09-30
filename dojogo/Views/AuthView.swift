import SwiftUI

struct AuthView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showFontDebug = false

    var body: some View {
        ZStack {
            // Retro dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Main Logo
                Image("MainLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)

                VStack(spacing: 20) {
                    // Sign Up Button
                    Button(action: {
                        authViewModel.signUp()
                    }) {
                        Text("SIGN UP")
                            .font(.pixelifyButtonLarge)
                            .foregroundColor(.black)
                            .frame(width: 200, height: 50)
                            .background(Color.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
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
                            .frame(width: 200, height: 50)
                            .background(Color.yellow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .disabled(authViewModel.isLoading)
                }

                if authViewModel.isLoading {
                    Text("LOADING...")
                        .font(.pixelifyCaption)
                        .foregroundColor(.white)
                }

                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.pixelifySmall)
                        .foregroundColor(.red)
                }

                // Debug button - remove this after fixing fonts
                Button("Debug Fonts") {
                    showFontDebug = true
                }
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.top, 20)

            }
        }
        .fullScreenCover(isPresented: $authViewModel.isAuthenticated) {
            MainMapView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showFontDebug) {
            FontDebugView()
        }
    }
}