import SwiftUI

/// Fun, hype-y nudge presets for congratulating a stage's komainu — distinct
/// from the general "come train" presets in NudgeComposeSheet.
private let komainuNudgePresets = [
    "You go! Guardian of the gate! 🔥🔥",
    "That komainu title is well earned — keep it up! 👏",
    "LET'S GOOO! Defend that gate! 💪🛡️"
]

/// Full-screen, centered "spotlight" for the komainu: an enlarged icon with
/// its info bubble above it, dimmed backdrop behind, dismissed by tapping
/// anywhere outside the pair.
struct KomainuFocusView: View {
    let entry: StageChampionsEntry?
    let onDismiss: () -> Void

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var nudgeViewModel = NakamaViewModel()
    @State private var nudgeSheetKomainu: StageChampion?
    @State private var justRequestedUserIds: Set<String> = []

    private let komainuSize: CGFloat = 140
    private let jumpHeight: CGFloat = 24

    @State private var jumpScale: CGFloat = 1.0
    @State private var jumpOffset: CGFloat = 0
    private let jumpTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    @State private var nicknameColor: Color = .white

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded(onDismiss))

            VStack(spacing: 12) {
                KomainuBubbleView(entry: entry)

                komainuIcon
                    .frame(width: komainuSize, height: komainuSize)
                    .scaleEffect(jumpScale)
                    .offset(y: jumpOffset)
                    .onReceive(jumpTimer) { _ in performJump() }

                if let komainu = entry?.komainu {
                    nameplate(for: komainu)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .sheet(item: $nudgeSheetKomainu) { komainu in
            let target = NudgeTarget(userId: komainu.userId, displayName: komainu.displayName)
            let mode: NudgeSheetMode = {
                if komainu.isFriend {
                    return nudgeViewModel.isOnNudgeCooldown(userId: komainu.userId) ? .cooldown : .presets
                } else if komainu.isPending || justRequestedUserIds.contains(komainu.userId) {
                    return .requestPending
                } else {
                    return .sendRequest
                }
            }()
            NudgeComposeSheet(
                target: target,
                mode: mode,
                presets: komainuNudgePresets,
                onSendMessage: { message in
                    Task { await nudgeViewModel.sendNudge(toUserId: komainu.userId, message: message) }
                },
                onSendRequest: {
                    justRequestedUserIds.insert(komainu.userId)
                    Task { await nudgeViewModel.sendFriendRequest(toUserId: komainu.userId) }
                }
            )
        }
        .alert(
            "Couldn't do that",
            isPresented: Binding(
                get: { nudgeViewModel.errorMessage != nil },
                set: { if !$0 { nudgeViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(nudgeViewModel.errorMessage ?? "")
        }
    }

    private func performJump() {
        withAnimation(.easeOut(duration: 0.18)) {
            jumpScale = 1.3
            jumpOffset = -jumpHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeIn(duration: 0.18)) {
                jumpScale = 1.0
                jumpOffset = 0
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
                .font(.system(size: komainuSize * 0.5))
                .foregroundColor(.yellow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
        }
    }

    private func nameplate(for komainu: StageChampion) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(komainu.displayName)
                    .font(.pixelify(size: 24, weight: .bold))
                    .foregroundColor(nicknameColor)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            nicknameColor = .yellow
                        }
                    }

                if komainu.userId != authViewModel.currentUser?.id {
                    Button(action: { nudgeSheetKomainu = komainu }) {
                        Image("tegami")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .opacity(komainu.isFriend ? 0.85 : 0.4)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Text("\(komainu.totalSwings) SWINGS")
                    .font(.pixelify(size: 14, weight: .bold))
                    .foregroundColor(.green)

                if let since = entry?.komainuSinceDate {
                    Text("SINCE \(Self.dateFormatter.string(from: since).uppercased())")
                        .font(.pixelify(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
