import SwiftUI

struct PixelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { AudioService.shared.playSFX(name: "sfx_tap") }
            }
    }
}
