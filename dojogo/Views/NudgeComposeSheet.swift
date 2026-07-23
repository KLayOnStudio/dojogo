import SwiftUI

private let nudgePresets = [
    "Time to pick up your shinai! ⚔️",
    "Don't break your streak! 🔥",
    "Let's train together today! 🥋"
]

/// Lightweight identity for anyone the nudge sheet can target — a nakama (FriendInfo)
/// or a leaderboard entry that may not be a friend yet.
struct NudgeTarget: Identifiable {
    let userId: String
    let displayName: String
    var id: String { userId }
}

enum NudgeSheetMode {
    case presets
    case cooldown
    case sendRequest
    case requestPending
}

struct NudgeComposeSheet: View {
    let target: NudgeTarget
    let mode: NudgeSheetMode
    var presets: [String] = nudgePresets
    let onSendMessage: (String) -> Void
    let onSendRequest: () -> Void
    @Environment(\.dismiss) var dismiss

    private var headerText: String {
        switch mode {
        case .presets: return "PICK A MESSAGE"
        case .cooldown: return "ALREADY NUDGED"
        case .sendRequest: return "NOT NAKAMA YET"
        case .requestPending: return "REQUEST SENT"
        }
    }

    private var cards: [String] {
        switch mode {
        case .presets:
            return presets
        case .cooldown:
            return ["Wait at least 2 minutes before nudging \(target.displayName) again."]
        case .sendRequest:
            return ["Send \(target.displayName) a nakama request"]
        case .requestPending:
            return ["You already sent \(target.displayName) a nakama request."]
        }
    }

    /// Cards that are purely informational (no action, just an OK to dismiss).
    private var isInformational: Bool {
        mode == .cooldown || mode == .requestPending
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("NUDGE \(target.displayName.uppercased())")
                    .font(.pixelifyBodyBold)
                    .foregroundColor(.white)
                    .padding(.top, 28)

                Text(headerText)
                    .font(.pixelify(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    ForEach(cards, id: \.self) { card in
                        Button(action: { handleTap(card) }) {
                            Text(card)
                                .font(.pixelifyBody)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                if isInformational {
                    Button(action: { dismiss() }) {
                        Text("OK")
                            .font(.pixelifyButton)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.yellow)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationBackground(.black)
    }

    private func handleTap(_ card: String) {
        switch mode {
        case .presets:
            onSendMessage(card)
            dismiss()
        case .sendRequest:
            onSendRequest()
            dismiss()
        case .cooldown, .requestPending:
            dismiss()
        }
    }
}
