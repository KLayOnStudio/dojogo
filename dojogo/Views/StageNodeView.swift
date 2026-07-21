import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let swings: Int
    let isUnlocked: Bool
    let onTap: () -> Void
    var showConquerorBanner: Bool = false

    @State private var pulseScale: CGFloat = 1.0

    private let size: CGFloat = 77

    private var rawProgress: Double {
        min(Double(swings) / Double(stage.swingsRequired), 1.0)
    }
    private var isCompleted: Bool { stage.isCompleted(swings: swings) }
    private var isCurrent: Bool { isUnlocked && !isCompleted }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Base: faded gate (transparent look when locked/in-progress)
                    Image("toriiGate")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .saturation(isUnlocked ? 0.3 : 0.2)
                        .opacity(isUnlocked ? 0.45 : 0.35)

                    // Overlay: full-color gate filled from bottom by progress
                    if isUnlocked && rawProgress > 0 {
                        Image("toriiGate")
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .mask(
                                VStack(spacing: 0) {
                                    Color.clear
                                        .frame(height: size * (1.0 - rawProgress))
                                    Color.black
                                        .frame(height: size * rawProgress)
                                }
                            )
                    }

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)
                    }
                }
                .frame(width: size, height: size)
                .scaleEffect(pulseScale)
                .overlay(alignment: .top) {
                    if showConquerorBanner {
                        // Drop an image named "toriiConquerorBanner" into Assets.xcassets
                        // to show it here — e.g. shide streamers with the winner's name.
                        Image("toriiConquerorBanner")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.9)
                            .offset(y: -34)
                    }
                }

                // Progress count
                if isUnlocked {
                    Text("\(min(swings, stage.swingsRequired))/\(stage.swingsRequired)")
                        .font(.pixelify(size: 11, weight: .bold))
                        .foregroundColor(isCompleted ? .yellow : .white)
                        .shadow(color: .black, radius: 2, x: 0, y: 1)
                }
            }
        }
        .onAppear {
            if isCurrent {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }
        }
    }
}
