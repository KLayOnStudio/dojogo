import SwiftUI

struct SensorModePickerView: View {
    @Binding var isPresented: Bool
    @State private var selected: SensorMode = LocalStorageService.shared.getLastSensorMode()
    let onConfirm: (SensorMode) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Text("HOW ARE YOU\nHOLDING YOUR PHONE?")
                        .font(.pixelifyHeadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 10) {
                        ForEach(SensorMode.allCases, id: \.self) { mode in
                            Button(action: { selected = mode }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.displayName)
                                            .font(.pixelifyBodyBold)
                                        Text(mode.detail)
                                            .font(.pixelify(size: 11))
                                            .opacity(0.7)
                                    }
                                    Spacer()
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(selected == mode ? Color.yellow : Color.white.opacity(0.4), lineWidth: 1)
                                            .frame(width: 20, height: 20)
                                        if selected == mode {
                                            Rectangle()
                                                .fill(Color.yellow)
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                }
                                .foregroundColor(selected == mode ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(selected == mode ? Color.white.opacity(0.08) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(selected == mode ? Color.yellow : Color.white.opacity(0.15), lineWidth: selected == mode ? 2 : 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                Button(action: {
                    LocalStorageService.shared.saveLastSensorMode(selected)
                    isPresented = false
                    onConfirm(selected)
                }) {
                    Text("CONFIRM")
                        .font(.pixelifyBodyBold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.yellow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}
