import SwiftUI

struct CountdownSplashView: View {
    @Binding var isPresented: Bool
    @State private var countdown = 3

    var onCountdownComplete: () -> Void

    var body: some View {
        ZStack {
            // Off white background (same as app loading splash)
            Color(red: 0.98, green: 0.98, blue: 0.96)
                .ignoresSafeArea()

            // Fixed position logos
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

            // Text overlay (KAMAE + Countdown)
            VStack(spacing: 20) {
                // KAMAE text
                Text("KAMAE")
                    .font(.pixelify(size: 72, weight: .bold))
                    .foregroundColor(.black)

                // Countdown number
                Text(countdown > 0 ? "\(countdown)" : "")
                    .font(.pixelify(size: 120, weight: .bold))
                    .foregroundColor(.red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        guard countdown > 0 else {
            // Countdown complete
            isPresented = false
            onCountdownComplete()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            // Trigger animation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            countdown -= 1
            startCountdown()
        }
    }
}
