import SwiftUI

struct SessionIntroView: View {
    @Binding var isPresented: Bool
    @State private var doNotShowAgain = false

    let onHajime: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    Text("HOW IT WORKS")
                        .font(.pixelifyHeadline)
                        .foregroundColor(.white)
                        .padding(.top, 48)
                        .padding(.bottom, 32)

                    // Flow chart
                    VStack(spacing: 0) {
                        flowStep(icon: "bell.fill",              color: .cyan,   title: "CUE",     detail: "A sound signals you to strike")
                        arrow
                        flowStep(icon: "figure.martial.arts",    color: .red,    title: "MEN",     detail: "Strike shomen with full spirit")
                        arrow
                        flowStep(icon: "arrow.up",               color: .yellow, title: "ZANSHIN", detail: "Hold position — keep your ki")
                        arrow
                        flowStep(icon: "arrow.counterclockwise", color: .green,  title: "RESET",   detail: "Step back to kamae and wait")
                    }
                    .padding(.horizontal, 32)

                    // Beta note
                    Text("During beta, we encourage forward men only — it helps us calibrate the sensor data.")
                        .font(.pixelify(size: 12))
                        .foregroundColor(.yellow.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 28)

                    // Do not show again
                    Button(action: { doNotShowAgain.toggle() }) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    .frame(width: 18, height: 18)
                                if doNotShowAgain {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                            }
                            Text("Do not show this again")
                                .font(.pixelifyBody)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    // Hajime button
                    Button(action: {
                        if doNotShowAgain {
                            LocalStorageService.shared.setSessionIntroSeen()
                        }
                        isPresented = false
                        onHajime()
                    }) {
                        Text("HAJIME!")
                            .font(.pixelifyTitle)
                            .foregroundColor(.black)
                            .frame(maxWidth: 200)
                            .frame(height: 64)
                            .background(Color.red)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 4)
                            )
                    }
                    .padding(.bottom, 48)
                }
            }
        }
    }

    private func flowStep(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.pixelify(size: 20, weight: .bold))
                    .foregroundColor(color)
                Text(detail)
                    .font(.pixelify(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private var arrow: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
    }
}
