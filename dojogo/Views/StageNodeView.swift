import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let swings: Int
    let isUnlocked: Bool
    let onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    private var progress: Double { stage.progress(swings: swings) }
    private var isCompleted: Bool { stage.isCompleted(swings: swings) }
    private var isCurrent: Bool { isUnlocked && !isCompleted }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Torii gate icon
                    Image("toriiGate")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 77, height: 77)
                        .saturation(isUnlocked ? 1.0 : 0.5)
                        .opacity(isUnlocked ? 1.0 : 0.8)

                    // Progress reveal (bottom-up)
                    if isUnlocked && progress > 0 {
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .fill(isCompleted ? Color.yellow : Color.white)
                                .frame(height: 77 * progress)
                        }
                        .frame(width: 77, height: 77)
                        .clipped()
                        .mask(
                            Image("toriiGate")
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 77, height: 77)
                        )
                    }

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .frame(width: 77, height: 77)
                .scaleEffect(pulseScale)

                // Progress count
                if isUnlocked {
                    Text("\(swings)/\(stage.swingsRequired)")
                        .font(.pixelify(size: 11, weight: .bold))
                        .foregroundColor(isCompleted ? .yellow : .white)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                }
            }
        }
        // Always tappable (locked stages show locked bubble)
        .onAppear {
            if isCurrent {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }
        }
    }
}
