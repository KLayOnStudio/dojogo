import SwiftUI

struct SplashView: View {
    @State private var showAuth = false

    var body: some View {
        ZStack {
            // Off white background
            Color(red: 0.98, green: 0.98, blue: 0.96)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Logo 1
                Image("Logo1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)

                // Logo 2
                Image("Logo2")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
            }
        }
        .onAppear {
            // Show splash for 2 seconds then transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showAuth = true
                }
            }
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthView()
        }
    }
}