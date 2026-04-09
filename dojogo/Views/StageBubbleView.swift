import SwiftUI

struct StageBubbleView: View {
    let stage: Stage
    let swings: Int
    let isUnlocked: Bool
    let onHajime: () -> Void

    private var isCompleted: Bool { stage.isCompleted(swings: swings) }

    var body: some View {
        VStack(spacing: 0) {
            // Bubble content
            VStack(spacing: 8) {
                if isUnlocked {
                    unlockedContent
                } else {
                    lockedContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white, lineWidth: 2)
            )

            // Speech bubble tail
            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 8)
        }
        .fixedSize()
    }

    // MARK: - Unlocked

    private var unlockedContent: some View {
        VStack(spacing: 8) {
            Text(stage.name)
                .font(.pixelify(size: 14, weight: .bold))
                .foregroundColor(.white)

            // Mode info
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("GUIDED")
                        .font(.pixelify(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
                if stage.cueConfig.useRandomInterval {
                    HStack(spacing: 4) {
                        Text("RANDOM")
                            .font(.pixelify(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            // Progress
            Text("\(swings) / \(stage.swingsRequired)")
                .font(.pixelify(size: 12, weight: .bold))
                .foregroundColor(isCompleted ? .yellow : .white)

            // HAJIME button
            Button(action: onHajime) {
                Text("HAJIME!")
                    .font(.pixelify(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.white, lineWidth: 2)
                    )
            }
        }
        .frame(width: 160)
    }

    // MARK: - Locked

    private var lockedContent: some View {
        VStack(spacing: 6) {
            Text(stage.name)
                .font(.pixelify(size: 14, weight: .bold))
                .foregroundColor(.gray)

            Text(lockedMessage)
                .font(.pixelify(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 160)
    }

    private var lockedMessage: String {
        switch stage.id {
        case 2:
            return "Warm up first, then the path opens."
        case 3:
            return "Steady your blade before you press forward."
        case 4:
            return "Prove your pressure. The mountain awaits."
        case 5:
            return "Only those who endure may reach the summit."
        default:
            return "Clear the path ahead to continue."
        }
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
