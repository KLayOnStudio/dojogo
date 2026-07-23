import SwiftUI

/// Speech bubble showing the komainu (guardian) info for a stage's torii gate:
/// whoever has swung it the most, their total, and how long they've held it.
/// More info (top-3 runners-up, etc.) can be added here later.
struct KomainuBubbleView: View {
    let entry: StageChampionsEntry?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private func description(swings: Int) -> String {
        "The komainu is the guardian of this gate, having fought off countless challengers through \(swings) swings. You could be the next one — it's waiting for you to step up!"
    }

    private let noKomainuDescription = "No komainu guards this gate yet. Be the first challenger to step up and claim it!"

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("KOMAINU")
                    .font(.pixelify(size: 12, weight: .bold))
                    .foregroundColor(.yellow)

                if let komainu = entry?.komainu {
                    Text(description(swings: komainu.totalSwings))
                        .font(.pixelify(size: 10))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().background(Color.white.opacity(0.2))

                    Text(komainu.displayName)
                        .font(.pixelify(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(komainu.totalSwings) SWINGS")
                        .font(.pixelify(size: 11, weight: .bold))
                        .foregroundColor(.green)

                    if let since = entry?.komainuSinceDate {
                        Text("SINCE \(Self.dateFormatter.string(from: since).uppercased())")
                            .font(.pixelify(size: 9))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(noKomainuDescription)
                        .font(.pixelify(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 220)
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
