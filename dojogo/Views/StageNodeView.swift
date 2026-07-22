import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let swings: Int
    let isUnlocked: Bool
    let onTap: () -> Void
    var championsEntry: StageChampionsEntry? = nil
    var showKomainu: Bool = false
    var showKomainuBubble: Binding<Bool>? = nil

    @State private var pulseScale: CGFloat = 1.0

    private let size: CGFloat = 77
    private var komainuSize: CGFloat { size / 2 }

    private var rawProgress: Double {
        min(Double(swings) / Double(stage.swingsRequired), 1.0)
    }
    private var isCompleted: Bool { stage.isCompleted(swings: swings) }
    private var isCurrent: Bool { isUnlocked && !isCompleted }

    var body: some View {
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
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .overlay(alignment: .bottomLeading) {
                if showKomainu {
                    // Komainu — guardian of this gate, standing beside it.
                    // Drop an image named "komainu" into Assets.xcassets to
                    // replace this placeholder icon automatically.
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showKomainuBubble?.wrappedValue.toggle()
                        }
                    }) {
                        komainuIcon
                            .frame(width: komainuSize, height: komainuSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: -komainuSize)
                    .overlay(alignment: .bottom) {
                        if showKomainuBubble?.wrappedValue == true {
                            KomainuBubbleView(entry: championsEntry)
                                .offset(y: -komainuSize - 10)
                        }
                    }
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
        .onAppear {
            if isCurrent {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }
        }
    }

    @ViewBuilder
    private var komainuIcon: some View {
        if UIImage(named: "komainu") != nil {
            Image("komainu")
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: komainuSize * 0.55))
                .foregroundColor(.yellow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
        }
    }
}
