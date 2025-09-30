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

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Direct Custom Font Tests:")
                            .font(.subheadline)
                            .foregroundColor(.blue)

                        Text("PixelifySans-Regular: The quick brown fox")
                            .font(.custom("PixelifySans-Regular", size: 18))

                        Text("PixelifySans-Bold: The quick brown fox")
                            .font(.custom("PixelifySans-Bold", size: 18))

                        Text("PixelifySans-SemiBold: The quick brown fox")
                            .font(.custom("PixelifySans-SemiBold", size: 18))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Extension Tests:")
                            .font(.subheadline)
                            .foregroundColor(.green)

                        Text("pixelifyBody: The quick brown fox")
                            .font(.pixelifyBody)

                        Text("pixelifyTitle: TITLE TEXT")
                            .font(.pixelifyTitle)

                        Text("pixelifyButton: BUTTON TEXT")
                            .font(.pixelifyButton)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Font Availability Check:")
                            .font(.subheadline)
                            .foregroundColor(.purple)

                        Text("Regular: \(UIFont(name: "PixelifySans-Regular", size: 16) != nil ? "✅ Available" : "❌ Not Found")")
                        Text("Bold: \(UIFont(name: "PixelifySans-Bold", size: 16) != nil ? "✅ Available" : "❌ Not Found")")
                        Text("SemiBold: \(UIFont(name: "PixelifySans-SemiBold", size: 16) != nil ? "✅ Available" : "❌ Not Found")")
                    }
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