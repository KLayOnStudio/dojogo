import SwiftUI

private let nudgePresets = [
    "Time to pick up your shinai! ⚔️",
    "Don't break your streak! 🔥",
    "Let's train together today! 🥋"
]

struct NudgeComposeSheet: View {
    let friend: FriendInfo
    let isOnCooldown: Bool
    let onSend: (String) -> Void
    @Environment(\.dismiss) var dismiss

    private var headerText: String {
        isOnCooldown ? "ALREADY NUDGED" : "PICK A MESSAGE"
    }

    private var cards: [String] {
        isOnCooldown
            ? ["Wait at least 2 minutes before nudging \(friend.displayName) again."]
            : nudgePresets
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("NUDGE \(friend.displayName.uppercased())")
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
                        Button(action: {
                            if isOnCooldown {
                                dismiss()
                            } else {
                                onSend(card)
                                dismiss()
                            }
                        }) {
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

                if isOnCooldown {
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
}
