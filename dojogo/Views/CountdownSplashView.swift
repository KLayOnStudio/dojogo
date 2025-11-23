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

            // Text overlay (KAMAETO! + Countdown)
            VStack(spacing: 20) {
                // KAMAETO! text
                Text("KAMAETO!")
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
