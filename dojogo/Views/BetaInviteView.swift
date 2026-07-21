import SwiftUI
import CoreImage.CIFilterBuiltins

private let testFlightLink = "https://testflight.apple.com/join/BVgq53xP"

struct BetaInviteView: View {
    @Environment(\.dismiss) var dismiss
    @State private var copied = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("← BACK")
                                .font(.pixelifyButton)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PixelButtonStyle())

                        Spacer()

                        Text("INVITE BETA")
                            .font(.pixelifyHeadline)
                            .foregroundColor(.white)

                        Spacer().frame(width: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, max(geometry.safeAreaInsets.top + 8, 20))

                    Text("Scan to join the DojoGo beta on TestFlight")
                        .font(.pixelifyBody)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let qrImage = Self.generateQRCode(from: testFlightLink) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(16)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.yellow, lineWidth: 2))
                    }

                    Button(action: {
                        UIPasteboard.general.string = testFlightLink
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }) {
                        HStack(spacing: 8) {
                            Text(testFlightLink)
                                .font(.pixelifySmall)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(copied ? .green : .gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
            }
        }
    }

    private static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
