// GuidedSessionOverlays.swift
// DojoGo - SwiftUI overlays for guided session cues
//
// Layers (all non-interactive):
//   1. Green flash — full-screen pulse on each cue
//   2. Phase text — "3", "2", "1", "Men!", "ZANSHIN", "RESET"

import SwiftUI

// MARK: - Green Flash Overlay

struct GreenFlashOverlay: View {
    let visible: Bool

    var body: some View {
        Color.green.opacity(visible ? 0.35 : 0)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.3), value: visible)
            .allowsHitTesting(false)
    }
}

// MARK: - Red Alert Overlay (persists after Men! cue until swing)

struct RedAlertOverlay: View {
    let phase: CueManager.Phase

    private var isActive: Bool {
        phase == .active || phase == .men || phase == .countdownGo
    }

    var body: some View {
        Color.red.opacity(isActive ? 0.25 : 0)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: isActive)
            .allowsHitTesting(false)
    }
}

// MARK: - Curtain Overlay

struct CurtainOverlay: View {
    let progress: CGFloat          // 0 → 1
    let direction: CueManager.CurtainDirection

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height * progress
            Color.white.opacity(0.25)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .position(
                    x: geo.size.width / 2,
                    y: direction == .bottomToTop
                        ? geo.size.height - height / 2
                        : height / 2
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Phase Text Overlay

struct PhaseTextOverlay: View {
    let phase: CueManager.Phase

    var body: some View {
        Group {
            switch phase {
            case .countdown(let n):
                Text("\(n)")
                    .font(.pixelify(size: 120, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .transition(.scale.combined(with: .opacity))

            case .countdownGo, .men:
                Text("Men!")
                    .font(.pixelify(size: 80, weight: .bold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))

            case .zanshin:
                Text("ZANSHIN")
                    .font(.pixelify(size: 48, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity)

            case .reset:
                Text("RESET")
                    .font(.pixelify(size: 48, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.8))
                    .transition(.opacity)

            case .earlySwing:
                Text("WAIT FOR CUE")
                    .font(.pixelify(size: 36, weight: .bold))
                    .foregroundColor(.red.opacity(0.9))
                    .transition(.scale.combined(with: .opacity))

            case .guidanceAbandoned:
                VStack(spacing: 12) {
                    Text("GUIDE OFF")
                        .font(.pixelify(size: 36, weight: .bold))
                        .foregroundColor(.red.opacity(0.9))
                    Text("Follow the cues or switch to free mode")
                        .font(.pixelify(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity)

            default:
                EmptyView()
            }
        }
        .animation(.easeOut(duration: 0.2), value: phaseKey)
    }

    private var phaseKey: String {
        switch phase {
        case .countdown(let n): return "cd_\(n)"
        case .countdownGo: return "go"
        case .men: return "men_\(UUID().uuidString.prefix(4))"
        case .zanshin: return "zanshin"
        case .reset: return "reset"
        case .ready: return "ready"
        case .earlySwing: return "early_\(UUID().uuidString.prefix(4))"
        case .guidanceAbandoned: return "abandoned"
        default: return "none"
        }
    }
}

// MARK: - Composite Overlay

struct GuidedSessionOverlays: View {
    @ObservedObject var cueManager: CueManager

    var body: some View {
        ZStack {
            CurtainOverlay(
                progress: cueManager.curtainProgress,
                direction: cueManager.curtainDirection
            )
            RedAlertOverlay(phase: cueManager.phase)
            GreenFlashOverlay(visible: cueManager.showGreenFlash)
            PhaseTextOverlay(phase: cueManager.phase)
        }
    }
}
