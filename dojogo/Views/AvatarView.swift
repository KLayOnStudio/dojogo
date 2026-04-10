import SwiftUI

struct AvatarView: View {
    var avatarName: String = LocalStorageService.shared.getSelectedAvatar()

    var body: some View {
        Image(avatarName)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
    }
}
