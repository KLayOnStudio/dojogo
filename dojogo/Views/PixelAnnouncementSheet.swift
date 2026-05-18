import SwiftUI

private let sheetGreen = Color(red: 0x52/255, green: 0xB6/255, blue: 0x74/255)

struct PixelAnnouncementSheet: View {
    let title: String
    let message: String
    @Environment(\.dismiss) var dismiss

    private let logoSize: CGFloat = 64

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                HStack(alignment: .bottom, spacing: 0) {
                    Image("LogoPixel")
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)

                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.pixelifyBodyBold)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(message)
                                .font(.pixelifySmall)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(sheetGreen.opacity(0.05))
                        .overlay(
                            Image("SpeechBubbleBorder")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(sheetGreen.opacity(0.6))
                        )
                    }
                }
                .padding(.horizontal, 24)

                Button(action: { dismiss() }) {
                    Text("OK")
                        .font(.pixelifyButton)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PixelButtonStyle())
                .padding(.top, 24)

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.4)])
        .presentationBackground(.black)
    }
}
