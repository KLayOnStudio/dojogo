import SwiftUI

/// Speech bubble telling the story of a stage's komainu (guardian): it's a
/// title held by whoever has swung the gate the most, not a fixed character.
/// The current titleholder's name/swings/date live in the nameplate below
/// the icon (see KomainuFocusView) — this bubble is flavor text only.
struct KomainuBubbleView: View {
    let entry: StageChampionsEntry?

    private let assignedDescription = "Every swing drives away the four sicknesses — fear, hesitation, surprise, and doubt — that cling to this gate. Enough of them, and the komainu is summoned — its power now flows into the shinai of the one who called it forth."

    private let noKomainuDescription = "Every swing drives away the four sicknesses — fear, hesitation, surprise, and doubt — that cling to this gate. Strike enough, and you'll summon the komainu — awakening its power in your shinai."

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("KOMAINU")
                    .font(.pixelify(size: 14, weight: .bold))
                    .foregroundColor(.yellow)

                Text(entry?.komainu != nil ? assignedDescription : noKomainuDescription)
                    .font(.pixelify(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 260)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white, lineWidth: 2)
            )

            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 8)
        }
        .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
