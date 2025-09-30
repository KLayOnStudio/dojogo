import SwiftUI

struct FontDebugView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Font Debug Information")
                    .font(.headline)
                    .padding()

                // Test Pixelify fonts
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pixelify Font Tests:")
                        .font(.headline)

                    Text("PixelifySans-Regular")
                        .font(.custom("PixelifySans-Regular", size: 18))

                    Text("PixelifySans-Bold")
                        .font(.custom("PixelifySans-Bold", size: 18))

                    Text("PixelifySans-SemiBold")
                        .font(.custom("PixelifySans-SemiBold", size: 18))

                    Text("Using Extension - pixelifyBody")
                        .font(.pixelifyBody)

                    Text("Using Extension - pixelifyTitle")
                        .font(.pixelifyTitle)
                }
                .padding()
                .background(Color.gray.opacity(0.1))

                // List all available fonts
                VStack(alignment: .leading, spacing: 5) {
                    Text("All Available Fonts:")
                        .font(.headline)

                    ForEach(UIFont.familyNames.sorted(), id: \.self) { family in
                        VStack(alignment: .leading) {
                            Text(family)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)

                            ForEach(UIFont.fontNames(forFamilyName: family), id: \.self) { font in
                                Text(font)
                                    .font(.custom(font, size: 14))
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    FontDebugView()
}