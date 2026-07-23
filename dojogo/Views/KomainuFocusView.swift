import SwiftUI

/// Full-screen, centered "spotlight" for the komainu: an enlarged icon with
/// its info bubble above it, dimmed backdrop behind, dismissed by tapping
/// anywhere outside the pair.
struct KomainuFocusView: View {
    let entry: StageChampionsEntry?
    let onDismiss: () -> Void

    private let komainuSize: CGFloat = 140

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 12) {
                KomainuBubbleView(entry: entry)

                komainuIcon
                    .frame(width: komainuSize, height: komainuSize)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
}
