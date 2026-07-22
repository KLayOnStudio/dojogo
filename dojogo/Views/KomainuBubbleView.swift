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

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("KOMAINU")
                    .font(.pixelify(size: 12, weight: .bold))
                    .foregroundColor(.yellow)

                if let komainu = entry?.komainu {
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
                    Text("No komainu yet")
                        .font(.pixelify(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
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
